/// Dart-only plugin entry point for non-Android platforms.
///
/// Hashing and picking on iOS, macOS, Windows, and Linux are pure Dart
/// (plus [file_picker]). This class exists so those platforms can be
/// declared in `pubspec.yaml` and shown on pub.dev; registration is a no-op.
class OpenSubtitlesHasherDartPlugin {
  /// Called by Flutter at startup on Dart-only platforms. No-op.
  static void registerWith() {}
}
