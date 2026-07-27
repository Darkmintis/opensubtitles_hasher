# opensubtitles_hasher

[![pub.dev](https://img.shields.io/pub/v/opensubtitles_hasher.svg)](https://pub.dev/packages/opensubtitles_hasher)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Fast OpenSubtitles hashing and movie picking for Flutter - all platforms, one API.

- **Instant hash** - reads only **128 KB**, even for 50 GB files
- **Built-in picker** - works on Android, iOS, macOS, Windows, and Linux
- **Android folder browser** - videos only, no images or docs; filters apply at the query level
- **Zero-copy** - Android `content://` URI → native Kotlin hash (no full-file copy)

---

## Install

```yaml
dependencies:
  opensubtitles_hasher: ^1.1.0
```

```bash
flutter pub get
```

---

## Quick start

### Pick and hash (any platform)

```dart
import 'package:opensubtitles_hasher/opensubtitles_hasher.dart';

final picked = await OpenSubtitlesHasher.pickAndHash();
if (picked != null) {
  print(picked.hash.hash);       // e.g. 8e245d9679d31e12
  print(picked.hash.fileSize);   // bytes
  print(picked.hash.toApiMap()); // {moviehash, moviebytesize} for the API
}
```

That's it. No `file_picker` code, no platform checks - the package handles everything.

### Just pick

```dart
final movie = await OpenSubtitlesHasher.pickMovie();
if (movie == null) return; // user cancelled

final result = await OpenSubtitlesHasher.computeHashResult(movie.effectivePath);
```

### Just hash (path you already have)

```dart
final result = await OpenSubtitlesHasher.computeHashResult('/path/to/movie.mkv');
print(result.hash);
print(result.toApiMap()); // ready for the OpenSubtitles API
```

---

## Platform behaviour

| Platform | Picker | Hash |
|----------|--------|------|
| Android | Native folder browser (MediaStore) + SAF fallback | Native Kotlin (zero-copy `content://`) |
| iOS / macOS / Windows / Linux | System file dialog (video extensions) | Pure Dart |
| Web | Not supported | Not supported |

On Android, the folder browser shows **only folders that contain matching videos**. Images and documents never appear. Filters (duration, size, MIME) are applied in the MediaStore query - short clips and small files are hidden before the UI renders.

On other platforms the system file dialog filters by video extension. Duration and size cannot be pre-filtered on those platforms.

---

## Android picker - make it yours

```dart
await OpenSubtitlesHasher.pickMovie(
  options: MoviePickerOptions.defaults.copyWith(
    // Folder browser on by default. Switch to system Documents UI:
    // mode: MoviePickerMode.systemDocuments,

    mimeTypes: ['video/mp4', 'video/x-matroska'],
    minSizeBytes: 50 * 1024 * 1024,       // at least 50 MB
    minDuration: Duration(minutes: 30),   // hides clips shorter than 30 min
    toolbarColorHex: '#1F6FEB',           // optional toolbar colour
    toolbarOnColorHex: '#FFFFFF',         // toolbar text / icon colour
    statusBarColorHex: '#174EA6',         // status bar colour
  ),
);
```

| Option | What it does |
|--------|--------------|
| `mode` | `mediaStore` = folder browser · `systemDocuments` = system file UI |
| `mimeTypes` | Which video types to show (default: `video/*`) |
| `minSizeBytes` / `maxSizeBytes` | Size limits (`null` = off) |
| `minDuration` / `maxDuration` | Duration limits (`null` = off) |
| `toolbarColorHex` | Folder browser toolbar colour (`#RRGGBB` / `#AARRGGBB`) |
| `toolbarOnColorHex` | Toolbar title + icon colour |
| `statusBarColorHex` | Status bar colour for the picker screen |
| `takePersistablePermission` | Keep URI readable later (Documents mode only) |

The folder browser requests video read permission. If the user denies it the package falls back to the system Documents UI automatically.

---

## PickedMovie

```dart
final movie = await OpenSubtitlesHasher.pickMovie();
if (movie != null) {
  movie.effectivePath; // pass this to computeHashResult - works on all platforms
  movie.uri;           // Android content:// URI (null on other platforms)
  movie.path;          // Filesystem path (iOS, macOS, Windows, Linux)
  movie.name;          // Display name
  movie.size;          // Bytes (if reported)
  movie.duration;      // Duration (Android folder browser only)
}
```

Always use `effectivePath` with `computeHashResult` - it picks `uri` on Android (zero-copy) or `path` elsewhere.

---

## API reference

| Method | What |
|--------|------|
| `pickMovie({options})` | Pick a movie on any platform → `PickedMovie?` |
| `pickAndHash({options})` | Pick + hash in one call → `({PickedMovie, HashResult})?` |
| `computeHashResult(pathOrUri)` | Hash + size + `toApiMap()` |
| `computeHash(pathOrUri)` | Hash string only |
| `computeHashSync(path)` | Synchronous Dart hash (filesystem paths only) |
| `computeFileHash(file)` | Hash from a `File` object |
| `isValidHash(hash)` | True if 16 lowercase hex chars |
| `isContentUri(path)` | True if `content://` URI |

**Types:** `HashResult`, `PickedMovie`, `MoviePickerOptions`, `MoviePickerMode`, `InvalidFileException`, `MovieFilterException`.

---

## Error handling

```dart
try {
  final picked = await OpenSubtitlesHasher.pickAndHash();
} on MovieFilterException catch (e) {
  // Android Documents mode: file failed your filters
  print(e.code);    // TOO_SMALL, TOO_SHORT, etc.
  print(e.message);
} on InvalidFileException {
  // file is smaller than 64 KB - cannot hash
} on PlatformException {
  // native Android error
} on UnsupportedError {
  // web (not supported)
}
```

---

## How the hash works

OpenSubtitles identifies files with a tiny checksum:

```
hash = fileSize
     + sum(first 64 KB as little-endian uint64)
     + sum(last  64 KB as little-endian uint64)
→ 16 lowercase hex digits
```

Only **128 KB** is read regardless of file size. Files under 64 KB raise `InvalidFileException`.

---

## Try the example

```bash
cd example
flutter run
```

On Android: toggle folder browser, step min duration / min size, pick video types, then tap **Pick movie + hash**. On other platforms: tap the same button - the system file dialog opens.

---

## License

MIT - see [LICENSE](LICENSE).
