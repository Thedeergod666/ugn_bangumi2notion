import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../models/bangumi_models.dart';
import '../../providers/batch_binding_ui_models.dart';
import 'widgets/batch_import_debug_ribbon.dart';
import 'widgets/batch_import_left_pane.dart';
import 'widgets/batch_import_progress_bar.dart';
import 'widgets/batch_import_right_pane.dart';
import 'widgets/batch_import_top_actions.dart';

class BatchImportViewState {
  const BatchImportViewState({
    required this.isLoading,
    required this.errorMessage,
    required this.searchController,
    required this.manualInputController,
    required this.onlyUnbound,
    required this.sortMode,
    required this.visibleItems,
    required this.activeItem,
    required this.pendingCount,
    required this.completedCount,
    required this.selectedCount,
    required this.isBulkBinding,
    required this.isManualVerifying,
    required this.manualVerifiedId,
    required this.manualVerifiedDetail,
  });

  final bool isLoading;
  final String? errorMessage;
  final TextEditingController searchController;
  final TextEditingController manualInputController;
  final bool onlyUnbound;
  final BatchSortMode sortMode;
  final List<BatchUiItem> visibleItems;
  final BatchUiItem? activeItem;
  final int pendingCount;
  final int completedCount;
  final int selectedCount;
  final bool isBulkBinding;
  final bool isManualVerifying;
  final int? manualVerifiedId;
  final BangumiSubjectDetail? manualVerifiedDetail;
}

class BatchImportViewCallbacks {
  const BatchImportViewCallbacks({
    required this.onSearchChanged,
    required this.onOnlyUnboundChanged,
    required this.onSortChanged,
    required this.onOneClickBind,
    required this.onSelectItem,
    required this.onToggleItemSelected,
    required this.onSkipSelected,
    required this.onBindSelected,
    required this.onBindSingle,
    required this.onOpenNotionDetail,
    required this.onOpenBangumiDetail,
    required this.onOpenBangumiExternal,
    required this.onManualInputChanged,
    required this.onVerifyManual,
    required this.onBindManual,
    required this.onToggleConflict,
  });

  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onOnlyUnboundChanged;
  final ValueChanged<BatchSortMode> onSortChanged;
  final VoidCallback onOneClickBind;
  final ValueChanged<String> onSelectItem;
  final ValueChanged<String> onToggleItemSelected;
  final VoidCallback onSkipSelected;
  final VoidCallback onBindSelected;
  final void Function(BatchUiItem item, int bangumiId) onBindSingle;
  final ValueChanged<BatchUiItem> onOpenNotionDetail;
  final ValueChanged<int> onOpenBangumiDetail;
  final ValueChanged<int> onOpenBangumiExternal;
  final ValueChanged<String> onManualInputChanged;
  final VoidCallback onVerifyManual;
  final VoidCallback onBindManual;
  final ValueChanged<String> onToggleConflict;
}

class BatchImportView extends StatelessWidget {
  const BatchImportView({
    super.key,
    required this.state,
    required this.callbacks,
  });

  final BatchImportViewState state;
  final BatchImportViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null) {
      return Center(
        child: Text(
          state.errorMessage!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    if (state.visibleItems.isEmpty && state.activeItem == null) {
      return const Center(child: Text('暂无待绑定条目'));
    }

    final content = Column(
      children: [
        BatchImportTopActions(
          searchController: state.searchController,
          onlyUnbound: state.onlyUnbound,
          onSearchChanged: callbacks.onSearchChanged,
          onOnlyUnboundChanged: callbacks.onOnlyUnboundChanged,
          onOneClickBind: callbacks.onOneClickBind,
          isBinding: state.isBulkBinding,
        ),
        const SizedBox(height: 10),
        BatchImportProgressBar(
          pendingCount: state.pendingCount,
          completedCount: state.completedCount,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              if (isNarrow) {
                return Column(
                  children: [
                    Expanded(
                      child: BatchImportLeftPane(
                        items: state.visibleItems,
                        activePageId: state.activeItem?.pageId,
                        sortMode: state.sortMode,
                        selectedCount: state.selectedCount,
                        isBusy: state.isBulkBinding,
                        onSortChanged: callbacks.onSortChanged,
                        onSelectItem: callbacks.onSelectItem,
                        onToggleItemSelected: callbacks.onToggleItemSelected,
                        onSkipSelected: callbacks.onSkipSelected,
                        onBindSelected: callbacks.onBindSelected,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: BatchImportRightPane(
                        activeItem: state.activeItem,
                        manualInputController: state.manualInputController,
                        isManualVerifying: state.isManualVerifying,
                        manualVerifiedId: state.manualVerifiedId,
                        manualVerifiedDetail: state.manualVerifiedDetail,
                        isBusy: state.isBulkBinding,
                        onOpenNotionDetail: callbacks.onOpenNotionDetail,
                        onBindSingle: callbacks.onBindSingle,
                        onOpenBangumiDetail: callbacks.onOpenBangumiDetail,
                        onOpenBangumiExternal: callbacks.onOpenBangumiExternal,
                        onManualInputChanged: callbacks.onManualInputChanged,
                        onVerifyManual: callbacks.onVerifyManual,
                        onBindManual: callbacks.onBindManual,
                        onToggleConflict: callbacks.onToggleConflict,
                      ),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 390,
                    child: BatchImportLeftPane(
                      items: state.visibleItems,
                      activePageId: state.activeItem?.pageId,
                      sortMode: state.sortMode,
                      selectedCount: state.selectedCount,
                      isBusy: state.isBulkBinding,
                      onSortChanged: callbacks.onSortChanged,
                      onSelectItem: callbacks.onSelectItem,
                      onToggleItemSelected: callbacks.onToggleItemSelected,
                      onSkipSelected: callbacks.onSkipSelected,
                      onBindSelected: callbacks.onBindSelected,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BatchImportRightPane(
                      activeItem: state.activeItem,
                      manualInputController: state.manualInputController,
                      isManualVerifying: state.isManualVerifying,
                      manualVerifiedId: state.manualVerifiedId,
                      manualVerifiedDetail: state.manualVerifiedDetail,
                      isBusy: state.isBulkBinding,
                      onOpenNotionDetail: callbacks.onOpenNotionDetail,
                      onBindSingle: callbacks.onBindSingle,
                      onOpenBangumiDetail: callbacks.onOpenBangumiDetail,
                      onOpenBangumiExternal: callbacks.onOpenBangumiExternal,
                      onManualInputChanged: callbacks.onManualInputChanged,
                      onVerifyManual: callbacks.onVerifyManual,
                      onBindManual: callbacks.onBindManual,
                      onToggleConflict: callbacks.onToggleConflict,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );

    return Stack(
      children: [
        Positioned.fill(child: content),
        if (kDebugMode) const BatchImportDebugRibbon(),
      ],
    );
  }
}
