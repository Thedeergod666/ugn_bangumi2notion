import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_services.dart';
import '../app/app_settings.dart';
import '../view_models/database_settings_view_model.dart';
import '../widgets/navigation_shell.dart';

class DatabaseSettingsPage extends StatefulWidget {
  const DatabaseSettingsPage({super.key});

  @override
  State<DatabaseSettingsPage> createState() => _DatabaseSettingsPageState();
}

class _DatabaseSettingsPageState extends State<DatabaseSettingsPage> {
  late final DatabaseSettingsViewModel _viewModel;

  final _notionTokenController = TextEditingController();
  final _notionDbController = TextEditingController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _viewModel = DatabaseSettingsViewModel(
      notionApi: context.read<AppServices>().notionApi,
      settings: context.read<AppSettings>(),
    );
    _viewModel.addListener(_syncControllers);
    _viewModel.load();
  }

  void _syncControllers() {
    if (_initialized || _viewModel.isLoading) {
      return;
    }
    _initialized = true;
    _notionTokenController.text = _viewModel.notionToken;
    _notionDbController.text = _viewModel.notionDatabaseId;
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
    _viewModel.updateToken(_notionTokenController.text);
    _viewModel.updateDatabaseId(_notionDbController.text);
    await _viewModel.autoSave();
  }

  Future<void> _saveAll() async {
    _viewModel.updateToken(_notionTokenController.text);
    _viewModel.updateDatabaseId(_notionDbController.text);
    await _viewModel.saveAll();
    if (!mounted) return;
    if (_viewModel.errorMessage != null) {
      _showSnackBar(_viewModel.errorMessage!, isError: true);
    } else if (_viewModel.successMessage != null) {
      _showSnackBar(_viewModel.successMessage!);
    }
  }

  Future<void> _testNotionConnection() async {
    _viewModel.updateToken(_notionTokenController.text);
    _viewModel.updateDatabaseId(_notionDbController.text);
    await _viewModel.testConnection();
    if (!mounted) return;
    if (_viewModel.errorMessage != null) {
      _showSnackBar(_viewModel.errorMessage!, isError: true);
    } else if (_viewModel.successMessage != null) {
      _showSnackBar(_viewModel.successMessage!);
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_syncControllers);
    _viewModel.dispose();
    _notionTokenController.dispose();
    _notionDbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<DatabaseSettingsViewModel>(
        builder: (context, model, _) {
          return NavigationShell(
            title: '数据库设置',
            selectedRoute: '/settings',
            onBack: () => Navigator.of(context).pop(),
            child: model.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _sectionTitle('Notion 数据库'),
                      _buildFormCard(context, model),
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
        },
      ),
    );
  }

  Widget _buildFormCard(
    BuildContext context,
    DatabaseSettingsViewModel model,
  ) {
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
                  onPressed: model.isSaving ? null : _saveAll,
                  icon: const Icon(Icons.save),
                  label: const Text('保存设置'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: model.isSaving ? null : _testNotionConnection,
                icon: model.isSaving
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
