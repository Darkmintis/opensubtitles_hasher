import 'package:flutter/services.dart';

import '../models.dart';

/// Thin MethodChannel bridge to the Android plugin.
class HasherChannel {
  HasherChannel._();

  static const MethodChannel _channel = MethodChannel('opensubtitles_hasher');

  /// Native zero-copy hash for a `content://` URI.
  static Future<HashResult> computeHash(String uri) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'computeHash',
        {'uri': uri},
      );

      if (result == null) {
        throw PlatformException(
          code: 'HASH_FAILED',
          message: 'Native hash computation returned null',
        );
      }

      final hash = result['hash'];
      final size = _asInt(result['size']);

      if (hash is! String || hash.length != 16) {
        throw PlatformException(
          code: 'HASH_FAILED',
          message: 'Native hash computation returned invalid hash',
        );
      }

      if (size == null || size <= 0) {
        throw PlatformException(
          code: 'HASH_FAILED',
          message: 'Native hash computation returned invalid file size',
        );
      }

      return HashResult(hash: hash, fileSize: size, filePath: uri);
    } on PlatformException catch (e) {
      if (e.code == 'FILE_TOO_SMALL') {
        throw InvalidFileException(
          e.message ??
              'File is too small for OpenSubtitles hashing. '
                  'Minimum size is 64 KB.',
          uri,
        );
      }
      rethrow;
    }
  }

  /// Native SAF movie picker with optional post-pick filters.
  static Future<PickedMovie?> pickMovie(MoviePickerOptions options) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'pickMovie',
        options.toChannelMap(),
      );

      if (result == null) {
        return null;
      }

      final uri = result['uri'];
      if (uri is! String || uri.isEmpty) {
        return null;
      }

      final durationMs = _asInt(result['durationMs']);

      return PickedMovie(
        uri: uri,
        name: result['name'] as String?,
        size: _asInt(result['size']),
        duration:
            durationMs != null ? Duration(milliseconds: durationMs) : null,
      );
    } on PlatformException catch (e) {
      if (_isFilterError(e.code)) {
        throw MovieFilterException(
          code: e.code,
          message: e.message ?? 'Selected file did not match picker filters',
          uri: e.details is String ? e.details as String : null,
        );
      }
      rethrow;
    }
  }

  static bool _isFilterError(String code) =>
      code == 'TOO_SMALL' ||
      code == 'TOO_LARGE' ||
      code == 'TOO_SHORT' ||
      code == 'TOO_LONG' ||
      code == 'DURATION_UNAVAILABLE' ||
      code == 'FILTER_REJECTED';

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
