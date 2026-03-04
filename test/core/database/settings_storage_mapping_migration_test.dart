import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_utools/core/database/settings_storage.dart';
import 'package:flutter_utools/models/mapping_config.dart';
import 'package:flutter_utools/models/mapping_schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsStorage mapping migration', () {
    test('migrates V1 to V2 once and persists schemaVersion=2', () async {
      final legacyMapping = <String, dynamic>{
        'title': '旧标题',
        'bangumiId': '旧BangumiID',
        'watchBindings': <String, dynamic>{
          'title': '追番标题',
          'bangumiId': '追番BangumiID',
          'yougnScore': '追番评分',
        },
      };
      final legacyDaily = <String, dynamic>{
        'title': '推荐标题',
        'yougnScore': '推荐评分',
      };

      SharedPreferences.setMockInitialValues({
        SettingsKeys.mappingConfig: jsonEncode(legacyMapping),
        SettingsKeys.dailyRecommendationBindings: jsonEncode(legacyDaily),
      });

      final storage = SettingsStorage();
      final config = await storage.getMappingConfig();

      expect(config.schemaVersion, mappingSchemaVersion);
      expect(config.bindingFor(MappingSlotKey.title).propertyName, '追番标题');
      expect(
        config.bindingFor(MappingSlotKey.bangumiId).propertyName,
        '追番BangumiID',
      );

      final notes = storage.takeLastMappingMigrationNotes();
      expect(notes, isNotNull);
      expect(notes, isNotEmpty);

      final prefs = await SharedPreferences.getInstance();
      final persistedRaw = prefs.getString(SettingsKeys.mappingConfig);
      expect(persistedRaw, isNotNull);
      final persistedMap = jsonDecode(persistedRaw!) as Map<String, dynamic>;
      expect(persistedMap['schemaVersion'], mappingSchemaVersion);

      final secondLoad = await storage.getMappingConfig();
      expect(secondLoad.schemaVersion, mappingSchemaVersion);
      expect(storage.takeLastMappingMigrationNotes(), isNull);
    });

    test('returns V2 directly without migration notes when already migrated',
        () async {
      var v2 = MappingConfig();
      v2 = v2.updateBinding(
        MappingSlotKey.title,
        const FieldBinding(propertyName: '已迁移标题'),
      );

      SharedPreferences.setMockInitialValues({
        SettingsKeys.mappingConfig: jsonEncode(v2.toJson()),
        SettingsKeys.dailyRecommendationBindings: jsonEncode({
          'title': 'legacy_should_not_override',
          'yougnScore': 'legacy_should_not_override',
        }),
      });

      final storage = SettingsStorage();
      final config = await storage.getMappingConfig();

      expect(config.schemaVersion, mappingSchemaVersion);
      expect(config.bindingFor(MappingSlotKey.title).propertyName, '已迁移标题');
      expect(storage.takeLastMappingMigrationNotes(), isNull);
    });

    test('saveDailyRecommendationBindings syncs into V2 common bindings',
        () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SettingsStorage();

      await storage.saveDailyRecommendationBindings(
        const NotionDailyRecommendationBindings(
          title: '推荐标题',
          yougnScore: '推荐评分',
          longReview: '长评字段',
        ),
      );

      final config = await storage.getMappingConfig();
      expect(config.bindingFor(MappingSlotKey.title).propertyName, '推荐标题');
      expect(config.bindingFor(MappingSlotKey.yougnScore).propertyName, '推荐评分');
      expect(config.bindingFor(MappingSlotKey.longReview).propertyName, '长评字段');

      final dailyBindings = await storage.getDailyRecommendationBindings();
      expect(dailyBindings.title, '推荐标题');
      expect(dailyBindings.yougnScore, '推荐评分');
      expect(dailyBindings.longReview, '长评字段');
    });
  });
}
