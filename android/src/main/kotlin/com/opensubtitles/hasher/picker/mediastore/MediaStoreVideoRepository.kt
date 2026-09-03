package com.opensubtitles.hasher.picker.mediastore

import android.content.ContentUris
import android.content.Context
import android.os.Build
import android.provider.MediaStore
import com.opensubtitles.hasher.picker.MoviePickerOptions

/**
 * Queries [MediaStore.Video] only - images and documents never appear.
 * Size/duration/MIME filters are applied in the SQL selection so the UI
 * only lists files the app is willing to accept.
 *
 * Requires the host app to hold video/storage permission.
 */
internal class MediaStoreVideoRepository(
    private val context: Context,
) : VideoBrowserRepository {

    override fun loadFolders(options: MoviePickerOptions): List<VideoFolder> {
        val videos = queryVideos(options)
        return videos
            .groupBy { it.folderId to it.folderName }
            .map { (key, items) ->
                VideoFolder(
                    id = key.first,
                    name = key.second.ifBlank { "Movies" },
                    videoCount = items.size,
                )
            }
            .sortedBy { it.name.lowercase() }
    }

    override fun loadVideosInFolder(
        folderId: String,
        options: MoviePickerOptions,
    ): List<VideoItem> {
        return queryVideos(options, bucketId = folderId.toLongOrNull())
            .map { it.item }
            .sortedBy { it.name.lowercase() }
    }

    private data class QueriedVideo(
        val item: VideoItem,
        val folderId: String,
        val folderName: String,
    )

    private fun queryVideos(
        options: MoviePickerOptions,
        bucketId: Long? = null,
    ): List<QueriedVideo> {
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        }

        val projection = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.MIME_TYPE,
            MediaStore.Video.Media.BUCKET_ID,
            MediaStore.Video.Media.BUCKET_DISPLAY_NAME,
        )

        val selectionParts = mutableListOf<String>()
        val selectionArgs = mutableListOf<String>()

        selectionParts += "${MediaStore.Video.Media.SIZE} > 0"

        if (bucketId != null) {
            selectionParts += "${MediaStore.Video.Media.BUCKET_ID} = ?"
            selectionArgs += bucketId.toString()
        }

        options.minSizeBytes?.let {
            selectionParts += "${MediaStore.Video.Media.SIZE} >= ?"
            selectionArgs += it.toString()
        }
        options.maxSizeBytes?.let {
            selectionParts += "${MediaStore.Video.Media.SIZE} <= ?"
            selectionArgs += it.toString()
        }
        options.minDurationMs?.let {
            selectionParts += "${MediaStore.Video.Media.DURATION} >= ?"
            selectionArgs += it.toString()
        }
        options.maxDurationMs?.let {
            selectionParts += "${MediaStore.Video.Media.DURATION} <= ?"
            selectionArgs += it.toString()
        }

        val mimeFilters = options.mimeTypes
            .filter { it.isNotBlank() && it != "video/*" && !it.endsWith("/*") }
            .flatMap {
                when (it.lowercase()) {
                    "video/avi", "video/x-msvideo" ->
                        listOf("video/avi", "video/x-msvideo")
                    else -> listOf(it)
                }
            }
            .distinct()
        if (mimeFilters.isNotEmpty()) {
            val placeholders = mimeFilters.joinToString(",") { "?" }
            selectionParts += "${MediaStore.Video.Media.MIME_TYPE} IN ($placeholders)"
            selectionArgs.addAll(mimeFilters)
        } else {
            selectionParts += "${MediaStore.Video.Media.MIME_TYPE} LIKE ?"
            selectionArgs += "video/%"
        }

        val selection = selectionParts.joinToString(" AND ")
        val sortOrder = "${MediaStore.Video.Media.DATE_ADDED} DESC"

        val results = mutableListOf<QueriedVideo>()
        context.contentResolver.query(
            collection,
            projection,
            selection,
            selectionArgs.toTypedArray(),
            sortOrder,
        )?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
            val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
            val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
            val durationCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
            val mimeCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.MIME_TYPE)
            val bucketIdCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.BUCKET_ID)
            val bucketNameCol =
                cursor.getColumnIndexOrThrow(MediaStore.Video.Media.BUCKET_DISPLAY_NAME)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idCol)
                val uri = ContentUris.withAppendedId(collection, id)
                val folderId = cursor.getLong(bucketIdCol).toString()
                val folderName = cursor.getString(bucketNameCol) ?: ""
                results += QueriedVideo(
                    item = VideoItem(
                        id = id.toString(),
                        uri = uri,
                        name = cursor.getString(nameCol) ?: "video_$id",
                        sizeBytes = cursor.getLong(sizeCol),
                        durationMs = cursor.getLong(durationCol).coerceAtLeast(0L),
                        mimeType = cursor.getString(mimeCol),
                    ),
                    folderId = folderId,
                    folderName = folderName,
                )
            }
        }

        return results
    }
}
