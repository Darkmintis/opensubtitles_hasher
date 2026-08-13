# Changelog

All notable changes to this project are documented in this file.

## [1.1.2] - 2026-08-13

### Fixed

- Declared iOS, macOS, Windows, and Linux in `pubspec.yaml` via
  `dartPluginClass` so pub.dev lists all supported platforms (not Android only).
  Runtime behavior was already cross-platform; this is a metadata fix.

## [1.1.1] - 2026-08-04

### Fixed

- Android movie folder browser is fully edge-to-edge on Android 15/16:
  `enableEdgeToEdge()`, transparent system bars, and `WindowInsets` handling
  for status bar, navigation/gesture bar, and display cutouts.
- `toolbarColorHex` and `statusBarColorHex` now render as intended in
  edge-to-edge mode (status scrim + toolbar), avoiding toolbar color overrides.
- System bar styling no longer depends on deprecated status bar color behavior.

### Changed

- Folder rows use a modern rounded icon + chevron instead of legacy system
  drawables; icon accent follows `toolbarColorHex` when provided.
- Android build configuration updated for modern targets (`compileSdk 36`) and
  refreshed AndroidX/Material dependencies.

## [1.1.0] - 2026-07-27

### Added

- **Cross-platform picker** - `pickMovie()` and `pickAndHash()` now work on
  Android, iOS, macOS, Windows, and Linux. No `file_picker` code needed in
  your app; the package handles it internally.
- `PickedMovie.effectivePath` - always use this with `computeHashResult`;
  resolves to `uri` on Android (zero-copy) or `path` elsewhere.
- `PickedMovie.path` for non-Android filesystem results.
- Android **folder browser** (`MoviePickerMode.mediaStore`): folders → videos
  only (images/documents never listed); disable via `systemDocuments`.
- `MoviePickerOptions` - override mode, MIME, min/max size, min/max duration
  via constructor or `copyWith` (defaults: folder browser, `video/*`, no limits).
- Filters apply in the MediaStore query so non-matching videos never appear.
- Interactive example app: toggle folder browser, step duration/size, MIME chips
  (Android); cross-platform picker button on all platforms.
- `MovieFilterException` for documents-mode post-pick filter failures.
- `OpenSubtitlesHasher.pickAndHash()` convenience API.
- `PickedMovie.duration` when available (Android folder browser).
- Modular Android Kotlin (`hash/`, `picker/`, `mediastore/`, `ui/`) and Dart
  (`models/`, `platform/`).
- Plugin requests `READ_MEDIA_VIDEO` / storage; falls back to Documents UI if denied.

### Fixed

- Android hashing uses native code only for `content://` URIs; filesystem
  paths use Dart again
- Native hash runs off the UI thread
- Content URI errors no longer fall back to a broken Dart file read
- Kotlin rejects files under 64 KB, matching Dart
- Kotlin chunk summing aligned with the OpenSubtitles reference
- Picker no longer duplicates activity listeners or leaves Futures hanging
- Plugin declares `minSdk 21`

### Docs

- README covers hasher + customizable folder browser picker

## [1.0.0] - 2026-06-14

### Added

- `OpenSubtitlesHasher.computeHash()` and `computeHashResult()` for file paths
  and Android `content://` URIs
- `HashResult` with `toApiMap()` for OpenSubtitles API requests
- `InvalidFileException` for files smaller than 64 KB
- Android native plugin for zero-copy hashing from content URIs
- Pure Dart implementation for filesystem paths on mobile and desktop
