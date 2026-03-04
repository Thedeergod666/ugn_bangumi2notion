import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_utools/features/settings/providers/batch_binding_similarity.dart';

void main() {
  group('computeTitleSimilarity', () {
    test('returns 100 for exact match', () {
      final score = computeTitleSimilarity('赛马娘 Pretty Derby 第二季', '赛马娘 Pretty Derby 第二季');
      expect(score, 100);
    });

    test('returns high score for containment match', () {
      final score = computeTitleSimilarity('赛马娘PrettyDerby第二季', '赛马娘第二季');
      expect(score, greaterThanOrEqualTo(85));
    });

    test('returns low score for unrelated titles', () {
      final score = computeTitleSimilarity('赛马娘', '药屋少女的呢喃');
      expect(score, lessThan(60));
    });
  });

  group('parseBangumiIdInput', () {
    test('parses plain id', () {
      expect(parseBangumiIdInput('315574'), 315574);
    });

    test('parses subject url', () {
      expect(
        parseBangumiIdInput('https://bgm.tv/subject/315574'),
        315574,
      );
    });

    test('returns null for invalid input', () {
      expect(parseBangumiIdInput('abc'), isNull);
    });
  });

  group('extractAirYear', () {
    test('extracts year from date text', () {
      expect(extractAirYear('2023-04-05'), 2023);
    });

    test('returns 0 when year missing', () {
      expect(extractAirYear('unknown'), 0);
    });
  });
}
