import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/bangumi_oauth.dart';
import '../services/notion_api.dart';
import '../services/settings_storage.dart';
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

  final _appIdController = TextEditingController();
  final _appSecretController = TextEditingController();
  final _accessTokenController = TextEditingController();
  final _notionTokenController = TextEditingController();
  final _notionDbController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _storage.loadAll();

    // Load from storage first, then fallback to .env if storage is empty
    String appId = data[SettingsKeys.bangumiAppId] ?? '';
    if (appId.isEmpty) {
      appId = dotenv.env['BANGUMI_APP_ID'] ?? '';
    }

    String appSecret = data[SettingsKeys.bangumiAppSecret] ?? '';
    if (appSecret.isEmpty) {
      appSecret = dotenv.env['BANGUMI_APP_SECRET'] ?? '';
    }

    String notionToken = data[SettingsKeys.notionToken] ?? '';
    if (notionToken.isEmpty) {
      notionToken = dotenv.env['NOTION_TOKEN'] ?? '';
    }

    String notionDbId = data[SettingsKeys.notionDatabaseId] ?? '';
    if (notionDbId.isEmpty) {
      notionDbId = dotenv.env['NOTION_DATABASE_ID'] ?? '';
    }

    _appIdController.text = appId;
    _appSecretController.text = appSecret;
    _accessTokenController.text = data[SettingsKeys.bangumiAccessToken] ?? '';
    _notionTokenController.text = notionToken;
    _notionDbController.text = notionDbId;

    if (mounted) {
      setState(() {
        _loading = false;
      });
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

  Future<void> _autoSaveBangumiCredentials() async {
    try {
      await _storage.saveBangumiCredentials(
        appId: _appIdController.text.trim(),
        appSecret: _appSecretController.text.trim(),
      );
    } catch (_) {}
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
      await _storage.saveBangumiCredentials(
        appId: _appIdController.text.trim(),
        appSecret: _appSecretController.text.trim(),
      );
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '保存失败：$e';
        });
        _showSnackBar('保存失败：$e', isError: true);
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
    setState(() {
      _saving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final appId = _appIdController.text.trim();
      final appSecret = _appSecretController.text.trim();
      if (appId.isEmpty || appSecret.isEmpty) {
        throw Exception('请先填写 Bangumi AppID 与 App Secret');
      }
      await _storage.saveBangumiCredentials(
        appId: appId,
        appSecret: appSecret,
      );
      final token = await _oauth.authorize(
        appId: appId,
        appSecret: appSecret,
      );
      await _storage.saveBangumiAccessToken(token);
      _accessTokenController.text = token;
      if (mounted) {
        setState(() {
          _successMessage = 'Bangumi Access Token 已更新';
        });
        _showSnackBar('Bangumi Access Token 已更新');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '授权失败：$e';
        });
        _showSnackBar('授权失败：$e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '连接失败：$e';
        });
        _showSnackBar('连接失败：$e', isError: true);
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
    _appIdController.dispose();
    _appSecretController.dispose();
    _accessTokenController.dispose();
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
                TextField(
                  controller: _appIdController,
                  decoration: InputDecoration(
                    labelText: 'Bangumi AppID',
                    border: const OutlineInputBorder(),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: TextButton.icon(
                        onPressed: () => launchUrl(Uri.parse('https://bgm.tv/dev/app')),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('去配置'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    helperText: '前往 Bangumi 开发者后台创建应用并获取 ID',
                  ),
                  onChanged: (_) => _autoSaveBangumiCredentials(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _appSecretController,
                  decoration: const InputDecoration(
                    labelText: 'Bangumi App Secret',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  onChanged: (_) => _autoSaveBangumiCredentials(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _accessTokenController,
                  decoration: const InputDecoration(
                    labelText: 'Bangumi Access Token',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Text(
                  'Access Token 无需手动填写，会在授权成功后自动写入。',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _authorize,
                        icon: const Icon(Icons.lock_open),
                        label: const Text('授权并获取 Token'),
                      ),
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
                    helperText: '前往 Notion 开发者后台获取 Internal Integration Token',
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
                const Text(
                  '''OAuth 回调配置：
Windows 必须使用固定 loopback 回调：http://localhost:61390
其它平台使用 bangumi-importer://oauth2redirect
请在 Bangumi 开发者后台添加回调（示例：http://localhost:61390）。''',
                  style: TextStyle(color: Colors.black54),
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
