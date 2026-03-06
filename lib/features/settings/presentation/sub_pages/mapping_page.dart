import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_services.dart';
import '../../../../app/app_settings.dart';
import '../../../../core/widgets/error_detail_dialog.dart';
import '../../../../core/widgets/navigation_shell.dart';
import '../../providers/mapping_view_model.dart';
import 'mapping_view.dart';

class MappingPage extends StatelessWidget {
  const MappingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MappingViewModel(
        notionApi: context.read<AppServices>().notionApi,
      )..load(context.read<AppSettings>()),
      child: Consumer<MappingViewModel>(
        builder: (context, model, _) {
          return NavigationShell(
            title: '数据映射',
            selectedRoute: '/mapping',
            actions: [
              IconButton(
                tooltip: '刷新属性',
                onPressed: model.isLoading
                    ? null
                    : () => model.load(
                          context.read<AppSettings>(),
                          forceRefresh: true,
                        ),
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
            ],
            child: MappingView(
              model: model,
              onApplyMagicMap: model.applyMagicMap,
              onBack: () => _handleBack(context),
              onReset: model.resetDraft,
              onSave: () => unawaited(_handleSave(context)),
            ),
          );
        },
      ),
    );
  }

  void _handleBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed('/settings');
  }

  Future<void> _handleSave(BuildContext context) async {
    final model = context.read<MappingViewModel>();
    try {
      await model.saveConfig();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功')),
      );
    } catch (error, stackTrace) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('保存失败，请稍后重试'),
          action: SnackBarAction(
            label: '详情',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => ErrorDetailDialog(
                  error: error,
                  stackTrace: stackTrace,
                ),
              );
            },
          ),
        ),
      );
    }
  }
}
