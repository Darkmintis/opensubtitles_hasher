import 'dart:io';

import 'package:flutter/foundation.dart';

import 'hasher.dart';
import 'models.dart';
import 'platform/cross_platform_picker.dart';
import 'platform/hasher_channel.dart';

/// OpenSubtitles hashing and movie picking for all platforms.
///
/// **Hashing**
/// - Filesystem paths → pure Dart (all platforms)
/// - Android `content://` URIs → native Kotlin (zero-copy)
///
/// **Picking**
/// - Android default → system Documents UI (`MoviePickerMode.systemDocuments`)
/// - Android branded → SAF folder browser (`MoviePickerMode.safFolder`)
/// - Android legacy → MediaStore when the host declares storage permissions
/// - iOS / macOS / Windows / Linux → system file dialog via `file_picker`
///
/// Single API for everything:
/// ```dart
/// final picked = await OpenSubtitlesHasher.pickMovie();
/// if (picked != null) {
///   final result = await OpenSubtitlesHasher.computeHashResult(
///     picked.effectivePath,
///   );
/// }
/// ```
class OpenSubtitlesHasher {
  OpenSubtitlesHasher._();

  /// Whether [pathOrUri] is an Android content URI.
  static bool isContentUri(String pathOrUri) =>
      pathOrUri.startsWith('content:');

  /// Computes hash from a filesystem path or Android `content://` URI.
  ///
  /// Routes to native Kotlin on Android for content URIs; pure Dart elsewhere.
  static Future<HashResult> computeHashResult(String pathOrUri) async {
    _ensureHashingSupported();
    if (!kIsWeb && Platform.isAndroid && isContentUri(pathOrUri)) {
      return HasherChannel.computeHash(pathOrUri);
    }
    return OpenSubtitlesHasherImpl.computeHashResult(pathOrUri);
  }

  /// Convenience: hash string only.
  static Future<String> computeHash(String pathOrUri) async {
    final result = await computeHashResult(pathOrUri);
    return result.hash;
  }

  /// Synchronous hashing for filesystem paths (Dart only).
  ///
  /// Does not support Android `content://` URIs.
  static String computeHashSync(String path) {
    _ensureHashingSupported();
    return OpenSubtitlesHasherImpl.computeHashSync(path);
  }

  /// Hashes a [File] via the Dart implementation.
  static Future<String> computeFileHash(File file) {
    _ensureHashingSupported();
    return OpenSubtitlesHasherImpl.computeFileHash(file);
  }

  /// Returns true if [hash] is 16 lowercase hex characters.
  static bool isValidHash(String hash) =>
      OpenSubtitlesHasherImpl.isValidHash(hash);

  /// Parses a video filename into a search title, year, and SxxExx metadata.
  static ParsedVideoName parseFileName(String fileName) =>
      VideoFileNameParser.parse(fileName);

  /// Picks a movie on any platform and returns a [PickedMovie].
  ///
  /// - **Android** - folder browser (MediaStore, videos only). Duration, size,
  ///   MIME, and color filters all apply. Falls back to system Documents UI if
  ///   permission is denied.
  /// - **iOS / macOS / Windows / Linux** - system file dialog filtered by
  ///   video extension. Size limits are checked after selection; duration
  ///   limits cannot be checked because duration metadata is unavailable.
  ///
  /// Returns `null` if the user cancels.
  ///
  /// Throws [MovieFilterException] when an Android Documents-mode pick fails
  /// post-pick size/duration filters.
  ///
  /// [options] defaults to [MoviePickerOptions.defaults] (all videos, no
  /// size/duration limits). Use [MoviePickerOptions.copyWith] to customise.
  ///
  /// ```dart
  /// final picked = await OpenSubtitlesHasher.pickMovie(
  ///   options: MoviePickerOptions.defaults.copyWith(
  ///     mode: MoviePickerMode.safFolder, // branded Play-safe browser
  ///     minDuration: Duration(minutes: 30),
  ///     toolbarColorHex: '#F5A623',
  ///   ),
  /// );
  /// if (picked != null) {
  ///   final hash = await OpenSubtitlesHasher.computeHashResult(
  ///     picked.effectivePath,
  ///   );
  /// }
  /// ```
  static Future<PickedMovie?> pickMovie({
    MoviePickerOptions options = MoviePickerOptions.defaults,
  }) async {
    _validateOptions(options);
    if (kIsWeb) {
      throw UnsupportedError('pickMovie() is not supported on web.');
    }

    if (Platform.isAndroid) {
      return HasherChannel.pickMovie(options);
    }

    // iOS, macOS, Windows, Linux - system file dialog.
    return CrossPlatformPicker.pickMovie(options);
  }

  /// Picks a movie and computes its hash in one call (all platforms).
  ///
  /// Returns `null` if the user cancels. Same rules as [pickMovie].
  static Future<({PickedMovie movie, HashResult hash})?> pickAndHash({
    MoviePickerOptions options = MoviePickerOptions.defaults,
  }) async {
    final movie = await pickMovie(options: options);
    if (movie == null) return null;

    final hash = await computeHashResult(movie.effectivePath);
    return (movie: movie, hash: hash);
  }

  static void _ensureHashingSupported() {
    if (kIsWeb) {
      throw UnsupportedError(
        'OpenSubtitles hashing is not supported on web because browsers do '
        'not provide random access to filesystem paths.',
      );
    }
  }

  static void _validateOptions(MoviePickerOptions options) {
    final minDuration = options.minDuration;
    final maxDuration = options.maxDuration;

    if (minDuration != null && minDuration.isNegative) {
      throw ArgumentError.value(
        minDuration,
        'options.minDuration',
        'must be greater than or equal to zero',
      );
    }
    if (maxDuration != null && maxDuration.isNegative) {
      throw ArgumentError.value(
        maxDuration,
        'options.maxDuration',
        'must be greater than or equal to zero',
      );
    }
    if (minDuration != null &&
        maxDuration != null &&
        minDuration > maxDuration) {
      throw ArgumentError(
        'options.minDuration must be less than or equal to '
        'options.maxDuration',
      );
    }
  }
}
