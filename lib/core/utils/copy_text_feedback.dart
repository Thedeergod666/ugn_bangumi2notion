import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> copyTextWithFeedback(
  BuildContext context,
  String text, {
  String message = '已复制番剧名称。',
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(message)),
  );
}
