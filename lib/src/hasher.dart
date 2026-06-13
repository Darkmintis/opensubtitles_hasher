import 'dart:io';
import 'dart:typed_data';

import 'models.dart';

/// The size of each chunk read from the file (64 KB).
const int _chunkSize = 65536;

/// The number of 64-bit integers in a 64 KB chunk.
const int _int64Count = _chunkSize ~/ 8;

/// Pure Dart implementation of the OpenSubtitles hashing algorithm.
///
/// This implementation works on all platforms with direct file path access.
/// For modern Android with content:// URIs, use [OpenSubtitlesHasher] instead
/// which automatically selects the best method.
///
/// The OpenSubtitles hash is defined as:
/// ```
/// hash = fileSize + sum(first 64KB as uint64 LE) + sum(last 64KB as uint64 LE)
/// ```
///
/// Only 128 KB of data is ever read, regardless of file size — making this
/// algorithm O(1) in memory and extremely fast even for 50GB+ files.
///
/// Example:
/// ```dart
/// final hash = await OpenSubtitlesHasherImpl.computeFileHash('/path/to/movie.mp4');
/// print(hash); // e.g. "8e245d9679d31e12"
/// ```
class OpenSubtitlesHasherImpl {
  OpenSubtitlesHasherImpl._();

  /// Computes the OpenSubtitles hash from a file [path].
  ///
  /// Throws a [FileSystemException] if the file does not exist or cannot
  /// be read.
  ///
  /// Throws an [InvalidFileException] if the file is smaller than 128 KB
  /// (the minimum required by the algorithm).
  static Future<String> computeHash(String path) async {
    final file = File(path);

    // ignore: avoid_slow_async_io
    if (!await file.exists()) {
      throw FileSystemException('File not found', path);
    }

    final raf = await file.open(mode: FileMode.read);

    try {
      final fileSize = await raf.length();

      if (fileSize < _chunkSize) {
        throw InvalidFileException(
          'File is too small for OpenSubtitles hashing. '
          'Minimum size is 64 KB, got $fileSize bytes.',
          path,
        );
      }

      await raf.setPosition(0);
      final headBytes = await raf.read(_chunkSize);

      await raf.setPosition(fileSize - _chunkSize);
      final tailBytes = await raf.read(_chunkSize);

      var hash = _toUint64(fileSize);
      hash = _addUint64(hash, _sumChunk(headBytes));
      hash = _addUint64(hash, _sumChunk(tailBytes));

      return _toHex(hash);
    } finally {
      await raf.close();
    }
  }

  /// Synchronous version of [computeHash].
  ///
  /// Prefer [computeHash] in async contexts. Use this only when you
  /// absolutely cannot use async (e.g. during isolate startup).
  static String computeHashSync(String path) {
    final file = File(path);

    if (!file.existsSync()) {
      throw FileSystemException('File not found', path);
    }

    final raf = file.openSync(mode: FileMode.read);

    try {
      final fileSize = raf.lengthSync();

      if (fileSize < _chunkSize) {
        throw InvalidFileException(
          'File is too small for OpenSubtitles hashing. '
          'Minimum size is 64 KB, got $fileSize bytes.',
          path,
        );
      }

      raf.setPositionSync(0);
      final headBytes = raf.readSync(_chunkSize);

      raf.setPositionSync(fileSize - _chunkSize);
      final tailBytes = raf.readSync(_chunkSize);

      var hash = _toUint64(fileSize);
      hash = _addUint64(hash, _sumChunk(headBytes));
      hash = _addUint64(hash, _sumChunk(tailBytes));

      return _toHex(hash);
    } finally {
      raf.closeSync();
    }
  }

  /// Computes the OpenSubtitles hash from a [File] object.
  ///
  /// Convenience wrapper around [computeHash].
  static Future<String> computeFileHash(File file) =>
      computeHash(file.path);

  /// Computes the hash and also returns the file size.
  ///
  /// Some OpenSubtitles API calls require both the hash and byte size.
  /// This avoids having to stat the file twice.
  ///
  /// Returns a [HashResult] containing both values.
  static Future<HashResult> computeHashResult(String path) async {
    final file = File(path);

    // ignore: avoid_slow_async_io
    if (!await file.exists()) {
      throw FileSystemException('File not found', path);
    }

    final raf = await file.open(mode: FileMode.read);

    try {
      final fileSize = await raf.length();

      if (fileSize < _chunkSize) {
        throw InvalidFileException(
          'File is too small for OpenSubtitles hashing. '
          'Minimum size is 64 KB, got $fileSize bytes.',
          path,
        );
      }

      await raf.setPosition(0);
      final headBytes = await raf.read(_chunkSize);

      await raf.setPosition(fileSize - _chunkSize);
      final tailBytes = await raf.read(_chunkSize);

      var hash = _toUint64(fileSize);
      hash = _addUint64(hash, _sumChunk(headBytes));
      hash = _addUint64(hash, _sumChunk(tailBytes));

      return HashResult(
        hash: _toHex(hash),
        fileSize: fileSize,
        filePath: path,
      );
    } finally {
      await raf.close();
    }
  }

  /// Validates whether a hash string looks like a valid OpenSubtitles hash.
  ///
  /// A valid hash is exactly 16 lowercase hex characters.
  static bool isValidHash(String hash) {
    if (hash.length != 16) return false;
    return RegExp(r'^[0-9a-f]{16}$').hasMatch(hash);
  }

  // ─────────────────────────── Internal helpers ────────────────────────────

  /// Sums all 64-bit little-endian unsigned integers in [bytes].
  /// Reads via ByteData to avoid platform precision issues.
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

  /// Wraps a [int] into a [_Uint64] using two 32-bit halves.
  static _Uint64 _toUint64(int value) {
    final lo = value & 0xFFFFFFFF;
    final hi = (value >> 32) & 0xFFFFFFFF;
    return _Uint64(hi, lo);
  }

  /// Adds two [_Uint64] values with unsigned overflow (mod 2^64).
  static _Uint64 _addUint64(_Uint64 a, _Uint64 b) {
    final loSum = a.lo + b.lo;
    final carry = loSum >> 32;
    final hi = (a.hi + b.hi + carry) & 0xFFFFFFFF;
    final lo = loSum & 0xFFFFFFFF;
    return _Uint64(hi, lo);
  }

  /// Converts a [_Uint64] to a zero-padded 16-character lowercase hex string.
  static String _toHex(_Uint64 v) {
    final hiHex = v.hi.toRadixString(16).padLeft(8, '0');
    final loHex = v.lo.toRadixString(16).padLeft(8, '0');
    return '$hiHex$loHex';
  }
}

/// Internal representation of an unsigned 64-bit integer as two 32-bit halves.
class _Uint64 {
  final int hi;
  final int lo;

  const _Uint64(this.hi, this.lo);
  static const zero = _Uint64(0, 0);
}