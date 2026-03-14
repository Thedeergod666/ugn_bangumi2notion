import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_utools/core/database/settings_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  group('SettingsStorage scoped cache payloads', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, (call) async {
        if (call.method == 'read') {
          return null;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, null);
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

    test('loadAll defaults recent view mode to auto', () async {
      final storage = SettingsStorage();

      final data = await storage.loadAll();

      expect(data[SettingsKeys.recentViewMode], 'auto');
    });

    test('loadAll preserves explicit recent view mode selection', () async {
      final storage = SettingsStorage();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SettingsKeys.recentViewMode, 'gallery');

      final data = await storage.loadAll(forceRefresh: true);

      expect(data[SettingsKeys.recentViewMode], 'gallery');
    });
  });
}
