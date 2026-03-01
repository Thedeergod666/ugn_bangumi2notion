import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_utools/core/network/notion_api.dart';
import 'package:flutter_utools/core/utils/logging.dart';

void main() {
  const pageId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  NotionApi buildApi(List<Map<String, dynamic>> blocks) {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/v1/blocks/$pageId/children');
      return http.Response(
        jsonEncode({
          'results': blocks,
          'has_more': false,
          'next_cursor': null,
        }),
        200,
      );
    });

    return NotionApi(
      client: client,
      logger: Logger(level: LogLevel.off),
    );
  }

  test('getPageContent returns image block cover first', () async {
    final api = buildApi([
      {
        'type': 'image',
        'image': {
          'type': 'external',
          'external': {'url': 'https://cdn.example.com/cover-image'},
        },
      },
      {
        'type': 'paragraph',
        'paragraph': {
          'rich_text': [
            {
              'type': 'text',
              'plain_text': 'https://lain.bgm.tv/r/400/pic/cover/l/a7.jpg',
              'text': {
                'content': 'https://lain.bgm.tv/r/400/pic/cover/l/a7.jpg',
              },
            },
          ],
        },
      },
    ]);

    final result = await api.getPageContent(token: 'token', pageId: pageId);

    expect(result.coverUrl, 'https://cdn.example.com/cover-image');
  });

  test('getPageContent extracts image url from paragraph text', () async {
    const imageUrl =
        'https://lain.bgm.tv/r/400/pic/cover/l/a7/86/147068_60GJJ.jpg';
    final api = buildApi([
      {
        'type': 'paragraph',
        'paragraph': {
          'rich_text': [
            {
              'type': 'text',
              'plain_text': imageUrl,
              'href': imageUrl,
              'text': {'content': imageUrl},
            },
          ],
        },
      },
    ]);

    final result = await api.getPageContent(token: 'token', pageId: pageId);

    expect(result.coverUrl, imageUrl);
  });

  test('getPageContent ignores non-image urls in paragraph text', () async {
    const pageLink = 'https://bgm.tv/subject/147068';
    final api = buildApi([
      {
        'type': 'paragraph',
        'paragraph': {
          'rich_text': [
            {
              'type': 'text',
              'plain_text': pageLink,
              'href': pageLink,
              'text': {'content': pageLink},
            },
          ],
        },
      },
    ]);

    final result = await api.getPageContent(token: 'token', pageId: pageId);

    expect(result.coverUrl, isNull);
  });
}
