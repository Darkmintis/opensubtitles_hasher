# opensubtitles_hasher

Pure-Dart OpenSubtitles hashing for Flutter and Dart apps.

[![pub.dev](https://img.shields.io/pub/v/opensubtitles_hasher.svg)](https://pub.dev/packages/opensubtitles_hasher)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## What it does

`opensubtitles_hasher` computes the OpenSubtitles movie hash by reading only the first and last 64 KB of a file. It also returns the file size when you need it for the OpenSubtitles API.

## Install

```yaml
dependencies:
  opensubtitles_hasher: ^1.0.0
```

```bash
flutter pub get
```

## Quick start

```dart
import 'package:opensubtitles_hasher/opensubtitles_hasher.dart';

final hash = await OpenSubtitlesHasher.computeHash('/path/to/movie.mp4');
final result = await OpenSubtitlesHasher.computeHashResult('/path/to/movie.mp4');

print(hash);
print(result.fileSize);
print(result.toApiMap());
```

## API

### `OpenSubtitlesHasher`

- `computeHash(String path)` returns a `Future<String>`
- `computeHashSync(String path)` returns a `String`
- `computeFileHash(File file)` returns a `Future<String>`
- `computeHashResult(String path)` returns a `Future<HashResult>`
- `isValidHash(String hash)` returns a `bool`

### `HashResult`

- `hash` - 16-character lowercase hex hash
- `fileSize` - file size in bytes
- `filePath` - file path that was hashed
- `toApiMap()` - returns `{ moviehash, moviebytesize }`

## Example

See the `example/` folder for a small Flutter app that picks a video file and computes its hash.

## Behavior

- Reads only 128 KB total
- Uses `RandomAccessFile` instead of loading the whole file into memory
- Throws `FileSystemException` when the file cannot be opened
- Throws `InvalidFileException` when the file is smaller than 64 KB

## Platform support

- Android: supported
- iOS: supported
- macOS: supported
- Windows: supported
- Linux: supported
- Web: not supported

## Package quality

- No runtime dependencies
- Dart 3 null-safe
- Standard `lib/`, `test/`, and `example/` layout
- `flutter test` passes
- `flutter pub publish --dry-run` passes

## License

MIT
