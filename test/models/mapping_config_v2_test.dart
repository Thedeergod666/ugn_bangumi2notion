import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_utools/models/mapping_config.dart';
import 'package:flutter_utools/models/mapping_schema.dart';

void main() {
  group('MappingConfig V2', () {
    test('serializes and deserializes with bindings/overrides/module params',
        () {
      var config = MappingConfig();
      config = config
          .updateBinding(
            MappingSlotKey.title,
            const FieldBinding(
              propertyName: '标题',
              readOverride: '标题读',
              writeOverride: '标题写',
              writeEnabledDefault: false,
            ),
          )
          .updateBinding(
            MappingSlotKey.bangumiId,
            const FieldBinding(propertyName: 'Bangumi ID'),
          )
          .updateModuleOverride(
            MappingModuleId.watchRead,
            MappingSlotKey.title,
            const ModuleFieldOverride(
              propertyName: '最近观看标题',
              readOverride: '最近观看标题读',
            ),
          )
          .updateModuleParam(mappingParamWatchingStatusValue, '在看')
          .updateModuleParam(mappingParamWatchingStatusValueWatched, '已看');

      final encoded = jsonEncode(config.toJson());
      final decoded = MappingConfig.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(decoded.schemaVersion, mappingSchemaVersion);
      expect(
        decoded.bindingFor(MappingSlotKey.title).propertyName,
        '标题',
      );
      expect(
        decoded.bindingFor(MappingSlotKey.title).readOverride,
        '标题读',
      );
      expect(
        decoded.bindingFor(MappingSlotKey.title).writeOverride,
        '标题写',
      );
      expect(
        decoded.bindingFor(MappingSlotKey.title).writeEnabledDefault,
        isFalse,
      );
      expect(
        decoded
            .overrideFor(MappingModuleId.watchRead, MappingSlotKey.title)
            ?.readOverride,
        '最近观看标题读',
      );
      expect(
        decoded.moduleParam(mappingParamWatchingStatusValue),
        '在看',
      );
      expect(
        decoded.moduleParam(mappingParamWatchingStatusValueWatched),
        '已看',
      );
    });

    test('migrates V1 with conflict priority watch > daily > old config', () {
      final v1 = <String, dynamic>{
        'title': '旧标题',
        'imageUrl': '旧封面',
        'bangumiId': '旧BangumiID',
        'titleEnabled': false,
        'watchingStatusValue': '在看',
        'watchingStatusValueWatched': '看完',
        'watchBindings': <String, dynamic>{
          'title': '追番标题',
          'bangumiId': '追番BangumiID',
          'yougnScore': '追番自评',
        },
        'dailyRecommendationBindings': <String, dynamic>{
          'title': '推荐标题',
          'yougnScore': '推荐自评',
          'airDate': '推荐首播',
        },
      };
      final legacyDaily = <String, dynamic>{
        'title': '遗留推荐标题',
        'yougnScore': '遗留推荐自评',
      };

      final migration = MappingConfig.migrateFromLegacy(
        v1Config: v1,
        legacyDailyBindings: legacyDaily,
      );
      final config = migration.config;

      expect(migration.migrated, isTrue);
      expect(config.schemaVersion, mappingSchemaVersion);
      expect(config.bindingFor(MappingSlotKey.title).propertyName, '追番标题');
      expect(
        config.bindingFor(MappingSlotKey.bangumiId).propertyName,
        '追番BangumiID',
      );
      expect(
        config.bindingFor(MappingSlotKey.yougnScore).propertyName,
        '追番自评',
      );
      expect(config.bindingFor(MappingSlotKey.airDate).propertyName, '推荐首播');
      expect(config.bindingFor(MappingSlotKey.cover).propertyName, '旧封面');
      expect(
          config.bindingFor(MappingSlotKey.title).writeEnabledDefault, isFalse);
      expect(config.moduleParam(mappingParamWatchingStatusValue), '在看');
      expect(config.moduleParam(mappingParamWatchingStatusValueWatched), '看完');
      expect(migration.notes, isNotEmpty);
    });

    test('uses legacy daily bindings when config has no daily section', () {
      final v1 = <String, dynamic>{
        'title': '旧标题',
      };
      final legacyDaily = <String, dynamic>{
        'yougnScore': 'legacy_yougn',
      };

      final migration = MappingConfig.migrateFromLegacy(
        v1Config: v1,
        legacyDailyBindings: legacyDaily,
      );

      expect(
        migration.config.bindingFor(MappingSlotKey.yougnScore).propertyName,
        'legacy_yougn',
      );
    });
  });
}
