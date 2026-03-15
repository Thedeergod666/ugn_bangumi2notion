import 'package:flutter/material.dart';

ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showUndoSnackBar(
  BuildContext context, {
  required String message,
  required String actionLabel,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  return messenger.showSnackBar(
    SnackBar(
      duration: duration,
      content: Row(
        children: [
          Expanded(child: Text(message)),
          TextButton(
            onPressed: () {
              onUndo();
              messenger.hideCurrentSnackBar();
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    ),
  );
}
