import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/bangumi_models.dart';
import '../services/bangumi_api.dart';
import '../services/settings_storage.dart';
import '../services/notion_api.dart';
import '../models/mapping_config.dart';
import '../widgets/error_detail_dialog.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({super.key, required this.subjectId});

  final int subjectId;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final _api = BangumiApi();
  final _notionApi = NotionApi();
  final _storage = SettingsStorage();

  BangumiSubjectDetail? _detail;
  List<BangumiComment> _comments = [];
  bool _loading = true;
  bool _commentsLoading = true;
  bool _importing = false;
  bool _isSummaryExpanded = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _storage.loadAll();
      final token = data[SettingsKeys.bangumiAccessToken];
      // 涓嶅啀寮哄埗瑕佹眰 Token锛屾敮鎸佹湭鐧诲綍鏌ョ湅
      final detail = await _api.fetchDetail(
        subjectId: widget.subjectId,
        accessToken: token,
      );
      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
        });
      }
      _loadComments(token);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '鍔犺浇澶辫触锛岃绋嶅悗閲嶈瘯: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadComments(String? token) async {
    try {
      final comments = await _api.fetchSubjectComments(
        subjectId: widget.subjectId,
        accessToken: token,
      );
      if (mounted) {
        setState(() {
          _comments = comments;
          _commentsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load comments: $e');
      if (mounted) {
        setState(() => _commentsLoading = false);
      }
    }
  }

  Future<void> _showImportConfirmDialog() async {
    if (_detail == null) return;

    setState(() => _importing = true);

    String? existingPageId;
    MappingConfig? mappingConfig;

    try {
      final settings = await _storage.loadAll();
      final token = settings[SettingsKeys.notionToken] ?? '';
      final databaseId = settings[SettingsKeys.notionDatabaseId] ?? '';
      mappingConfig = await _storage.getMappingConfig();

      if (token.isNotEmpty && databaseId.isNotEmpty) {
        // 妫€鏌ユ槸鍚﹀凡瀛樺湪
        existingPageId = await _notionApi.findPageByBangumiId(
          token: token,
          databaseId: databaseId,
          bangumiId: _detail!.id,
          propertyName: mappingConfig.bangumiId.isNotEmpty
              ? mappingConfig.bangumiId
              : 'Bangumi ID',
        );
      }
    } catch (_) {
      debugPrint('Pre-check failed');
    } finally {
      if (mounted) setState(() => _importing = false);
    }

    if (!mounted) return;

    String formatLabel(String bangumiLabel, String? notionLabel) {
      if (notionLabel == null || notionLabel.trim().isEmpty) return '';
      // 绉婚櫎 Bangumi 灞炴€т腑鎷彿鍙婂叾鍚庨潰鐨勫唴瀹?
      final cleanBangumi =
          bangumiLabel.split('(').first.split('（').first.trim();
      // Notion 灞炴€у悕宸茬粡鏄竻娲楄繃鐨勶紝鐩存帴鎷兼帴
      return '$cleanBangumi（$notionLabel）';
    }

    final Map<String, String> fieldLabels = {
      'title': formatLabel('标题', mappingConfig?.title),
      'airDate': formatLabel('放送开始', mappingConfig?.airDate),
      'tags': formatLabel('标签', mappingConfig?.tags),
      'imageUrl': formatLabel('封面', mappingConfig?.imageUrl),
      'bangumiId': formatLabel('Bangumi ID', mappingConfig?.bangumiId),
      'score': formatLabel('评分', mappingConfig?.score),
      'link': formatLabel('链接', mappingConfig?.link),
      'animationProduction':
          formatLabel('动画制作', mappingConfig?.animationProduction),
      'director': formatLabel('导演', mappingConfig?.director),
      'script': formatLabel('脚本', mappingConfig?.script),
      'storyboard': formatLabel('分镜', mappingConfig?.storyboard),
      'description': formatLabel('简介/描述', mappingConfig?.description),
    };

    // 绉婚櫎涓虹┖鐨勫瓧娈碉紙濡傛灉娌℃湁鍦?mappingConfig 涓畾涔夛紝璇存槑璇ュ瓧娈典笉鍙敤锛?
    if (mappingConfig != null) {
      fieldLabels.removeWhere((key, value) {
        return value.trim().isEmpty;
      });
    }

    // 鍒濆閫夋嫨閫昏緫
    final Set<String> selectedFields = {};
    if (mappingConfig != null) {
      if (mappingConfig.titleEnabled) selectedFields.add('title');
      if (mappingConfig.airDateEnabled) selectedFields.add('airDate');
      if (mappingConfig.tagsEnabled) selectedFields.add('tags');
      if (mappingConfig.imageUrlEnabled) selectedFields.add('imageUrl');
      if (mappingConfig.bangumiIdEnabled) selectedFields.add('bangumiId');
      if (mappingConfig.scoreEnabled) selectedFields.add('score');
      if (mappingConfig.linkEnabled) selectedFields.add('link');
      if (mappingConfig.animationProductionEnabled) {
        selectedFields.add('animationProduction');
      }
      if (mappingConfig.directorEnabled) selectedFields.add('director');
      if (mappingConfig.scriptEnabled) selectedFields.add('script');
      if (mappingConfig.storyboardEnabled) selectedFields.add('storyboard');
      if (mappingConfig.descriptionEnabled) selectedFields.add('description');
    } else {
      if (existingPageId == null) {
        // 鏂板缓妯″紡榛樿鍏ㄩ€?
        selectedFields.addAll(fieldLabels.keys);
      } else {
        // 鏇存柊妯″紡榛樿鍕鹃€?
        selectedFields.addAll(['score', 'link', 'bangumiId']);
      }
    }

    final List<String> topTags = _detail!.tags.take(30).toList();
    final Set<String> selectedTags = {};

    final TextEditingController bangumiIdController = TextEditingController();
    final TextEditingController notionIdController = TextEditingController();
    bool isBindMode = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isUpdateMode = existingPageId != null;

            return AlertDialog(
              title: Text(isUpdateMode ? '更新 Notion 页面' : '导入到 Notion'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 鍖哄煙 A: 鐩爣瀹氫綅
                      _buildDialogSectionTitle('鐩爣瀹氫綅'),
                      if (isUpdateMode)
                        ListTile(
                          leading:
                              const Icon(Icons.check_circle, color: Colors.green),
                          title: const Text('已关联 Notion 页面'),
                          subtitle:
                              Text('ID: ${existingPageId.substring(0, 8)}...'),
                          dense: true,
                        )
                      else ...[
                        RadioGroup<bool>(
                          groupValue: isBindMode,
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => isBindMode = val);
                            }
                          },
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RadioListTile<bool>(
                                title: Text('鏂板缓椤甸潰'),
                                value: false,
                                dense: true,
                              ),
                              RadioListTile<bool>(
                                title: Text('绑定到已有页面'),
                                value: true,
                                dense: true,
                              ),
                            ],
                          ),
                        ),
                        if (isBindMode)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: bangumiIdController,
                                    enabled: notionIdController.text.isEmpty,
                                    onChanged: (val) => setDialogState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: 'Bangumi ID',
                                      hintText: 'Bangumi ID',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: notionIdController,
                                    enabled: bangumiIdController.text.isEmpty,
                                    onChanged: (val) => setDialogState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: 'Notion ID',
                                      hintText: 'Notion ID',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      const Divider(),

                      // 鍖哄煙 B: 瀛楁鏇存柊閫夋嫨
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          _buildDialogSectionTitle('瀛楁鏇存柊閫夋嫨'),
                          const SizedBox(width: 8),
                          const Text(
                            'Bangumi灞炴€э紙Notion灞炴€э級',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: fieldLabels.entries.map((entry) {
                          return FilterChip(
                            label: Text(entry.value),
                            selected: selectedFields.contains(entry.key),
                            onSelected: (val) {
                              setDialogState(() {
                                if (val) {
                                  selectedFields.add(entry.key);
                                } else {
                                  selectedFields.remove(entry.key);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const Divider(),

                      // 鍖哄煙 C: 鏍囩閫夋嫨
                      _buildDialogSectionTitle('鏍囩閫夋嫨 (Top 30)'),
                      if (topTags.isEmpty)
                        const Text('鏆傛棤鏍囩',
                            style: TextStyle(fontSize: 12, color: Colors.grey))
                      else
                        AbsorbPointer(
                          absorbing: !selectedFields.contains('tags'),
                          child: Opacity(
                            opacity: selectedFields.contains('tags') ? 1.0 : 0.5,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: topTags.map((tag) {
                                return FilterChip(
                                  label: Text(tag),
                                  selected: selectedTags.contains(tag),
                                  onSelected: (val) {
                                    setDialogState(() {
                                      if (val) {
                                        selectedTags.add(tag);
                                      } else {
                                        selectedTags.remove(tag);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('鍙栨秷'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'fields': selectedFields,
                      'tags': selectedTags,
                      'bangumiId': bangumiIdController.text.trim(),
                      'notionId': notionIdController.text.trim(),
                      'existingPageId': existingPageId,
                      'isBind': isBindMode,
                    });
                  },
                  child: Text(isUpdateMode ? '纭鏇存柊' : '纭瀵煎叆'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && mappingConfig != null) {
      final Set<String> fields = result['fields'];
      final Set<String> tags = result['tags'];
      final String? bangumiIdStr = result['bangumiId'];
      final String? notionIdStr = result['notionId'];
      final String? existingPageIdResult = result['existingPageId'];

      // 濡傛灉鏄粦瀹氭ā寮忥紝闇€瑕佹牴鎹?ID 鏌ユ壘椤甸潰
      String? targetPageId = existingPageIdResult;
      if (result['isBind'] == true) {
        setState(() => _importing = true);
        try {
          final settings = await _storage.loadAll();
          final token = settings[SettingsKeys.notionToken] ?? '';
          final databaseId = settings[SettingsKeys.notionDatabaseId] ?? '';

          if (bangumiIdStr != null && bangumiIdStr.isNotEmpty) {
            targetPageId = await _notionApi.findPageByProperty(
              token: token,
              databaseId: databaseId,
              propertyName: mappingConfig.idPropertyName,
              value: int.tryParse(bangumiIdStr) ?? 0,
              type: 'number',
            );
          } else if (notionIdStr != null && notionIdStr.isNotEmpty) {
            targetPageId = await _notionApi.findPageByProperty(
              token: token,
              databaseId: databaseId,
              propertyName: mappingConfig.notionId,
              value: notionIdStr,
              type: 'rich_text',
            );
          }

          if (targetPageId == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('未找到对应的 Notion 页面，请检查输入')),
              );
            }
            setState(() => _importing = false);
            return;
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('鏌ユ壘椤甸潰澶辫触: $e')),
            );
          }
          setState(() => _importing = false);
          return;
        }
      }

      _importToNotion(
        enabledFields: fields,
        mappingConfig: mappingConfig,
        selectedTags: tags.toList(),
        targetPageId: targetPageId,
      );
    }
  }

  Widget _buildDialogSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Future<void> _importToNotion({
    required Set<String> enabledFields,
    required MappingConfig mappingConfig,
    List<String>? selectedTags,
    String? targetPageId,
  }) async {
    setState(() {
      _importing = true;
    });

    try {
      final settings = await _storage.loadAll();
      final token = settings[SettingsKeys.notionToken] ?? '';
      final databaseId = settings[SettingsKeys.notionDatabaseId] ?? '';

      if (token.isEmpty || databaseId.isEmpty) {
        throw Exception('请先在设置页配置 Notion Token 和 Database ID');
      }

      // 鏋勯€犱复鏃剁殑 detail 瀵硅薄锛屽寘鍚€変腑鐨勬爣绛?
      final detailToImport = BangumiSubjectDetail(
        id: _detail!.id,
        name: _detail!.name,
        nameCn: _detail!.nameCn,
        summary: _detail!.summary,
        imageUrl: _detail!.imageUrl,
        airDate: _detail!.airDate,
        epsCount: _detail!.epsCount,
        tags: selectedTags ?? [], // 浣跨敤閫変腑鐨勬爣绛?
        studio: _detail!.studio,
        director: _detail!.director,
        script: _detail!.script,
        storyboard: _detail!.storyboard,
        animationProduction: _detail!.animationProduction,
        score: _detail!.score,
        ratingTotal: _detail!.ratingTotal,
        ratingCount: _detail!.ratingCount,
        rank: _detail!.rank,
        infoboxMap: _detail!.infoboxMap,
      );

      await _notionApi.createAnimePage(
        token: token,
        databaseId: databaseId,
        detail: detailToImport,
        mappingConfig: mappingConfig,
        enabledFields: enabledFields,
        existingPageId: targetPageId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作成功')),
        );
      }
    } catch (e, stackTrace) {
      if (mounted) {
        // 鎻愬彇寮傚父娑堟伅锛岀Щ闄?"Exception: " 鍓嶇紑
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // 鏄剧ず鍏蜂綋鐨勯敊璇師鍥狅紝鑰屼笉鏄€氱敤鐨勨€滄搷浣滃け璐モ€?
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '鏌ョ湅璇︽儏',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => ErrorDetailDialog(
                    error: e,
                    stackTrace: stackTrace,
                  ),
                );
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 64, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _load, child: const Text('閲嶈瘯')),
              ],
            ),
          ),
        ),
      );
    }

    if (_detail == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('鏆傛棤璇︽儏鏁版嵁')),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              _buildSliverAppBar(context, _detail!),
            ];
          },
          body: TabBarView(
            children: [
              _buildOverviewTab(context, _detail!),
              _buildStaffTab(context, _detail!),
              _buildCommentsTab(context),
            ],
          ),
        ),
        floatingActionButton: _importing
            ? null
            : FloatingActionButton.extended(
                onPressed: _showImportConfirmDialog,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text('导入到 Notion',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary)),
              ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, BangumiSubjectDetail detail) {
    final title = detail.nameCn.isNotEmpty ? detail.nameCn : detail.name;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ratingColor = colorScheme.tertiary;
    return SliverAppBar(
      expandedHeight: 380,
      pinned: true,
      stretch: true,
      backgroundColor: colorScheme.surface,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      actions: const [],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Backdrop with blur
            if (detail.imageUrl.isNotEmpty)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Opacity(
                  opacity: 0.5,
                  child: Image.network(detail.imageUrl, fit: BoxFit.cover),
                ),
              ),
            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surface.withValues(alpha: 0.2),
                    colorScheme.surface,
                  ],
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 100, 16, 60),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Poster
                  Hero(
                    tag: 'subject-${detail.id}',
                    child: Container(
                      width: 120,
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                        image: detail.imageUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(detail.imageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: detail.imageUrl.isEmpty
                          ? const Icon(Icons.image,
                              size: 48, color: Colors.white24)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Middle: Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleLarge?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          detail.airDate,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              detail.score.toStringAsFixed(1),
                              style: TextStyle(
                                color: ratingColor,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: List.generate(5, (index) {
                                    final rating = detail.score / 2;
                                    if (index < rating.floor()) {
                                      return Icon(
                                        Icons.star,
                                        color: ratingColor,
                                        size: 12,
                                      );
                                    } else if (index < rating) {
                                      return Icon(
                                        Icons.star_half,
                                        color: ratingColor,
                                        size: 12,
                                      );
                                    } else {
                                      return Icon(
                                        Icons.star_border,
                                        color: ratingColor,
                                        size: 12,
                                      );
                                    }
                                  }),
                                ),
                                Text(
                                  'Rank #${detail.rank ?? "N/A"}',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Action Button: View on Bangumi
                        InkWell(
                          onTap: () async {
                            final url = Uri.parse(
                                'https://bgm.tv/subject/${widget.subjectId}');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colorScheme.primary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.open_in_new,
                                  color: colorScheme.primary,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Bangumi',
                                  style: TextStyle(
                                      color: colorScheme.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right: Rating Distribution
                  Expanded(
                    child: RatingChart(
                        ratingCount: detail.ratingCount,
                        total: detail.ratingTotal),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottom: const TabBar(
        tabs: [
          Tab(text: '姒傝堪'),
          Tab(text: '鍒朵綔'),
          Tab(text: '鍚愭Ы'),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, BangumiSubjectDetail detail) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, '简介'),
          const SizedBox(height: 12),
          InkWell(
            onTap: () =>
                setState(() => _isSummaryExpanded = !_isSummaryExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.summary.isEmpty ? '暂无简介' : detail.summary,
                  maxLines: _isSummaryExpanded ? null : 6,
                  overflow: _isSummaryExpanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    height: 1.7,
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
                if (detail.summary.length > 100)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _isSummaryExpanded ? '鏀惰捣' : '灞曞紑鍏ㄩ儴',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle(context, '鍒朵綔浜哄憳'),
          const SizedBox(height: 12),
          _buildSimplifiedInfoGrid(detail),
          const SizedBox(height: 32),
          _buildSectionTitle(context, '鏍囩'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: detail.tags.isEmpty
                ? [const Chip(label: Text('鏆傛棤鏍囩'))]
                : detail.tags
                    .map((tag) => InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: tag));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('已复制标签: $tag'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
          ),
          const SizedBox(height: 100), // Bottom padding for FAB
        ],
      ),
    );
  }

  Widget _buildStaffTab(BuildContext context, BangumiSubjectDetail detail) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, '全制作人员'),
          const SizedBox(height: 12),
          _buildInfoGrid(detail),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildCommentsTab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (_commentsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_comments.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          final data = await _storage.loadAll();
          final token = data[SettingsKeys.bangumiAccessToken] ?? '';
          await _loadComments(token);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 300,
            child: Center(
              child: Text('鏆傛棤鍚愭Ы', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final data = await _storage.loadAll();
        final token = data[SettingsKeys.bangumiAccessToken] ?? '';
        await _loadComments(token);
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _comments.length,
        separatorBuilder: (context, index) =>
            Divider(height: 32, color: colorScheme.outlineVariant),
        itemBuilder: (context, index) {
          final comment = _comments[index];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: comment.user.avatar.isNotEmpty
                    ? NetworkImage(comment.user.avatar)
                    : null,
                child: comment.user.avatar.isEmpty
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          comment.user.nickname,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _formatTime(comment.updatedAt),
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (comment.rate > 0)
                      Row(
                        children: List.generate(5, (i) {
                          return Icon(
                            i < (comment.rate / 2).ceil()
                                ? Icons.star
                                : Icons.star_border,
                            color: colorScheme.tertiary,
                            size: 10,
                          );
                        }),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      comment.comment,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatTime(String time) {
    try {
      final dt = DateTime.parse(time);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.year}-${dt.month}-${dt.day}';
    } catch (_) {
      return time;
    }
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(BangumiSubjectDetail detail) {
    // 杩囨护鎺変竴浜涗笉闇€瑕佸湪鍒朵綔浜哄憳鍒楄〃涓噸澶嶆樉绀虹殑瀛楁锛堝鏋滄湁鐨勮瘽锛?
    final skipKeys = {
      '中文名',
      '别名',
      '话数',
      '放送开始',
      '放送星期',
      '官方网站',
      '播放电视台',
      '其他电视台',
      'Copyright'
    };

    final items = detail.infoboxMap.entries
        .where((e) => !skipKeys.contains(e.key))
        .map((e) => MapEntry(e.key, e.value))
        .toList();

    // 纭繚 Bangumi ID 鎬绘槸鏄剧ず鍦ㄦ渶鍚?
    items.add(MapEntry('Bangumi ID', detail.id.toString()));

    return _buildInfoListContainer(items);
  }

  Widget _buildSimplifiedInfoGrid(BangumiSubjectDetail detail) {
    final items = <MapEntry<String, String>>[];

    // Bangumi ID should be at the top
    items.add(MapEntry('Bangumi ID', detail.id.toString()));

    if (detail.animationProduction.isNotEmpty) {
      items.add(MapEntry('鍔ㄧ敾鍒朵綔', detail.animationProduction));
    }
    if (detail.director.isNotEmpty) {
      items.add(MapEntry('瀵兼紨', detail.director));
    }
    if (detail.script.isNotEmpty) {
      items.add(MapEntry('鑴氭湰', detail.script));
    }
    if (detail.storyboard.isNotEmpty) {
      items.add(MapEntry('鍒嗛暅', detail.storyboard));
    }

    return _buildInfoListContainer(items);
  }

  Widget _buildInfoListContainer(List<MapEntry<String, String>> items) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: colorScheme.outlineVariant),
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: item.value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已复制${item.key}: ${item.value}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 80,
                    child: Text(
                      item.key,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    item.value,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                      color: colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class RatingChart extends StatelessWidget {
  const RatingChart({
    super.key,
    required this.ratingCount,
    required this.total,
  });

  final Map<String, int> ratingCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    // Bangumi ratings are 1-10
    final counts = List.generate(10, (index) {
      final key = (index + 1).toString();
      return ratingCount[key] ?? 0;
    });

    final maxCount = counts.reduce((a, b) => a > b ? a : b);

    return Container(
      height: 180,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(10, (index) {
          // 1 star (left) to 10 stars (right)
          final count = counts[index];
          final ratio = maxCount == 0 ? 0.0 : count / maxCount;

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: ratio.clamp(0.05, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.tertiary.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${index + 1}',
                    style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
