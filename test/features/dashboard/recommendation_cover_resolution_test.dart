import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_utools/features/dashboard/presentation/recommendation_view.dart';
import 'package:flutter_utools/features/dashboard/providers/recommendation_view_model.dart';
import 'package:flutter_utools/models/bangumi_models.dart';
import 'package:flutter_utools/models/notion_models.dart';

void main() {
  RecommendationViewCallbacks buildCallbacks() {
    return RecommendationViewCallbacks(
      onOpenNotionDetail: () {},
      onCopyRecommendationTitle: (_) {},
      onToggleLongReview: () {},
      onNotionSearch: (_) {},
      onRecentViewModeChanged: (_) {},
      onOpenRecentEntry: (_) {},
      onCopyRecentTitle: (_) {},
      onIncrementRecentWatch: (_) {},
    );
  }

  DailyRecommendation buildRecommendation() {
    return const DailyRecommendation(
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
    );
  }

  BangumiSubjectDetail buildBangumiDetail({
    required int id,
    required String imageUrl,
  }) {
    return BangumiSubjectDetail.fromJson({
      'id': id,
      'name': 'name$id',
      'name_cn': 'name$id',
      'summary': '',
      'images': {'large': imageUrl},
      'date': '',
      'eps': 0,
      'tags': [],
      'infobox': [],
      'rating': {
        'score': 0,
        'total': 0,
        'count': <String, dynamic>{},
      },
    });
  }

  RecommendationViewState buildState({
    required TextEditingController controller,
    required List<NotionWatchEntry> watching,
    Map<String, RecommendationNotionContent> notionContentCache = const {},
    Map<int, BangumiSubjectDetail> bangumiDetailCache = const {},
  }) {
    return RecommendationViewState(
      showRatings: false,
      recommendation: buildRecommendation(),
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
      recentViewMode: 'list',
      isRecentLoading: false,
      recentMessage: null,
      recentWatching: watching,
      recentWatched: const [],
      bangumiDetailCache: bangumiDetailCache,
      notionContentCache: notionContentCache,
      recentReleaseSummaryCache: const {},
      notionSearchController: controller,
    );
  }

  NotionWatchEntry buildWatchEntry({
    required String id,
    String? coverUrl,
    String? bangumiId,
  }) {
    return NotionWatchEntry(
      id: id,
      title: 'entry-$id',
      coverUrl: coverUrl,
      bangumiId: bangumiId,
    );
  }

  Future<void> pumpView(
    WidgetTester tester, {
    required RecommendationViewState state,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecommendationView(
            state: state,
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );
  }

  String firstNetworkImageUrl(WidgetTester tester) {
    final finder = find.byWidgetPredicate(
      (widget) => widget is Image && widget.image is NetworkImage,
    );
    expect(finder, findsOneWidget);
    final image = tester.widget<Image>(finder);
    return (image.image as NetworkImage).url;
  }

  testWidgets('recent cover falls back to notion content cache first', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    final state = buildState(
      controller: controller,
      watching: [
        buildWatchEntry(id: 'page-1', coverUrl: null, bangumiId: '100'),
      ],
      notionContentCache: const {
        'page-1': RecommendationNotionContent(
          coverUrl: 'https://cover.example.com/notion.jpg',
          longReview: null,
        ),
      },
      bangumiDetailCache: {
        100: buildBangumiDetail(
          id: 100,
          imageUrl: 'https://cover.example.com/bangumi.jpg',
        ),
      },
    );

    await pumpView(tester, state: state);

    expect(
      firstNetworkImageUrl(tester),
      'https://cover.example.com/notion.jpg',
    );
  });

  testWidgets('recent cover falls back to bangumi detail when notion is empty',
      (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    final state = buildState(
      controller: controller,
      watching: [
        buildWatchEntry(id: 'page-2', coverUrl: null, bangumiId: '101'),
      ],
      bangumiDetailCache: {
        101: buildBangumiDetail(
          id: 101,
          imageUrl: 'https://cover.example.com/bangumi-only.jpg',
        ),
      },
    );

    await pumpView(tester, state: state);

    expect(
      firstNetworkImageUrl(tester),
      'https://cover.example.com/bangumi-only.jpg',
    );
  });

  testWidgets('recent cover keeps direct entry cover as highest priority', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    final state = buildState(
      controller: controller,
      watching: [
        buildWatchEntry(
          id: 'page-3',
          coverUrl: 'https://cover.example.com/direct.jpg',
          bangumiId: '102',
        ),
      ],
      notionContentCache: const {
        'page-3': RecommendationNotionContent(
          coverUrl: 'https://cover.example.com/notion-backup.jpg',
          longReview: null,
        ),
      },
      bangumiDetailCache: {
        102: buildBangumiDetail(
          id: 102,
          imageUrl: 'https://cover.example.com/bangumi-backup.jpg',
        ),
      },
    );

    await pumpView(tester, state: state);

    expect(
      firstNetworkImageUrl(tester),
      'https://cover.example.com/direct.jpg',
    );
  });
}
