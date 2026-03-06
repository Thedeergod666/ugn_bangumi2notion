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
              'Text Field': {'type': 'rich_text'},
              'Watch Status': {'type': 'status'},
              'Watched Episodes': {'type': 'number'},
              'Yougn Score': {'type': 'number'},
              'Global ID': {'type': 'rich_text'},
              'Notion ID': {'type': 'rich_text'},
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

  test('rowsForUi marks Bangumi ID row as required and error when missing',
      () async {
    final model = await createLoadedModel();

    final row = model.rowsForUi.firstWhere(
      (item) => item.slot == MappingSlotKey.bangumiId,
    );

    expect(row.isRequired, isTrue);
    expect(row.status, MappingRowStatus.error);
    expect(model.statusSummary.total, model.rowsForUi.length);
    expect(model.statusSummary.error, greaterThan(0));
  });

  test('rowsForUi detects type mismatch and recovers after valid selection',
      () async {
    final model = await createLoadedModel();

    model.updateSlotProperty(MappingSlotKey.link, 'Name');
    var linkRow = model.rowsForUi.firstWhere(
      (item) => item.slot == MappingSlotKey.link,
    );
    expect(linkRow.status, MappingRowStatus.error);

    model.updateSlotProperty(MappingSlotKey.link, 'Official URL');
    linkRow = model.rowsForUi.firstWhere(
      (item) => item.slot == MappingSlotKey.link,
    );
    expect(linkRow.status, MappingRowStatus.configured);
  });

  test('resetDraft reverts to latest loaded or saved snapshot', () async {
    final model = await createLoadedModel();

    expect(model.hasUnsavedChanges, isFalse);
    expect(
      model.config.bindingFor(MappingSlotKey.title).propertyName,
      isEmpty,
    );

    model.updateSlotProperty(MappingSlotKey.title, 'Name');
    expect(model.hasUnsavedChanges, isTrue);
    model.resetDraft();
    expect(model.hasUnsavedChanges, isFalse);
    expect(
      model.config.bindingFor(MappingSlotKey.title).propertyName,
      isEmpty,
    );

    model.updateSlotProperty(MappingSlotKey.title, 'Name');
    await model.saveConfig();
    expect(model.hasUnsavedChanges, isFalse);

    model.updateSlotProperty(MappingSlotKey.title, '');
    expect(model.hasUnsavedChanges, isTrue);
    model.resetDraft();
    expect(
      model.config.bindingFor(MappingSlotKey.title).propertyName,
      'Name',
    );
    expect(model.hasUnsavedChanges, isFalse);
  });
}
