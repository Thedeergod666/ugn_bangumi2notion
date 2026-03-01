import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_utools/core/network/notion_api.dart';
import 'package:flutter_utools/core/utils/logging.dart';

void main() {
  const pageId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  NotionApi buildApi(
    List<Map<String, dynamic>> blocks, {
    Map<String, http.Response> extraResponses = const {},
  }) {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/blocks/$pageId/children') {
        expect(request.method, 'GET');
        return http.Response(
          jsonEncode({
            'results': blocks,
            'has_more': false,
            'next_cursor': null,
          }),
          200,
        );
      }

      final key = request.url.toString();
      final extra = extraResponses[key];
      if (extra != null) return extra;

      return http.Response('', 404);
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

  test('getPageContent resolves og:image from non-image url', () async {
    const pageLink = 'https://example.com/item/123';
    const ogImage = 'https://cdn.example.com/cover-from-ogp.png';
    final api = buildApi(
      [
        {
          'type': 'bookmark',
          'bookmark': {'url': pageLink},
        },
      ],
      extraResponses: {
        pageLink: http.Response(
          '''
          <html><head>
          <meta property="og:image" content="$ogImage" />
          </head><body>ok</body></html>
          ''',
          200,
          headers: const {'content-type': 'text/html; charset=utf-8'},
        ),
      },
    );

    final result = await api.getPageContent(token: 'token', pageId: pageId);

    expect(result.coverUrl, ogImage);
  });

  test('getPageContent resolves bangumi cover from subject link', () async {
    const subjectLink = 'https://bgm.tv/subject/147068';
    const bangumiCover =
        'https://lain.bgm.tv/r/400/pic/cover/l/a7/86/147068_60GJJ.jpg';
    final api = buildApi(
      [
        {
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [
              {
                'type': 'text',
                'plain_text': subjectLink,
                'href': subjectLink,
                'text': {'content': subjectLink},
              },
            ],
          },
        },
      ],
      extraResponses: {
        'https://api.bgm.tv/v0/subjects/147068': http.Response(
          jsonEncode({
            'id': 147068,
            'images': {'large': bangumiCover},
          }),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      },
    );

    final result = await api.getPageContent(token: 'token', pageId: pageId);

    expect(result.coverUrl, bangumiCover);
  });
}
