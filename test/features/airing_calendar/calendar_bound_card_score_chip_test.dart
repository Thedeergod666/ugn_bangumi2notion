import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_utools/features/airing_calendar/presentation/calendar_view.dart';
import 'package:flutter_utools/models/bangumi_models.dart';
import 'package:flutter_utools/models/progress_segments.dart';

BangumiCalendarItem _buildItem() {
  return const BangumiCalendarItem(
    id: 9,
    type: 2,
    name: 'Sample Title',
    nameCn: '示例条目',
    summary: 'summary',
    imageUrl: '',
    airDate: '2026-03-09',
    airWeekday: 1,
    eps: 1,
    epsCount: 24,
  );
}

BangumiSubjectDetail _buildDetail() {
  return BangumiSubjectDetail(
    id: 9,
    name: 'Sample Title',
    nameCn: '示例条目',
    summary: 'summary',
    imageUrl: '',
    airDate: '2026-03-09',
    epsCount: 24,
    tags: const ['科幻'],
    tagDetails: const [BangumiTag(name: '科幻', count: 50)],
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

CalendarViewState _buildState() {
  final item = _buildItem();
  return CalendarViewState(
    notionConfigured: true,
    showRatings: true,
    calendarViewMode: 'list',
    selectedWeekday: 1,
    selectedWeekdayInfo: const BangumiCalendarWeekday(
      id: 1,
      en: 'Mon',
      cn: '周一',
      ja: '月',
    ),
    selectedItems: const [],
    boundItems: [item],
    boundIds: const {9},
    weekdayBoundCounts: const {1: 1},
    watchedEpisodes: const {9: 9},
    yougnScores: const {9: 7.1},
    lastWatchedAt: {
      9: DateTime.parse('2026-03-12T21:48:00'),
    },
    detailCache: {9: _buildDetail()},
    releaseSummaryCache: const {
      9: EpisodeReleaseSummary(
        latestAiredEpisode: 10,
        latestAiredAt: null,
        nextEpisode: 11,
        nextAiredAt: null,
      ),
    },
    airEndDateCache: const {9: '2026-09-01'},
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
  testWidgets('bound card shows Bangumi score chip alongside Yougn and +1',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
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

    final yougn = find.textContaining('7.1');
    final bangumi = find.text('BGM 8.4');
    final plusOne = find.text('+1');

    expect(yougn, findsOneWidget);
    expect(bangumi, findsOneWidget);
    expect(plusOne, findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
