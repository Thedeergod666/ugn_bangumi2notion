import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/bangumi_oauth_config.dart';
import '../models/bangumi_models.dart';
import '../services/bangumi_api.dart';
import '../services/bangumi_oauth.dart';
import '../services/notion_api.dart';
import '../services/settings_storage.dart';
import '../widgets/error_detail_dialog.dart';
import '../widgets/navigation_shell.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _storage = SettingsStorage();
  final _oauth = BangumiOAuth();
  final _notionApi = NotionApi();

  final _notionTokenController = TextEditingController();
  final _notionDbController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;
  String? _successMessage;
  bool _bangumiLoading = false;
  bool _bangumiHasToken = false;
  bool _bangumiTokenValid = false;
  BangumiUser? _bangumiUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _storage.loadAll();

    String notionToken = data[SettingsKeys.notionToken] ?? '';
    if (notionToken.isEmpty) {
      notionToken = dotenv.env['NOTION_TOKEN'] ?? '';
    }

    String notionDbId = data[SettingsKeys.notionDatabaseId] ?? '';
    if (notionDbId.isEmpty) {
      notionDbId = dotenv.env['NOTION_DATABASE_ID'] ?? '';
    }

    _notionTokenController.text = notionToken;
    _notionDbController.text = notionDbId;

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }

    await _refreshBangumiStatus();
  }

  Future<void> _refreshBangumiStatus() async {
    final token = await _oauth.getStoredAccessToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _bangumiHasToken = false;
          _bangumiTokenValid = false;
          _bangumiUser = null;
        });
      }
      return;
    }
    try {
      final api = BangumiApi();
      final user = await api.fetchSelf(accessToken: token);
      if (mounted) {
        setState(() {
          _bangumiHasToken = true;
          _bangumiTokenValid = true;
          _bangumiUser = user;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _bangumiHasToken = true;
          _bangumiTokenValid = false;
          _bangumiUser = null;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _autoSaveNotionSettings() async {
    try {
      await _storage.saveNotionSettings(
        notionToken: _notionTokenController.text.trim(),
        notionDatabaseId: _notionDbController.text.trim(),
      );
    } catch (_) {}
  }

  Future<void> _saveAll() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _storage.saveNotionSettings(
        notionToken: _notionTokenController.text.trim(),
        notionDatabaseId: _notionDbController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _successMessage = '设置已保存';
        });
        _showSnackBar('设置已保存');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = '保存失败，请稍后重试';
        });
        _showSnackBar('保存失败，请稍后重试', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _authorize() async {
    if (!BangumiOAuthConfig.isConfigured) {
      await _showBangumiConfigMissingDialog();
      return;
    }
    setState(() {
      _saving = true;
      _bangumiLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await _oauth.authorize();
      if (mounted) {
        setState(() {
          _successMessage = 'Bangumi 授权成功';
          _bangumiHasToken = true;
          _bangumiTokenValid = result.isTokenValid;
          _bangumiUser = result.user;
        });
        _showSnackBar('Bangumi 授权成功');
      }
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() {
          _errorMessage = '授权失败，请稍后重试';
        });
        _showSnackBar('授权失败，请稍后重试', isError: true);
        await showDialog(
          context: context,
          builder: (context) => ErrorDetailDialog(
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _bangumiLoading = false;
        });
      }
    }
  }

  Future<void> _showBangumiConfigMissingDialog() async {
    if (!mounted) {
      return;
    }
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bangumi 授权配置缺失'),
        content: Text(
          '${BangumiOAuthConfig.missingMessage}\n'
          '请在环境变量/打包参数中添加这两个，或联系开发人员重新打包。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () async {
              await launchUrl(
                Uri.parse('https://bgm.tv/oauth/clients'),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('前往 Bangumi 开发者平台'),
          ),
        ],
      ),
    );
  }

  Future<void> _logoutBangumi() async {
    setState(() {
      _saving = true;
      _bangumiLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _oauth.logout();
      if (mounted) {
        setState(() {
          _bangumiHasToken = false;
          _bangumiTokenValid = false;
          _bangumiUser = null;
          _successMessage = '已退出 Bangumi 授权';
        });
        _showSnackBar('已退出 Bangumi 授权');
      }
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() {
          _errorMessage = '退出失败，请稍后重试';
        });
        await showDialog(
          context: context,
          builder: (context) => ErrorDetailDialog(
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _bangumiLoading = false;
        });
      }
    }
  }
  Future<void> _testNotionConnection() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final token = _notionTokenController.text.trim();
      final databaseId = _notionDbController.text.trim();

      if (token.isEmpty || databaseId.isEmpty) {
        throw Exception('请先填写 Notion Token 与 Database ID');
      }

      await _notionApi.testConnection(
        token: token,
        databaseId: databaseId,
      );

      if (mounted) {
        setState(() {
          _successMessage = 'Notion 连接成功';
        });
        _showSnackBar('Notion 连接成功');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = '连接失败，请稍后重试';
        });
        _showSnackBar('连接失败，请稍后重试', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _notionTokenController.dispose();
    _notionDbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NavigationShell(
      title: '设置',
      selectedRoute: '/settings',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle('Bangumi 设置'),
                _buildBangumiStatusCard(),
                const SizedBox(height: 12),
                Text(
                  '点击授权将打开系统浏览器，完成登录后会回调到本地 http://localhost:8080/auth/callback。',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _authorize,
                        icon: _bangumiLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.lock_open),
                        label: const Text('登录/授权'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: (_saving || !_bangumiHasToken)
                          ? null
                          : _logoutBangumi,
                      icon: const Icon(Icons.logout),
                      label: const Text('登出'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _sectionTitle('Notion 设置'),
                TextField(
                  controller: _notionTokenController,
                  decoration: InputDecoration(
                    labelText: 'Notion Token',
                    border: const OutlineInputBorder(),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: TextButton.icon(
                        onPressed: () => launchUrl(Uri.parse('https://www.notion.so/my-integrations')),
                        icon: const Icon(Icons.key_rounded, size: 18),
                        label: const Text('获取'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    helperText: '前往 Notion 开发者后台获取 Internal Integration Token，将安全保存',
                  ),
                  obscureText: true,
                  onChanged: (_) => _autoSaveNotionSettings(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notionDbController,
                  decoration: const InputDecoration(
                    labelText: 'Notion Database ID',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _autoSaveNotionSettings(),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveAll,
                  icon: const Icon(Icons.save),
                  label: const Text('保存设置'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _testNotionConnection,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: const Text('测试 Notion 连接'),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (_successMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _successMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _sectionTitle('OAuth 回调配置'),
                _buildCopyableTile(
                  context,
                  label: '桌面端回调地址',
                  value: 'http://localhost:8080/auth/callback',
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBangumiStatusCard() {
    final hasToken = _bangumiHasToken;
    final userLabel = _bangumiUser == null
        ? '未获取到用户信息'
        : (_bangumiUser!.nickname.isNotEmpty ? _bangumiUser!.nickname : '已登录');
    final statusText = hasToken
        ? (_bangumiTokenValid ? '已登录' : 'Token 无效或已过期')
        : '未登录';
    final statusColor = _bangumiTokenValid
        ? Colors.green
        : (hasToken ? Colors.orange : Colors.grey);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.account_circle, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _bangumiLoading ? null : _refreshBangumiStatus,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('刷新'),
          ),
        ],
      ),
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
