import 'package:flutter/material.dart';

@Deprecated('已由 NavigationRail 替代，保留文件避免历史引用报错。')
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.selectedRoute});

  final String selectedRoute;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
