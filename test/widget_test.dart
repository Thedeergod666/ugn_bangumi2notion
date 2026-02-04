// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_utools/app/app_services.dart';
import 'package:flutter_utools/app/app_settings.dart';
import 'package:flutter_utools/main.dart';
import 'package:flutter_utools/screens/calendar_page.dart';

void main() {
  testWidgets('App launches to calendar page', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final mockClient = MockClient((request) async {
      if (request.url.toString().endsWith('/calendar')) {
        return http.Response('[]', 200, headers: {
          'content-type': 'application/json',
        });
      }
      return http.Response('{}', 200, headers: {
        'content-type': 'application/json',
      });
    });

    final settings = AppSettings();
    final services = AppServices(client: mockClient);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          Provider<AppServices>.value(value: services),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(CalendarPage), findsOneWidget);
  });
}
