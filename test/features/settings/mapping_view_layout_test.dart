import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_utools/app/app_settings.dart';
import 'package:flutter_utools/core/database/settings_storage.dart';
import 'package:flutter_utools/core/network/notion_api.dart';
import 'package:flutter_utools/features/settings/presentation/sub_pages/mapping_view.dart';
import 'package:flutter_utools/features/settings/presentation/sub_pages/widgets/mapping_card_mobile.dart';
import 'package:flutter_utools/features/settings/presentation/sub_pages/widgets/mapping_table_desktop.dart';
import 'package:flutter_utools/features/settings/providers/mapping_view_model.dart';

class _FakeSettings extends AppSettings {
  _FakeSettings({
    required this.token,
    required this.databaseId,
  });

  final String token;
  final String databaseId;

  @override
  String get notionToken => token;

  @override
  String get notionDatabaseId => databaseId;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<MappingViewModel> createLoadedModel() async {
    SharedPreferences.setMockInitialValues({});
    const dbId = '0123456789abcdef0123456789abcdef';
    final mockClient = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/v1/databases/$dbId') {
        return http.Response(
          jsonEncode({
            'properties': {
              'Name': {'type': 'title'},
              'Bangumi ID': {'type': 'number'},
              'Official URL': {'type': 'url'},
              'Watch Status': {'type': 'status'},
              'Watched Episodes': {'type': 'number'},
              'Yougn Score': {'type': 'number'},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 200,
          headers: {'content-type': 'application/json'});
    });

    final model = MappingViewModel(
      notionApi: NotionApi(client: mockClient),
      settingsStorage: SettingsStorage(),
    );
    await model.load(
      _FakeSettings(token: 'token', databaseId: dbId),
      forceRefresh: true,
    );
    return model;
  }

  testWidgets('desktop mapping view renders table header and required badge',
      (tester) async {
    final model = await createLoadedModel();

    await tester.binding.setSurfaceSize(const Size(1365, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MappingView(
            model: model,
            onApplyMagicMap: () {},
            onBack: () {},
            onReset: () {},
            onSave: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bangumi 属性'), findsOneWidget);
    expect(find.text('Notion 属性名称'), findsOneWidget);
    expect(find.textContaining('映射状态'), findsOneWidget);
    expect(find.text('必填'), findsOneWidget);
  });

  testWidgets('mobile mapping view switches to card layout', (tester) async {
    final model = await createLoadedModel();

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MappingView(
            model: model,
            onApplyMagicMap: () {},
            onBack: () {},
            onReset: () {},
            onSave: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MappingTableDesktop), findsNothing);
    expect(find.byType(MappingCardMobile), findsWidgets);
    expect(find.text('Bangumi 属性'), findsNothing);
    expect(find.text('Bangumi ID'), findsWidgets);
  });
}
