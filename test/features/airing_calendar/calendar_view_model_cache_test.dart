import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_utools/app/app_settings.dart';
import 'package:flutter_utools/core/database/settings_storage.dart';
import 'package:flutter_utools/core/network/bangumi_api.dart';
import 'package:flutter_utools/core/network/notion_api.dart';
import 'package:flutter_utools/features/airing_calendar/providers/calendar_view_model.dart';
import 'package:flutter_utools/models/bangumi_models.dart';

class _StaticSettings extends AppSettings {
  @override
  String get notionToken => '';

  @override
  String get notionDatabaseId => '';

  @override
  String get bangumiAccessToken => '';
}

class _FailingBangumiApi extends BangumiApi {
  _FailingBangumiApi()
      : super(
          client: MockClient(
            (_) async => http.Response('{"message":"failed"}', 500),
          ),
        );

  @override
  Future<List<BangumiCalendarDay>> fetchCalendar() async {
    throw Exception('network failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CalendarViewModel cache fallback', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('keeps cached data when network fails', () async {
      final storage = SettingsStorage();
      await storage.saveCalendarPageCache(
        scope: '',
        version: 1,
        data: {
          'days': [
            {
              'weekday': {'id': 1, 'en': 'Mon', 'cn': 'Mon', 'ja': '月'},
              'items': [
                {
                  'id': 101,
                  'type': 2,
                  'name': 'Cached Name',
                  'nameCn': 'Cached CN',
                  'summary': '',
                  'imageUrl': '',
                  'airDate': '2026-01-01',
                  'airWeekday': 1,
                  'eps': 1,
                  'epsCount': 12,
                }
              ],
            }
          ],
          'boundIds': [101],
          'watchedEpisodes': {'101': 3},
          'yougnScores': {'101': 8.8},
          'lastWatchedAt': {'101': '2026-01-02T00:00:00.000'},
          'notionPageIds': {'101': 'page-1'},
          'notionConfigured': true,
          'selectedWeekday': 1,
          'crossSeasonCandidateIds': [101],
        },
      );

      final viewModel = CalendarViewModel(
        bangumiApi: _FailingBangumiApi(),
        notionApi: NotionApi(
          client: MockClient(
            (_) async => http.Response('{"message":"failed"}', 500),
          ),
        ),
        settingsStorage: storage,
      );

      await viewModel.load(_StaticSettings());

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.days, isNotEmpty);
      expect(viewModel.boundIds, contains(101));
      expect(viewModel.watchedEpisodes[101], 3);
    });

    test('shows error state when no cache and network fails', () async {
      final storage = SettingsStorage();
      final viewModel = CalendarViewModel(
        bangumiApi: _FailingBangumiApi(),
        notionApi: NotionApi(
          client: MockClient(
            (_) async => http.Response('{"message":"failed"}', 500),
          ),
        ),
        settingsStorage: storage,
      );

      await viewModel.load(_StaticSettings());

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.days, isEmpty);
      expect(viewModel.errorMessage, isNotNull);
    });
  });
}
