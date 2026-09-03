package com.opensubtitles.hasher.picker

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.opensubtitles.hasher.picker.ui.MovieBrowserActivity
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Android movie picker:
 * - Default: system Documents UI (no storage permission)
 * - safFolder: branded browser after SAF tree grant (Play-safe)
 * - mediaStore: branded browser when the host app declares + grants storage access
 */
internal class MoviePicker(
    private val contextProvider: () -> Context,
) {
    companion object {
        private const val TAG = "OshMoviePicker"
        private const val REQUEST_PICK_MOVIE = 9021
        private const val REQUEST_PICK_TREE = 9023
        private const val REQUEST_PERMISSION = 9022
        private const val PREFS_NAME = "osh_movie_picker"
        private const val PREF_LAST_TREE_URI = "last_tree_uri"
    }

    private var activityBinding: ActivityPluginBinding? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingOptions: MoviePickerOptions = MoviePickerOptions()
    private val mainHandler = Handler(Looper.getMainLooper())

    private val activityResultListener =
        PluginRegistry.ActivityResultListener { requestCode, resultCode, data ->
            onActivityResult(requestCode, resultCode, data)
        }

    private val permissionListener =
        PluginRegistry.RequestPermissionsResultListener { requestCode, _, grantResults ->
            if (requestCode != REQUEST_PERMISSION) return@RequestPermissionsResultListener false
            if (grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            ) {
                launchMediaStoreBrowser()
            } else {
                // Host opted into mediaStore but user denied — fall back.
                Log.w(TAG, "mediaStore permission denied; falling back to systemDocuments")
                launchSystemDocumentsPicker()
            }
            true
        }

    fun attachActivity(binding: ActivityPluginBinding) {
        activityBinding?.removeActivityResultListener(activityResultListener)
        activityBinding?.removeRequestPermissionsResultListener(permissionListener)
        activityBinding = binding
        binding.addActivityResultListener(activityResultListener)
        binding.addRequestPermissionsResultListener(permissionListener)
    }

    fun detachActivity() {
        activityBinding?.removeActivityResultListener(activityResultListener)
        activityBinding?.removeRequestPermissionsResultListener(permissionListener)
        activityBinding = null
        pendingResult?.success(null)
        pendingResult = null
    }

    fun pick(options: MoviePickerOptions, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("PICKER_BUSY", "File picker is already active", null)
            return
        }

        val activity = activityBinding?.activity
        if (activity == null) {
            result.error("NO_ACTIVITY", "No activity available", null)
            return
        }

        pendingResult = result
        pendingOptions = options
        Log.i(TAG, "pick mode=${options.mode}")

        when (options.mode) {
            PickerMode.SYSTEM_DOCUMENTS -> launchSystemDocumentsPicker()
            PickerMode.SAF_FOLDER -> launchSafFolderFlow(activity)
            PickerMode.MEDIA_STORE -> {
                if (hasVideoPermission(activity)) {
                    launchMediaStoreBrowser()
                } else {
                    // Host must declare the permission in their manifest.
                    // We only request at runtime when mediaStore is selected.
                    ActivityCompat.requestPermissions(
                        activity,
                        arrayOf(requiredPermission()),
                        REQUEST_PERMISSION,
                    )
                }
            }
        }
    }

    private fun launchSafFolderFlow(activity: Activity) {
        val saved = loadPersistedTreeUri(activity)
        if (saved != null) {
            Log.i(TAG, "Reusing persisted SAF tree: $saved")
            launchSafBrowser(saved)
            return
        }
        launchOpenDocumentTree(activity)
    }

    private fun launchOpenDocumentTree(activity: Activity) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        try {
            Log.i(TAG, "Launching OPEN_DOCUMENT_TREE")
            activity.startActivityForResult(intent, REQUEST_PICK_TREE)
        } catch (e: Exception) {
            Log.e(TAG, "OPEN_DOCUMENT_TREE failed", e)
            val result = pendingResult
            pendingResult = null
            result?.error("PICKER_FAILED", e.message, null)
        }
    }

    private fun launchSafBrowser(treeUri: Uri) {
        val activity = activityBinding?.activity ?: run {
            pendingResult?.error("NO_ACTIVITY", "No activity available", null)
            pendingResult = null
            return
        }

        try {
            val intent = MovieBrowserActivity.createSafIntent(
                activity,
                pendingOptions,
                treeUri,
            )
            Log.i(TAG, "Launching SAF MovieBrowserActivity for $treeUri")
            activity.startActivityForResult(intent, REQUEST_PICK_MOVIE)
        } catch (e: Exception) {
            Log.e(TAG, "SAF browser failed to start", e)
            val result = pendingResult
            pendingResult = null
            result?.error(
                "PICKER_FAILED",
                "Could not open folder browser: ${e.message}",
                null,
            )
        }
    }

    private fun hasVideoPermission(activity: Activity): Boolean {
        val permission = requiredPermission()
        return ContextCompat.checkSelfPermission(activity, permission) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requiredPermission(): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_VIDEO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
    }

    private fun launchMediaStoreBrowser() {
        val activity = activityBinding?.activity ?: run {
            pendingResult?.error("NO_ACTIVITY", "No activity available", null)
            pendingResult = null
            return
        }

        try {
            Log.i(TAG, "Launching MediaStore MovieBrowserActivity")
            activity.startActivityForResult(
                MovieBrowserActivity.createMediaStoreIntent(activity, pendingOptions),
                REQUEST_PICK_MOVIE,
            )
        } catch (e: Exception) {
            Log.e(TAG, "MediaStore browser failed to start", e)
            val result = pendingResult
            pendingResult = null
            result?.error(
                "PICKER_FAILED",
                "Could not open MediaStore browser: ${e.message}",
                null,
            )
        }
    }

    private fun launchSystemDocumentsPicker() {
        val activity = activityBinding?.activity ?: run {
            pendingResult?.error("NO_ACTIVITY", "No activity available", null)
            pendingResult = null
            return
        }

        val mimeTypes = pendingOptions.mimeTypes.ifEmpty { listOf("video/*") }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeTypes.first()
            if (mimeTypes.size > 1) {
                putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
            }
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            if (pendingOptions.takePersistablePermission) {
                addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            }
        }

        try {
            Log.i(TAG, "Launching systemDocuments picker")
            activity.startActivityForResult(intent, REQUEST_PICK_MOVIE)
        } catch (e: Exception) {
            val result = pendingResult
            pendingResult = null
            result?.error("PICKER_FAILED", e.message, null)
        }
    }

    private fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ): Boolean {
        if (requestCode == REQUEST_PICK_TREE) {
            return onTreePicked(resultCode, data)
        }
        if (requestCode != REQUEST_PICK_MOVIE) return false

        // User asked to change the SAF folder from the browser toolbar.
        if (resultCode == MovieBrowserActivity.RESULT_CHANGE_FOLDER) {
            clearPersistedTreeUri(contextProvider())
            val activity = activityBinding?.activity
            if (activity == null) {
                val result = pendingResult
                pendingResult = null
                result?.success(null)
                return true
            }
            mainHandler.post { launchOpenDocumentTree(activity) }
            return true
        }

        val result = pendingResult
        pendingResult = null
        if (result == null) return false

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(null)
            return true
        }

        val uriString = data.getStringExtra(MovieBrowserActivity.EXTRA_RESULT_URI)
            ?: data.data?.toString()
        if (uriString.isNullOrBlank()) {
            result.success(null)
            return true
        }

        val uri = Uri.parse(uriString)
        val options = pendingOptions
        val context = contextProvider()

        if (options.takePersistablePermission && data.data != null) {
            try {
                val takeFlags = data.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION
                if (takeFlags != 0) {
                    context.contentResolver.takePersistableUriPermission(uri, takeFlags)
                }
            } catch (_: SecurityException) {
                // MediaStore / some document URIs do not support persistable grants.
            }
        }

        try {
            val name = data.getStringExtra(MovieBrowserActivity.EXTRA_RESULT_NAME)
                ?: MovieFilterValidator.queryDisplayName(context, uri)
            val size = if (data.hasExtra(MovieBrowserActivity.EXTRA_RESULT_SIZE)) {
                data.getLongExtra(MovieBrowserActivity.EXTRA_RESULT_SIZE, -1L)
                    .takeIf { it >= 0L }
            } else {
                MovieFilterValidator.querySize(context, uri)
            }
            val durationFromBrowser =
                if (data.hasExtra(MovieBrowserActivity.EXTRA_RESULT_DURATION_MS)) {
                    data.getLongExtra(MovieBrowserActivity.EXTRA_RESULT_DURATION_MS, -1L)
                        .takeIf { it >= 0L }
                } else {
                    null
                }

            val durationMs = if (options.mode == PickerMode.SYSTEM_DOCUMENTS) {
                MovieFilterValidator.validate(context, uri, options)
                    ?: durationFromBrowser
            } else {
                durationFromBrowser
            }

            val payload = mutableMapOf<String, Any?>(
                "uri" to uri.toString(),
                "name" to name,
                "size" to size,
            )
            if (durationMs != null) {
                payload["durationMs"] = durationMs
            }
            result.success(payload)
        } catch (e: FilterRejectedException) {
            result.error(e.code, e.message, uri.toString())
        } catch (e: Exception) {
            result.error("PICKER_FAILED", e.message, uri.toString())
        }

        return true
    }

    private fun onTreePicked(resultCode: Int, data: Intent?): Boolean {
        if (pendingResult == null) return false

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            val result = pendingResult
            pendingResult = null
            result?.success(null)
            return true
        }

        val treeUri = data.data!!
        val context = contextProvider()
        try {
            val takeFlags = data.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION
            if (takeFlags != 0) {
                context.contentResolver.takePersistableUriPermission(treeUri, takeFlags)
            } else {
                context.contentResolver.takePersistableUriPermission(
                    treeUri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "takePersistableUriPermission failed; browsing may still work", e)
        }
        savePersistedTreeUri(context, treeUri)
        // Post so we are not starting another activity directly inside onActivityResult.
        mainHandler.post { launchSafBrowser(treeUri) }
        return true
    }

    private fun loadPersistedTreeUri(context: Context): Uri? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(PREF_LAST_TREE_URI, null) ?: return null
        val uri = Uri.parse(raw)
        val stillGranted = context.contentResolver.persistedUriPermissions.any {
            it.isReadPermission && (
                it.uri == uri ||
                    it.uri.toString() == uri.toString() ||
                    uri.toString().startsWith(it.uri.toString())
                )
        }
        if (!stillGranted) {
            Log.w(TAG, "Persisted SAF tree no longer granted: $uri")
            prefs.edit().remove(PREF_LAST_TREE_URI).apply()
            return null
        }
        return uri
    }

    private fun savePersistedTreeUri(context: Context, uri: Uri) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(PREF_LAST_TREE_URI, uri.toString())
            .apply()
    }

    private fun clearPersistedTreeUri(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(PREF_LAST_TREE_URI)
            .apply()
    }
}
