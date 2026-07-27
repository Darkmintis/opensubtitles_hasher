/// Result of an OpenSubtitles hash computation.
class HashResult {
  /// 16-character lowercase hex hash.
  final String hash;

  /// File size in bytes.
  final int fileSize;

  /// Original path or `content://` URI that was hashed.
  final String filePath;

  /// Creates a hash result.
  const HashResult({
    required this.hash,
    required this.fileSize,
    required this.filePath,
  });

  /// OpenSubtitles API search params: `{moviehash, moviebytesize}`.
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
