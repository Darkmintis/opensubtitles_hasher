package com.opensubtitles.hasher.hash

import android.content.Context
import android.net.Uri
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors

/**
 * OpenSubtitles movie hash: size + sum(first 64KB LE uint64) + sum(last 64KB).
 * Reads only 128 KB via a seekable file descriptor - no full-file copy.
 */
internal object HashCalculator {
    private const val CHUNK_SIZE = 64 * 1024L

    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "opensubtitles-hasher").apply { isDaemon = true }
    }

    fun computeAsync(
        context: Context,
        uri: Uri,
        onSuccess: (Map<String, Any>) -> Unit,
        onError: (code: String, message: String?) -> Unit,
    ) {
        executor.execute {
            try {
                val payload = compute(context, uri)
                onSuccess(payload)
            } catch (e: FileTooSmallException) {
                onError(
                    "FILE_TOO_SMALL",
                    "File is too small for OpenSubtitles hashing. " +
                        "Minimum size is 64 KB, got ${e.size} bytes.",
                )
            } catch (e: Exception) {
                onError("HASH_FAILED", e.message)
            }
        }
    }

    fun compute(context: Context, uri: Uri): Map<String, Any> {
        val pfd = context.contentResolver.openFileDescriptor(uri, "r")
            ?: throw IllegalStateException(
                "Cannot open file descriptor (URI may not be seekable)",
            )

        pfd.use { fd ->
            FileInputStream(fd.fileDescriptor).channel.use { channel ->
                val size = channel.size()
                if (size <= 0L) {
                    throw IllegalStateException("Empty or unreadable file")
                }
                if (size < CHUNK_SIZE) {
                    throw FileTooSmallException(size)
                }

                val first = readChunk(channel, 0L, CHUNK_SIZE.toInt())
                val last = readChunk(channel, size - CHUNK_SIZE, CHUNK_SIZE.toInt())

                var hash = size.toULong()
                hash = addChunk(hash, first)
                hash = addChunk(hash, last)

                return mapOf(
                    "hash" to hash.toString(16).padStart(16, '0'),
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

        return acc
    }

    private class FileTooSmallException(val size: Long) : Exception()
}
