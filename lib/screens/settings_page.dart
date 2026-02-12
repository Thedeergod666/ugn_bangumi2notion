import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_services.dart';
import '../app/app_settings.dart';
import '../config/bangumi_oauth_config.dart';
import '../view_models/settings_view_model.dart';
import '../widgets/error_detail_dialog.dart';
import '../widgets/navigation_shell.dart';
import 'appearance_settings_page.dart';
import 'database_settings_page.dart';
import 'error_log_page.dart';

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
    if (!mounted) {
      return;
    }
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
    if (!mounted) {
      return;
    }
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
    if (!mounted) {
      return;
    }
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
    if (!mounted) {
      return;
    }
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
                '请在环境变量/打包参数中添加这两个，或联系开发人员重新打包。\n'
                '提示：写入环境变量后需要重新打包/重启应用。',
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
                    helperText: '可选，Bangumi 允许为空，但仍建议填写',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final clientId = _bangumiClientIdController.text.trim();
                    final clientSecret =
                        _bangumiClientSecretController.text.trim();
                    if (clientId.isEmpty) {
                      _showSnackBar('BANGUMI_CLIENT_ID 不能为空', isError: true);
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
              onPressed: () {
                setDialogState(() {
                  showEnvInputs = !showEnvInputs;
                });
              },
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
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
          return NavigationShell(
            title: '设置',
            selectedRoute: '/settings',
            child: model.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _sectionTitle('账号与同步'),
                      _buildBangumiCard(model),
                      if (model.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          model.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      if (model.successMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          model.successMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _sectionTitle('应用与外观'),
                      _buildGroup(
                        context,
                        [
                          _buildNavTile(
                            icon: Icons.storage_rounded,
                            title: '数据库设置',
                            subtitle: '配置 Notion Token 与数据库 ID',
                            onTap: () =>
                                _openPage(const DatabaseSettingsPage()),
                          ),
                          _buildNavTile(
                            icon: Icons.map_outlined,
                            title: '映射设置',
                            subtitle: 'Bangumi/Notion 字段绑定',
                            onTap: () =>
                                Navigator.of(context).pushNamed('/mapping'),
                          ),
                          _buildNavTile(
                            icon: Icons.palette_outlined,
                            title: '外观设置',
                            subtitle: '主题、配色、字体等',
                            onTap: () =>
                                _openPage(const AppearanceSettingsPage()),
                          ),
                          _buildNavTile(
                            icon: Icons.bug_report_outlined,
                            title: '错误日志',
                            subtitle: '查看错误日志与复制',
                            onTap: () => _openPage(const ErrorLogPage()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle('开发者'),
                      _buildGroup(
                        context,
                        [
                          _buildCopyableTile(
                            context,
                            label: 'OAuth 回调地址',
                            value: 'http://localhost:8080/auth/callback',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '请在 Bangumi 开发者后台登记该回调地址，授权时会通过本地回调接收 code。',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildBangumiCard(SettingsViewModel model) {
    final hasToken = model.bangumiHasToken;
    final userLabel = model.bangumiUser == null
        ? '未获取到用户信息'
        : (model.bangumiUser!.nickname.isNotEmpty
            ? model.bangumiUser!.nickname
            : '已登录');
    final statusText = hasToken
        ? (model.bangumiTokenValid ? '已登录' : 'Token 无效或已过期')
        : '未登录';
    final statusColor = model.bangumiTokenValid
        ? Colors.green
        : (hasToken ? Colors.orange : Colors.grey);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.account_circle, color: statusColor),
            title: Text(
              statusText,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
            subtitle: Text(
              userLabel,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            trailing: TextButton.icon(
              onPressed:
                  model.isBangumiLoading ? null : model.refreshBangumiStatus,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('刷新'),
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: model.isSaving ? null : _authorize,
                        icon: model.isBangumiLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.lock_open),
                        label: const Text('登录/授权'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: (model.isSaving || !model.bangumiHasToken)
                          ? null
                          : _logoutBangumi,
                      icon: const Icon(Icons.logout),
                      label: const Text('登出'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '点击授权将打开系统浏览器，完成登录后会回调到本地地址。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyableTile(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        _showSnackBar('已复制到剪贴板: $value');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.link_rounded, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.copy_rounded,
              size: 16,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroup(BuildContext context, List<Widget> tiles) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: _addDividers(context, tiles),
      ),
    );
  }

  List<Widget> _addDividers(BuildContext context, List<Widget> tiles) {
    final colorScheme = Theme.of(context).colorScheme;
    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) {
        children.add(
          Divider(height: 1, color: colorScheme.outlineVariant),
        );
      }
      children.add(tiles[i]);
    }
    return children;
  }

  Widget _buildNavTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

