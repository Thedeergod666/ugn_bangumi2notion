import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_utools/core/widgets/undo_snack_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'undo snackbar auto dismisses even with accessible navigation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(accessibleNavigation: true),
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () {
                        controller = showUndoSnackBar(
                          context,
                          message: '已追集数 +1',
                          actionLabel: '撤销',
                          onUndo: () {},
                        );
                      },
                      child: const Text('show'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('撤销'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await expectLater(
        controller!.closed,
        completion(SnackBarClosedReason.timeout),
      );
    },
  );

  testWidgets('undo snackbar triggers callback and closes immediately',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    var undoCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showUndoSnackBar(
                      context,
                      message: '已追集数 +1',
                      actionLabel: '撤销',
                      onUndo: () {
                        undoCount += 1;
                      },
                    );
                  },
                  child: const Text('show'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final undoButton = find.widgetWithText(TextButton, '撤销');
    expect(undoButton, findsOneWidget);

    await tester.tap(undoButton);
    await tester.pumpAndSettle();

    expect(undoCount, 1);
    expect(find.widgetWithText(TextButton, '撤销'), findsNothing);
  });
}
