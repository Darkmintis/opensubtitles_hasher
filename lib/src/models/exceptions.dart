/// Thrown when a file is smaller than 64 KB (OpenSubtitles minimum).
class InvalidFileException implements Exception {
  /// Human-readable description.
  final String message;

  /// Path or URI that failed.
  final String path;

  /// Creates an exception for [path].
  const InvalidFileException(this.message, this.path);

  @override
  String toString() => 'InvalidFileException: $message (path: $path)';
}

/// Thrown when a picked file fails [MoviePickerOptions] filters.
///
/// The system picker cannot hide short/small files up front; this is raised
/// after selection when size or duration does not match the options.
class MovieFilterException implements Exception {
  /// Why the file was rejected (`TOO_SMALL`, `TOO_LARGE`, `TOO_SHORT`,
  /// `TOO_LONG`, `DURATION_UNAVAILABLE`, …).
  final String code;

  /// Human-readable description.
  final String message;

  /// URI or filesystem path that was rejected, if known.
  final String? uri;

  /// Creates a filter rejection.
  const MovieFilterException({
    required this.code,
    required this.message,
    this.uri,
  });

  @override
  String toString() => 'MovieFilterException($code): $message';
}
