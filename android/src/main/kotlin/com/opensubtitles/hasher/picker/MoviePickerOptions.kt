package com.opensubtitles.hasher.picker

/**
 * Options for the movie picker, parsed from the Dart method-channel map.
 *
 * [mode] defaults to [PickerMode.SYSTEM_DOCUMENTS] (no storage permission).
 */
internal enum class PickerMode {
    SYSTEM_DOCUMENTS,
    SAF_FOLDER,
    MEDIA_STORE,
}

internal data class MoviePickerOptions(
    val mimeTypes: List<String> = listOf("video/*"),
    val minSizeBytes: Long? = null,
    val maxSizeBytes: Long? = null,
    val minDurationMs: Long? = null,
    val maxDurationMs: Long? = null,
    val takePersistablePermission: Boolean = true,
    val mode: PickerMode = PickerMode.SYSTEM_DOCUMENTS,
    val toolbarColorHex: String? = null,
    val toolbarOnColorHex: String? = null,
    val statusBarColorHex: String? = null,
    val accentColorHex: String? = null,
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
                "mediastore", "media_store" -> PickerMode.MEDIA_STORE
                "saffolder", "saf_folder", "saf", "tree", "documenttree" ->
                    PickerMode.SAF_FOLDER
                else -> PickerMode.SYSTEM_DOCUMENTS
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
                accentColorHex = args["accentColorHex"] as? String,
            )
        }
    }
}

internal class FilterRejectedException(
    val code: String,
    override val message: String,
) : Exception(message)
