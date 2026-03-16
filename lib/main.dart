import 'dart:async';
import 'dart:ui';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'app/app_settings.dart';
import 'app/app_services.dart';
import 'core/theme/kazumi_theme.dart';
import 'core/utils/logging.dart';
import 'features/airing_calendar/presentation/calendar_page.dart';
import 'features/dashboard/presentation/notion_detail_page.dart';
import 'features/dashboard/presentation/recommendation_page.dart';
import 'features/search/presentation/search_page.dart';
import 'features/settings/presentation/settings_page.dart';
import 'features/settings/presentation/sub_pages/mapping_page.dart';

void main() {
  final logger = Logger();
  String? lastErrorSignature;
  DateTime? lastErrorAt;

  bool isKnownDuplicateKeyDownAssertion(Object error) {
    final message = error.toString();
    return message.contains('A KeyDownEvent is dispatched') &&
        message.contains('physical key is already pressed') &&
        message.contains('hardware_keyboard.dart');
  }

  bool shouldSkipDuplicateError(Object error, StackTrace? stackTrace) {
    final head = stackTrace == null
        ? ''
        : stackTrace.toString().split('\n').take(8).join('\n');
    final signature = '${error.runtimeType}|$error|$head';
    final now = DateTime.now();
    if (lastErrorSignature == signature &&
        lastErrorAt != null &&
        now.difference(lastErrorAt!) < const Duration(seconds: 1)) {
      return true;
    }
    lastErrorSignature = signature;
    lastErrorAt = now;
    return false;
  }

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      try {
        await dotenv.load(fileName: ".env");
      } catch (_) {
        // .env file is optional
      }

      final settings = AppSettings();
      await settings.load();
      await logger.restorePersistedErrors();

      try {
        await HardwareKeyboard.instance.syncKeyboardState();
      } catch (error) {
        logger.debug('Keyboard state sync skipped: $error');
      }

      FlutterError.onError = (details) {
        final error = details.exception;
        if (isKnownDuplicateKeyDownAssertion(error)) {
          logger.debug('Ignored known Flutter keyboard assertion: $error');
          return;
        }
        if (shouldSkipDuplicateError(error, details.stack)) {
          return;
        }

        FlutterError.presentError(details);
        logger.error(
          'FlutterError: ${details.exceptionAsString()}',
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        if (isKnownDuplicateKeyDownAssertion(error)) {
          logger.debug('Ignored known Flutter keyboard assertion: $error');
          return true;
        }
        if (shouldSkipDuplicateError(error, stack)) {
          return true;
        }

        logger.error(
          'PlatformDispatcher error: ${error.runtimeType}',
          error: error,
          stackTrace: stack,
        );
        return true;
      };

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
      if (isKnownDuplicateKeyDownAssertion(error)) {
        logger.debug('Ignored known Flutter keyboard assertion: $error');
        return;
      }
      if (shouldSkipDuplicateError(error, stack)) {
        return;
      }

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
      case '/notion-detail':
        return _buildSlideRoute(const NotionDetailPage(), settings);
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
          title: '悠gn追番助手',
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
