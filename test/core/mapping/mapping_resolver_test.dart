import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_utools/core/mapping/mapping_resolver.dart';
import 'package:flutter_utools/models/mapping_config.dart';
import 'package:flutter_utools/models/mapping_schema.dart';

void main() {
  group('DefaultMappingResolver', () {
    test('resolves shared binding for read and write when no override', () {
      var config = MappingConfig();
      config = config.updateBinding(
        MappingSlotKey.title,
        const FieldBinding(propertyName: '标题字段'),
      );

      final resolver = DefaultMappingResolver(config);

      expect(
        resolver.resolve(
          MappingSlotKey.title,
          MappingModuleId.recommendationRead,
          forWrite: false,
        ),
        '标题字段',
      );
      expect(
        resolver.resolve(
          MappingSlotKey.title,
          MappingModuleId.importWrite,
          forWrite: true,
        ),
        '标题字段',
      );
    });

    test('module override and read/write override take precedence', () {
      var config = MappingConfig();
      config = config.updateBinding(
        MappingSlotKey.title,
        const FieldBinding(
          propertyName: '通用标题',
          readOverride: '通用标题读',
          writeOverride: '通用标题写',
        ),
      );
      config = config.updateModuleOverride(
        MappingModuleId.watchRead,
        MappingSlotKey.title,
        const ModuleFieldOverride(
          propertyName: '最近观看标题',
          readOverride: '最近观看标题读',
          writeOverride: '最近观看标题写',
        ),
      );

      final resolver = DefaultMappingResolver(config);

      expect(
        resolver.resolve(
          MappingSlotKey.title,
          MappingModuleId.watchRead,
          forWrite: false,
        ),
        '最近观看标题读',
      );
      expect(
        resolver.resolve(
          MappingSlotKey.title,
          MappingModuleId.watchRead,
          forWrite: true,
        ),
        '最近观看标题写',
      );
      expect(
        resolver.resolve(
          MappingSlotKey.title,
          MappingModuleId.searchRead,
          forWrite: false,
        ),
        '通用标题读',
      );
      expect(
        resolver.resolve(
          MappingSlotKey.title,
          MappingModuleId.importWrite,
          forWrite: true,
        ),
        '通用标题写',
      );
    });

    test(
        'validateByModule reports only affected modules when a critical slot is missing',
        () {
      var config = MappingConfig();
      config = config
          .updateBinding(
            MappingSlotKey.title,
            const FieldBinding(propertyName: '标题'),
          )
          .updateBinding(
            MappingSlotKey.bangumiId,
            const FieldBinding(propertyName: 'Bangumi ID'),
          )
          .updateBinding(
            MappingSlotKey.yougnScore,
            const FieldBinding(propertyName: 'Yougn 评分'),
          )
          .updateBinding(
            MappingSlotKey.watchingStatus,
            const FieldBinding(propertyName: '追番状态'),
          )
          .updateBinding(
            MappingSlotKey.watchedEpisodes,
            const FieldBinding(propertyName: '已追集数'),
          )
          .updateBinding(
            MappingSlotKey.idProperty,
            const FieldBinding(propertyName: '查询ID'),
          )
          .updateBinding(
            MappingSlotKey.notionId,
            const FieldBinding(propertyName: 'NotionID'),
          )
          .updateBinding(
            MappingSlotKey.globalIdProperty,
            const FieldBinding(propertyName: 'GlobalID'),
          )
          .updateModuleParam(mappingParamWatchingStatusValue, '在看');

      final baselineResolver = DefaultMappingResolver(config);
      expect(baselineResolver.validateByModule(), isEmpty);

      final missingBangumiConfig = config.updateBinding(
        MappingSlotKey.bangumiId,
        const FieldBinding(propertyName: ''),
      );
      final resolver = DefaultMappingResolver(missingBangumiConfig);
      final issues = resolver.validateByModule();
      final modules = issues.map((issue) => issue.module).toSet();

      expect(modules.contains(MappingModuleId.importWrite), isTrue);
      expect(modules.contains(MappingModuleId.watchRead), isTrue);
      expect(modules.contains(MappingModuleId.batchImport), isTrue);
      expect(modules.contains(MappingModuleId.recommendationRead), isFalse);
      expect(modules.contains(MappingModuleId.searchRead), isFalse);
    });

    test(
        'buildPropertyUsageIndex returns slot/module usage for reused properties',
        () {
      var config = MappingConfig();
      config = config
          .updateBinding(
            MappingSlotKey.title,
            const FieldBinding(propertyName: '标题'),
          )
          .updateBinding(
            MappingSlotKey.yougnScore,
            const FieldBinding(propertyName: '评分'),
          );

      final resolver = DefaultMappingResolver(config);
      final usage = resolver.buildPropertyUsageIndex();

      expect(usage.containsKey('标题'), isTrue);
      expect(usage.containsKey('评分'), isTrue);

      final titleUsage = usage['标题']!;
      final titleModules = titleUsage.map((item) => item.module).toSet();
      final titleSlots = titleUsage.map((item) => item.slot).toSet();

      expect(titleModules.contains(MappingModuleId.importWrite), isTrue);
      expect(titleModules.contains(MappingModuleId.searchRead), isTrue);
      expect(titleSlots.contains(MappingSlotKey.title), isTrue);

      final slotUsage = resolver.usageOfSlot(MappingSlotKey.title);
      expect(slotUsage.contains(MappingModuleId.importWrite), isTrue);
      expect(slotUsage.contains(MappingModuleId.searchRead), isTrue);
    });
  });
}
