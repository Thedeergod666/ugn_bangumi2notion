import 'package:http/http.dart' as http;

import '../services/bangumi_api.dart';
import '../services/bangumi_oauth.dart';
import '../services/logging.dart';
import '../services/notion_api.dart';

class AppServices {
  AppServices({Logger? logger, http.Client? client})
      : _client = client ?? http.Client(),
        _logger = logger ?? Logger();

  final http.Client _client;
  final Logger _logger;

  late final BangumiApi bangumiApi = BangumiApi(
    client: _client,
    logger: _logger,
  );

  late final NotionApi notionApi = NotionApi(
    client: _client,
    logger: _logger,
  );

  late final BangumiOAuth bangumiOAuth = BangumiOAuth(
    client: _client,
  );

  Logger get logger => _logger;

  void dispose() {
    bangumiApi.dispose();
    notionApi.dispose();
    _client.close();
  }
}
