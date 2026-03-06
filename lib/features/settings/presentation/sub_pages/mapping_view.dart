import 'package:flutter/material.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/mapping_theme_extension.dart';
import '../../../../models/mapping_schema.dart';
import '../../providers/mapping_view_model.dart';
import 'widgets/mapping_card_mobile.dart';
import 'widgets/mapping_status_footer.dart';
import 'widgets/mapping_table_desktop.dart';
import 'widgets/mapping_top_bar.dart';

class MappingView extends StatelessWidget {
  const MappingView({
    super.key,
    required this.model,
    required this.onApplyMagicMap,
    required this.onBack,
    required this.onReset,
    required this.onSave,
  });

  final MappingViewModel model;
  final VoidCallback onApplyMagicMap;
  final VoidCallback onBack;
  final VoidCallback onReset;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    if (model.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = Breakpoints.isNarrow(constraints.maxWidth);
        final maxWidth = Breakpoints.contentWidth(constraints.maxWidth);
        final mappingExt = Theme.of(context).extension<MappingThemeExtension>();

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                mappingExt?.pageBgTop ??
                    Theme.of(context).colorScheme.surfaceContainerLowest,
                mappingExt?.pageBgBottom ??
                    Theme.of(context).colorScheme.surface,
              ],
            ),
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isNarrow ? 12 : 18,
                        vertical: 16,
                      ),
                      children: [
                        MappingTopBar(
                          model: model,
                          onBack: onBack,
                          onApplyMagicMap: onApplyMagicMap,
                        ),
                        if (model.error != null) ...[
                          const SizedBox(height: 10),
                          _buildErrorBanner(context),
                        ],
                        if (!model.isConfigured) ...[
                          const SizedBox(height: 10),
                          _buildNoticeBanner(
                            context,
                            '请先在设置页配置 Notion Token 与 Database ID。',
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (isNarrow)
                          ...model.rowsForUi.map(
                            (row) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: MappingCardMobile(
                                row: row,
                                options: model.optionsForSlot(row.slot),
                                onPropertyChanged: (value) =>
                                    model.updateSlotProperty(row.slot, value),
                                onParamChanged: (value) =>
                                    _updateParamSlot(row.slot, value),
                              ),
                            ),
                          )
                        else
                          MappingTableDesktop(
                            model: model,
                            rows: model.rowsForUi,
                            onPropertyChanged: (slot, value) =>
                                model.updateSlotProperty(slot, value),
                            onParamChanged: _updateParamSlot,
                          ),
                      ],
                    ),
                  ),
                  MappingStatusFooter(
                    summary: model.statusSummary,
                    hasUnsavedChanges: model.hasUnsavedChanges,
                    onReset: onReset,
                    onSave: () => _handleSave(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '加载映射配置失败，请稍后重试。',
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBanner(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
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

  void _updateParamSlot(MappingSlotKey slot, String value) {
    if (slot == MappingSlotKey.watchingStatusValue) {
      model.updateModuleParam(mappingParamWatchingStatusValue, value);
      return;
    }
    if (slot == MappingSlotKey.watchingStatusValueWatched) {
      model.updateModuleParam(mappingParamWatchingStatusValueWatched, value);
    }
  }

  Future<void> _handleSave(BuildContext context) async {
    if (model.statusSummary.error > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('存在错误映射'),
          content: Text(
            '当前有 ${model.statusSummary.error} 个错误映射，仍要继续保存吗？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('继续保存'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    onSave();
  }
}
