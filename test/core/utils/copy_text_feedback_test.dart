import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_utools/core/utils/copy_text_feedback.dart';

void main() {
  testWidgets('copyTextWithFeedback copies text and shows snackbar',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => copyTextWithFeedback(context, '葬送的芙莉莲'),
                child: const Text('copy'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('copy'));
    await tester.pump();

    final clipboard = await Clipboard.getData('text/plain');
    expect(clipboard?.text, '葬送的芙莉莲');
    expect(find.text('已复制番剧名称。'), findsOneWidget);
  });
}
