/// A fast, pure Dart implementation of the OpenSubtitles hashing algorithm.
///
/// Computes the OpenSubtitles movie hash by reading only the first and last
/// 64 KB of a file — making it O(1) in memory and extremely fast even for
/// files larger than 50 GB.
///
/// ## Quick start
///
/// ```dart
/// import 'package:opensubtitles_hasher/opensubtitles_hasher.dart';
///
/// // Simple hash
/// final hash = await OpenSubtitlesHasher.computeHash('/path/to/movie.mp4');
///
/// // Hash + file size (for OpenSubtitles API)
/// final result = await OpenSubtitlesHasher.computeHashResult('/path/to/movie.mp4');
/// print(result.hash);       // "8e245d9679d31e12"
/// print(result.fileSize);   // 12345678
/// print(result.toApiMap()); // { 'moviehash': '...', 'moviebytesize': '...' }
/// ```
library opensubtitles_hasher;

export 'src/opensubtitles_hasher.dart';
export 'src/models.dart';