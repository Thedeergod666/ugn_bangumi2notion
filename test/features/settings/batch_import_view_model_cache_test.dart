import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_utools/app/app_settings.dart';
import 'package:flutter_utools/core/database/settings_storage.dart';
import 'package:flutter_utools/core/network/bangumi_api.dart';
import 'package:flutter_utools/core/network/notion_api.dart';
import 'package:flutter_utools/features/settings/providers/batch_import_view_model.dart';
import 'package:flutter_utools/models/mapping_config.dart';

class _StaticBatchSettings extends AppSettings {
  _StaticBatchSettings({
    required this.token,
    required this.databaseId,
  });

  final String token;
  final String databaseId;

  @override
  String get notionToken => token;

  @override
  String get notionDatabaseId => databaseId;

  @override
  String get bangumiAccessToken => '';
}

const _dbA = '11111111111111111111111111111111';
const _dbB = '22222222222222222222222222222222';

http.Response _databaseSchemaResponse() {
  return http.Response(
    jsonEncode({
      'properties': {
        'Bangumi ID': {'type': 'number'},
        'Title': {'type': 'title'},
        'Notion ID': {'type': 'rich_text'},
        'type': {'type': 'select'},
      },
    }),
    200,
  );
}

http.Response _queryResponse({
  required String title,
  required String pageId,
}) {
  return http.Response(
    jsonEncode({
      'results': [
        {
          'id': pageId,
          'url': 'https://www.notion.so/$pageId',
          'properties': {
            'Title': {
              'type': 'title',
              'title': [
                {'plain_text': title}
              ],
            },
            'Notion ID': {
              'type': 'rich_text',
              'rich_text': [
                {'plain_text': 'note-$pageId'}
              ],
            },
            'type': {
              'type': 'select',
              'select': {'name': 'anime'},
            },
          },
        }
      ],
    }),
    200,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('does not reuse in-memory candidates across different database scopes',
      () async {
    final storage = SettingsStorage();
    await storage.saveMappingConfig(
      MappingConfig().copyWith(
        title: 'Title',
        bangumiId: 'Bangumi ID',
        notionId: 'Notion ID',
      ),
    );

    final firstNotionClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path.endsWith(_dbA)) {
        return _databaseSchemaResponse();
      }
      if (request.method == 'POST' &&
          request.url.path.endsWith('$_dbA/query')) {
        return _queryResponse(title: 'K-On!', pageId: 'page-a');
      }
      return http.Response('{"message":"not found"}', 404);
    });
    final firstBangumiClient = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path.endsWith('/v0/search/subjects')) {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 123,
                'name': 'K-On!',
                'name_cn': 'K-On!',
                'summary': '',
                'images': {'large': ''},
                'date': '2009-04-03',
                'score': 8.0,
                'rank': 0,
              }
            ],
          }),
          200,
        );
      }
      return http.Response('{"message":"not found"}', 404);
    });

    final firstViewModel = BatchImportViewModel(
      settings: _StaticBatchSettings(token: 'token', databaseId: _dbA),
      notionApi: NotionApi(client: firstNotionClient),
      bangumiApi: BangumiApi(client: firstBangumiClient),
      settingsStorage: storage,
    );

    await firstViewModel.load();
    expect(firstViewModel.errorMessage, isNull);
    expect(firstViewModel.candidates, hasLength(1));

    final blocker = Completer<void>();
    final secondNotionClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path.endsWith(_dbB)) {
        return _databaseSchemaResponse();
      }
      if (request.method == 'POST' &&
          request.url.path.endsWith('$_dbB/query')) {
        await blocker.future;
        return http.Response(jsonEncode({'results': const []}), 200);
      }
      return http.Response('{"message":"not found"}', 404);
    });

    final secondViewModel = BatchImportViewModel(
      settings: _StaticBatchSettings(token: 'token', databaseId: _dbB),
      notionApi: NotionApi(client: secondNotionClient),
      bangumiApi: BangumiApi(
        client: MockClient((_) async => http.Response('{"data":[]}', 200)),
      ),
      settingsStorage: storage,
    );

    final pendingLoad = secondViewModel.load();
    await Future<void>.delayed(Duration.zero);

    expect(secondViewModel.candidates, isEmpty);

    blocker.complete();
    await pendingLoad;
  });
}
