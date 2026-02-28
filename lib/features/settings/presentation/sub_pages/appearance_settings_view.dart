import 'package:flutter/material.dart';

class AppearanceSettingsViewState {
  const AppearanceSettingsViewState({
    required this.themeModeLabel,
    required this.colorSchemeLabel,
    required this.useDynamicColor,
    required this.useSystemFont,
    required this.showRatings,
    required this.oledOptimization,
    required this.useSystemTitleBar,
  });

  final String themeModeLabel;
  final String colorSchemeLabel;
  final bool useDynamicColor;
  final bool useSystemFont;
  final bool showRatings;
  final bool oledOptimization;
  final bool useSystemTitleBar;
}

class AppearanceSettingsViewCallbacks {
  const AppearanceSettingsViewCallbacks({
    required this.onPickThemeMode,
    required this.onPickColorScheme,
    required this.onUseDynamicColorChanged,
    required this.onUseSystemFontChanged,
    required this.onShowRatingsChanged,
    required this.onOledOptimizationChanged,
    required this.onUseSystemTitleBarChanged,
  });

  final VoidCallback onPickThemeMode;
  final VoidCallback onPickColorScheme;
  final ValueChanged<bool> onUseDynamicColorChanged;
  final ValueChanged<bool> onUseSystemFontChanged;
  final ValueChanged<bool> onShowRatingsChanged;
  final ValueChanged<bool> onOledOptimizationChanged;
  final ValueChanged<bool> onUseSystemTitleBarChanged;
}

class AppearanceSettingsView extends StatelessWidget {
  const AppearanceSettingsView({
    super.key,
    required this.state,
    required this.callbacks,
  });

  final AppearanceSettingsViewState state;
  final AppearanceSettingsViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle(context, '外观'),
        _buildGroup(
          context,
          [
            _buildActionTile(
              title: '主题模式',
              trailing: Text(state.themeModeLabel),
              onTap: callbacks.onPickThemeMode,
            ),
            _buildActionTile(
              title: '配色方案',
              trailing: Text(state.colorSchemeLabel),
              onTap: callbacks.onPickColorScheme,
            ),
            _buildSwitchTile(
              title: '动态配色',
              value: state.useDynamicColor,
              onChanged: callbacks.onUseDynamicColorChanged,
            ),
            _buildSwitchTile(
              title: '使用系统字体',
              subtitle: '关闭后使用内置字体',
              value: state.useSystemFont,
              onChanged: callbacks.onUseSystemFontChanged,
            ),
            _buildSwitchTile(
              title: '显示评分',
              subtitle: '控制评分/排名的显示',
              value: state.showRatings,
              onChanged: callbacks.onShowRatingsChanged,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '动态配色在部分平台/版本可能不可用。',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        _sectionTitle(context, 'OLED 优化'),
        _buildGroup(
          context,
          [
            _buildSwitchTile(
              title: 'OLED 优化',
              subtitle: '深色模式下尽量使用纯黑背景',
              value: state.oledOptimization,
              onChanged: callbacks.onOledOptimizationChanged,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionTitle(context, '窗口'),
        _buildGroup(
          context,
          [
            _buildSwitchTile(
              title: '使用系统标题栏',
              subtitle: '重启应用生效',
              value: state.useSystemTitleBar,
              onChanged: callbacks.onUseSystemTitleBarChanged,
            ),
          ],
        ),
      ],
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

  Widget _buildActionTile({
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(title),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
      onTap: () => onChanged(!value),
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

