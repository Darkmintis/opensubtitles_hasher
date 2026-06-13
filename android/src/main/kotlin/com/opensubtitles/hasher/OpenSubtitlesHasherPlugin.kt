package com.opensubtitles.hasher

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.min

class OpenSubtitlesHasherPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: android.content.Context
    private var activity: Activity? = null
    private var pendingPickResult: Result? = null

    companion object {
        private const val CHANNEL_NAME = "opensubtitles_hasher"
        private const val CHUNK_SIZE = 64 * 1024L
        private const val REQUEST_PICK_MOVIE = 9021
    }

    // ==================== FlutterPlugin Methods ====================

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "pickMovie" -> pickMovie(result)
            "computeHash" -> {
                val uriString = call.argument<String>("uri")
                if (uriString.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "uri is required", null)
                    return
                }

                try {
                    val payload = computeMovieHashFromUri(Uri.parse(uriString))
                    result.success(payload)
                } catch (e: Exception) {
                    result.error("HASH_FAILED", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // ==================== ActivityAware Methods ====================

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener { requestCode, resultCode, data ->
            onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onDetachedFromActivity() {
        activity = null
        pendingPickResult = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    // ==================== Native File Picker ====================

    private fun pickMovie(result: Result) {
        if (pendingPickResult != null) {
            result.error("PICKER_BUSY", "File picker is already active", null)
            return
        }

        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "No activity available", null)
            return
        }

        pendingPickResult = result

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "video/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }

        currentActivity.startActivityForResult(intent, REQUEST_PICK_MOVIE)
    }

    private fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK_MOVIE) {
            return false
        }

        val result = pendingPickResult
        pendingPickResult = null

        if (result == null) {
            return false
        }

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return true
        }

        val uri = data.data!!

        // Persist permission for future access
        try {
            context.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        } catch (_: SecurityException) {
            // Some providers don't support persistable permissions
        }

        val payload = mapOf(
            "uri" to uri.toString(),
            "name" to getFileName(uri),
            "size" to getFileSize(uri)
        )

        result.success(payload)
        return true
    }

    private fun getFileName(uri: Uri): String? {
        var name: String? = null
        val cursor = context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
        cursor?.use {
            if (it.moveToFirst()) {
                val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0) {
                    name = it.getString(nameIndex)
                }
            }
        }
        return name ?: uri.path?.substringAfterLast('/')
    }

    private fun getFileSize(uri: Uri): Long? {
        var size: Long? = null
        val cursor = context.contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)
        cursor?.use {
            if (it.moveToFirst()) {
                val sizeIndex = it.getColumnIndex(OpenableColumns.SIZE)
                if (sizeIndex >= 0 && !it.isNull(sizeIndex)) {
                    size = it.getLong(sizeIndex)
                }
            }
        }
        return size
    }

    // ==================== Native Hash Calculator ====================

    private fun computeMovieHashFromUri(uri: Uri): Map<String, Any> {
        val contentResolver = context.contentResolver
        val pfd = contentResolver.openFileDescriptor(uri, "r")
            ?: throw IllegalStateException("Cannot open file descriptor")

        pfd.use { fd ->
            FileInputStream(fd.fileDescriptor).channel.use { channel ->
                val size = channel.size()
                if (size <= 0L) {
                    throw IllegalStateException("Empty or unreadable file")
                }

                val firstLength = min(CHUNK_SIZE, size).toInt()
                val lastStart = if (size > CHUNK_SIZE) size - CHUNK_SIZE else 0L
                val lastLength = (size - lastStart).toInt()

                val first = readChunk(channel, 0L, firstLength)
                val last = readChunk(channel, lastStart, lastLength)

                var hash = size.toULong()
                hash = addChunk(hash, first)
                hash = addChunk(hash, last)

                val hashHex = hash.toString(16).padStart(16, '0')

                return mapOf(
                    "hash" to hashHex,
                    "size" to size,
                )
            }
        }
    }

    private fun readChunk(
        channel: java.nio.channels.FileChannel,
        position: Long,
        length: Int,
    ): ByteArray {
        val buffer = ByteBuffer.allocate(length)
        channel.position(position)

        while (buffer.hasRemaining()) {
            val read = channel.read(buffer)
            if (read <= 0) {
                throw IllegalStateException("Unexpected EOF while reading file")
            }
        }

        return buffer.array()
    }

    private fun addChunk(sum: ULong, bytes: ByteArray): ULong {
        var acc = sum
        val full = bytes.size - (bytes.size % 8)
        val wrapped = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)

        var i = 0
        while (i < full) {
            acc += wrapped.getLong(i).toULong()
            i += 8
        }

        while (i < bytes.size) {
            acc += bytes[i].toUByte().toULong()
            i += 1
        }

        return acc
    }
}