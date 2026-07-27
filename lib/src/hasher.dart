import 'dart:io';
import 'dart:typed_data';

import 'models.dart';

/// Chunk size for OpenSubtitles hashing (64 KB).
const int kOpenSubtitlesChunkSize = 65536;

const int _int64Count = kOpenSubtitlesChunkSize ~/ 8;

/// Pure Dart OpenSubtitles hash implementation (filesystem paths).
///
/// Prefer [OpenSubtitlesHasher] for platform-aware hashing.
class OpenSubtitlesHasherImpl {
  OpenSubtitlesHasherImpl._();

  /// Async hash for a filesystem [path].
  static Future<String> computeHash(String path) async {
    final result = await computeHashResult(path);
    return result.hash;
  }

  /// Sync hash for a filesystem [path].
  static String computeHashSync(String path) {
    final file = File(path);

    if (!file.existsSync()) {
      throw FileSystemException('File not found', path);
    }

    final raf = file.openSync(mode: FileMode.read);

    try {
      final fileSize = raf.lengthSync();
      _ensureMinSize(fileSize, path);

      raf.setPositionSync(0);
      final headBytes = raf.readSync(kOpenSubtitlesChunkSize);
      _validateChunk(headBytes, path);

      raf.setPositionSync(fileSize - kOpenSubtitlesChunkSize);
      final tailBytes = raf.readSync(kOpenSubtitlesChunkSize);
      _validateChunk(tailBytes, path);

      return _toHex(_computeHashValue(fileSize, headBytes, tailBytes));
    } finally {
      raf.closeSync();
    }
  }

  /// Hash a [File] path via Dart.
  static Future<String> computeFileHash(File file) => computeHash(file.path);

  /// Hash + size for OpenSubtitles API calls.
  static Future<HashResult> computeHashResult(String path) async {
    final file = File(path);

    // ignore: avoid_slow_async_io
    if (!await file.exists()) {
      throw FileSystemException('File not found', path);
    }

    final raf = await file.open(mode: FileMode.read);

    try {
      final fileSize = await raf.length();
      _ensureMinSize(fileSize, path);

      await raf.setPosition(0);
      final headBytes = await raf.read(kOpenSubtitlesChunkSize);
      _validateChunk(headBytes, path);

      await raf.setPosition(fileSize - kOpenSubtitlesChunkSize);
      final tailBytes = await raf.read(kOpenSubtitlesChunkSize);
      _validateChunk(tailBytes, path);

      return HashResult(
        hash: _toHex(_computeHashValue(fileSize, headBytes, tailBytes)),
        fileSize: fileSize,
        filePath: path,
      );
    } finally {
      await raf.close();
    }
  }

  /// Validates a 16-char lowercase hex OpenSubtitles hash.
  static bool isValidHash(String hash) {
    if (hash.length != 16) return false;
    return RegExp(r'^[0-9a-f]{16}$').hasMatch(hash);
  }

  static void _ensureMinSize(int fileSize, String path) {
    if (fileSize < kOpenSubtitlesChunkSize) {
      throw InvalidFileException(
        'File is too small for OpenSubtitles hashing. '
        'Minimum size is 64 KB, got $fileSize bytes.',
        path,
      );
    }
  }

  static void _validateChunk(Uint8List bytes, String path) {
    if (bytes.length != kOpenSubtitlesChunkSize) {
      throw FileSystemException(
        'Unexpected EOF while reading file chunk',
        path,
      );
    }
  }

  static _Uint64 _computeHashValue(
    int fileSize,
    Uint8List headBytes,
    Uint8List tailBytes,
  ) {
    var hash = _toUint64(fileSize);
    hash = _addUint64(hash, _sumChunk(headBytes));
    hash = _addUint64(hash, _sumChunk(tailBytes));
    return hash;
  }

  static _Uint64 _sumChunk(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    var sum = _Uint64.zero;

    for (var i = 0; i < _int64Count; i++) {
      final lo = bd.getUint32(i * 8, Endian.little);
      final hi = bd.getUint32(i * 8 + 4, Endian.little);
      sum = _addUint64(sum, _Uint64(hi, lo));
    }

    return sum;
  }

  static _Uint64 _toUint64(int value) {
    final lo = value & 0xFFFFFFFF;
    final hi = (value >> 32) & 0xFFFFFFFF;
    return _Uint64(hi, lo);
  }

  static _Uint64 _addUint64(_Uint64 a, _Uint64 b) {
    final loSum = a.lo + b.lo;
    final carry = loSum >> 32;
    final hi = (a.hi + b.hi + carry) & 0xFFFFFFFF;
    final lo = loSum & 0xFFFFFFFF;
    return _Uint64(hi, lo);
  }

  static String _toHex(_Uint64 v) {
    final hiHex = v.hi.toRadixString(16).padLeft(8, '0');
    final loHex = v.lo.toRadixString(16).padLeft(8, '0');
    return '$hiHex$loHex';
  }
}

class _Uint64 {
  final int hi;
  final int lo;

  const _Uint64(this.hi, this.lo);
  static const zero = _Uint64(0, 0);
}
