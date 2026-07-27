/// How the Android movie picker presents files.
enum MoviePickerMode {
  /// Folder browser: lists only folders that contain matching videos, then
  /// videos in the selected folder.
  ///
  /// Images and documents never appear. [MoviePickerOptions] filters
  /// (duration, size, MIME) hide non-matching videos from the list.
  /// Requests video read permission; falls back to [systemDocuments] if
  /// denied.
  mediaStore,

  /// System Documents UI with MIME filter. No storage permission required.
  /// Size/duration filters are checked after the user selects a file.
  systemDocuments,
}

/// Customizable options for the native Android movie picker.
///
/// Everything is optional. Defaults: [MoviePickerMode.mediaStore], all
/// videos (`video/*`), no size or duration limits. Use [copyWith] to
/// tighten filters or switch modes.
///
/// ```dart
/// // Folder browser, only movies ≥ 120 minutes
/// await OpenSubtitlesHasher.pickMovie(
///   options: MoviePickerOptions.defaults.copyWith(
///     minDuration: Duration(minutes: 120),
///   ),
/// );
///
/// // Disable folder browser → system Documents UI
/// await OpenSubtitlesHasher.pickMovie(
///   options: MoviePickerOptions.defaults.copyWith(
///     mode: MoviePickerMode.systemDocuments,
///   ),
/// );
/// ```
class MoviePickerOptions {
  /// Default MIME filter: all video types.
  static const List<String> defaultMimeTypes = ['video/*'];

  /// Picker UI mode. Defaults to [MoviePickerMode.mediaStore] (folder browser).
  /// Set to [MoviePickerMode.systemDocuments] to disable the folder browser.
  final MoviePickerMode mode;

  /// MIME types to include. Folder browser is always video-only; specific
  /// types (e.g. `video/mp4`) further narrow the list.
  final List<String> mimeTypes;

  /// Minimum file size in bytes (inclusive). `null` = no minimum.
  ///
  /// Folder browser: applied in the query - smaller files never appear.
  final int? minSizeBytes;

  /// Maximum file size in bytes (inclusive). `null` = no maximum.
  final int? maxSizeBytes;

  /// Minimum media duration (inclusive). `null` = no minimum.
  ///
  /// Folder browser: applied in the query - shorter videos never appear.
  final Duration? minDuration;

  /// Maximum media duration (inclusive). `null` = no maximum.
  final Duration? maxDuration;

  /// When true (default), requests a persistable read grant after Documents
  /// picks. MediaStore URIs often ignore this (still fine for hashing).
  final bool takePersistablePermission;

  /// Optional toolbar color for the Android folder browser UI.
  /// Format: `#RRGGBB` or `#AARRGGBB`.
  final String? toolbarColorHex;

  /// Optional toolbar text/icon color for the Android folder browser UI.
  /// Format: `#RRGGBB` or `#AARRGGBB`.
  final String? toolbarOnColorHex;

  /// Optional status bar color for the Android folder browser UI.
  /// Format: `#RRGGBB` or `#AARRGGBB`.
  final String? statusBarColorHex;

  /// Creates picker options. Omit fields to keep package defaults.
  const MoviePickerOptions({
    this.mode = MoviePickerMode.mediaStore,
    this.mimeTypes = defaultMimeTypes,
    this.minSizeBytes,
    this.maxSizeBytes,
    this.minDuration,
    this.maxDuration,
    this.takePersistablePermission = true,
    this.toolbarColorHex,
    this.toolbarOnColorHex,
    this.statusBarColorHex,
  }) : assert(
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

  /// Package defaults: folder browser, `video/*`, no size/duration limits.
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
    bool clearMinSizeBytes = false,
    bool clearMaxSizeBytes = false,
    bool clearMinDuration = false,
    bool clearMaxDuration = false,
    bool clearToolbarColorHex = false,
    bool clearToolbarOnColorHex = false,
    bool clearStatusBarColorHex = false,
  }) {
    return MoviePickerOptions(
      mode: mode ?? this.mode,
      mimeTypes: mimeTypes ?? this.mimeTypes,
      minSizeBytes:
          clearMinSizeBytes ? null : (minSizeBytes ?? this.minSizeBytes),
      maxSizeBytes:
          clearMaxSizeBytes ? null : (maxSizeBytes ?? this.maxSizeBytes),
      minDuration:
          clearMinDuration ? null : (minDuration ?? this.minDuration),
      maxDuration:
          clearMaxDuration ? null : (maxDuration ?? this.maxDuration),
      takePersistablePermission:
          takePersistablePermission ?? this.takePersistablePermission,
      toolbarColorHex:
          clearToolbarColorHex ? null : (toolbarColorHex ?? this.toolbarColorHex),
      toolbarOnColorHex: clearToolbarOnColorHex
          ? null
          : (toolbarOnColorHex ?? this.toolbarOnColorHex),
      statusBarColorHex: clearStatusBarColorHex
          ? null
          : (statusBarColorHex ?? this.statusBarColorHex),
    );
  }

  /// Serializes options for the Android method channel.
  Map<String, Object?> toChannelMap() => {
        'mode': mode == MoviePickerMode.systemDocuments
            ? 'systemDocuments'
            : 'mediaStore',
        'mimeTypes': mimeTypes,
        'minSizeBytes': minSizeBytes,
        'maxSizeBytes': maxSizeBytes,
        'minDurationMs': minDuration?.inMilliseconds,
        'maxDurationMs': maxDuration?.inMilliseconds,
        'takePersistablePermission': takePersistablePermission,
        'toolbarColorHex': toolbarColorHex,
        'toolbarOnColorHex': toolbarOnColorHex,
        'statusBarColorHex': statusBarColorHex,
      };
}
