import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'hasher.dart';
import 'models.dart';

/// Main entry point for OpenSubtitles hashing with automatic platform selection.
class OpenSubtitlesHasher {
  static const MethodChannel _nativeChannel = MethodChannel('opensubtitles_hasher');
  
  /// Computes hash from a file path or content URI.
  /// 
  /// Automatically selects the best method:
  /// - Android + content:// URI → Native (no copy, fast)
  /// - Everything else → Pure Dart (fast)
  static Future<HashResult> computeHashResult(String pathOrUri) async {
    // Modern Android with content URI → Use native
    if (!kIsWeb && Platform.isAndroid && pathOrUri.startsWith('content://')) {
      try {
        final result = await _nativeChannel.invokeMapMethod<String, dynamic>(
          'computeHash',
          {'uri': pathOrUri},
        );
        
        if (result == null) {
          throw Exception('Native hash computation failed');
        }
        
        return HashResult(
          hash: result['hash'] as String,
          fileSize: result['size'] as int,
          filePath: pathOrUri,
        );
      } catch (e) {
        // Fallback to Dart if native fails
        return await OpenSubtitlesHasherImpl.computeHashResult(pathOrUri);
      }
    }
    
    // Everything else → Use pure Dart
    return await OpenSubtitlesHasherImpl.computeHashResult(pathOrUri);
  }
  
  /// Convenience method for just the hash string.
  static Future<String> computeHash(String pathOrUri) async {
    final result = await computeHashResult(pathOrUri);
    return result.hash;
  }
}