import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_utools/features/dashboard/presentation/recommendation_view.dart';

void main() {
  group('recent view mode resolution', () {
    test('defaults auto to list on wide screens', () {
      expect(resolveRecentViewModeForWidth('auto', 1200), 'list');
    });

    test('keeps explicit gallery preference', () {
      expect(resolveRecentViewModeForWidth('gallery', 1200), 'gallery');
    });

    test('keeps list on narrow screens', () {
      expect(resolveRecentViewModeForWidth('auto', 420), 'list');
    });
  });
}
