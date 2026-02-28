import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_services.dart';
import '../../../../app/app_settings.dart';
import '../../../../core/widgets/error_detail_dialog.dart';
import '../../../../core/widgets/navigation_shell.dart';
import '../../providers/mapping_view_model.dart';
import 'mapping_view.dart';

class MappingPage extends StatefulWidget {
  const MappingPage({super.key});

  @override
  State<MappingPage> createState() => _MappingPageState();
}

class _MappingPageState extends State<MappingPage> {
  MappingSegment _segment = MappingSegment.bangumi;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MappingViewModel(
        notionApi: context.read<AppServices>().notionApi,
      )..load(context.read<AppSettings>()),
      child: Consumer<MappingViewModel>(
        builder: (context, model, _) {
          return NavigationShell(
            title: '映射设置',
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
              IconButton(
                tooltip: '保存',
                onPressed: model.isLoading ? null : () => _handleSave(model),
                icon: const Icon(Icons.save),
              ),
              const SizedBox(width: 8),
            ],
            child: MappingView(
              state: MappingViewState(
                segment: _segment,
                isLoading: model.isLoading,
                isConfigured: model.isConfigured,
                error: model.error,
                config: model.config,
                notionProperties: model.notionProperties,
                bindings: model.bindings,
                watchBindings: model.watchBindings,
              ),
              callbacks: MappingViewCallbacks(
                onSegmentChanged: (segment) =>
                    setState(() => _segment = segment),
                onApplyMagicMap: model.applyMagicMap,
                onConfigChanged: model.updateConfig,
                onBindingsChanged: model.updateBindings,
                onWatchBindingsChanged: model.updateWatchBindings,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleSave(MappingViewModel model) async {
    try {
      if (_segment == MappingSegment.bangumi) {
        await model.saveConfig();
      } else {
        await model.saveBindings();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功')),
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
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
