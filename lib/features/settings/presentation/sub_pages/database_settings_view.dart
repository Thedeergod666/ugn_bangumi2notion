import 'package:flutter/material.dart';

class DatabaseSettingsViewState {
  const DatabaseSettingsViewState({
    required this.isSaving,
    required this.errorMessage,
    required this.successMessage,
  });

  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;
}

class DatabaseSettingsViewCallbacks {
  const DatabaseSettingsViewCallbacks({
    required this.onOpenNotionIntegrations,
    required this.onSaveAll,
    required this.onTestConnection,
    required this.onTokenChanged,
    required this.onDatabaseIdChanged,
    required this.onMovieDatabaseIdChanged,
    required this.onGameDatabaseIdChanged,
  });

  final VoidCallback onOpenNotionIntegrations;
  final VoidCallback onSaveAll;
  final VoidCallback onTestConnection;
  final ValueChanged<String> onTokenChanged;
  final ValueChanged<String> onDatabaseIdChanged;
  final ValueChanged<String> onMovieDatabaseIdChanged;
  final ValueChanged<String> onGameDatabaseIdChanged;
}

class DatabaseSettingsView extends StatelessWidget {
  const DatabaseSettingsView({
    super.key,
    required this.state,
    required this.callbacks,
    required this.notionTokenController,
    required this.notionDatabaseIdController,
    required this.notionMovieDatabaseIdController,
    required this.notionGameDatabaseIdController,
  });

  final DatabaseSettingsViewState state;
  final DatabaseSettingsViewCallbacks callbacks;
  final TextEditingController notionTokenController;
  final TextEditingController notionDatabaseIdController;
  final TextEditingController notionMovieDatabaseIdController;
  final TextEditingController notionGameDatabaseIdController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle(context, 'Notion 数据源'),
        _buildFormCard(context),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            state.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (state.successMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            state.successMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          '配置后用于每日推荐、放送页绑定与同步功能。',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
            controller: notionTokenController,
            decoration: InputDecoration(
              labelText: 'Notion Token',
              border: const OutlineInputBorder(),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  onPressed: callbacks.onOpenNotionIntegrations,
                  icon: const Icon(Icons.key_rounded, size: 18),
                  label: const Text('获取'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: colorScheme.primary,
                  ),
                ),
              ),
              helperText: 'Notion 后台 → My integrations → 复制 Secret。',
            ),
            obscureText: true,
            onChanged: callbacks.onTokenChanged,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notionDatabaseIdController,
            decoration: const InputDecoration(
              labelText: 'Notion Database ID',
              border: OutlineInputBorder(),
            ),
            onChanged: callbacks.onDatabaseIdChanged,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: state.isSaving ? null : callbacks.onSaveAll,
                  icon: const Icon(Icons.save),
                  label: const Text('保存设置'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed:
                    state.isSaving ? null : callbacks.onTestConnection,
                icon: state.isSaving
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

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

