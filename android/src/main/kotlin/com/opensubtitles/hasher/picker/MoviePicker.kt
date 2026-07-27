package com.opensubtitles.hasher.picker

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.opensubtitles.hasher.picker.ui.MovieBrowserActivity
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Android movie picker:
 * - Default: MediaStore folder browser (videos only - no images/docs)
 * - Optional: system Documents UI
 * - Falls back to Documents UI if MediaStore permission is denied
 */
internal class MoviePicker(
    private val contextProvider: () -> android.content.Context,
) {
    companion object {
        private const val REQUEST_PICK_MOVIE = 9021
        private const val REQUEST_PERMISSION = 9022
    }

    private var activityBinding: ActivityPluginBinding? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingOptions: MoviePickerOptions = MoviePickerOptions()

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
                // Still let the user pick via SAF (no permission required).
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

        when (options.mode) {
            PickerMode.SYSTEM_DOCUMENTS -> launchSystemDocumentsPicker()
            PickerMode.MEDIA_STORE -> {
                if (hasVideoPermission(activity)) {
                    launchMediaStoreBrowser()
                } else {
                    requestVideoPermission(activity)
                }
            }
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

    private fun requestVideoPermission(activity: Activity) {
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(requiredPermission()),
            REQUEST_PERMISSION,
        )
    }

    private fun launchMediaStoreBrowser() {
        val activity = activityBinding?.activity ?: run {
            pendingResult?.error("NO_ACTIVITY", "No activity available", null)
            pendingResult = null
            return
        }

        try {
            activity.startActivityForResult(
                MovieBrowserActivity.createIntent(activity, pendingOptions),
                REQUEST_PICK_MOVIE,
            )
        } catch (_: Exception) {
            launchSystemDocumentsPicker()
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
        if (requestCode != REQUEST_PICK_MOVIE) return false

        val result = pendingResult
        pendingResult = null
        if (result == null) return false

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(null)
            return true
        }

        // MediaStore browser returns extras; SAF returns data.data.
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
                context.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            } catch (_: SecurityException) {
                // MediaStore content URIs often don't support persistable grants.
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

            // SAF needs post-pick checks. MediaStore already filtered the list.
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
}
