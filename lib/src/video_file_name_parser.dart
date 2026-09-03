import 'models/parsed_video_name.dart';

/// Extracts a search title, year, and SxxExx info from a video filename.
///
/// Typical scene/release names:
/// - `The.Matrix.1999.1080p.BluRay.x264-GRP.mkv` → The Matrix, 1999
/// - `Breaking.Bad.S01E01.Pilot.1080p.mkv` → Breaking Bad, S01E01
class VideoFileNameParser {
  VideoFileNameParser._();

  static final _extensionPattern = RegExp(
    r'\.(mkv|mp4|avi|mov|wmv|webm|m4v|ts|flv|m2ts|mpg|mpeg)$',
    caseSensitive: false,
  );
  static final _seasonEpisodePattern = RegExp(
    r'(?:^|[\s._\-])s(\d{1,2})e(\d{1,3})(?:[\s._\-]|$)',
    caseSensitive: false,
  );
  static final _altSeasonEpisodePattern = RegExp(
    r'(?:^|[\s._\-])(\d{1,2})x(\d{1,3})(?:[\s._\-]|$)',
    caseSensitive: false,
  );
  static final _yearPattern = RegExp(
    r'(?:^|[\s._\-\[\(])((?:19|20)\d{2})(?:[\s._\]\)\-]|$)',
  );
  static final _bracketPattern = RegExp(r'\[.*?\]|\(.*?\)');
  static final _multiSpacePattern = RegExp(r'\s+');

  static const _junkTokens = {
    '1080p',
    '720p',
    '480p',
    '2160p',
    '4k',
    '8k',
    'uhd',
    'hdr',
    'hdr10',
    'hdr10plus',
    'dv',
    'dovi',
    'dolby',
    'vision',
    'bluray',
    'blu-ray',
    'bdrip',
    'brrip',
    'dvdrip',
    'dvd',
    'webrip',
    'web-dl',
    'webdl',
    'web',
    'hdtv',
    'hdrip',
    'pdtv',
    'remux',
    'hybrid',
    'cam',
    'ts',
    'tc',
    'r5',
    'screener',
    'x264',
    'x265',
    'h264',
    'h265',
    'hevc',
    'avc',
    'av1',
    'xvid',
    'divx',
    'aac',
    'ac3',
    'dts',
    'truehd',
    'atmos',
    'ddp',
    'ddp5',
    'dd5',
    '5.1',
    '7.1',
    '2.0',
    '10bit',
    '8bit',
    'proper',
    'repack',
    'extended',
    'unrated',
    'directors',
    'cut',
    'internal',
    'limited',
    'multi',
    'dual',
    'audio',
    'subs',
    'subbed',
    'nf',
    'amzn',
    'dsnp',
    'atvp',
    'hulu',
    'hmax',
    'complete',
    'readnfo',
    'nfo',
    'sample',
    'ws',
    'fs',
    'pal',
    'ntsc',
  };

  /// Parses [fileNameOrPath] into a [ParsedVideoName].
  static ParsedVideoName parse(String fileNameOrPath) {
    final original = fileNameOrPath.trim();
    if (original.isEmpty || original.startsWith('content:')) {
      return ParsedVideoName(title: '', originalName: original);
    }

    var working = original.replaceAll('\\', '/');
    final slash = working.lastIndexOf('/');
    if (slash >= 0 && slash < working.length - 1) {
      working = working.substring(slash + 1);
    }

    working = working.replaceAll(_extensionPattern, '');
    working = working.replaceAll(_bracketPattern, ' ');

    int? season;
    int? episode;
    final seasonMatch = _seasonEpisodePattern.firstMatch(working) ??
        _altSeasonEpisodePattern.firstMatch(working);
    if (seasonMatch != null) {
      season = int.tryParse(seasonMatch.group(1) ?? '');
      episode = int.tryParse(seasonMatch.group(2) ?? '');
      working = working.substring(0, seasonMatch.start);
    }

    int? year;
    final yearMatch = _yearPattern.firstMatch(working);
    if (yearMatch != null) {
      year = int.tryParse(yearMatch.group(1) ?? '');
      if (season == null) {
        working = working.substring(0, yearMatch.start);
      }
    }

    working =
        working.replaceAll('.', ' ').replaceAll('_', ' ').replaceAll('-', ' ');
    working = working.replaceAll(_multiSpacePattern, ' ').trim();

    final kept = <String>[];
    for (final token in working.split(' ')) {
      final normalized =
          token.toLowerCase().replaceAll(RegExp(r'[^a-z0-9.+]'), '');
      if (normalized.isEmpty) continue;
      if (_junkTokens.contains(normalized)) continue;
      kept.add(token);
    }

    final title = kept.join(' ').replaceAll(_multiSpacePattern, ' ').trim();

    return ParsedVideoName(
      title: title,
      year: year,
      season: season,
      episode: episode,
      originalName: original,
    );
  }
}
