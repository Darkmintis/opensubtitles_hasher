package com.opensubtitles.hasher.picker.saf

import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import com.opensubtitles.hasher.picker.MovieFilterValidator
import com.opensubtitles.hasher.picker.MoviePickerOptions
import com.opensubtitles.hasher.picker.mediastore.VideoBrowserRepository
import com.opensubtitles.hasher.picker.mediastore.VideoFolder
import com.opensubtitles.hasher.picker.mediastore.VideoItem

/**
 * Lists videos under a SAF tree URI ([DocumentFile]). Images and non-video
 * documents are skipped. Size/MIME filters run first; duration filters use
 * [MovieFilterValidator.readDurationMs] when configured.
 */
internal class SafVideoRepository(
    private val context: Context,
    private val treeUri: Uri,
) : VideoBrowserRepository {

    private val root: DocumentFile?
        get() = DocumentFile.fromTreeUri(context, treeUri)

    override fun loadFolders(options: MoviePickerOptions): List<VideoFolder> {
        val rootDir = root ?: return emptyList()
        val folders = mutableListOf<VideoFolder>()

        val rootDirectVideos = listMatchingVideos(rootDir, options, recursive = false)
        if (rootDirectVideos.isNotEmpty()) {
            folders += VideoFolder(
                id = rootDir.uri.toString(),
                name = rootDir.name?.ifBlank { null } ?: "Movies",
                videoCount = rootDirectVideos.size,
            )
        }

        for (child in rootDir.listFiles()) {
            if (!child.isDirectory) continue
            val count = countMatchingVideos(child, options)
            if (count <= 0) continue
            folders += VideoFolder(
                id = child.uri.toString(),
                name = child.name?.ifBlank { null } ?: "Folder",
                videoCount = count,
            )
        }

        return folders.sortedBy { it.name.lowercase() }
    }

    override fun loadVideosInFolder(
        folderId: String,
        options: MoviePickerOptions,
    ): List<VideoItem> {
        val folder = resolveFolder(folderId) ?: return emptyList()
        val recursive = folder.uri.toString() != root?.uri?.toString()
        return listMatchingVideos(folder, options, recursive = recursive)
            .sortedBy { it.name.lowercase() }
    }

    private fun resolveFolder(folderId: String): DocumentFile? {
        val rootDir = root ?: return null
        if (rootDir.uri.toString() == folderId) return rootDir

        val fromSingle = DocumentFile.fromSingleUri(context, Uri.parse(folderId))
        if (fromSingle != null && fromSingle.exists() && fromSingle.isDirectory) {
            return fromSingle
        }

        return findDirectory(rootDir, folderId)
    }

    private fun findDirectory(dir: DocumentFile, folderId: String): DocumentFile? {
        for (child in dir.listFiles()) {
            if (!child.isDirectory) continue
            if (child.uri.toString() == folderId) return child
            findDirectory(child, folderId)?.let { return it }
        }
        return null
    }

    private fun countMatchingVideos(
        dir: DocumentFile,
        options: MoviePickerOptions,
    ): Int {
        var count = 0
        for (child in dir.listFiles()) {
            when {
                child.isDirectory -> count += countMatchingVideos(child, options)
                child.isFile && matchesFilters(child, options) != null -> count++
            }
        }
        return count
    }

    private fun listMatchingVideos(
        dir: DocumentFile,
        options: MoviePickerOptions,
        recursive: Boolean,
    ): List<VideoItem> {
        val results = mutableListOf<VideoItem>()
        for (child in dir.listFiles()) {
            when {
                child.isDirectory && recursive ->
                    results += listMatchingVideos(child, options, recursive = true)
                child.isFile -> {
                    val item = matchesFilters(child, options) ?: continue
                    results += item
                }
            }
        }
        return results
    }

    private fun matchesFilters(
        file: DocumentFile,
        options: MoviePickerOptions,
    ): VideoItem? {
        val mime = file.type
        if (!isVideoMime(mime, options.mimeTypes)) return null

        val size = file.length().coerceAtLeast(0L)
        if (size <= 0L) return null
        options.minSizeBytes?.let { if (size < it) return null }
        options.maxSizeBytes?.let { if (size > it) return null }

        var durationMs = 0L
        if (options.hasDurationFilter) {
            durationMs = MovieFilterValidator.readDurationMs(context, file.uri) ?: return null
            options.minDurationMs?.let { if (durationMs < it) return null }
            options.maxDurationMs?.let { if (durationMs > it) return null }
        }

        val name = file.name?.ifBlank { null } ?: "video"
        return VideoItem(
            id = file.uri.toString(),
            uri = file.uri,
            name = name,
            sizeBytes = size,
            durationMs = durationMs,
            mimeType = mime,
        )
    }

    private fun isVideoMime(mime: String?, allowed: List<String>): Boolean {
        if (mime.isNullOrBlank() || !mime.startsWith("video/", ignoreCase = true)) {
            return false
        }
        val specific = allowed
            .filter { it.isNotBlank() && it != "video/*" && !it.endsWith("/*") }
            .flatMap {
                when (it.lowercase()) {
                    "video/avi", "video/x-msvideo" ->
                        listOf("video/avi", "video/x-msvideo")
                    else -> listOf(it.lowercase())
                }
            }
            .distinct()
        if (specific.isEmpty()) return true
        return mime.lowercase() in specific
    }
}
