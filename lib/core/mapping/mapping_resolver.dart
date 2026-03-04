import '../../models/mapping_config.dart';
import '../../models/mapping_schema.dart';

abstract class MappingResolver {
  String resolve(
    MappingSlotKey slot,
    MappingModuleId module, {
    required bool forWrite,
  });

  List<ModuleValidationIssue> validateByModule();

  List<MappingModuleId> usageOfSlot(MappingSlotKey slot);

  Map<String, List<MappingSlotUsage>> buildPropertyUsageIndex();
}

class MappingSlotUsage {
  final MappingSlotKey slot;
  final MappingModuleId module;
  final bool forWrite;

  const MappingSlotUsage({
    required this.slot,
    required this.module,
    required this.forWrite,
  });
}

class DefaultMappingResolver implements MappingResolver {
  final MappingConfig config;

  const DefaultMappingResolver(this.config);

  @override
  String resolve(
    MappingSlotKey slot,
    MappingModuleId module, {
    required bool forWrite,
  }) {
    return config.resolve(slot, module, forWrite: forWrite);
  }

  @override
  List<ModuleValidationIssue> validateByModule() {
    final issues = <ModuleValidationIssue>[];
    for (final module in mappingModuleMetas) {
      final forWrite = _forWriteModule(module.id);
      for (final slot in module.criticalSlots) {
        final resolved = resolve(slot, module.id, forWrite: forWrite);
        if (resolved.trim().isEmpty) {
          final slotLabel = mappingSlotMetaByKey[slot]?.label ?? slot.name;
          issues.add(
            ModuleValidationIssue(
              module: module.id,
              slot: slot,
              message: '${module.label} 缺少关键字段：$slotLabel',
            ),
          );
        }
      }
    }
    return issues;
  }

  @override
  List<MappingModuleId> usageOfSlot(MappingSlotKey slot) {
    final usage = <MappingModuleId>{
      ...?mappingSlotMetaByKey[slot]?.modules,
    };
    for (final moduleEntry in config.moduleOverrides.entries) {
      if (moduleEntry.value.containsKey(slot)) {
        usage.add(moduleEntry.key);
      }
    }
    return usage.toList();
  }

  @override
  Map<String, List<MappingSlotUsage>> buildPropertyUsageIndex() {
    final result = <String, List<MappingSlotUsage>>{};
    for (final slotMeta in mappingSlotMetas) {
      if (!_isNotionPropertySlot(slotMeta.key)) continue;
      final modules = usageOfSlot(slotMeta.key);
      for (final module in modules) {
        final forWrite = _forWriteModule(module);
        final property = resolve(slotMeta.key, module, forWrite: forWrite);
        final trimmed = property.trim();
        if (trimmed.isEmpty) continue;
        final list = result.putIfAbsent(trimmed, () => <MappingSlotUsage>[]);
        list.add(
          MappingSlotUsage(
            slot: slotMeta.key,
            module: module,
            forWrite: forWrite,
          ),
        );
      }
    }
    return result;
  }

  bool _forWriteModule(MappingModuleId module) {
    return module == MappingModuleId.importWrite ||
        module == MappingModuleId.watchWrite;
  }

  bool _isNotionPropertySlot(MappingSlotKey slot) {
    return slot != MappingSlotKey.watchingStatusValue &&
        slot != MappingSlotKey.watchingStatusValueWatched;
  }
}
