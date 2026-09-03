package com.opensubtitles.hasher.picker.mediastore

import android.net.Uri
import com.opensubtitles.hasher.picker.MoviePickerOptions

internal data class VideoFolder(
    val id: String,
    val name: String,
    val videoCount: Int,
)

internal data class VideoItem(
    val id: String,
    val uri: Uri,
    val name: String,
    val sizeBytes: Long,
    val durationMs: Long,
    val mimeType: String?,
)

internal interface VideoBrowserRepository {
    fun loadFolders(options: MoviePickerOptions): List<VideoFolder>

    fun loadVideosInFolder(folderId: String, options: MoviePickerOptions): List<VideoItem>
}
