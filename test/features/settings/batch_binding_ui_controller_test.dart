import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_utools/features/settings/providers/batch_binding_ui_controller.dart';
import 'package:flutter_utools/features/settings/providers/batch_binding_ui_models.dart';
import 'package:flutter_utools/features/settings/providers/batch_import_view_model.dart';
import 'package:flutter_utools/models/bangumi_models.dart';
import 'package:flutter_utools/models/notion_models.dart';

BatchImportCandidate buildCandidate({
  required String pageId,
  required String title,
  required List<BangumiSearchItem> matches,
  bool bound = false,
}) {
  return BatchImportCandidate(
    notionItem: NotionSearchItem(
      id: pageId,
      title: title,
      url: 'https://www.notion.so/$pageId',
      notionId: pageId,
      notionType: '动画',
    ),
    matches: matches,
    bound: bound,
  );
}

BangumiSearchItem buildMatch({
  required int id,
  required String nameCn,
  required String airDate,
  required double score,
}) {
  return BangumiSearchItem(
    id: id,
    name: nameCn,
    nameCn: nameCn,
    summary: '',
    imageUrl: '',
    airDate: airDate,
    score: score,
    rank: 0,
  );
}

void main() {
  group('BatchBindingUiController', () {
    test('defaults to only-unbound and selects first visible item', () {
      final controller = BatchBindingUiController();
      controller.applyCandidates([
        buildCandidate(
          pageId: 'p1',
          title: '赛马娘 第二季',
          matches: [
            buildMatch(id: 1, nameCn: '赛马娘 第二季', airDate: '2021-01-01', score: 7.8),
          ],
        ),
        buildCandidate(
          pageId: 'p2',
          title: '药屋少女',
          matches: [
            buildMatch(id: 2, nameCn: '药屋少女', airDate: '2023-01-01', score: 8.1),
          ],
          bound: true,
        ),
      ]);

      expect(controller.onlyUnbound, isTrue);
      expect(controller.visibleItems.length, 1);
      expect(controller.activeItem?.pageId, 'p1');
    });

    test('filters by notion title and candidate id', () {
      final controller = BatchBindingUiController();
      controller.applyCandidates([
        buildCandidate(
          pageId: 'p1',
          title: '赛马娘 第二季',
          matches: [
            buildMatch(id: 315574, nameCn: '赛马娘 第二季', airDate: '2021-01-01', score: 7.8),
          ],
        ),
        buildCandidate(
          pageId: 'p2',
          title: '药屋少女',
          matches: [
            buildMatch(id: 407332, nameCn: '药屋少女', airDate: '2023-01-01', score: 8.1),
          ],
        ),
      ]);

      controller.setQuery('药屋');
      expect(controller.visibleItems.map((item) => item.pageId), ['p2']);

      controller.setQuery('315574');
      expect(controller.visibleItems.map((item) => item.pageId), ['p1']);
    });

    test('sorts by score and year using highest-score match baseline', () {
      final controller = BatchBindingUiController();
      controller.setOnlyUnbound(false);
      controller.applyCandidates([
        buildCandidate(
          pageId: 'p1',
          title: '条目1',
          matches: [
            buildMatch(id: 11, nameCn: '条目1 A', airDate: '2019-01-01', score: 6.2),
            buildMatch(id: 12, nameCn: '条目1 B', airDate: '2021-01-01', score: 8.9),
          ],
        ),
        buildCandidate(
          pageId: 'p2',
          title: '条目2',
          matches: [
            buildMatch(id: 21, nameCn: '条目2', airDate: '2023-01-01', score: 7.1),
          ],
        ),
      ]);

      controller.setSortMode(BatchSortMode.score);
      expect(controller.visibleItems.first.pageId, 'p1');

      controller.setSortMode(BatchSortMode.year);
      expect(controller.visibleItems.first.pageId, 'p1');
    });

    test('supports selection and remove-selected', () {
      final controller = BatchBindingUiController();
      controller.applyCandidates([
        buildCandidate(
          pageId: 'p1',
          title: 'A',
          matches: [buildMatch(id: 1, nameCn: 'A', airDate: '2020', score: 7.0)],
        ),
        buildCandidate(
          pageId: 'p2',
          title: 'B',
          matches: [buildMatch(id: 2, nameCn: 'B', airDate: '2021', score: 7.0)],
        ),
      ]);

      controller.toggleItemSelected('p1');
      expect(controller.selectedVisibleCount, 1);

      final removed = controller.removeSelectedVisibleItems();
      expect(removed.length, 1);
      expect(removed.first.pageId, 'p1');
      expect(controller.visibleItems.map((item) => item.pageId), ['p2']);
    });

    test('auto-bind picks visible unbound items above threshold', () {
      final controller = BatchBindingUiController(autoBindThreshold: 85);
      controller.applyCandidates([
        buildCandidate(
          pageId: 'p1',
          title: '赛马娘 第二季',
          matches: [
            buildMatch(id: 1, nameCn: '赛马娘 第二季', airDate: '2021', score: 7.8),
          ],
        ),
        buildCandidate(
          pageId: 'p2',
          title: '赛马娘 第二季',
          matches: [
            buildMatch(id: 2, nameCn: '完全不相关标题', airDate: '2021', score: 7.8),
          ],
        ),
      ]);

      final targets = controller.autoBindableVisibleItems();
      expect(targets.map((item) => item.pageId), ['p1']);
    });

    test('conflict toggle is visual-only and keeps item in auto-bind pool', () {
      final controller = BatchBindingUiController(autoBindThreshold: 85);
      controller.applyCandidates([
        buildCandidate(
          pageId: 'p1',
          title: '赛马娘 第二季',
          matches: [
            buildMatch(id: 1, nameCn: '赛马娘 第二季', airDate: '2021', score: 7.8),
          ],
        ),
      ]);

      controller.toggleConflict('p1');
      expect(controller.visibleItems.first.status, BatchItemStatus.conflict);

      final targets = controller.autoBindableVisibleItems();
      expect(targets.length, 1);
      expect(targets.first.pageId, 'p1');
    });
  });
}
