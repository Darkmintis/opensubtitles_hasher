import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opensubtitles_hasher/opensubtitles_hasher.dart';
import 'package:opensubtitles_hasher/src/hasher.dart';

void main() {
  group('OpenSubtitlesHasher', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('oshash_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('hashes an all-zero 64 KB file to the file size value', () async {
      final file = await _createZeroFile(tempDir, sizeInKB: 64);

      final hash = await OpenSubtitlesHasher.computeHash(file.path);

      // For a 64KB (65536 bytes) zero-filled file:
      // hash = size (65536) + sum(first 64KB) + sum(last 64KB)
      // Both sums = 0, so hash = 65536 = 0x0000000000010000
      expect(hash, '0000000000010000');
    });

    test('sync and async produce identical results', () async {
      final file = await _createTestFile(tempDir, sizeInKB: 256);

      // Use OpenSubtitlesHasherImpl for sync version
      final asyncHash = await OpenSubtitlesHasher.computeHash(file.path);
      final syncHash = OpenSubtitlesHasherImpl.computeHashSync(file.path);

      expect(asyncHash, equals(syncHash));
    });

    test('computeFileHash matches computeHash', () async {
      final file = await _createTestFile(tempDir, sizeInKB: 256);

      final byPath = await OpenSubtitlesHasher.computeHash(file.path);
      // Use OpenSubtitlesHasherImpl for computeFileHash
      final byFile = await OpenSubtitlesHasherImpl.computeFileHash(file);

      expect(byPath, equals(byFile));
    });

    group('computeHashResult', () {
      test('returns correct fileSize and API map', () async {
        final file = await _createTestFile(tempDir, sizeInKB: 128);
        final result = await OpenSubtitlesHasher.computeHashResult(file.path);

        expect(result.fileSize, equals(128 * 1024));
        expect(result.hash.length, equals(16));
        expect(result.filePath, equals(file.path));

        final map = result.toApiMap();
        expect(map['moviehash'], equals(result.hash));
        expect(map['moviebytesize'], equals(result.fileSize.toString()));
      });

      test('hash from computeHash matches hash in computeHashResult', () async {
        final file = await _createTestFile(tempDir, sizeInKB: 512);

        final hash = await OpenSubtitlesHasher.computeHash(file.path);
        final result = await OpenSubtitlesHasher.computeHashResult(file.path);

        expect(hash, equals(result.hash));
      });
    });

    group('determinism', () {
      test('same file always produces same hash', () async {
        final file = await _createTestFile(tempDir, sizeInKB: 256);

        final h1 = await OpenSubtitlesHasher.computeHash(file.path);
        final h2 = await OpenSubtitlesHasher.computeHash(file.path);
        final h3 = await OpenSubtitlesHasher.computeHash(file.path);

        expect(h1, equals(h2));
        expect(h2, equals(h3));
      });

      test('different files produce different hashes', () async {
        final file1 = await _createFilledFile(
          tempDir,
          sizeInKB: 256,
          fillByte: 0,
        );
        final file2 = await _createFilledFile(
          tempDir,
          sizeInKB: 256,
          fillByte: 1,
        );

        final h1 = await OpenSubtitlesHasher.computeHash(file1.path);
        final h2 = await OpenSubtitlesHasher.computeHash(file2.path);

        expect(h1, isNot(equals(h2)));
      });
    });

    group('edge cases', () {
      test('throws FileSystemException for non-existent file', () async {
        expect(
          () => OpenSubtitlesHasher.computeHash('/nonexistent/path/movie.mp4'),
          throwsA(isA<FileSystemException>()),
        );
      });

      test('throws InvalidFileException for files smaller than 64 KB', () async {
        final smallFile = File('${tempDir.path}/small.mp4');
        await smallFile.writeAsBytes(List.filled(1024, 0));

        expect(
          () => OpenSubtitlesHasher.computeHash(smallFile.path),
          throwsA(isA<InvalidFileException>()),
        );
      });

      test('handles exactly 64 KB file', () async {
        final file = await _createTestFile(tempDir, sizeInKB: 64);
        final hash = await OpenSubtitlesHasher.computeHash(file.path);
        expect(hash.length, equals(16));
      });
    });

    group('isValidHash', () {
      test('accepts valid 16-char lowercase hex', () {
        // Use OpenSubtitlesHasherImpl for isValidHash
        expect(OpenSubtitlesHasherImpl.isValidHash('8e245d9679d31e12'), isTrue);
        expect(OpenSubtitlesHasherImpl.isValidHash('0000000000000000'), isTrue);
        expect(OpenSubtitlesHasherImpl.isValidHash('ffffffffffffffff'), isTrue);
      });

      test('rejects invalid hashes', () {
        expect(OpenSubtitlesHasherImpl.isValidHash(''), isFalse);
        expect(OpenSubtitlesHasherImpl.isValidHash('8E245D9679D31E12'), isFalse);
        expect(OpenSubtitlesHasherImpl.isValidHash('8e245d9679d31e1'), isFalse);
        expect(OpenSubtitlesHasherImpl.isValidHash('8e245d9679d31e123'), isFalse);
        expect(OpenSubtitlesHasherImpl.isValidHash('8e245d9679d31eXY'), isFalse);
      });
    });
  });
}

// Helper: Create test file with pseudo-random content
Future<File> _createTestFile(
  Directory dir, {
  required int sizeInKB,
  int seed = 42,
}) async {
  final path = '${dir.path}/test_${sizeInKB}kb_seed$seed.bin';
  final file = File(path);
  final size = sizeInKB * 1024;
  final bytes = Uint8List(size);

  for (var i = 0; i < size; i++) {
    bytes[i] = ((i + seed) * 31 + seed * 17) & 0xFF;
  }

  await file.writeAsBytes(bytes);
  return file;
}

// Helper: Create file filled with zeros
Future<File> _createZeroFile(
  Directory dir, {
  required int sizeInKB,
}) async {
  final path = '${dir.path}/zero_${sizeInKB}kb.bin';
  final file = File(path);
  final size = sizeInKB * 1024;

  await file.writeAsBytes(List.filled(size, 0));
  return file;
}

// Helper: Create file filled with specific byte value
Future<File> _createFilledFile(
  Directory dir, {
  required int sizeInKB,
  required int fillByte,
}) async {
  final path = '${dir.path}/filled_${sizeInKB}kb_$fillByte.bin';
  final file = File(path);
  final size = sizeInKB * 1024;

  await file.writeAsBytes(List.filled(size, fillByte & 0xFF));
  return file;
}