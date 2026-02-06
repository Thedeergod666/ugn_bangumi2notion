import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_settings.dart';

class NavigationShell extends StatefulWidget {
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

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  bool? _userExtended;
  bool? _lastIsWide;

  int _selectedIndex() {
    switch (widget.selectedRoute) {
      case '/calendar':
        return 0;
      case '/recommendation':
        return 1;
      case '/search':
        return 2;
      case '/mapping':
        return 3;
      case '/settings':
        return 4;
      default:
        return 0;
    }
  }

  void _handleDestinationSelected(BuildContext context, int index) {
    String route;
    switch (index) {
      case 4:
        route = '/settings';
        break;
      case 3:
        route = '/mapping';
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
    if (route == widget.selectedRoute) {
      return;
    }
    Navigator.pushReplacementNamed(context, route);
  }

  void _toggleTheme() async {
    final settings = context.read<AppSettings>();
    final currentMode = settings.themeMode;
    ThemeMode newMode;
    if (currentMode == ThemeMode.light) {
      newMode = ThemeMode.dark;
    } else if (currentMode == ThemeMode.dark) {
      newMode = ThemeMode.light;
    } else {
      // 如果是系统模式，根据当前实际亮度切换
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
        widget.onBack != null || !(isDesktop && settings.useSystemTitleBar);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (_lastIsWide != null && _lastIsWide != isWide) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _userExtended = null;
              });
            }
          });
        }
        _lastIsWide = isWide;

        final isExtended = _userExtended ?? isWide;

        return Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: showAppBar
              ? AppBar(
                  title: Text(widget.title),
                  automaticallyImplyLeading: widget.onBack != null,
                  leading: widget.onBack == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: widget.onBack,
                        ),
                  actions: widget.actions,
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
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: IntrinsicWidth(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: colorScheme.outlineVariant),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.08),
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
                                extended: isExtended,
                                groupAlignment: -1.0,
                                useIndicator: true,
                                indicatorShape: const StadiumBorder(),
                                minWidth: 72,
                                minExtendedWidth: 220,
                                destinations: const [
                                  NavigationRailDestination(
                                    icon: Icon(Icons.calendar_month),
                                    label: Text('新番放送'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.recommend),
                                    label: Text('每日推荐'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.search),
                                    label: Text('搜索'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.map),
                                    label: Text('映射配置'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.settings),
                                    label: Text('设置'),
                                  ),
                                ],
                                onDestinationSelected: (index) =>
                                    _handleDestinationSelected(context, index),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
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
                                  final label = isDark ? '浅色模式' : '深色模式';

                                  return isExtended
                                      ? TextButton.icon(
                                          onPressed: _toggleTheme,
                                          icon: Icon(icon),
                                          label: Text(label),
                                          style: TextButton.styleFrom(
                                            alignment: Alignment.centerLeft,
                                            minimumSize:
                                                const Size(double.infinity, 48),
                                            backgroundColor:
                                                colorScheme.surfaceContainerLow,
                                            foregroundColor:
                                                colorScheme.onSurfaceVariant,
                                          ),
                                        )
                                      : IconButton(
                                          tooltip: label,
                                          icon: Icon(icon),
                                          onPressed: _toggleTheme,
                                        );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 20,
                                left: 12,
                                right: 12,
                                top: 8,
                              ),
                              child: isExtended
                                  ? TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _userExtended = !isExtended;
                                        });
                                      },
                                      icon: const Icon(Icons.chevron_left),
                                      label: const Text('收起侧边栏'),
                                      style: TextButton.styleFrom(
                                        alignment: Alignment.centerLeft,
                                        minimumSize:
                                            const Size(double.infinity, 48),
                                        foregroundColor:
                                            colorScheme.onSurfaceVariant,
                                      ),
                                    )
                                  : IconButton(
                                      tooltip: '展开侧边栏',
                                      icon: const Icon(Icons.chevron_right),
                                      onPressed: () {
                                        setState(() {
                                          _userExtended = !isExtended;
                                        });
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 16, 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
