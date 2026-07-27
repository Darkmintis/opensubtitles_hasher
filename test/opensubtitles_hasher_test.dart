import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opensubtitles_hasher/opensubtitles_hasher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const filePickerChannel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(filePickerChannel, (call) async => null);

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

      expect(hash, '0000000000010000');
    });

    test('sync and async produce identical results', () async {
      final file = await _createTestFile(tempDir, sizeInKB: 256);

      final asyncHash = await OpenSubtitlesHasher.computeHash(file.path);
      final syncHash = OpenSubtitlesHasher.computeHashSync(file.path);

      expect(asyncHash, equals(syncHash));
    });

    test('computeFileHash matches computeHash', () async {
      final file = await _createTestFile(tempDir, sizeInKB: 256);

      final byPath = await OpenSubtitlesHasher.computeHash(file.path);
      final byFile = await OpenSubtitlesHasher.computeFileHash(file);

      expect(byPath, equals(byFile));
    });

    test('isContentUri detects content URIs', () {
      expect(
        OpenSubtitlesHasher.isContentUri('content://media/1'),
        isTrue,
      );
      expect(OpenSubtitlesHasher.isContentUri('/storage/movie.mkv'), isFalse);
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

      test('throws InvalidFileException for sync path under 64 KB', () {
        final smallFile = File('${tempDir.path}/small_sync.mp4');
        smallFile.writeAsBytesSync(List.filled(1024, 0));

        expect(
          () => OpenSubtitlesHasher.computeHashSync(smallFile.path),
          throwsA(isA<InvalidFileException>()),
        );
      });

      test('handles exactly 64 KB file', () async {
        final file = await _createTestFile(tempDir, sizeInKB: 64);
        final hash = await OpenSubtitlesHasher.computeHash(file.path);
        expect(hash.length, equals(16));
      });

      test('content URI on non-Android falls through to Dart filesystem read',
          () async {
        expect(
          () => OpenSubtitlesHasher.computeHash('content://example/video.mp4'),
          throwsA(isA<FileSystemException>()),
        );
      }, skip: Platform.isAndroid ? 'Android uses native channel' : false);
    });

    group('pickMovie', () {
      test('returns null on non-Android when user cancels picker', () async {
        final picked = await OpenSubtitlesHasher.pickMovie();
        expect(picked, isNull);
      }, skip: Platform.isAndroid ? 'Android uses native channel' : false);

      test('pickAndHash returns null on non-Android when user cancels', () async {
        final picked = await OpenSubtitlesHasher.pickAndHash();
        expect(picked, isNull);
      }, skip: Platform.isAndroid ? 'Android uses native channel' : false);
    });

    group('MoviePickerOptions', () {
      test('defaults have no size or duration filters', () {
        const options = MoviePickerOptions.defaults;
        expect(options.mimeTypes, MoviePickerOptions.defaultMimeTypes);
        expect(options.minSizeBytes, isNull);
        expect(options.maxSizeBytes, isNull);
        expect(options.minDuration, isNull);
        expect(options.maxDuration, isNull);
        expect(options.hasPostPickFilters, isFalse);
      });

      test('copyWith overrides only provided fields', () {
        final options = MoviePickerOptions.defaults.copyWith(
          mimeTypes: const ['video/mp4'],
          minSizeBytes: 1000,
          minDuration: const Duration(minutes: 45),
        );

        expect(options.mimeTypes, ['video/mp4']);
        expect(options.minSizeBytes, 1000);
        expect(options.maxSizeBytes, isNull);
        expect(options.minDuration, const Duration(minutes: 45));
        expect(options.maxDuration, isNull);
        expect(options.hasPostPickFilters, isTrue);
      });

      test('toChannelMap serializes filters', () {
        final options = MoviePickerOptions.defaults.copyWith(
          mode: MoviePickerMode.systemDocuments,
          mimeTypes: const ['video/mp4', 'video/x-matroska'],
          minSizeBytes: 1000,
          maxSizeBytes: 5000,
          minDuration: const Duration(minutes: 45),
          maxDuration: const Duration(hours: 3),
          takePersistablePermission: false,
        );

        final map = options.toChannelMap();
        expect(map['mode'], 'systemDocuments');
        expect(map['mimeTypes'], ['video/mp4', 'video/x-matroska']);
        expect(map['minSizeBytes'], 1000);
        expect(map['maxSizeBytes'], 5000);
        expect(map['minDurationMs'], 45 * 60 * 1000);
        expect(map['maxDurationMs'], 3 * 60 * 60 * 1000);
        expect(map['takePersistablePermission'], isFalse);
      });

      test('defaults use mediaStore mode', () {
        expect(
          MoviePickerOptions.defaults.mode,
          MoviePickerMode.mediaStore,
        );
        expect(
          MoviePickerOptions.defaults.toChannelMap()['mode'],
          'mediaStore',
        );
      });
    });

    group('isValidHash', () {
      test('accepts valid 16-char lowercase hex', () {
        expect(OpenSubtitlesHasher.isValidHash('8e245d9679d31e12'), isTrue);
        expect(OpenSubtitlesHasher.isValidHash('0000000000000000'), isTrue);
        expect(OpenSubtitlesHasher.isValidHash('ffffffffffffffff'), isTrue);
      });

      test('rejects invalid hashes', () {
        expect(OpenSubtitlesHasher.isValidHash(''), isFalse);
        expect(OpenSubtitlesHasher.isValidHash('8E245D9679D31E12'), isFalse);
        expect(OpenSubtitlesHasher.isValidHash('8e245d9679d31e1'), isFalse);
        expect(OpenSubtitlesHasher.isValidHash('8e245d9679d31e123'), isFalse);
        expect(OpenSubtitlesHasher.isValidHash('8e245d9679d31eXY'), isFalse);
      });
    });

    group('oshash reference vectors', () {
      test('matches opensubtitles/oshash testfile.bin vector', () async {
        final file = await _createOshashReferenceFile(
          tempDir,
          seed: 42,
          size: 1048576,
          name: 'testfile.bin',
        );

        final hash = await OpenSubtitlesHasher.computeHash(file.path);

        expect(hash, 'e7e2e71e035b137f');
      }, skip: !Platform.isLinux && !Platform.isMacOS && !Platform.isWindows);

      test('matches opensubtitles/oshash testfile_small.bin vector', () async {
        final file = await _createOshashReferenceFile(
          tempDir,
          seed: 123,
          size: 131080,
          name: 'testfile_small.bin',
        );

        final hash = await OpenSubtitlesHasher.computeHash(file.path);

        expect(hash, '6e4ae67790577f76');
      }, skip: !Platform.isLinux && !Platform.isMacOS && !Platform.isWindows);
    });
  });
}

Future<File> _createOshashReferenceFile(
  Directory dir, {
  required int seed,
  required int size,
  required String name,
}) async {
  final result = await Process.run(
    'python3',
    [
      '-c',
      'import random, sys; random.seed($seed); '
          'sys.stdout.buffer.write(bytes(random.getrandbits(8) for _ in range($size)))',
    ],
    stdoutEncoding: null,
  );

  if (result.exitCode != 0) {
    fail('Failed to generate oshash reference file: ${result.stderr}');
  }

  final file = File('${dir.path}/$name');
  await file.writeAsBytes(result.stdout as List<int>);
  return file;
}

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
