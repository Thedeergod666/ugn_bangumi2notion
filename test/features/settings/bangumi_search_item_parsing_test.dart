import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_utools/models/bangumi_models.dart';

void main() {
  group('BangumiSearchItem.fromJson', () {
    test('reads score and rank from rating object when top-level missing', () {
      final item = BangumiSearchItem.fromJson({
        'id': 252655,
        'name': 'ゾンビランドサガ',
        'name_cn': '佐贺偶像是传奇',
        'summary': 'summary',
        'date': '2018-10-04',
        'images': {'medium': 'https://img.example/1.jpg'},
        'rating': {
          'score': 8.3,
          'rank': 86,
        },
      });

      expect(item.score, 8.3);
      expect(item.rank, 86);
    });

    test('falls back to top-level score and rank when rating missing', () {
      final item = BangumiSearchItem.fromJson({
        'id': 100,
        'name': 'A',
        'name_cn': 'A',
        'summary': '',
        'date': '2020-01-01',
        'images': {'medium': ''},
        'score': 7.1,
        'rank': 999,
      });

      expect(item.score, 7.1);
      expect(item.rank, 999);
    });
  });
}
