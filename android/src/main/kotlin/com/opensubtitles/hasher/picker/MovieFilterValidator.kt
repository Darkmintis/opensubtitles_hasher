package com.opensubtitles.hasher.picker

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.OpenableColumns

/**
 * Post-pick validation for size and duration filters.
 *
 * The Android document picker cannot hide files by duration/size in its UI;
 * MIME is the only pre-filter. Everything else is checked here.
 */
internal object MovieFilterValidator {
    fun validate(
        context: Context,
        uri: Uri,
        options: MoviePickerOptions,
    ): Long? {
        val size = querySize(context, uri)
        validateSize(size, options)

        if (!options.hasDurationFilter) {
            return null
        }

        val durationMs = readDurationMs(context, uri)
            ?: throw FilterRejectedException(
                "DURATION_UNAVAILABLE",
                "Could not read media duration for the selected file. " +
                    "Duration filters require a readable video.",
            )

        validateDuration(durationMs, options)
        return durationMs
    }

    private fun validateSize(size: Long?, options: MoviePickerOptions) {
        val min = options.minSizeBytes
        val max = options.maxSizeBytes
        if (min == null && max == null) return

        if (size == null) {
            throw FilterRejectedException(
                "FILTER_REJECTED",
                "Could not determine file size for filter check",
            )
        }

        if (min != null && size < min) {
            throw FilterRejectedException(
                "TOO_SMALL",
                "File is ${size} bytes; minimum allowed is $min bytes",
            )
        }

        if (max != null && size > max) {
            throw FilterRejectedException(
                "TOO_LARGE",
                "File is ${size} bytes; maximum allowed is $max bytes",
            )
        }
    }

    private fun validateDuration(durationMs: Long, options: MoviePickerOptions) {
        val min = options.minDurationMs
        val max = options.maxDurationMs

        if (min != null && durationMs < min) {
            throw FilterRejectedException(
                "TOO_SHORT",
                "Video is ${durationMs}ms; minimum allowed is ${min}ms",
            )
        }

        if (max != null && durationMs > max) {
            throw FilterRejectedException(
                "TOO_LONG",
                "Video is ${durationMs}ms; maximum allowed is ${max}ms",
            )
        }
    }

    fun querySize(context: Context, uri: Uri): Long? {
        val cursor = context.contentResolver.query(
            uri,
            arrayOf(OpenableColumns.SIZE),
            null,
            null,
            null,
        )
        cursor?.use {
            if (it.moveToFirst()) {
                val index = it.getColumnIndex(OpenableColumns.SIZE)
                if (index >= 0 && !it.isNull(index)) {
                    return it.getLong(index)
                }
            }
        }
        return null
    }

    fun queryDisplayName(context: Context, uri: Uri): String? {
        val cursor = context.contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )
        cursor?.use {
            if (it.moveToFirst()) {
                val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) {
                    return it.getString(index)
                }
            }
        }
        return uri.path?.substringAfterLast('/')
    }

    fun readDurationMs(context: Context, uri: Uri): Long? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(context, uri)
            retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull()
        } catch (_: Exception) {
            null
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
                // ignore
            }
        }
    }
}
