import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_utools/features/airing_calendar/presentation/calendar_view.dart';
import 'package:flutter_utools/models/bangumi_models.dart';
import 'package:flutter_utools/models/progress_segments.dart';

BangumiCalendarItem _buildItem(int id) {
  return BangumiCalendarItem(
    id: id,
    type: 2,
    name: 'Sample Title $id',
    nameCn: '示例条目 $id',
    summary: '这是一个用于布局测试的较长简介文本，用来覆盖卡片摘要区域。',
    imageUrl: '',
    airDate: '2026-03-09',
    airWeekday: 1,
    eps: 1,
    epsCount: 24,
  );
}

BangumiSubjectDetail _buildDetail(int id) {
  return BangumiSubjectDetail(
    id: id,
    name: 'Sample Title $id',
    nameCn: '示例条目 $id',
    summary: 'summary',
    imageUrl: '',
    airDate: '2026-03-09',
    epsCount: 24,
    tags: const ['科幻', '战斗', '校园', '成长'],
    tagDetails: const [
      BangumiTag(name: '科幻', count: 50),
      BangumiTag(name: '战斗', count: 45),
      BangumiTag(name: '校园', count: 30),
      BangumiTag(name: '成长', count: 22),
    ],
    studio: '',
    director: '',
    script: '',
    storyboard: '',
    animationProduction: '',
    score: 8.4,
    ratingTotal: 1000,
    ratingCount: const {},
    rank: 120,
    infoboxMap: const {},
  );
}

CalendarViewState _buildState({
  String mode = 'gallery',
  bool withItems = true,
  List<BangumiCalendarItem>? boundItems,
  Map<int, int>? watchedEpisodes,
  Map<int, DateTime?>? lastWatchedAt,
  Map<int, EpisodeReleaseSummary>? releaseSummaryCache,
}) {
  final items = [_buildItem(1), _buildItem(2), _buildItem(3)];
  final detailCache = {
    for (final item in items) item.id: _buildDetail(item.id),
  };

  return CalendarViewState(
    notionConfigured: true,
    showRatings: true,
    calendarViewMode: mode,
    selectedWeekday: 1,
    selectedWeekdayInfo: const BangumiCalendarWeekday(
      id: 1,
      en: 'Mon',
      cn: '周一',
      ja: '月',
    ),
    selectedItems: withItems ? items : const [],
    boundItems: boundItems ?? const [],
    boundIds: const {1, 2},
    weekdayBoundCounts: const {
      1: 12,
      2: 9,
      3: 8,
      4: 7,
      5: 6,
      6: 5,
      7: 4,
    },
    watchedEpisodes: watchedEpisodes ??
        const {
          1: 3,
          2: 5,
          3: 2,
        },
    yougnScores: const {},
    lastWatchedAt: lastWatchedAt ?? const {},
    detailCache: detailCache,
    releaseSummaryCache: releaseSummaryCache ??
        const {
          1: EpisodeReleaseSummary(
            latestAiredEpisode: 8,
            latestAiredAt: null,
            nextEpisode: 9,
            nextAiredAt: null,
          ),
          2: EpisodeReleaseSummary(
            latestAiredEpisode: 10,
            latestAiredAt: null,
            nextEpisode: 11,
            nextAiredAt: null,
          ),
          3: EpisodeReleaseSummary(
            latestAiredEpisode: 6,
            latestAiredAt: null,
            nextEpisode: 7,
            nextAiredAt: null,
          ),
        },
    airEndDateCache: const {
      1: '2026-09-01',
      2: '2026-09-01',
      3: '2026-09-01',
    },
  );
}

CalendarViewCallbacks _callbacks() {
  return CalendarViewCallbacks(
    onWeekdaySelected: (_) {},
    onCalendarViewModeChanged: (_) {},
    onTapSubject: (_) {},
    onLongPressBoundSubject: (_) {},
  );
}

void main() {
  testWidgets('calendar view does not report overflow on gallery layout',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(980, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarView(
            state: _buildState(),
            callbacks: _callbacks(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('weekday chip does not overflow on narrow width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarView(
            state: _buildState(mode: 'list', withItems: false),
            callbacks: _callbacks(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('bound card shows update-driven content without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final state = _buildState(
      mode: 'list',
      boundItems: [_buildItem(1)],
      watchedEpisodes: const {1: 6, 2: 5, 3: 2},
      lastWatchedAt: {
        1: DateTime.parse('2026-03-12T21:15:00'),
      },
      releaseSummaryCache: const {
        1: EpisodeReleaseSummary(
          latestAiredEpisode: 8,
          latestAiredAt: null,
          nextEpisode: 9,
          nextAiredAt: null,
        ),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarView(
            state: state,
            callbacks: _callbacks(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('最近更新'), findsWidgets);
    expect(find.textContaining('下次更新'), findsWidgets);
    expect(find.textContaining('看到'), findsWidgets);
    expect(find.textContaining('最近观看'), findsWidgets);
    expect(find.textContaining('未看'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
