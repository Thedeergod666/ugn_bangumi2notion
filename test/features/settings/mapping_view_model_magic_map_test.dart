import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_utools/app/app_settings.dart';
import 'package:flutter_utools/core/database/settings_storage.dart';
import 'package:flutter_utools/core/network/notion_api.dart';
import 'package:flutter_utools/features/settings/providers/mapping_view_model.dart';
import 'package:flutter_utools/models/mapping_schema.dart';

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

  test('Magic Map writes into V2 common slots and updates usage index',
      () async {
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
              'Yougn Score': {'type': 'number'},
              'Status': {'type': 'status'},
              'Watched': {'type': 'number'},
              'Tags': {'type': 'multi_select'},
              'Description': {'type': 'rich_text'},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response(
        '{}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final storage = SettingsStorage();
    final notionApi = NotionApi(client: mockClient);
    final model = MappingViewModel(
      notionApi: notionApi,
      settingsStorage: storage,
    );

    await model.load(
      _FakeSettings(token: 'token', databaseId: dbId),
      forceRefresh: true,
    );
    model.applyMagicMap();

    expect(
      model.config.bindingFor(MappingSlotKey.title).propertyName,
      'Name',
    );
    expect(
      model.config.bindingFor(MappingSlotKey.bangumiId).propertyName,
      'Bangumi ID',
    );
    expect(
      model.config.bindingFor(MappingSlotKey.yougnScore).propertyName,
      'Yougn Score',
    );
    expect(
      model.config.bindingFor(MappingSlotKey.watchingStatus).propertyName,
      'Status',
    );
    expect(
      model.config.bindingFor(MappingSlotKey.watchedEpisodes).propertyName,
      'Watched',
    );

    final usage = model.propertyUsageIndex['Name'];
    expect(usage, isNotNull);
    expect(usage!, isNotEmpty);
  });
}
