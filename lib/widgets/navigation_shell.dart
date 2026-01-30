import 'package:flutter/material.dart';
import '../main.dart';
import '../services/settings_storage.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({
    super.key,
    required this.title,
    required this.selectedRoute,
    required this.child,
  });

  final String title;
  final String selectedRoute;
  final Widget child;

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  bool? _userExtended;
  bool? _lastIsWide;

  int _selectedIndex() {
    switch (widget.selectedRoute) {
      case '/mapping':
        return 1;
      case '/settings':
        return 2;
      case '/search':
      default:
        return 0;
    }
  }

  void _handleDestinationSelected(BuildContext context, int index) {
    String route;
    switch (index) {
      case 1:
        route = '/mapping';
        break;
      case 2:
        route = '/settings';
        break;
      case 0:
      default:
        route = '/search';
        break;
    }
    if (route == widget.selectedRoute) {
      return;
    }
    Navigator.pushReplacementNamed(context, route);
  }

  void _toggleTheme() async {
    final currentMode = themeNotifier.value;
    ThemeMode newMode;
    if (currentMode == ThemeMode.light) {
      newMode = ThemeMode.dark;
    } else if (currentMode == ThemeMode.dark) {
      newMode = ThemeMode.light;
    } else {
      // 如果是系统模式，根据当前实际亮度切换
      final brightness = MediaQuery.of(context).platformBrightness;
      newMode = brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    }
    themeNotifier.value = newMode;
    await SettingsStorage().saveThemeMode(newMode.name);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        // 当宽度跨越阈值时，重置手动状态
        // 使用 WidgetsBinding.instance.addPostFrameCallback 避免在 build 过程中调用 setState
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

        // 优先级：手动状态 > 自动状态
        final isExtended = _userExtended ?? isWide;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            automaticallyImplyLeading: false,
            leading: null,
          ),
          body: Row(
            children: [
              // 使用 Column 包装 NavigationRail 以确保切换按钮位于底部
              IntrinsicWidth(
                child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: Column(
                    children: [
                      Expanded(
                        child: NavigationRail(
                          selectedIndex: _selectedIndex(),
                          extended: isExtended,
                          groupAlignment: -1.0,
                          destinations: const [
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
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: ValueListenableBuilder<ThemeMode>(
                          valueListenable: themeNotifier,
                          builder: (context, mode, _) {
                            final isDark = mode == ThemeMode.dark ||
                                (mode == ThemeMode.system &&
                                    MediaQuery.of(context).platformBrightness ==
                                        Brightness.dark);
                            final icon =
                                isDark ? Icons.light_mode : Icons.dark_mode;
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
                                      foregroundColor: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
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
                            bottom: 20, left: 8, right: 8, top: 8),
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
                                  minimumSize: const Size(double.infinity, 48),
                                  foregroundColor: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
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
              const VerticalDivider(width: 1),
              Expanded(child: widget.child),
            ],
          ),
        );
      },
    );
  }
}
