import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_services.dart';
import '../../../../app/app_settings.dart';
import '../../../../core/widgets/navigation_shell.dart';
import '../../providers/batch_import_view_model.dart';
import 'batch_import_view.dart';

class BatchImportPage extends StatelessWidget {
  const BatchImportPage({super.key});

  Future<void> _bindCandidate(
    BuildContext context,
    BatchImportViewModel model,
    BatchImportCandidate candidate,
    int bangumiId,
  ) async {
    try {
      await model.bindCandidate(candidate: candidate, bangumiId: bangumiId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('绑定成功')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('绑定失败: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => BatchImportViewModel(
        notionApi: context.read<AppServices>().notionApi,
        bangumiApi: context.read<AppServices>().bangumiApi,
        settings: context.read<AppSettings>(),
      )..load(),
      child: Consumer<BatchImportViewModel>(
        builder: (context, model, _) {
          return NavigationShell(
            title: '批量导入/更新',
            selectedRoute: '/settings',
            onBack: () => Navigator.of(context).pop(),
            actions: [
              IconButton(
                tooltip: '刷新',
                onPressed: model.isLoading ? null : model.load,
                icon: const Icon(Icons.refresh),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: BatchImportView(
                state: BatchImportViewState(
                  isLoading: model.isLoading,
                  errorMessage: model.errorMessage,
                  candidates: model.candidates,
                ),
                callbacks: BatchImportViewCallbacks(
                  onBind: (candidate, bangumiId) =>
                      unawaited(_bindCandidate(
                        context,
                        model,
                        candidate,
                        bangumiId,
                      )),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

