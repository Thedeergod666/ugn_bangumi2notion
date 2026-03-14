import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_utools/features/dashboard/presentation/recommendation_view.dart';
import 'package:flutter_utools/features/dashboard/providers/recommendation_view_model.dart';
import 'package:flutter_utools/models/notion_models.dart';
import 'package:flutter_utools/models/progress_segments.dart';

void main() {
  RecommendationViewState buildState({
    required TextEditingController controller,
  }) {
    return RecommendationViewState(
      showRatings: false,
      recommendation: const DailyRecommendation(
        title: 'demo',
        yougnScore: null,
        bangumiScore: null,
        airDate: null,
        airEndDate: null,
        followDate: null,
        tags: [],
        type: null,
        shortReview: null,
        longReview: null,
        cover: null,
        contentCoverUrl: null,
        contentLongReview: null,
        bangumiId: null,
        subjectId: null,
        pageId: null,
        pageUrl: null,
        animationProduction: null,
        director: null,
        script: null,
        storyboard: null,
      ),
      coverUrl: '',
      longReview: '',
      tags: const [],
      bangumiScore: null,
      yougnRank: null,
      bangumiRank: null,
      showLongReview: false,
      isStatsLoading: false,
      scoreBins: const [],
      scoreTotal: 0,
      currentScoreBinLabel: null,
      recentViewMode: 'auto',
      isRecentLoading: false,
      recentMessage: null,
      recentWatching: const [
        NotionWatchEntry(
          id: 'watching-1',
          title: '在看作品',
          bangumiId: '101',
          watchedEpisodes: 6,
          totalEpisodes: 12,
          yougnScore: 7.4,
          followDate: null,
          lastWatchedAt: null,
        ),
      ],
      recentWatched: const [
        NotionWatchEntry(
          id: 'watched-1',
          title: '已看作品',
          bangumiId: '202',
          watchedEpisodes: 12,
          totalEpisodes: 12,
          lastWatchedAt: null,
        ),
      ],
      bangumiDetailCache: const {},
      notionContentCache: const {},
      recentReleaseSummaryCache: const {
        101: EpisodeReleaseSummary(
          latestAiredEpisode: 8,
          latestAiredAt: null,
          nextEpisode: 9,
          nextAiredAt: null,
        ),
        202: EpisodeReleaseSummary(
          latestAiredEpisode: 12,
          latestAiredAt: null,
          nextEpisode: null,
          nextAiredAt: null,
        ),
      },
      notionSearchController: controller,
    );
  }

  RecommendationViewCallbacks callbacks() {
    return RecommendationViewCallbacks(
      onOpenNotionDetail: () {},
      onToggleLongReview: () {},
      onNotionSearch: (_) {},
      onRecentViewModeChanged: (_) {},
      onOpenRecentEntry: (_) {},
      onIncrementRecentWatch: (_) {},
    );
  }

  testWidgets('recent section renders dense list content on wide layout',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecommendationView(
            state: buildState(controller: controller),
            callbacks: callbacks(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('最近更新'), findsWidgets);
    expect(find.textContaining('最近观看'), findsWidgets);
    expect(find.textContaining('已看完'), findsOneWidget);
    expect(find.byTooltip('+1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recommendation hero section keeps readable Chinese labels',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecommendationView(
            state: buildState(controller: controller),
            callbacks: callbacks(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('今日安利'), findsOneWidget);
    expect(find.text('Notion 搜索'), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('排名分布'), findsOneWidget);
    expect(find.text('长评'), findsOneWidget);
  });
}
