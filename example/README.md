# Example

Interactive demo for `opensubtitles_hasher`.

```bash
cd example
flutter create . --platforms=android   # once if needed
flutter pub get
flutter run
```

**Android**

- Toggle folder browser (on = folders with matching videos only)
- +/- for min duration and min size
- Filter chips for video types
- **Pick movie + hash** applies your filters

**Other platforms**

- Use **Pick movie + hash** to select a video with the system file dialog
- Enter a filesystem path and tap **Compute hash** to hash a known path
