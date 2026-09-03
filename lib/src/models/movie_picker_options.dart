/// How the Android movie picker presents files.
enum MoviePickerMode {
  /// System Documents UI with MIME filter. No storage permission required.
  /// Size/duration filters are checked after the user selects a file.
  ///
  /// Default mode. Play Store safe.
  systemDocuments,

  /// Branded folder browser after the user grants a folder via SAF
  /// (`OPEN_DOCUMENT_TREE`). Video-only list with the same filters and theme
  /// colors as [mediaStore]. No `READ_MEDIA_VIDEO` required.
  ///
  /// Recommended for Play apps that want a custom picker UI.
  safFolder,

  /// MediaStore folder browser across the whole device. Requires the **host
  /// app** to declare storage permissions (`READ_MEDIA_VIDEO` on API 33+).
  /// The plugin never declares those permissions. Falls back to
  /// [systemDocuments] if permission is missing.
  ///
  /// Not recommended for Google Play; use for sideload / non-Play builds.
  mediaStore,
}

/// Customizable options for the cross-platform movie picker.
///
/// Everything is optional. Defaults: [MoviePickerMode.systemDocuments], all
/// videos (`video/*`), no size or duration limits. Use [copyWith] to
/// tighten filters or switch modes.
///
/// ```dart
/// // Play-safe branded browser (Android)
/// await OpenSubtitlesHasher.pickMovie(
///   options: MoviePickerOptions.defaults.copyWith(
///     mode: MoviePickerMode.safFolder,
///     minDuration: Duration(minutes: 30),
///   ),
/// );
///
/// // System Documents UI (default)
/// await OpenSubtitlesHasher.pickMovie();
/// ```
class MoviePickerOptions {
  /// Default MIME filter: all video types.
  static const List<String> defaultMimeTypes = ['video/*'];

  /// Picker UI mode. Defaults to [MoviePickerMode.systemDocuments].
  final MoviePickerMode mode;

  /// MIME types to include. Folder browsers are always video-only; specific
  /// types (e.g. `video/mp4`) further narrow the list.
  final List<String> mimeTypes;

  /// Minimum file size in bytes (inclusive). `null` = no minimum.
  ///
  /// Folder browsers: applied when listing - smaller files never appear.
  final int? minSizeBytes;

  /// Maximum file size in bytes (inclusive). `null` = no maximum.
  final int? maxSizeBytes;

  /// Minimum media duration (inclusive). `null` = no minimum.
  ///
  /// Folder browsers: applied when listing - shorter videos never appear.
  final Duration? minDuration;

  /// Maximum media duration (inclusive). `null` = no maximum.
  final Duration? maxDuration;

  /// When true (default), requests a persistable read grant after Documents
  /// / SAF picks. MediaStore URIs often ignore this (still fine for hashing).
  final bool takePersistablePermission;

  /// Optional toolbar color for the Android folder browser UI
  /// ([safFolder] / [mediaStore]). Format: `#RRGGBB` or `#AARRGGBB`.
  final String? toolbarColorHex;

  /// Optional toolbar text/icon color for the Android folder browser UI.
  /// Format: `#RRGGBB` or `#AARRGGBB`.
  final String? toolbarOnColorHex;

  /// Optional status bar color for the Android folder browser UI.
  /// Format: `#RRGGBB` or `#AARRGGBB`.
  final String? statusBarColorHex;

  /// Optional accent color for folder icons and highlights in the Android
  /// folder browser UI. Format: `#RRGGBB` or `#AARRGGBB`.
  final String? accentColorHex;

  /// Creates picker options. Omit fields to keep package defaults.
  const MoviePickerOptions({
    this.mode = MoviePickerMode.systemDocuments,
    this.mimeTypes = defaultMimeTypes,
    this.minSizeBytes,
    this.maxSizeBytes,
    this.minDuration,
    this.maxDuration,
    this.takePersistablePermission = true,
    this.toolbarColorHex,
    this.toolbarOnColorHex,
    this.statusBarColorHex,
    this.accentColorHex,
  })  : assert(
          minSizeBytes == null || minSizeBytes >= 0,
          'minSizeBytes must be >= 0',
        ),
        assert(
          maxSizeBytes == null || maxSizeBytes >= 0,
          'maxSizeBytes must be >= 0',
        ),
        assert(
          minSizeBytes == null ||
              maxSizeBytes == null ||
              minSizeBytes <= maxSizeBytes,
          'minSizeBytes must be <= maxSizeBytes',
        );

  /// Package defaults: system Documents UI, `video/*`, no size/duration limits.
  static const defaults = MoviePickerOptions();

  /// Alias for [defaults].
  static const videos = defaults;

  /// Whether any size/duration filter is configured.
  bool get hasPostPickFilters =>
      minSizeBytes != null ||
      maxSizeBytes != null ||
      minDuration != null ||
      maxDuration != null;

  /// Returns a copy with selected fields replaced.
  MoviePickerOptions copyWith({
    MoviePickerMode? mode,
    List<String>? mimeTypes,
    int? minSizeBytes,
    int? maxSizeBytes,
    Duration? minDuration,
    Duration? maxDuration,
    bool? takePersistablePermission,
    String? toolbarColorHex,
    String? toolbarOnColorHex,
    String? statusBarColorHex,
    String? accentColorHex,
    bool clearMinSizeBytes = false,
    bool clearMaxSizeBytes = false,
    bool clearMinDuration = false,
    bool clearMaxDuration = false,
    bool clearToolbarColorHex = false,
    bool clearToolbarOnColorHex = false,
    bool clearStatusBarColorHex = false,
    bool clearAccentColorHex = false,
  }) {
    return MoviePickerOptions(
      mode: mode ?? this.mode,
      mimeTypes: mimeTypes ?? this.mimeTypes,
      minSizeBytes:
          clearMinSizeBytes ? null : (minSizeBytes ?? this.minSizeBytes),
      maxSizeBytes:
          clearMaxSizeBytes ? null : (maxSizeBytes ?? this.maxSizeBytes),
      minDuration: clearMinDuration ? null : (minDuration ?? this.minDuration),
      maxDuration: clearMaxDuration ? null : (maxDuration ?? this.maxDuration),
      takePersistablePermission:
          takePersistablePermission ?? this.takePersistablePermission,
      toolbarColorHex: clearToolbarColorHex
          ? null
          : (toolbarColorHex ?? this.toolbarColorHex),
      toolbarOnColorHex: clearToolbarOnColorHex
          ? null
          : (toolbarOnColorHex ?? this.toolbarOnColorHex),
      statusBarColorHex: clearStatusBarColorHex
          ? null
          : (statusBarColorHex ?? this.statusBarColorHex),
      accentColorHex:
          clearAccentColorHex ? null : (accentColorHex ?? this.accentColorHex),
    );
  }

  /// Serializes options for the Android method channel.
  Map<String, Object?> toChannelMap() => {
        'mode': switch (mode) {
          MoviePickerMode.systemDocuments => 'systemDocuments',
          MoviePickerMode.safFolder => 'safFolder',
          MoviePickerMode.mediaStore => 'mediaStore',
        },
        'mimeTypes': mimeTypes,
        'minSizeBytes': minSizeBytes,
        'maxSizeBytes': maxSizeBytes,
        'minDurationMs': minDuration?.inMilliseconds,
        'maxDurationMs': maxDuration?.inMilliseconds,
        'takePersistablePermission': takePersistablePermission,
        'toolbarColorHex': toolbarColorHex,
        'toolbarOnColorHex': toolbarOnColorHex,
        'statusBarColorHex': statusBarColorHex,
        'accentColorHex': accentColorHex,
      };
}
