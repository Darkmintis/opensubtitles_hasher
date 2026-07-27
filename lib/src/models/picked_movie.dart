/// A movie selected via [OpenSubtitlesHasher.pickMovie].
///
/// On Android the file is identified by a `content://` [uri] (zero-copy
/// hashing). On all other platforms a filesystem [path] is returned instead.
/// Use [effectivePath] to get whichever is available and pass it directly to
/// [OpenSubtitlesHasher.computeHashResult].
class PickedMovie {
  /// `content://` URI on Android.
  final String? uri;

  /// Filesystem path on iOS, macOS, Windows, and Linux.
  final String? path;

  /// Display name of the file.
  final String? name;

  /// Size in bytes, if the provider reported it.
  final int? size;

  /// Duration from media metadata (Android folder browser only).
  final Duration? duration;

  /// Creates a picked movie result.
  const PickedMovie({
    this.uri,
    this.path,
    this.name,
    this.size,
    this.duration,
  }) : assert(
          uri != null || path != null,
          'PickedMovie requires either a uri or a path',
        );

  /// The value to pass to [OpenSubtitlesHasher.computeHashResult].
  /// Prefers [uri] (Android zero-copy) over [path].
  String get effectivePath => uri ?? path!;

  @override
  String toString() =>
      'PickedMovie(uri: $uri, path: $path, name: $name, size: $size, '
      'duration: $duration)';
}
