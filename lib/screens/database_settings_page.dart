import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_services.dart';
import '../app/app_settings.dart';
import '../services/notion_api.dart';
import '../widgets/navigation_shell.dart';

class DatabaseSettingsPage extends StatefulWidget {
  const DatabaseSettingsPage({super.key});

  @override
  State<DatabaseSettingsPage> createState() => _DatabaseSettingsPageState();
}

class _DatabaseSettingsPageState extends State<DatabaseSettingsPage> {
  late final NotionApi _notionApi;

  final _notionTokenController = TextEditingController();
  final _notionDbController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _notionApi = context.read<AppServices>().notionApi;
    _load();
  }

  Future<void> _load() async {
    final appSettings = context.read<AppSettings>();

    String notionToken = appSettings.notionToken;
    if (notionToken.isEmpty) {
      notionToken = dotenv.env['NOTION_TOKEN'] ?? '';
    }

    String notionDbId = appSettings.notionDatabaseId;
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

  Future<void> _autoSaveNotionSettings() async {
    try {
      await context.read<AppSettings>().saveNotionSettings(
            token: _notionTokenController.text.trim(),
            databaseId: _notionDbController.text.trim(),
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
      await context.read<AppSettings>().saveNotionSettings(
            token: _notionTokenController.text.trim(),
            databaseId: _notionDbController.text.trim(),
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
      title: '数据库设置',
      selectedRoute: '/settings',
      onBack: () => Navigator.of(context).pop(),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle('Notion 数据库'),
                _buildFormCard(context),
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
                const SizedBox(height: 12),
                Text(
                  '填写后可用于每日推荐与番剧同步功能。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _notionTokenController,
            decoration: InputDecoration(
              labelText: 'Notion Token',
              border: const OutlineInputBorder(),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton.icon(
                  onPressed: () => launchUrl(
                      Uri.parse('https://www.notion.so/my-integrations')),
                  icon: const Icon(Icons.key_rounded, size: 18),
                  label: const Text('获取'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              helperText: '前往 Notion 后台获取 Integration Token',
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
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveAll,
                  icon: const Icon(Icons.save),
                  label: const Text('保存设置'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _testNotionConnection,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link),
                label: const Text('测试连接'),
              ),
            ],
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
