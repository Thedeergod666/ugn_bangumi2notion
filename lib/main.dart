import 'dart:async';
import 'dart:ui';

import 'package:dynamic_color/dynamic_color.dart';
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
import 'services/logging.dart';
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
  final logger = Logger();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    logger.error(
      'FlutterError: ${details.exceptionAsString()}',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    logger.error(
      'PlatformDispatcher error: ${error.runtimeType}',
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  runZonedGuarded(
    () {
      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: logger),
            Provider<AppServices>(
              create: (_) => AppServices(logger: logger),
              dispose: (_, services) => services.dispose(),
            ),
          ],
          child: const MyApp(),
        ),
      );
    },
    (error, stack) {
      logger.error(
        'Uncaught zone error: ${error.runtimeType}',
        error: error,
        stackTrace: stack,
      );
    },
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
    final settings = context.watch<AppSettings>();
    final seed = KazumiTheme.seedForId(settings.colorSchemeId).color;
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme = KazumiTheme.buildScheme(
          brightness: Brightness.light,
          seedColor: seed,
          dynamicScheme: settings.useDynamicColor ? lightDynamic : null,
        );
        final darkScheme = KazumiTheme.buildScheme(
          brightness: Brightness.dark,
          seedColor: seed,
          dynamicScheme: settings.useDynamicColor ? darkDynamic : null,
          oledOptimization: settings.oledOptimization,
        );
        return MaterialApp(
          title: '鎮爂n助手',
          theme: KazumiTheme.light(
            scheme: lightScheme,
            useSystemFont: settings.useSystemFont,
          ),
          darkTheme: KazumiTheme.dark(
            scheme: darkScheme,
            useSystemFont: settings.useSystemFont,
          ),
          themeMode: settings.themeMode,
          initialRoute: '/calendar',
          onGenerateRoute: _onGenerateRoute,
        );
      },
    );
  }
}
