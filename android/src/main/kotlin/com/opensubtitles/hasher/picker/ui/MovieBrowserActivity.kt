package com.opensubtitles.hasher.picker.ui

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Size
import android.provider.MediaStore
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.ProgressBar
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.core.graphics.ColorUtils
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updatePadding
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.appbar.MaterialToolbar
import com.opensubtitles.hasher.R
import com.opensubtitles.hasher.picker.MoviePickerOptions
import com.opensubtitles.hasher.picker.mediastore.MediaStoreVideoRepository
import com.opensubtitles.hasher.picker.mediastore.VideoFolder
import com.opensubtitles.hasher.picker.mediastore.VideoItem
import java.util.Locale
import java.util.concurrent.Executors
import kotlin.math.roundToInt

private val MARQUEE_REQUEST_TAG = R.id.osh_marquee_request_tag

/**
 * Folder browser: folders that contain matching videos → videos only.
 * Images and non-video files never appear (MediaStore.Video only).
 *
 * Draws edge-to-edge on Android 15+ and pads system bars via WindowInsets.
 */
class MovieBrowserActivity : AppCompatActivity() {

    companion object {
        const val EXTRA_RESULT_URI = "osh_uri"
        const val EXTRA_RESULT_NAME = "osh_name"
        const val EXTRA_RESULT_SIZE = "osh_size"
        const val EXTRA_RESULT_DURATION_MS = "osh_duration_ms"

        private const val EXTRA_MIN_SIZE = "minSizeBytes"
        private const val EXTRA_MAX_SIZE = "maxSizeBytes"
        private const val EXTRA_MIN_DURATION = "minDurationMs"
        private const val EXTRA_MAX_DURATION = "maxDurationMs"
        private const val EXTRA_MIME_TYPES = "mimeTypes"
        private const val EXTRA_TOOLBAR_COLOR_HEX = "toolbarColorHex"
        private const val EXTRA_TOOLBAR_ON_COLOR_HEX = "toolbarOnColorHex"
        private const val EXTRA_STATUS_BAR_COLOR_HEX = "statusBarColorHex"
        private const val EXTRA_ACCENT_COLOR_HEX = "accentColorHex"

        internal fun createIntent(context: Context, options: MoviePickerOptions): Intent {
            return Intent(context, MovieBrowserActivity::class.java).apply {
                options.minSizeBytes?.let { putExtra(EXTRA_MIN_SIZE, it) }
                options.maxSizeBytes?.let { putExtra(EXTRA_MAX_SIZE, it) }
                options.minDurationMs?.let { putExtra(EXTRA_MIN_DURATION, it) }
                options.maxDurationMs?.let { putExtra(EXTRA_MAX_DURATION, it) }
                putStringArrayListExtra(
                    EXTRA_MIME_TYPES,
                    ArrayList(options.mimeTypes),
                )
                options.toolbarColorHex?.let { putExtra(EXTRA_TOOLBAR_COLOR_HEX, it) }
                options.toolbarOnColorHex?.let { putExtra(EXTRA_TOOLBAR_ON_COLOR_HEX, it) }
                options.statusBarColorHex?.let { putExtra(EXTRA_STATUS_BAR_COLOR_HEX, it) }
                options.accentColorHex?.let { putExtra(EXTRA_ACCENT_COLOR_HEX, it) }
            }
        }
    }

    private lateinit var root: View
    private lateinit var statusScrim: View
    private lateinit var toolbar: MaterialToolbar
    private lateinit var content: View
    private lateinit var list: RecyclerView
    private lateinit var empty: TextView
    private lateinit var loading: ProgressBar

