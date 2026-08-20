import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../models.dart';

/// Picks a video file using the system file dialog on non-Android platforms.
///
/// Filters by extension derived from [MoviePickerOptions.mimeTypes].
/// Size filters are checked after the user picks a file.
/// Duration filters are not enforceable pre-pick on any platform.
class CrossPlatformPicker {
  CrossPlatformPicker._();

  /// Opens the platform file dialog and returns a picked video file.
  ///
  /// On non-Android platforms this is the backing implementation for
  /// [OpenSubtitlesHasher.pickMovie]. Returns `null` when the user cancels.
  static Future<PickedMovie?> pickMovie(MoviePickerOptions options) async {
    final extensions = _extensionsFromMimeTypes(options.mimeTypes);

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      withData: false,
      withReadStream: false,
      allowedExtensions: extensions,
    );

    if (result == null) return null;

    final file = result.files.single;
    final path = file.path;
    if (path == null || path.trim().isEmpty) return null;

    final pickedFile = File(path);
    if (!pickedFile.existsSync()) return null;

    final size = await pickedFile.length();
    if (options.minSizeBytes case final minSize? when size < minSize) {
      throw MovieFilterException(
        code: 'TOO_SMALL',
        message: 'Selected file is smaller than $minSize bytes',
        uri: path,
      );
    }
    if (options.maxSizeBytes case final maxSize? when size > maxSize) {
      throw MovieFilterException(
        code: 'TOO_LARGE',
        message: 'Selected file is larger than $maxSize bytes',
        uri: path,
      );
    }

    return PickedMovie(
      path: path,
      name: file.name,
      size: size,
    );
  }

  /// Converts MIME types like `video/mp4`, `video/x-matroska`, `video/*`
  /// into file extensions for `file_picker`.
  static List<String> _extensionsFromMimeTypes(List<String> mimeTypes) {
    // If only `video/*` (or wildcards), fall back to common video extensions.
    final specific = mimeTypes
        .where((m) => m.trim().isNotEmpty && !m.trim().endsWith('/*'))
        .map(_mimeToExtension)
        .whereType<String>()
        .map((e) => e.toLowerCase().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (specific.isNotEmpty) return specific;

    return ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'webm', 'm4v', 'ts', 'flv'];
  }

  static String? _mimeToExtension(String mime) {
    const map = {
      'video/mp4': 'mp4',
      'video/x-matroska': 'mkv',
      'video/avi': 'avi',
      'video/x-msvideo': 'avi',
      'video/quicktime': 'mov',
      'video/x-ms-wmv': 'wmv',
      'video/webm': 'webm',
      'video/x-m4v': 'm4v',
      'video/mp2t': 'ts',
      'video/x-flv': 'flv',
    };
    final normalized = mime.toLowerCase().trim();
    final mapped = map[normalized];
    if (mapped != null) return mapped;

    // Allow direct extension input too (e.g. "mkv", ".mp4").
    if (!normalized.contains('/')) {
      return normalized.startsWith('.') ? normalized.substring(1) : normalized;
    }

    final parts = normalized.split('/');
    if (parts.length != 2) return null;

    final top = parts[0];
    var subtype = parts[1];
    if (top != 'video' || subtype.isEmpty || subtype == '*') return null;

    // Common vendor prefix format: x-foo -> foo
    if (subtype.startsWith('x-') && subtype.length > 2) {
      subtype = subtype.substring(2);
    }

    // Strip optional suffixes: mp4+xml -> mp4
    final plus = subtype.indexOf('+');
    if (plus > 0) {
      subtype = subtype.substring(0, plus);
    }

    return subtype.isEmpty ? null : subtype;
  }
}
