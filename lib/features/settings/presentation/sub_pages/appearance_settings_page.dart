import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_settings.dart';
import '../../../../core/theme/kazumi_theme.dart';
import '../../../../core/widgets/navigation_shell.dart';
import '../../providers/appearance_settings_view_model.dart';
import 'appearance_settings_view.dart';

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
    AppearanceSettingsViewModel model,
  ) async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('主题模式'),
          content: RadioGroup<ThemeMode>(
            groupValue: model.themeMode,
            onChanged: (value) => Navigator.pop(context, value),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ThemeMode>(
                  title: Text('跟随系统'),
                  value: ThemeMode.system,
                  dense: true,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('浅色模式'),
                  value: ThemeMode.light,
                  dense: true,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('深色模式'),
                  value: ThemeMode.dark,
                  dense: true,
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      await model.setThemeMode(selected);
    }
  }

  Future<void> _showColorSchemePicker(
    BuildContext context,
    AppearanceSettingsViewModel model,
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
                final isSelected = seed.id == model.colorSchemeId;
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
      await model.setColorSchemeId(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          AppearanceSettingsViewModel(settings: context.read<AppSettings>()),
      child: Consumer<AppearanceSettingsViewModel>(
        builder: (context, model, _) {
          final seedLabel = KazumiTheme.seedForId(model.colorSchemeId).label;

          return NavigationShell(
            title: '外观设置',
            selectedRoute: '/settings',
            onBack: () => Navigator.of(context).pop(),
            child: AppearanceSettingsView(
              state: AppearanceSettingsViewState(
                themeModeLabel: _themeModeLabel(model.themeMode),
                colorSchemeLabel: seedLabel,
                useDynamicColor: model.useDynamicColor,
                useSystemFont: model.useSystemFont,
                showRatings: model.showRatings,
                oledOptimization: model.oledOptimization,
                useSystemTitleBar: model.useSystemTitleBar,
              ),
              callbacks: AppearanceSettingsViewCallbacks(
                onPickThemeMode: () => unawaited(
                  _showThemeModePicker(context, model),
                ),
                onPickColorScheme: () => unawaited(
                  _showColorSchemePicker(context, model),
                ),
                onUseDynamicColorChanged: (value) =>
                    unawaited(model.setUseDynamicColor(value)),
                onUseSystemFontChanged: (value) =>
                    unawaited(model.setUseSystemFont(value)),
                onShowRatingsChanged: (value) =>
                    unawaited(model.setShowRatings(value)),
                onOledOptimizationChanged: (value) =>
                    unawaited(model.setOledOptimization(value)),
                onUseSystemTitleBarChanged: (value) =>
                    unawaited(model.setUseSystemTitleBar(value)),
              ),
            ),
          );
        },
      ),
    );
  }
}
