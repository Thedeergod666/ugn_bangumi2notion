import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_utools/core/network/bangumi_api.dart';
import 'package:flutter_utools/models/bangumi_models.dart';

void main() {
  group('BangumiApi episode release summary', () {
    final api = BangumiApi();

    tearDownAll(api.dispose);

    test('captures latest aired and next scheduled episodes with time', () {
      final summary = api.buildEpisodeReleaseSummary(
        episodes: const [
          BangumiEpisode(
            id: 1,
            type: 0,
            sort: 9,
            ep: 9,
            airDate: '2026-03-13T23:30:00+08:00',
          ),
          BangumiEpisode(
            id: 2,
            type: 0,
            sort: 10,
            ep: 10,
            airDate: '2026-03-14T23:30:00+08:00',
          ),
          BangumiEpisode(
            id: 3,
            type: 0,
            sort: 11,
            ep: 11,
            airDate: '2026-03-20T23:30:00+08:00',
          ),
        ],
        now: DateTime.parse('2026-03-15T08:00:00+08:00'),
      );

      expect(summary.latestAiredEpisode, 10);
      expect(
        summary.latestAiredAt,
        DateTime.parse('2026-03-14T23:30:00+08:00'),
      );
      expect(summary.nextEpisode, 11);
      expect(
        summary.nextAiredAt,
        DateTime.parse('2026-03-20T23:30:00+08:00'),
      );
    });

    test('handles date-only releases and missing future schedule', () {
      final summary = api.buildEpisodeReleaseSummary(
        episodes: const [
          BangumiEpisode(
            id: 1,
            type: 0,
            sort: 1,
            ep: 1,
            airDate: '2026-03-01',
          ),
          BangumiEpisode(
            id: 2,
            type: 0,
            sort: 2,
            ep: 2,
            airDate: '2026-03-08',
          ),
        ],
        now: DateTime.parse('2026-03-10T08:00:00+08:00'),
      );

      expect(summary.latestAiredEpisode, 2);
      expect(summary.latestAiredAt, DateTime.parse('2026-03-08'));
      expect(summary.nextEpisode, isNull);
      expect(summary.nextAiredAt, isNull);
    });

    test('returns empty summary when episodes have no valid air dates', () {
      final summary = api.buildEpisodeReleaseSummary(
        episodes: const [
          BangumiEpisode(id: 1, type: 0, sort: 1, ep: 1, airDate: ''),
          BangumiEpisode(
            id: 2,
            type: 0,
            sort: 2,
            ep: 2,
            airDate: 'not-a-date',
          ),
        ],
        now: DateTime.parse('2026-03-10T08:00:00+08:00'),
      );

      expect(summary.latestAiredEpisode, isNull);
      expect(summary.latestAiredAt, isNull);
      expect(summary.nextEpisode, isNull);
      expect(summary.nextAiredAt, isNull);
    });
  });
}
