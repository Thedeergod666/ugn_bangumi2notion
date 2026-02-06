import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_settings.dart';
import '../theme/kazumi_theme.dart';
import '../widgets/navigation_shell.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '浅色模式';
      case ThemeMode.dark:
        return '深色模式';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  Color _shiftColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  Future<void> _showThemeModePicker(
    BuildContext context,
    AppSettings settings,
  ) async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('深色模式'),
          content: RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (value) => Navigator.pop(context, value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('跟随系统'),
                  value: ThemeMode.system,
                  selected: settings.themeMode == ThemeMode.system,
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('浅色模式'),
                  value: ThemeMode.light,
                  selected: settings.themeMode == ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('深色模式'),
                  value: ThemeMode.dark,
                  selected: settings.themeMode == ThemeMode.dark,
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      await settings.setThemeMode(selected);
    }
  }

  Future<void> _showColorSchemePicker(
    BuildContext context,
    AppSettings settings,
  ) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('配色方案'),
          content: SizedBox(
            width: 420,
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: KazumiTheme.seeds.map((seed) {
                final isSelected = seed.id == settings.colorSchemeId;
                final base = seed.color;
                return InkWell(
                  onTap: () => Navigator.pop(context, seed.id),
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 80,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    _shiftColor(base, 0.16),
                                    _shiftColor(base, -0.08),
                                  ],
                                ),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check,
                                color:
                                    Theme.of(context).colorScheme.onPrimary,
                                size: 18,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          seed.label,
                          style: Theme.of(context).textTheme.labelMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );

    if (selected != null) {
      await settings.setColorSchemeId(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final colorScheme = Theme.of(context).colorScheme;
    final seedLabel = KazumiTheme.seedForId(settings.colorSchemeId).label;

    return NavigationShell(
      title: '外观设置',
      selectedRoute: '/settings',
      onBack: () => Navigator.of(context).pop(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('外观'),
          _buildGroup(
            context,
            [
              _buildActionTile(
                title: '深色模式',
                trailing: Text(_themeModeLabel(settings.themeMode)),
                onTap: () => _showThemeModePicker(context, settings),
              ),
              _buildActionTile(
                title: '配色方案',
                trailing: Text(seedLabel),
                onTap: () => _showColorSchemePicker(context, settings),
              ),
              _buildSwitchTile(
                title: '动态配色',
                value: settings.useDynamicColor,
                onChanged: settings.setUseDynamicColor,
              ),
              _buildSwitchTile(
                title: '使用系统字体',
                subtitle: '关闭后使用内置字体',
                value: settings.useSystemFont,
                onChanged: settings.setUseSystemFont,
              ),
              _buildSwitchTile(
                title: '显示评分',
                subtitle: '控制评分/排名显示',
                value: settings.showRatings,
                onChanged: settings.setShowRatings,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '动态配色仅支持安卓12及以上和桌面平台',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          _sectionTitle('OLED优化'),
          _buildGroup(
            context,
            [
              _buildSwitchTile(
                title: 'OLED优化',
                subtitle: '深色模式下使用纯黑背景',
                value: settings.oledOptimization,
                onChanged: settings.setOledOptimization,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionTitle('窗口'),
          _buildGroup(
            context,
            [
              _buildSwitchTile(
                title: '使用系统标题栏',
                subtitle: '重启应用生效',
                value: settings.useSystemTitleBar,
                onChanged: settings.setUseSystemTitleBar,
              ),
            ],
          ),
        ],
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
    required Future<void> Function(bool) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: (next) => onChanged(next),
      ),
      onTap: () => onChanged(!value),
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
