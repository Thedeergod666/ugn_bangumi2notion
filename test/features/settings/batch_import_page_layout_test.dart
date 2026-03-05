import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_utools/features/settings/presentation/sub_pages/batch_import_view.dart';
import 'package:flutter_utools/features/settings/presentation/sub_pages/widgets/batch_import_left_pane.dart';
import 'package:flutter_utools/features/settings/presentation/sub_pages/widgets/batch_import_right_pane.dart';
import 'package:flutter_utools/features/settings/providers/batch_binding_ui_models.dart';
import 'package:flutter_utools/features/settings/providers/batch_import_view_model.dart';
import 'package:flutter_utools/models/bangumi_models.dart';
import 'package:flutter_utools/models/notion_models.dart';

BatchUiItem buildUiItem() {
  const candidate = BatchImportCandidate(
    notionItem: NotionSearchItem(
      id: 'page-1',
      title: 'Uma Musume Season 2',
      url: 'https://www.notion.so/page-1',
      notionId: 'a1b2c3',
      notionType: 'anime',
    ),
    matches: [
      BangumiSearchItem(
        id: 315574,
        name: 'Uma Musume Pretty Derby Season 2',
        nameCn: 'Uma Musume Pretty Derby Season 2',
        summary: '',
        imageUrl: '',
        airDate: '2021-01-01',
        score: 7.8,
        rank: 0,
      ),
    ],
  );
  return buildBatchUiItem(candidate);
}

BatchImportView buildView() {
  final item = buildUiItem();
  final search = TextEditingController();
  final manual = TextEditingController();

  return BatchImportView(
    state: BatchImportViewState(
      isLoading: false,
      errorMessage: null,
      searchController: search,
      manualInputController: manual,
      onlyUnbound: true,
      sortMode: BatchSortMode.similarity,
      visibleItems: [item],
      activeItem: item,
      pendingCount: 1,
      completedCount: 0,
      selectedCount: 0,
      isBulkBinding: false,
      isManualVerifying: false,
      manualVerifiedId: null,
      manualVerifiedDetail: null,
    ),
    callbacks: BatchImportViewCallbacks(
      onSearchChanged: (_) {},
      onOnlyUnboundChanged: (_) {},
      onSortChanged: (_) {},
      onOneClickBind: () {},
      onSelectItem: (_) {},
      onToggleItemSelected: (_) {},
      onSkipSelected: () {},
      onBindSelected: () {},
      onBindSingle: (_, __) {},
      onOpenNotionDetail: (_) {},
      onOpenBangumiDetail: (_) {},
      onOpenBangumiExternal: (_) {},
      onManualInputChanged: (_) {},
      onVerifyManual: () {},
      onBindManual: () {},
      onToggleConflict: (_) {},
    ),
  );
}

void main() {
  testWidgets('uses stacked layout on narrow width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            child: buildView(),
          ),
        ),
      ),
    );

    expect(find.byType(BatchImportLeftPane), findsOneWidget);
    expect(find.byType(BatchImportRightPane), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 390,
      ),
      findsNothing,
    );
  });

  testWidgets('uses two-pane layout on wide width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 980,
            child: buildView(),
          ),
        ),
      ),
    );

    expect(find.byType(BatchImportLeftPane), findsOneWidget);
    expect(find.byType(BatchImportRightPane), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 390,
      ),
      findsOneWidget,
    );
  });
}
