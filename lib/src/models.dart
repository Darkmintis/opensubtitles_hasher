/// The result of a hash computation, containing both the hash string
/// and the file size — both values required by the OpenSubtitles REST API.
class HashResult {
  /// The 16-character lowercase hex hash string.
  final String hash;

  /// The file size in bytes.
  final int fileSize;

  /// The absolute path of the file that was hashed.
  final String filePath;

  // ignore: public_member_api_docs
  const HashResult({
    required this.hash,
    required this.fileSize,
    required this.filePath,
  });
 
  /// Returns a Map compatible with the OpenSubtitles REST API search params.
  ///
  /// ```dart
  /// final result = await OpenSubtitlesHasher.computeHashResult(path);
  /// final params = result.toApiMap();
  /// // { 'moviehash': '8e245d9679d31e12', 'moviebytesize': '129994823' }
  /// ```
  Map<String, String> toApiMap() => {
        'moviehash': hash,
        'moviebytesize': fileSize.toString(),
      };

  @override
  String toString() =>
      'HashResult(hash: $hash, fileSize: $fileSize, filePath: $filePath)';

  @override
  bool operator ==(Object other) =>
      other is HashResult &&
      other.hash == hash &&
      other.fileSize == fileSize &&
      other.filePath == filePath;

  @override
  int get hashCode => Object.hash(hash, fileSize, filePath);
}

/// Thrown when a file is too small to be hashed using the OpenSubtitles
/// algorithm (minimum 64 KB required).
class InvalidFileException implements Exception {
  /// Human-readable error description.
  final String message;

  /// The path of the file that caused the error.
  final String path;

  // ignore: public_member_api_docs
  const InvalidFileException(this.message, this.path);

  @override
  String toString() => 'InvalidFileException: $message (path: $path)';
}