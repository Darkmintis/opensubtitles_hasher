# Changelog

## 1.0.0

Initial release of `opensubtitles_hasher`.

### Features

- `OpenSubtitlesHasher.computeHash(path)` for async hashing from a file path
- `OpenSubtitlesHasher.computeHashSync(path)` for synchronous hashing
- `OpenSubtitlesHasher.computeFileHash(file)` for hashing from a `File` object
- `OpenSubtitlesHasher.computeHashResult(path)` for hash + file size in one call
- `OpenSubtitlesHasher.isValidHash(hash)` for validating OpenSubtitles hash strings
- `HashResult.toApiMap()` for OpenSubtitles REST API parameters

### Notes

- Pure Dart and null-safe
- No runtime dependencies
- Reads only 128 KB per file using `RandomAccessFile`
