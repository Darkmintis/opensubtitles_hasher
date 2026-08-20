/// Metadata extracted from a video filename for OpenSubtitles search.
class ParsedVideoName {
  /// Clean title suitable for an OpenSubtitles `query` search.
  final String title;

  /// Four-digit year when present in the filename.
  final int? year;

  /// Season number when the filename looks like an episode (`S01E01`).
  final int? season;

  /// Episode number when the filename looks like an episode.
  final int? episode;

  /// Original filename (or path) that was parsed.
  final String originalName;

  /// Creates a parsed video name.
  const ParsedVideoName({
    required this.title,
    this.year,
    this.season,
    this.episode,
    required this.originalName,
  });

  /// True when both season and episode were detected.
  bool get isEpisode => season != null && episode != null;

  /// True when a usable title was extracted.
  bool get hasTitle => title.trim().isNotEmpty;

  @override
  String toString() =>
      'ParsedVideoName(title: $title, year: $year, season: $season, '
      'episode: $episode, originalName: $originalName)';

  @override
  bool operator ==(Object other) =>
      other is ParsedVideoName &&
      other.title == title &&
      other.year == year &&
      other.season == season &&
      other.episode == episode &&
      other.originalName == originalName;

  @override
  int get hashCode =>
      Object.hash(title, year, season, episode, originalName);
}
