import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_utools/app/app_settings.dart';
import 'package:flutter_utools/core/database/settings_storage.dart';
import 'package:flutter_utools/core/network/bangumi_api.dart';
import 'package:flutter_utools/core/network/notion_api.dart';
import 'package:flutter_utools/features/dashboard/providers/recommendation_view_model.dart';
import 'package:flutter_utools/models/mapping_config.dart';
import 'package:flutter_utools/models/notion_models.dart';

class _StaticSettings extends AppSettings {
  _StaticSettings({
    this.token = '',
    this.databaseId = '',
  });

  final String token;
  final String databaseId;

  @override
  String get notionToken => token;

  @override
  String get notionDatabaseId => databaseId;

  @override
  String get bangumiAccessToken => '';
}

DailyRecommendation _buildRecommendation() {
  return const DailyRecommendation(
    title: 'Cached Recommendation',
    yougnScore: 8.7,
    bangumiScore: 8.1,
    airDate: null,
    airEndDate: null,
    followDate: null,
    tags: ['tag-a'],
    type: 'Anime',
    shortReview: 'short',
    longReview: 'long',
    cover: 'https://img.example.com/cover.jpg',
    contentCoverUrl: null,
    contentLongReview: null,
    bangumiId: '101',
    subjectId: '101',
    pageId: 'page-1',
    pageUrl: 'https://www.notion.so/page-1',
    animationProduction: null,
    director: null,
    script: null,
    storyboard: null,
  );
}

Map<String, dynamic> _watchEntryJson({
  required String id,
  required String title,
}) {
  return {
    'id': id,
    'title': title,
    'coverUrl': null,
    'watchedEpisodes': 3,
    'totalEpisodes': 12,
    'updatedEpisodes': null,
    'bangumiId': '101',
    'pageUrl': 'https://www.notion.so/$id',
    'lastEditedAt': '2026-02-01T00:00:00.000',
    'lastWatchedAt': '2026-02-02T00:00:00.000',
    'followDate': '2026-01-01T00:00:00.000',
    'status': 'watching',
    'tags': ['cached'],
    'yougnScore': 8.5,
  };
}

Future<void> _seedAllCaches(
  SettingsStorage storage, {
  required String scope,
}) async {
  final recommendation = _buildRecommendation();
  await storage.saveDailyRecommendationCache(
    date: '2026-02-01',
    payload: jsonEncode({
      'version': RecommendationViewModel.dailyCacheVersion,
      'currentIndex': 0,
      'indices': const [0],
      'candidates': [recommendation.toJson()],
    }),
  );
  await storage.saveRecommendationStatsCache(
    scope: scope,
    version: RecommendationViewModel.statsCacheVersion,
    data: {
      'entries': const [
        {'yougnScore': 8.7, 'bangumiScore': 8.1},
      ],
    },
  );
  await storage.saveRecommendationRecentCache(
    scope: scope,
    version: RecommendationViewModel.recentCacheVersion,
    data: {
      'watching': [_watchEntryJson(id: 'w1', title: 'Watching 1')],
      'watched': [_watchEntryJson(id: 'w2', title: 'Watched 1')],
      'message': 'cached recent message',
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecommendationViewModel cache behavior', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('restores daily/stats/recent modules from cache', () async {
      final storage = SettingsStorage();
      await _seedAllCaches(storage, scope: '');

      final client = MockClient(
        (_) async => http.Response('{"message":"failed"}', 500),
      );
      final viewModel = RecommendationViewModel(
        notionApi: NotionApi(client: client),
        bangumiApi: BangumiApi(client: client),
        settingsStorage: storage,
      );

      await viewModel.load(_StaticSettings());

      expect(viewModel.errorMessage, isNull);
      expect(viewModel.dailyCandidates.length, 1);
      expect(viewModel.dailyCandidates.first.title, 'Cached Recommendation');
      expect(viewModel.scoreTotal, 1);
      expect(viewModel.recentWatching.length, 1);
      expect(viewModel.recentWatched.length, 1);
      expect(viewModel.recentMessage, 'cached recent message');
    });

    test('keeps restored cache when refresh request fails', () async {
      final storage = SettingsStorage();
      await _seedAllCaches(storage, scope: 'db-1');
      await storage.saveDailyRecommendationBindings(
        const NotionDailyRecommendationBindings(
          title: 'Title',
          yougnScore: 'Yougn Score',
        ),
      );

      final client = MockClient(
        (_) async => http.Response('{"message":"failed"}', 500),
      );
      final viewModel = RecommendationViewModel(
        notionApi: NotionApi(client: client),
        bangumiApi: BangumiApi(client: client),
        settingsStorage: storage,
      );

      await viewModel.load(
        _StaticSettings(token: 'token', databaseId: 'db-1'),
      );

      expect(viewModel.dailyCandidates.length, 1);
      expect(viewModel.dailyCandidates.first.title, 'Cached Recommendation');
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.scoreTotal, 1);
      expect(viewModel.recentWatching.length, 1);
    });
  });
}
