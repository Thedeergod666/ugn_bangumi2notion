import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_utools/core/database/settings_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsStorage scoped cache payloads', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('calendar cache supports save/get/clear', () async {
      final storage = SettingsStorage();

      await storage.saveCalendarPageCache(
        scope: 'db-1',
        version: 1,
        data: {
          'days': const [],
          'selectedWeekday': 3,
        },
      );

      final hit = await storage.getCalendarPageCache(scope: 'db-1');
      expect(hit, isNotNull);
      expect(hit?['selectedWeekday'], 3);

      await storage.clearCalendarPageCache();
      final afterClear = await storage.getCalendarPageCache(scope: 'db-1');
      expect(afterClear, isNull);
    });

    test('scope mismatch returns null', () async {
      final storage = SettingsStorage();

      await storage.saveRecommendationStatsCache(
        scope: 'db-A',
        version: 1,
        data: {
          'entries': const [
            {'yougnScore': 8.7, 'bangumiScore': 8.1},
          ],
        },
      );

      final miss = await storage.getRecommendationStatsCache(scope: 'db-B');
      expect(miss, isNull);

      final hit = await storage.getRecommendationStatsCache(scope: 'db-A');
      expect(hit?['entries'], isA<List>());
    });

    test('damaged payload is ignored safely', () async {
      final storage = SettingsStorage();
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        SettingsKeys.batchImportCandidatesCachePayload,
        '{broken json',
      );

      final value = await storage.getBatchImportCandidatesCache(scope: 'db-1');
      expect(value, isNull);
    });

    test('error log cache uses fixed scope and supports clear', () async {
      final storage = SettingsStorage();

      await storage.saveErrorLogCache(
        version: 1,
        data: {
          'entries': const [
            {'message': 'E1'},
          ],
        },
      );

      final hit = await storage.getErrorLogCache();
      expect(hit, isNotNull);
      expect((hit?['entries'] as List).length, 1);

      await storage.clearErrorLogCache();
      final cleared = await storage.getErrorLogCache();
      expect(cleared, isNull);
    });
  });
}
