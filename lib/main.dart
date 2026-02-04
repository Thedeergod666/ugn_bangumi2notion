import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'app/app_settings.dart';
import 'app/app_services.dart';
import 'screens/recommendation_page.dart';
import 'screens/search_page.dart';
import 'screens/settings_page.dart';
import 'screens/mapping_page.dart';
import 'screens/calendar_page.dart';
import 'theme/kazumi_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // .env file is optional
  }

  final settings = AppSettings();
  await settings.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        Provider<AppServices>(
          create: (_) => AppServices(),
          dispose: (_, services) => services.dispose(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  PageRouteBuilder<void> _buildSlideRoute(
    Widget page,
    RouteSettings settings,
  ) {
    return PageRouteBuilder<void>(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (_, __, ___, child) => child,
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/settings':
        return _buildSlideRoute(const SettingsPage(), settings);
      case '/mapping':
        return _buildSlideRoute(const MappingPage(), settings);
      case '/search':
        return _buildSlideRoute(const SearchPage(), settings);
      case '/calendar':
        return _buildSlideRoute(const CalendarPage(), settings);
      case '/recommendation':
      default:
        return _buildSlideRoute(const RecommendationPage(), settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = context.watch<AppSettings>().themeMode;
    return MaterialApp(
      title: '悠gn助手',
      theme: KazumiTheme.light(),
      darkTheme: KazumiTheme.dark(),
      themeMode: currentMode,
      initialRoute: '/calendar',
      onGenerateRoute: _onGenerateRoute,
    );
  }
}
