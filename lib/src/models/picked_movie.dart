import 'parsed_video_name.dart';
import '../video_file_name_parser.dart';

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

  /// Filename used for title parsing (`name`, then path basename).
  String get displayName {
    final named = name?.trim();
    if (named != null && named.isNotEmpty) return named;
    final filePath = path?.trim();
    if (filePath == null || filePath.isEmpty) return '';
    final normalized = filePath.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash >= 0 ? normalized.substring(slash + 1) : normalized;
  }

  /// Title, year, and SxxExx metadata parsed from [displayName].
  ParsedVideoName get parsedName => VideoFileNameParser.parse(displayName);

  /// Clean title for an OpenSubtitles text search. Null when none could be parsed.
  String? get searchTitle {
    final title = parsedName.title;
    return title.isEmpty ? null : title;
  }

  @override
  String toString() =>
      'PickedMovie(uri: $uri, path: $path, name: $name, size: $size, '
      'duration: $duration)';

  @override
  bool operator ==(Object other) =>
      other is PickedMovie &&
      other.uri == uri &&
      other.path == path &&
      other.name == name &&
      other.size == size &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(uri, path, name, size, duration);
}
