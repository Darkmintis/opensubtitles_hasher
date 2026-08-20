import 'package:flutter_test/flutter_test.dart';
import 'package:opensubtitles_hasher/opensubtitles_hasher.dart';

void main() {
  group('VideoFileNameParser', () {
    test('extracts a movie title and year from a scene filename', () {
      final parsed = OpenSubtitlesHasher.parseFileName(
        'The.Matrix.1999.1080p.BluRay.x264-GRP.mkv',
      );

      expect(parsed.title, 'The Matrix');
      expect(parsed.year, 1999);
      expect(parsed.isEpisode, isFalse);
    });

    test('extracts a series title and SxxExx from a scene filename', () {
      final parsed = VideoFileNameParser.parse(
        'Breaking.Bad.S01E01.Pilot.1080p.WEBRip.x264.mkv',
      );

      expect(parsed.title, 'Breaking Bad');
      expect(parsed.season, 1);
      expect(parsed.episode, 1);
      expect(parsed.isEpisode, isTrue);
    });

    test('supports 1x05 episode numbering', () {
      final parsed = VideoFileNameParser.parse(
        'Show.Name.1x05.720p.WEBRip.mkv',
      );

      expect(parsed.title, 'Show Name');
      expect(parsed.season, 1);
      expect(parsed.episode, 5);
    });

    test('returns a searchTitle on PickedMovie', () {
      const picked = PickedMovie(
        path: '/movies/Inception.2010.1080p.mkv',
        name: 'Inception.2010.1080p.mkv',
      );

      expect(picked.searchTitle, 'Inception');
      expect(picked.parsedName.year, 2010);
    });

    test('ignores content URIs without a display name', () {
      final parsed = VideoFileNameParser.parse('content://media/external/1');
      expect(parsed.hasTitle, isFalse);
    });
  });
}
