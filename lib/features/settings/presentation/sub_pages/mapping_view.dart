import 'package:flutter/material.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../models/mapping_schema.dart';
import '../../../../models/notion_models.dart';
import '../../providers/mapping_view_model.dart';

class MappingView extends StatelessWidget {
  const MappingView({
    super.key,
    required this.model,
    required this.onApplyMagicMap,
  });

  final MappingViewModel model;
  final VoidCallback onApplyMagicMap;

  @override
  Widget build(BuildContext context) {
    if (model.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = Breakpoints.isNarrow(constraints.maxWidth);
        final maxWidth = Breakpoints.contentWidth(constraints.maxWidth);
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 16 : 24,
                vertical: 16,
              ),
              children: [
                _buildHeader(context),
                const SizedBox(height: 16),
                if (model.migrationNotes != null)
                  _buildMigrationCard(context, model.migrationNotes!),
                if (model.error != null) _buildErrorBanner(context),
                if (!model.isConfigured)
                  _buildNoticeCard(
                    context,
                    '请先在设置页配置 Notion Token 和 Database ID，才能加载属性列表。',
                  ),
                _buildValidationCard(context),
                const SizedBox(height: 12),
                _buildCommonBindingsCard(context),
                const SizedBox(height: 12),
                ...mappingModuleMetas.map(
                  (module) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildModuleSummaryCard(context, module),
                  ),
                ),
                const SizedBox(height: 8),
                _buildPropertyUsageCard(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Text(
          '映射配置',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: model.isConfigured ? onApplyMagicMap : null,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('推荐配置'),
        ),
      ],
    );
  }

  Widget _buildMigrationCard(BuildContext context, List<String> notes) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primaryContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '映射配置已升级到 V2',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          ...notes.map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $note'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '加载映射配置失败，请稍后重试',
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationCard(BuildContext context) {
    final issues = model.moduleValidationIssues;
    final colorScheme = Theme.of(context).colorScheme;
    final hasBlocking = issues.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasBlocking
            ? colorScheme.errorContainer.withValues(alpha: 0.45)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasBlocking
              ? colorScheme.error
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasBlocking ? '模块校验存在缺失项' : '模块校验通过',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          if (!hasBlocking)
            Text(
              '当前映射已满足所有模块关键字段要求。',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ...issues.map((issue) {
              final moduleLabel = mappingModuleMetaById[issue.module]?.label ??
                  issue.module.name;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• [$moduleLabel] ${issue.message}'),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCommonBindingsCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '通用字段池（每个槽位仅出现一次）',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '同一字段只绑定一次，模块通过“使用去向”自动复用。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 10),
          ...mappingSlotMetas.map(
            (slotMeta) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildSlotRow(context, slotMeta),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleSummaryCard(
      BuildContext context, MappingModuleMeta module) {
    final moduleIssues = model.moduleValidationIssues
        .where((issue) => issue.module == module.id)
        .toList();
    final complete = moduleIssues.isEmpty;
    final colorScheme = Theme.of(context).colorScheme;
    final forWrite = _forWriteModule(module.id);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  module.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (complete ? Colors.green : Colors.orange)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  complete ? '已就绪' : '缺少关键字段',
                  style: TextStyle(
                    color: complete ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            module.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 10),
          ...module.criticalSlots.map((slot) {
            final slotLabel = mappingSlotMetaByKey[slot]?.label ?? slot.name;
            final resolved = model.resolveForModule(
              slot,
              module.id,
              forWrite: forWrite,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $slotLabel: ${resolved.trim().isEmpty ? '未配置' : resolved.trim()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }),
          if (moduleIssues.isNotEmpty) ...[
            const Divider(height: 18),
            ...moduleIssues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${issue.message}',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSlotRow(BuildContext context, MappingSlotMeta slotMeta) {
    final slot = slotMeta.key;
    final binding = model.config.bindingFor(slot);
    final isParamSlot = slot == MappingSlotKey.watchingStatusValue ||
        slot == MappingSlotKey.watchingStatusValueWatched;

    final usageModules = [...model.usageOfSlot(slot)]..sort((a, b) {
        final aIndex = mappingModuleMetas.indexWhere((meta) => meta.id == a);
        final bIndex = mappingModuleMetas.indexWhere((meta) => meta.id == b);
        return aIndex.compareTo(bIndex);
      });
    final usageText = usageModules
        .map((moduleId) =>
            mappingModuleMetaById[moduleId]?.label ?? moduleId.name)
        .join(' / ');

    final title = Row(
      children: [
        Expanded(
          child: Text(
            slotMeta.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (slotMeta.writeSlot)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('默认写入', style: TextStyle(fontSize: 12)),
              Switch(
                value: binding.writeEnabledDefault,
                onChanged: (value) => model.updateSlotWriteEnabled(slot, value),
              ),
            ],
          ),
      ],
    );

    Widget input;
    if (isParamSlot) {
      final key = slot == MappingSlotKey.watchingStatusValue
          ? mappingParamWatchingStatusValue
          : mappingParamWatchingStatusValueWatched;
      final value = model.config.moduleParam(
        key,
        defaultValue:
            slot == MappingSlotKey.watchingStatusValueWatched ? '已看' : '',
      );
      input = TextFormField(
        key: ValueKey('$key:$value'),
        initialValue: value,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
        ),
        onChanged: (newValue) => model.updateModuleParam(key, newValue),
      );
    } else {
      final options = model.optionsForSlot(slot);
      final current = binding.propertyName;
      final currentProperty = options.firstWhere(
        (item) => item.name == current,
        orElse: () => NotionProperty(name: current, type: ''),
      );
      final currentType = currentProperty.type;
      input = DropdownButtonFormField<String>(
        initialValue: current.isEmpty ? null : current,
        isExpanded: true,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
        ),
        items: options.map((prop) {
          return DropdownMenuItem(
            value: prop.name,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    prop.name.isEmpty ? '未选择' : prop.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (prop.type.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _buildTypeBadge(context, prop.type),
                ],
              ],
            ),
          );
        }).toList(),
        onChanged: (selected) => model.updateSlotProperty(slot, selected ?? ''),
      );

      if (currentType.isNotEmpty && currentType != 'unknown') {
        input = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            input,
            const SizedBox(height: 4),
            _buildTypeBadge(context, currentType),
          ],
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 6),
        input,
        const SizedBox(height: 4),
        Text(
          '使用去向: $usageText',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildPropertyUsageCard(BuildContext context) {
    final entries = model.propertyUsageIndex.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '字段复用说明',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          if (entries.isEmpty)
            Text(
              '尚未配置字段映射。',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ...entries.map((entry) {
              final usages = entry.value
                  .map((usage) {
                    final moduleLabel =
                        mappingModuleMetaById[usage.module]?.label ??
                            usage.module.name;
                    final slotLabel = mappingSlotMetaByKey[usage.slot]?.label ??
                        usage.slot.name;
                    return '$moduleLabel:$slotLabel';
                  })
                  .toSet()
                  .join(' | ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• ${entry.key} -> $usages'),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildNoticeCard(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(BuildContext context, String type) {
    final label = _typeLabel(type);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  bool _forWriteModule(MappingModuleId module) {
    return module == MappingModuleId.importWrite ||
        module == MappingModuleId.watchWrite;
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'title':
        return 'Title';
      case 'rich_text':
        return 'Text';
      case 'number':
        return 'Number';
      case 'date':
        return 'Date';
      case 'multi_select':
        return 'Tag';
      case 'select':
        return 'Select';
      case 'files':
        return 'Files';
      case 'url':
        return 'URL';
      case 'status':
        return 'Status';
      case 'formula':
        return 'Formula';
      case 'rollup':
        return 'Rollup';
      case 'page_content':
        return 'Page';
      default:
        return type.isEmpty ? '-' : type;
    }
  }
}
