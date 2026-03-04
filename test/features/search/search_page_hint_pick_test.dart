import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_utools/app/app_services.dart';
import 'package:flutter_utools/app/app_settings.dart';
import 'package:flutter_utools/core/database/settings_storage.dart';
import 'package:flutter_utools/features/search/presentation/search_page.dart';

void main() {
  Future<void> pumpSearchPage(
    WidgetTester tester, {
    required AppSettings settings,
    required AppServices services,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          Provider<AppServices>.value(value: services),
        ],
        child: const MaterialApp(home: SearchPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('SearchPage hint/history pick', () {
    testWidgets('pick history fills text field and searches with same keyword',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        SettingsKeys.searchHistory: ['alpha', 'beta'],
      });

      String? lastKeyword;
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/v0/search/subjects')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          lastKeyword = body['keyword'] as String?;
          return http.Response('{"data":[]}', 200, headers: {
            'content-type': 'application/json',
          });
        }
        return http.Response('{}', 200, headers: {
          'content-type': 'application/json',
        });
      });

      final settings = AppSettings();
      final services = AppServices(client: mockClient);

      await pumpSearchPage(
        tester,
        settings: settings,
        services: services,
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ActionChip, 'alpha'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'alpha').first);
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, 'alpha');
      expect(lastKeyword, 'alpha');
    });

    testWidgets(
        'pick suggestion fills text field and searches with same keyword',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        SettingsKeys.searchHistory: ['alpha', 'beta'],
      });

      String? lastKeyword;
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/v0/search/subjects')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          lastKeyword = body['keyword'] as String?;
          return http.Response('{"data":[]}', 200, headers: {
            'content-type': 'application/json',
          });
        }
        return http.Response('{}', 200, headers: {
          'content-type': 'application/json',
        });
      });

      final settings = AppSettings();
      final services = AppServices(client: mockClient);

      await pumpSearchPage(
        tester,
        settings: settings,
        services: services,
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'al');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ActionChip, 'alpha'), findsWidgets);

      await tester.tap(find.widgetWithText(ActionChip, 'alpha').first);
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, 'alpha');
      expect(lastKeyword, 'alpha');
    });

    testWidgets('history chip stays tappable during pointer down/up sequence',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        SettingsKeys.searchHistory: ['alpha', 'beta'],
      });

      String? lastKeyword;
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/v0/search/subjects')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          lastKeyword = body['keyword'] as String?;
          return http.Response('{"data":[]}', 200, headers: {
            'content-type': 'application/json',
          });
        }
        return http.Response('{}', 200, headers: {
          'content-type': 'application/json',
        });
      });

      final settings = AppSettings();
      final services = AppServices(client: mockClient);

      await pumpSearchPage(
        tester,
        settings: settings,
        services: services,
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      final chipFinder = find.widgetWithText(ActionChip, 'alpha').first;
      expect(chipFinder, findsOneWidget);

      final chipCenter = tester.getCenter(chipFinder);
      final gesture = await tester.startGesture(chipCenter);
      await tester.pump();

      // Pointer-down should not immediately remove hint chips.
      expect(find.widgetWithText(ActionChip, 'alpha'), findsWidgets);

      await gesture.up();
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, 'alpha');
      expect(lastKeyword, 'alpha');
    });
  });
}
