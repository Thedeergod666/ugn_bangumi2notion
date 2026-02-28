import 'package:flutter/material.dart';

class SettingsViewState {
  const SettingsViewState({
    required this.isLoading,
    required this.isSaving,
    required this.isBangumiLoading,
    required this.bangumiHasToken,
    required this.bangumiTokenValid,
    required this.bangumiUserLabel,
    required this.errorMessage,
    required this.successMessage,
  });

  final bool isLoading;
  final bool isSaving;
  final bool isBangumiLoading;
  final bool bangumiHasToken;
  final bool bangumiTokenValid;
  final String bangumiUserLabel;
  final String? errorMessage;
  final String? successMessage;
}

class SettingsViewCallbacks {
  const SettingsViewCallbacks({
    required this.onAuthorize,
    required this.onLogout,
    required this.onRefreshBangumiStatus,
    required this.onOpenDatabaseSettings,
    required this.onOpenMapping,
    required this.onOpenBatchImport,
    required this.onOpenAppearance,
    required this.onOpenErrorLog,
    required this.onCopyOAuthCallbackUrl,
  });

  final VoidCallback onAuthorize;
  final VoidCallback onLogout;
  final VoidCallback onRefreshBangumiStatus;
  final VoidCallback onOpenDatabaseSettings;
  final VoidCallback onOpenMapping;
  final VoidCallback onOpenBatchImport;
  final VoidCallback onOpenAppearance;
  final VoidCallback onOpenErrorLog;
  final VoidCallback onCopyOAuthCallbackUrl;
}

class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.state,
    required this.callbacks,
    required this.oauthCallbackUrl,
  });

  final SettingsViewState state;
  final SettingsViewCallbacks callbacks;
  final String oauthCallbackUrl;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle(context, '账号与同步'),
        _buildBangumiCard(context),
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
        const SizedBox(height: 20),
        _sectionTitle(context, '数据与外观'),
        _buildGroup(
          context,
          [
            _buildNavTile(
              icon: Icons.storage_rounded,
              title: '数据绑定',
              subtitle: '配置 Notion Token 与 Database ID',
              onTap: callbacks.onOpenDatabaseSettings,
            ),
            _buildNavTile(
              icon: Icons.map_outlined,
              title: '数据映射',
              subtitle: 'Bangumi/Notion 字段映射',
              onTap: callbacks.onOpenMapping,
            ),
            _buildNavTile(
              icon: Icons.cloud_upload_outlined,
              title: '批量导入/更新',
              subtitle: '批量绑定 Bangumi ID',
              onTap: callbacks.onOpenBatchImport,
            ),
            _buildNavTile(
              icon: Icons.palette_outlined,
              title: '外观',
              subtitle: '主题与配色方案',
              onTap: callbacks.onOpenAppearance,
            ),
            _buildNavTile(
              icon: Icons.bug_report_outlined,
              title: '错误日志',
              subtitle: '应用运行时错误日志',
              onTap: callbacks.onOpenErrorLog,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionTitle(context, '开发者'),
        _buildGroup(
          context,
          [
            _buildCopyableTile(
              context,
              label: 'OAuth 回调地址',
              value: oauthCallbackUrl,
              onTap: callbacks.onCopyOAuthCallbackUrl,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '请在 Bangumi 开发者后台登记该回调地址，授权时将通过本地回调接收 code。',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildBangumiCard(BuildContext context) {
    final hasToken = state.bangumiHasToken;
    final isValid = state.bangumiTokenValid;
    final statusText = hasToken ? (isValid ? '已登录' : 'Token 无效/过期') : '未登录';
    final statusColor = isValid
        ? Colors.green
        : (hasToken ? Colors.orange : Theme.of(context).disabledColor);
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
              state.bangumiUserLabel,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            trailing: TextButton.icon(
              onPressed: state.isBangumiLoading
                  ? null
                  : callbacks.onRefreshBangumiStatus,
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
                        onPressed:
                            state.isSaving ? null : callbacks.onAuthorize,
                        icon: state.isBangumiLoading
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
                      onPressed:
                          (state.isSaving || !state.bangumiHasToken)
                              ? null
                              : callbacks.onLogout,
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
      child: Column(children: _addDividers(context, tiles)),
    );
  }

  List<Widget> _addDividers(BuildContext context, List<Widget> tiles) {
    final colorScheme = Theme.of(context).colorScheme;
    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) {
        children.add(Divider(height: 1, color: colorScheme.outlineVariant));
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

