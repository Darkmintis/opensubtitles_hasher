# Changelog

## 1.0.0

Initial release of `opensubtitles_hasher`.

### Features

- **`OpenSubtitlesHasher.computeHash(path)`** — async hashing from a file path
- **`OpenSubtitlesHasher.computeHashSync(path)`** — synchronous hashing for non-async contexts
- **`OpenSubtitlesHasher.computeFileHash(file)`** — hash from a `dart:io` `File` object
- **`OpenSubtitlesHasher.computeHashResult(path)`** — single call returning both hash and file size
- **`OpenSubtitlesHasher.isValidHash(hash)`** — validate OpenSubtitles hash format
- **`HashResult.toApiMap()`** — produces `{moviehash, moviebytesize}` for REST API calls

### Android

- Native Kotlin plugin for zero-copy hashing from `content://` URIs
- File size retrieval via `ContentResolver` without opening the file
- Persistable URI permission handling for long-lived access
- Built-in `pickMovie` activity for native file selection

### Performance

- Reads only 128 KB per file (first and last 64 KB) regardless of file size
- Uses `RandomAccessFile` — no full file loading into memory
- 64-bit arithmetic implemented with two 32-bit halves for precision

### Quality

- 100% null-safe (Dart 3)
- Zero runtime dependencies
- 12 unit tests covering determinism, edge cases, and validation
- `flutter test` and `flutter pub publish --dry-run` pass cleanly
