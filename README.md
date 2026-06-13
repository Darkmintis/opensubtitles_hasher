# opensubtitles\_hasher

[![pub.dev](https://img.shields.io/pub/v/opensubtitles_hasher.svg)](https://pub.dev/packages/opensubtitles_hasher)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Fast, cross-platform OpenSubtitles hashing for Flutter and Dart apps. Reads only 128 KB regardless of file size — O(1) in memory and I/O.

## What is the OpenSubtitles hash?

The [OpenSubtitles API](https://opensubtitles.com) uses a file hash to identify movie files. The hash is computed as:

```
hash = fileSize + sum(head 64KB as uint64 LE) + sum(tail 64KB as uint64 LE)
```

Only the first and last 64 KB are read, so even 50 GB files hash instantly. The hash is combined with the file size when making API requests for subtitle search.

## Features

- **Fast** — reads only 128 KB total via `RandomAccessFile`
- **Pure Dart** — works on all desktop and mobile platforms
- **Android content URI** — native plugin for zero-copy hashing from `content://` URIs (no file copy)
- **Sync & async APIs** — choose what fits your use case
- **No runtime dependencies** — zero transitive package weight
- **Null-safe** — Dart 3 fully sound

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

// Just the hash
final hash = await OpenSubtitlesHasher.computeHash('/path/to/movie.mp4');

// Hash + file size (for the OpenSubtitles API)
final result = await OpenSubtitlesHasher.computeHashResult('/path/to/movie.mp4');

print(result.hash);        // "8e245d9679d31e12"
print(result.fileSize);    // 129994823
print(result.toApiMap());  // {moviehash: 8e245d9679d31e12, moviebytesize: 129994823}
```

## API reference

### `OpenSubtitlesHasher`

Platform-aware entry point. On Android with `content://` URIs it delegates to native Kotlin code; everywhere else it uses the pure Dart implementation.

| Method | Returns | Description |
|--------|---------|-------------|
| `computeHash(String path)` | `Future<String>` | 16-char lowercase hex hash |
| `computeHashResult(String path)` | `Future<HashResult>` | Hash + file size + API map |
| `computeHashSync(String path)` | `String` | Synchronous variant (Dart only) |
| `computeFileHash(File file)` | `Future<String>` | Hash from a `dart:io` `File` object |
| `isValidHash(String hash)` | `bool` | Validates 16-char lowercase hex format |

### `HashResult`

Contains both values required by the OpenSubtitles search API.

| Property | Type | Description |
|----------|------|-------------|
| `hash` | `String` | 16-char lowercase hex |
| `fileSize` | `int` | File size in bytes |
| `filePath` | `String` | Original file path |
| `toApiMap()` | `Map<String, String>` | `{moviehash, moviebytesize}` |

### Using with the OpenSubtitles API

```dart
final result = await OpenSubtitlesHasher.computeHashResult(file.path);

// Use the hash and file size to search for subtitles
final response = await dio.post(
  'https://api.opensubtitles.com/api/v1/subtitles',
  data: result.toApiMap(),
);
```

### Android content URI support

On modern Android, files picked via `Intent.ACTION_OPEN_DOCUMENT` or libraries like `file_picker` return `content://` URIs — not file paths. Dart's `File` class cannot read these URIs directly. Without the native plugin, you'd need to copy the entire file to a temp location before hashing, which is slow and wasteful.

`opensubtitles_hasher` solves this with a native Kotlin plugin that reads the content URI's file descriptor directly — zero copy, zero temp files:

```dart
final result = await FilePicker.platform.pickFiles(type: FileType.video);
final uri = result.files.single.path;  // content://...
final hash = await OpenSubtitlesHasher.computeHash(uri);
```

## Error handling

| Error | Cause |
|-------|-------|
| `FileSystemException` | File doesn't exist or can't be opened |
| `InvalidFileException` | File is smaller than 64 KB (minimum required by the algorithm) |

```dart
try {
  final hash = await OpenSubtitlesHasher.computeHash(path);
} on FileSystemException {
  // Handle missing/unreadable file
} on InvalidFileException {
  // Handle files too small to hash
}
```

## Platform support

| Platform | Dart (path) | Android (content URI) |
|----------|-------------|----------------------|
| Android  | ✅ | ✅ native |
| iOS      | ✅ | n/a |
| macOS    | ✅ | n/a |
| Windows  | ✅ | n/a |
| Linux    | ✅ | n/a |
| Web      | ❌ | ❌ |

## How it works

1. Opens the file with `RandomAccessFile`
2. Reads the first 64 KB
3. Reads the last 64 KB (seeks to `fileSize - 65536`)
4. Interprets each 8-byte chunk as a little-endian unsigned 64-bit integer
5. Sums all values and adds the total file size
6. Returns the 16-character lowercase hex result

The 64-bit arithmetic is implemented using two 32-bit halves to avoid JavaScript precision issues on the web (though web itself is not supported).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT — see [LICENSE](LICENSE).
