import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/logging.dart';
import '../../../../core/widgets/navigation_shell.dart';
import '../../providers/error_log_view_model.dart';
import 'error_log_view.dart';

class ErrorLogPage extends StatelessWidget {
  const ErrorLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ErrorLogViewModel(logger: context.read<Logger>()),
      child: Consumer<ErrorLogViewModel>(
        builder: (context, model, _) {
          final entries = model.entries;
          final viewState = ErrorLogViewState(entries: entries);

          return NavigationShell(
            title: '错误日志',
            selectedRoute: '/settings',
            onBack: () => Navigator.of(context).pop(),
            actions: [
              IconButton(
                tooltip: '一键复制',
                onPressed: model.canCopy
                    ? () {
                        final payload = model.exportText();
                        Clipboard.setData(ClipboardData(text: payload));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('错误日志已复制')),
                        );
                      }
                    : null,
                icon: const Icon(Icons.copy_all),
              ),
              IconButton(
                tooltip: '清空',
                onPressed: entries.isNotEmpty
                    ? () {
                        model.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已清空错误日志')),
                        );
                      }
                    : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
            child: ErrorLogView(state: viewState),
          );
        },
      ),
    );
  }
}

