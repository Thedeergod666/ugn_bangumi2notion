import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_settings.dart';
import '../core/layout/breakpoints.dart';
import 'sidebar_recommendation_card.dart';

class NavigationShell extends StatelessWidget {
  const NavigationShell({
    super.key,
    required this.title,
    required this.selectedRoute,
    required this.child,
    this.actions,
    this.onBack,
  });

  final String title;
  final String selectedRoute;
  final Widget child;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  int _selectedIndex() {
    switch (selectedRoute) {
      case '/calendar':
        return 0;
      case '/recommendation':
        return 1;
      case '/search':
        return 2;
      case '/settings':
      case '/mapping':
        return 3;
      default:
        return 0;
    }
  }

  void _handleDestinationSelected(BuildContext context, int index) {
    String route;
    switch (index) {
      case 3:
        route = '/settings';
        break;
      case 1:
        route = '/recommendation';
        break;
      case 2:
        route = '/search';
        break;
      case 0:
      default:
        route = '/calendar';
        break;
    }
    if (route == selectedRoute) {
      return;
    }
    Navigator.pushReplacementNamed(context, route);
  }

  Future<void> _toggleTheme(BuildContext context) async {
    final settings = context.read<AppSettings>();
    final currentMode = settings.themeMode;
    ThemeMode newMode;
    if (currentMode == ThemeMode.light) {
      newMode = ThemeMode.dark;
    } else if (currentMode == ThemeMode.dark) {
      newMode = ThemeMode.light;
    } else {
      final brightness = MediaQuery.of(context).platformBrightness;
      newMode =
          brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    }
    await settings.setThemeMode(newMode);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    final showAppBar =
        onBack != null || !(isDesktop && settings.useSystemTitleBar);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Breakpoints.sizeForWidth(constraints.maxWidth);
        final isNarrow = size == ScreenSize.narrow;
        final isWide = size == ScreenSize.wide;
        final useRail = !isNarrow;
        final useBottomNav = isNarrow && onBack == null;

        final contentRadius =
            isNarrow ? BorderRadius.zero : BorderRadius.circular(28);
        final surfaceBorder = isNarrow
            ? null
            : Border.all(color: colorScheme.outlineVariant);

        final content = Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: contentRadius,
            border: surfaceBorder,
          ),
          child: ClipRRect(
            borderRadius: contentRadius,
            child: child,
          ),
        );

        return Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: showAppBar
              ? AppBar(
                  title: Text(title),
                  automaticallyImplyLeading: onBack != null,
                  leading: onBack == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: onBack,
                        ),
                  actions: actions,
                )
              : null,
          bottomNavigationBar: useBottomNav
              ? NavigationBar(
                  selectedIndex: _selectedIndex(),
                  onDestinationSelected: (index) =>
                      _handleDestinationSelected(context, index),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month),
                      label: '放送',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.recommend),
                      label: '推荐',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.search),
                      label: '搜索',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings),
                      label: '设置',
                    ),
                  ],
                )
              : null,
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.surfaceContainerLowest,
                  colorScheme.surface,
                ],
              ),
            ),
            child: useRail
                ? Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                        child: IntrinsicWidth(
                          child: Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(24),
                              border:
                                  Border.all(color: colorScheme.outlineVariant),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.shadow
                                      .withValues(alpha: 0.08),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: NavigationRail(
                                      selectedIndex: _selectedIndex(),
                                      extended: isWide,
                                      groupAlignment: -1.0,
                                      useIndicator: true,
                                      indicatorShape: const StadiumBorder(),
                                      minWidth: 72,
                                      minExtendedWidth: 220,
                                      destinations: const [
                                        NavigationRailDestination(
                                          icon: Icon(Icons.calendar_month),
                                          label: Text('放送页'),
                                        ),
                                        NavigationRailDestination(
                                          icon: Icon(Icons.recommend),
                                          label: Text('推荐页'),
                                        ),
                                        NavigationRailDestination(
                                          icon: Icon(Icons.search),
                                          label: Text('搜索页'),
                                        ),
                                        NavigationRailDestination(
                                          icon: Icon(Icons.settings),
                                          label: Text('设置页'),
                                        ),
                                      ],
                                      onDestinationSelected: (index) =>
                                          _handleDestinationSelected(
                                              context, index),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: SidebarRecommendationCard(
                                      extended: isWide,
                                      compact: !isWide,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Consumer<AppSettings>(
                                      builder: (context, settings, _) {
                                        final mode = settings.themeMode;
                                        final isDark = mode == ThemeMode.dark ||
                                            (mode == ThemeMode.system &&
                                                MediaQuery.of(context)
                                                        .platformBrightness ==
                                                    Brightness.dark);
                                        final icon = isDark
                                            ? Icons.light_mode
                                            : Icons.dark_mode;
                                        final label =
                                            isDark ? '浅色模式' : '深色模式';

                                        return isWide
                                            ? TextButton.icon(
                                                onPressed: () =>
                                                    _toggleTheme(context),
                                                icon: Icon(icon),
                                                label: Text(label),
                                                style: TextButton.styleFrom(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  minimumSize: const Size(
                                                      double.infinity, 48),
                                                  backgroundColor: colorScheme
                                                      .surfaceContainerLow,
                                                  foregroundColor: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              )
                                            : IconButton(
                                                tooltip: label,
                                                icon: Icon(icon),
                                                onPressed: () =>
                                                    _toggleTheme(context),
                                              );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 12, 16, 12),
                          child: content,
                        ),
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: content,
                  ),
          ),
        );
      },
    );
  }
}
