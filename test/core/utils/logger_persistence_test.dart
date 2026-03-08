import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_utools/core/database/settings_storage.dart';
import 'package:flutter_utools/core/utils/logging.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Logger persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('restores error logs after logger recreation', () async {
      final storage = SettingsStorage();
      final logger = Logger(storage: storage, maxEntries: 300);

      logger.info('session-info');
      logger.error('session-error');
      await logger.waitForPersistence();

      final restored = Logger(storage: storage, maxEntries: 300);
      await restored.restorePersistedErrors();

      expect(restored.entries.length, 1);
      expect(restored.entries.single.level, LogLevel.error);
      expect(restored.entries.single.message, 'session-error');
    });

    test('clear removes both memory and persisted error logs', () async {
      final storage = SettingsStorage();
      final logger = Logger(storage: storage, maxEntries: 300);

      logger.error('to-clear');
      await logger.waitForPersistence();
      logger.clear();

      for (var i = 0; i < 8; i += 1) {
        if (await storage.getErrorLogCache() == null) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final restored = Logger(storage: storage, maxEntries: 300);
      await restored.restorePersistedErrors();
      expect(restored.entries, isEmpty);
    });

    test('stores only latest 300 error logs', () async {
      final storage = SettingsStorage();
      final logger = Logger(storage: storage, maxEntries: 300);

      for (var i = 0; i < 350; i += 1) {
        logger.error('error-$i');
      }
      await logger.waitForPersistence();

      final restored = Logger(storage: storage, maxEntries: 300);
      await restored.restorePersistedErrors();

      expect(restored.entries.length, 300);
      expect(restored.entries.first.message, 'error-50');
      expect(restored.entries.last.message, 'error-349');
    });
  });
}
