package com.opensubtitles.hasher.picker

/**
 * Options for the movie picker, parsed from the Dart method-channel map.
 *
 * [mode] defaults to [PickerMode.MEDIA_STORE] (folder browser, videos only).
 * Size/duration/MIME filters are applied in the MediaStore query so unwanted
 * files never appear in the UI.
 */
internal enum class PickerMode {
    MEDIA_STORE,
    SYSTEM_DOCUMENTS,
}

internal data class MoviePickerOptions(
    val mimeTypes: List<String> = listOf("video/*"),
    val minSizeBytes: Long? = null,
    val maxSizeBytes: Long? = null,
    val minDurationMs: Long? = null,
    val maxDurationMs: Long? = null,
    val takePersistablePermission: Boolean = true,
    val mode: PickerMode = PickerMode.MEDIA_STORE,
    val toolbarColorHex: String? = null,
    val toolbarOnColorHex: String? = null,
    val statusBarColorHex: String? = null,
) {
    val hasDurationFilter: Boolean
        get() = minDurationMs != null || maxDurationMs != null

    companion object {
        @Suppress("UNCHECKED_CAST")
        fun fromChannelArgs(args: Map<*, *>?): MoviePickerOptions {
            if (args == null) return MoviePickerOptions()

            val mimeRaw = args["mimeTypes"]
            val mimeTypes = when (mimeRaw) {
                is List<*> -> mimeRaw.mapNotNull { it as? String }
                    .filter { it.isNotBlank() }
                    .ifEmpty { listOf("video/*") }
                else -> listOf("video/*")
            }

            val mode = when ((args["mode"] as? String)?.lowercase()) {
                "systemdocuments", "system_documents", "saf", "documents" ->
                    PickerMode.SYSTEM_DOCUMENTS
                else -> PickerMode.MEDIA_STORE
            }

            return MoviePickerOptions(
                mimeTypes = mimeTypes,
                minSizeBytes = (args["minSizeBytes"] as? Number)?.toLong(),
                maxSizeBytes = (args["maxSizeBytes"] as? Number)?.toLong(),
                minDurationMs = (args["minDurationMs"] as? Number)?.toLong(),
                maxDurationMs = (args["maxDurationMs"] as? Number)?.toLong(),
                takePersistablePermission =
                    args["takePersistablePermission"] as? Boolean ?: true,
                mode = mode,
                toolbarColorHex = args["toolbarColorHex"] as? String,
                toolbarOnColorHex = args["toolbarOnColorHex"] as? String,
                statusBarColorHex = args["statusBarColorHex"] as? String,
            )
        }
    }
}

internal class FilterRejectedException(
    val code: String,
    override val message: String,
) : Exception(message)