    private lateinit var repository: MediaStoreVideoRepository
    private lateinit var options: MoviePickerOptions

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private var showingFolders = true
    private var toolbarBaseColor: Int? = null
    private var accentColor: Int = Color.parseColor("#0B6E4F")

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.osh_activity_movie_browser)

        root = findViewById(R.id.osh_root)
        statusScrim = findViewById(R.id.osh_status_scrim)
        toolbar = findViewById(R.id.osh_toolbar)
        content = findViewById(R.id.osh_content)
        list = findViewById(R.id.osh_list)
        empty = findViewById(R.id.osh_empty)
        loading = findViewById(R.id.osh_loading)

        list.layoutManager = LinearLayoutManager(this)
        repository = MediaStoreVideoRepository(this)
        options = optionsFromIntent()
        applyCustomColors()
        applyWindowInsets()

        toolbar.setNavigationOnClickListener { navigateBack() }
        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    navigateBack()
                }
            },
        )

        showFolders()
    }

    private fun applyWindowInsets() {
        ViewCompat.setOnApplyWindowInsetsListener(root) { _, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            val cutout = insets.getInsets(WindowInsetsCompat.Type.displayCutout())

            val top = maxOf(systemBars.top, cutout.top)
            val bottom = maxOf(systemBars.bottom, cutout.bottom)
            val left = maxOf(systemBars.left, cutout.left)
            val right = maxOf(systemBars.right, cutout.right)

            statusScrim.layoutParams = statusScrim.layoutParams.apply { height = top }
            statusScrim.updatePadding(left = left, right = right)
            toolbar.updatePadding(left = left, top = 0, right = right, bottom = 0)
            content.updatePadding(left = left, top = 0, right = right, bottom = bottom)

            val listBottomPad = (4 * resources.displayMetrics.density).roundToInt()
            list.setPadding(
                list.paddingLeft,
                list.paddingTop,
                list.paddingRight,
                listBottomPad,
            )

            insets
        }
        ViewCompat.requestApplyInsets(root)
    }

    private fun navigateBack() {
        if (!showingFolders) {
            showFolders()
        } else {
            setResult(Activity.RESULT_CANCELED)
            finish()
        }
    }

    override fun onDestroy() {
        io.shutdownNow()
        super.onDestroy()
    }

    private fun optionsFromIntent(): MoviePickerOptions {
        val mime = intent.getStringArrayListExtra(EXTRA_MIME_TYPES)
        return MoviePickerOptions(
            mimeTypes = mime?.takeIf { it.isNotEmpty() } ?: listOf("video/*"),
            minSizeBytes = intent.longExtraOrNull(EXTRA_MIN_SIZE),
            maxSizeBytes = intent.longExtraOrNull(EXTRA_MAX_SIZE),
            minDurationMs = intent.longExtraOrNull(EXTRA_MIN_DURATION),
            maxDurationMs = intent.longExtraOrNull(EXTRA_MAX_DURATION),
            toolbarColorHex = intent.getStringExtra(EXTRA_TOOLBAR_COLOR_HEX),
            toolbarOnColorHex = intent.getStringExtra(EXTRA_TOOLBAR_ON_COLOR_HEX),
            statusBarColorHex = intent.getStringExtra(EXTRA_STATUS_BAR_COLOR_HEX),
            accentColorHex = intent.getStringExtra(EXTRA_ACCENT_COLOR_HEX),
        )
    }

    private fun Intent.longExtraOrNull(key: String): Long? =
        if (hasExtra(key)) getLongExtra(key, -1L).takeIf { it >= 0L } else null

    private fun applyCustomColors() {
        val defaultPrimary = Color.parseColor("#0B6E4F")
        val toolbarColor = parseColorOrNull(options.toolbarColorHex) ?: defaultPrimary
        val statusColor = parseColorOrNull(options.statusBarColorHex) ?: toolbarColor
        val onToolbar = parseColorOrNull(options.toolbarOnColorHex)

        toolbarBaseColor = toolbarColor
        accentColor = parseColorOrNull(options.accentColorHex) ?: toolbarColor

        statusScrim.setBackgroundColor(statusColor)
        toolbar.setBackgroundColor(toolbarColor)

        if (onToolbar != null) {
            toolbar.setTitleTextColor(onToolbar)
            toolbar.navigationIcon?.setTint(onToolbar)
        }

        val lightStatusIcons = ColorUtils.calculateLuminance(statusColor) >= 0.5
        WindowCompat.getInsetsController(window, window.decorView).apply {
            isAppearanceLightStatusBars = lightStatusIcons
            isAppearanceLightNavigationBars = false
        }
    }

    private fun parseColorOrNull(hex: String?): Int? {
        if (hex.isNullOrBlank()) return null
        return try {
            Color.parseColor(hex.trim())
        } catch (_: IllegalArgumentException) {
            null
        }
    }

    private fun showFolders() {
        showingFolders = true
        toolbar.title = getString(R.string.osh_folders_title)
        setLoading(true)

        io.execute {
            val folders = try {
                repository.loadFolders(options)
            } catch (_: SecurityException) {
                emptyList()
            }
            main.post {
                setLoading(false)
                if (folders.isEmpty()) {
                    list.adapter = null
                    empty.visibility = View.VISIBLE
                    empty.text = getString(R.string.osh_empty_folders)
                } else {
                    empty.visibility = View.GONE
                    list.adapter = FolderAdapter(folders, accentColor) { folder ->
                        showVideos(folder)
                    }
                }
            }
        }
    }

    private fun showVideos(folder: VideoFolder) {
        showingFolders = false
        toolbar.title = folder.name
        setLoading(true)

        io.execute {
            val videos = try {
                repository.loadVideosInFolder(folder.bucketId, options)
            } catch (_: SecurityException) {
                emptyList()
            }
            main.post {
                setLoading(false)
                if (videos.isEmpty()) {
                    list.adapter = null
                    empty.visibility = View.VISIBLE
                    empty.text = getString(R.string.osh_empty_videos)
                } else {
                    empty.visibility = View.GONE
                    list.adapter = VideoAdapter(videos, io, main) { video ->
                        finishWithVideo(video)
                    }
                }
            }
        }
    }

    private fun finishWithVideo(video: VideoItem) {
        val data = Intent().apply {
            putExtra(EXTRA_RESULT_URI, video.uri.toString())
            putExtra(EXTRA_RESULT_NAME, video.name)
            putExtra(EXTRA_RESULT_SIZE, video.sizeBytes)
            putExtra(EXTRA_RESULT_DURATION_MS, video.durationMs)
            this.data = video.uri
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        setResult(Activity.RESULT_OK, data)
        finish()
    }

    private fun setLoading(isLoading: Boolean) {
        loading.visibility = if (isLoading) View.VISIBLE else View.GONE
        if (isLoading) {
            empty.visibility = View.GONE
        }
    }

    private class FolderAdapter(
        private val items: List<VideoFolder>,
        private val accentColor: Int,
        private val onClick: (VideoFolder) -> Unit,
    ) : RecyclerView.Adapter<FolderAdapter.Holder>() {

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Holder {
            val view = LayoutInflater.from(parent.context)
                .inflate(R.layout.osh_item_folder, parent, false)
            return Holder(view)
        }

        override fun getItemCount(): Int = items.size

        override fun onBindViewHolder(holder: Holder, position: Int) {
            val item = items[position]
            startLoopingMarquee(holder.name, item.name)
            holder.count.text = holder.itemView.context.getString(
                R.string.osh_video_count,
                item.videoCount,
            )
            holder.icon.setColorFilter(accentColor)
            holder.iconBackground.background?.mutate()?.setTint(
                ColorUtils.setAlphaComponent(accentColor, 0x26),
            )
            holder.itemView.setOnClickListener { onClick(item) }
        }

        class Holder(view: View) : RecyclerView.ViewHolder(view) {
            val iconBackground: View = view.findViewById(R.id.osh_folder_icon_bg)
            val icon: ImageView = view.findViewById(R.id.osh_folder_icon)
            val name: TextView = view.findViewById(R.id.osh_folder_name)
            val count: TextView = view.findViewById(R.id.osh_folder_count)
        }
    }

    private class VideoAdapter(
        private val items: List<VideoItem>,
        private val io: java.util.concurrent.Executor,
        private val main: Handler,
        private val onClick: (VideoItem) -> Unit,
    ) : RecyclerView.Adapter<VideoAdapter.Holder>() {

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Holder {
            val view = LayoutInflater.from(parent.context)
                .inflate(R.layout.osh_item_video, parent, false)
            return Holder(view)
        }

        override fun getItemCount(): Int = items.size

        override fun onBindViewHolder(holder: Holder, position: Int) {
            val item = items[position]
            startLoopingMarquee(holder.name, item.name)
            holder.meta.text = formatMeta(item.durationMs, item.sizeBytes)
            holder.thumb.setImageDrawable(null)
            holder.thumb.tag = item.id

            io.execute {
                val bitmap = loadThumbnail(holder.itemView.context, item)
                main.post {
                    if (holder.thumb.tag == item.id && bitmap != null) {
                        holder.thumb.setImageBitmap(bitmap)
                    }
                }
            }

            holder.itemView.setOnClickListener { onClick(item) }
        }

        private fun loadThumbnail(context: Context, item: VideoItem): Bitmap? {
            return try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    context.contentResolver.loadThumbnail(
                        item.uri,
                        Size(144, 96),
                        null,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    MediaStore.Video.Thumbnails.getThumbnail(
                        context.contentResolver,
                        item.id,
                        MediaStore.Video.Thumbnails.MINI_KIND,
                        null,
                    )
                }
            } catch (_: Exception) {
                null
            }
        }

        private fun formatMeta(durationMs: Long, sizeBytes: Long): String {
            val duration = formatDuration(durationMs)
            val size = formatSize(sizeBytes)
            return "$duration · $size"
        }

        private fun formatDuration(ms: Long): String {
            val totalSec = (ms / 1000.0).roundToInt().coerceAtLeast(0)
            val h = totalSec / 3600
            val m = (totalSec % 3600) / 60
            val s = totalSec % 60
            return if (h > 0) {
                String.format(Locale.US, "%d:%02d:%02d", h, m, s)
            } else {
                String.format(Locale.US, "%d:%02d", m, s)
            }
        }

        private fun formatSize(bytes: Long): String {
            if (bytes < 1024) return "$bytes B"
            val kb = bytes / 1024.0
            if (kb < 1024) return String.format(Locale.US, "%.0f KB", kb)
            val mb = kb / 1024.0
            if (mb < 1024) return String.format(Locale.US, "%.1f MB", mb)
            val gb = mb / 1024.0
            return String.format(Locale.US, "%.2f GB", gb)
        }

        class Holder(view: View) : RecyclerView.ViewHolder(view) {
            val thumb: ImageView = view.findViewById(R.id.osh_video_thumb)
            val name: TextView = view.findViewById(R.id.osh_video_name)
            val meta: TextView = view.findViewById(R.id.osh_video_meta)
        }
    }
}

private fun startLoopingMarquee(label: TextView, text: String) {
    val requestId = (label.getTag(MARQUEE_REQUEST_TAG) as? Int ?: 0) + 1
    label.setTag(MARQUEE_REQUEST_TAG, requestId)
    label.isSelected = false
    label.ellipsize = android.text.TextUtils.TruncateAt.MARQUEE
    label.isSingleLine = true
    label.marqueeRepeatLimit = -1
    label.isHorizontalFadingEdgeEnabled = true
    label.setFadingEdgeLength((8 * label.resources.displayMetrics.density).toInt())
    label.text = text

    fun applyIfCurrent() {
        if (label.getTag(MARQUEE_REQUEST_TAG) != requestId) return
        val layout = label.layout
        val overflows = if (layout != null && label.width > 0) {
            layout.getLineWidth(0) > label.width
        } else {
            false
        }
        label.isSelected = overflows
    }

    label.post {
        if (label.width == 0) {
            label.post { applyIfCurrent() }
        } else {
            applyIfCurrent()
        }
    }
}
