import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_services.dart';
import '../../../app/app_settings.dart';
import '../../../config/bangumi_oauth_config.dart';
import '../../../core/widgets/error_detail_dialog.dart';
import '../../../core/widgets/navigation_shell.dart';
import '../providers/settings_view_model.dart';
import 'settings_view.dart';
import 'sub_pages/appearance_settings_page.dart';
import 'sub_pages/batch_import_page.dart';
import 'sub_pages/database_settings_page.dart';
import 'sub_pages/error_log_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsViewModel _viewModel;

  final _bangumiClientIdController = TextEditingController();
  final _bangumiClientSecretController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = SettingsViewModel(
      services: context.read<AppServices>(),
      settings: context.read<AppSettings>(),
    );
    _viewModel.load();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _authorize() async {
    if (!_viewModel.isBangumiConfigured) {
      await _showBangumiConfigMissingDialog();
      return;
    }
    final result = await _viewModel.authorize();
    if (!mounted) return;
    _showSnackBar(result.message, isError: !result.success);
    if (!result.success && result.error != null) {
      await showDialog(
        context: context,
        builder: (context) => ErrorDetailDialog(
          error: result.error!,
          stackTrace: result.stackTrace,
        ),
      );
    }
  }

  Future<void> _logoutBangumi() async {
    final result = await _viewModel.logout();
    if (!mounted) return;
    _showSnackBar(result.message, isError: !result.success);
    if (!result.success && result.error != null) {
      await showDialog(
        context: context,
        builder: (context) => ErrorDetailDialog(
          error: result.error!,
          stackTrace: result.stackTrace,
        ),
      );
    }
  }

  Future<void> _showBangumiConfigMissingDialog() async {
    if (!mounted) return;

    bool showEnvInputs = false;
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Bangumi 授权配置缺失'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${BangumiOAuthConfig.missingMessage}\n'
                '请在环境变量/打包参数中配置这些值，或联系开发者重新打包。\n'
                '提示：写入环境变量后需重启应用。',
              ),
              if (showEnvInputs) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _bangumiClientIdController,
                  decoration: const InputDecoration(
                    labelText: 'BANGUMI_CLIENT_ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bangumiClientSecretController,
                  decoration: const InputDecoration(
                    labelText: 'BANGUMI_CLIENT_SECRET',
                    border: OutlineInputBorder(),
                    helperText: '可选，但建议填写',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final clientId = _bangumiClientIdController.text.trim();
                    final clientSecret =
                        _bangumiClientSecretController.text.trim();
                    if (clientId.isEmpty) {
                      _showSnackBar(
                        'BANGUMI_CLIENT_ID 不能为空',
                        isError: true,
                      );
                      return;
                    }
                    try {
                      await _viewModel.applyBangumiEnvVariables(
                        clientId: clientId,
                        clientSecret: clientSecret,
                      );
                      if (mounted) {
                        _showSnackBar('已写入环境变量，重启应用后生效');
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    } catch (error, stackTrace) {
                      if (context.mounted) {
                        await showDialog(
                          context: context,
                          builder: (context) => ErrorDetailDialog(
                            error: error,
                            stackTrace: stackTrace,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('确认添加环境变量'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
            TextButton(
              onPressed: () => setDialogState(() {
                showEnvInputs = !showEnvInputs;
              }),
              child: Text(showEnvInputs ? '收起环境变量' : '添加环境变量'),
            ),
            FilledButton(
              onPressed: () async {
                await launchUrl(
                  Uri.parse('https://bgm.tv/dev/app'),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text('前往 Bangumi 开发者平台'),
            ),
          ],
        ),
      ),
    );
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _bangumiClientIdController.dispose();
    _bangumiClientSecretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<SettingsViewModel>(
        builder: (context, model, _) {
          final userLabel = model.bangumiUser == null
              ? '未获取到用户信息'
              : (model.bangumiUser!.nickname.isNotEmpty
                  ? model.bangumiUser!.nickname
                  : '已登录');

          return NavigationShell(
            title: '设置',
            selectedRoute: '/settings',
            child: SettingsView(
              oauthCallbackUrl: 'http://localhost:8080/auth/callback',
              state: SettingsViewState(
                isLoading: model.isLoading,
                isSaving: model.isSaving,
                isBangumiLoading: model.isBangumiLoading,
                bangumiHasToken: model.bangumiHasToken,
                bangumiTokenValid: model.bangumiTokenValid,
                bangumiUserLabel: userLabel,
                errorMessage: model.errorMessage,
                successMessage: model.successMessage,
              ),
              callbacks: SettingsViewCallbacks(
                onAuthorize: () => unawaited(_authorize()),
                onLogout: () => unawaited(_logoutBangumi()),
                onRefreshBangumiStatus: model.refreshBangumiStatus,
                onOpenDatabaseSettings: () =>
                    _openPage(const DatabaseSettingsPage()),
                onOpenMapping: () => Navigator.of(context).pushNamed('/mapping'),
                onOpenBatchImport: () => _openPage(const BatchImportPage()),
                onOpenAppearance: () =>
                    _openPage(const AppearanceSettingsPage()),
                onOpenErrorLog: () => _openPage(const ErrorLogPage()),
                onCopyOAuthCallbackUrl: () {
                  Clipboard.setData(
                    const ClipboardData(
                      text: 'http://localhost:8080/auth/callback',
                    ),
                  );
                  _showSnackBar('已复制回调地址');
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

