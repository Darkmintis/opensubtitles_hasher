# opensubtitles_hasher

[![pub.dev](https://img.shields.io/pub/v/opensubtitles_hasher.svg)](https://pub.dev/packages/opensubtitles_hasher)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Fast OpenSubtitles hashing and movie picking for Flutter - all platforms, one API.

- **Instant hash** - reads only **128 KB**, even for 50 GB files
- **Built-in picker** - works on Android, iOS, macOS, Windows, and Linux
- **Play-safe by default** - Android uses the system Documents UI (no `READ_MEDIA_VIDEO`)
- **Optional branded browser** - SAF folder grant (`safFolder`) for custom video-only UI
- **Zero-copy** - Android `content://` URI → native Kotlin hash (no full-file copy)

---

## Install

```yaml
dependencies:
  opensubtitles_hasher: ^1.2.0
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
| Android | See [Android picker modes](#android-picker-modes) below | Native Kotlin (zero-copy `content://`) |
| iOS / macOS / Windows / Linux | System file dialog (video extensions) | Pure Dart |
| Web | Not supported | Not supported |

On other platforms the system file dialog filters by video extension. Size
limits are checked immediately after selection. Duration limits cannot be
checked because system file dialogs do not provide media duration metadata.

---

## Android picker modes

Choosing a mode in Dart **does not** change which permissions land in your AAB.
Permissions come only from merged manifests. **This plugin never declares
`READ_MEDIA_VIDEO`.**

| Mode | Play Store | Custom UI | Permission |
|------|------------|-----------|------------|
| `systemDocuments` (**default**) | Yes | No (system UI) | None |
| `safFolder` | Yes | Yes (branded, video-only) | Folder grant via SAF |
| `mediaStore` | Usually no | Yes (whole-device MediaStore) | Host app must declare storage / `READ_MEDIA_VIDEO` |

### Default — system Documents UI

```dart
await OpenSubtitlesHasher.pickMovie(); // MoviePickerMode.systemDocuments
```

One system file dialog. Google Play safe.

### Recommended branded UI — SAF folder browser

User grants a Movies / Downloads folder once; your themed folder → video list
opens. The grant is remembered for later picks.

```dart
await OpenSubtitlesHasher.pickMovie(
  options: MoviePickerOptions.defaults.copyWith(
    mode: MoviePickerMode.safFolder,
    minDuration: Duration(minutes: 30),
    toolbarColorHex: '#1F6FEB',
    toolbarOnColorHex: '#FFFFFF',
    statusBarColorHex: '#174EA6',
    accentColorHex: '#58A6FF',
  ),
);
```

### Legacy — MediaStore (host permission required)

Use only for sideload / non-Play builds. Add permissions in **your app**
manifest (not this plugin):

```xml
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission
    android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
```

```dart
await OpenSubtitlesHasher.pickMovie(
  options: MoviePickerOptions.defaults.copyWith(
    mode: MoviePickerMode.mediaStore,
  ),
);
```

When `mediaStore` is selected, the plugin requests the runtime permission.
If the host never declared it, or the user denies, the package falls back to
`systemDocuments`.

---

## Options reference

```dart
await OpenSubtitlesHasher.pickMovie(
  options: MoviePickerOptions.defaults.copyWith(
    mode: MoviePickerMode.safFolder,
    mimeTypes: ['video/mp4', 'video/x-matroska'],
    minSizeBytes: 50 * 1024 * 1024,
    minDuration: Duration(minutes: 30),
    toolbarColorHex: '#1F6FEB',
    toolbarOnColorHex: '#FFFFFF',
    statusBarColorHex: '#174EA6',
    accentColorHex: '#58A6FF',
  ),
);
```

| Option | What it does |
|--------|--------------|
| `mode` | `systemDocuments` · `safFolder` · `mediaStore` |
| `mimeTypes` | Which video types to show (default: `video/*`) |
| `minSizeBytes` / `maxSizeBytes` | Size limits (`null` = off) |
| `minDuration` / `maxDuration` | Duration limits (`null` = off) |
| `toolbarColorHex` | Folder browser toolbar colour (`safFolder` / `mediaStore`) |
| `toolbarOnColorHex` | Toolbar title + icon colour |
| `statusBarColorHex` | Status bar colour for the picker screen |
| `accentColorHex` | Folder icon / highlight colour |
| `takePersistablePermission` | Keep URI readable later (Documents / SAF) |

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
  movie.duration;      // Duration (Android folder browsers when available)
}
```

Always use `effectivePath` with `computeHashResult` - it picks `uri` on Android (zero-copy) or `path` elsewhere.

`picked.searchTitle` is a cleaned title from the filename (`The.Matrix.1999.1080p.mkv` → `The Matrix`). Use it for an OpenSubtitles text search when the hash has no match. Episode files also expose `picked.parsedName.season` and `episode`.

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
| `parseFileName(name)` | Title, year, season, episode from a filename |

**Types:** `HashResult`, `PickedMovie`, `ParsedVideoName`, `MoviePickerOptions`, `MoviePickerMode`, `InvalidFileException`, `MovieFilterException`.

---

## Error handling

```dart
try {
  final picked = await OpenSubtitlesHasher.pickAndHash();
} on MovieFilterException catch (e) {
  // Picked file failed a size/duration filter
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

On Android: pick a mode (`systemDocuments` / `safFolder` / `mediaStore`), step min duration / min size, pick video types, then tap **Pick movie + hash**.

---

## License

MIT - see [LICENSE](LICENSE).
