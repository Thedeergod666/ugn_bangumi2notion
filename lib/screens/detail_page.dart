import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/bangumi_models.dart';
import '../services/bangumi_api.dart';
import '../services/settings_storage.dart';
import '../services/notion_api.dart';
import '../models/mapping_config.dart';

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
  bool _loading = true;
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
      final token = data[SettingsKeys.bangumiAccessToken] ?? '';
      if (token.isEmpty) {
        throw Exception('未设置 Bangumi Access Token，请先在设置页授权');
      }
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = '加载失败，请稍后重试';
          _loading = false;
        });
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
        // 检查是否已存在
        existingPageId = await _notionApi.findPageByBangumiId(
          token: token,
          databaseId: databaseId,
          bangumiId: _detail!.id,
          propertyName: mappingConfig.bangumiId.isNotEmpty ? mappingConfig.bangumiId : 'Bangumi ID',
        );
      }
    } catch (_) {
      debugPrint('Pre-check failed');
    } finally {
      if (mounted) setState(() => _importing = false);
    }

    if (!mounted) return;

    final Map<String, String> fieldLabels = {
      'title': '标题',
      'airDate': '放送日期',
      'imageUrl': '封面链接',
      'bangumiId': 'Bangumi ID',
      'score': '评分',
      'link': 'Bangumi 链接',
      'animationProduction': '动画制作',
      'director': '导演',
      'script': '脚本',
      'storyboard': '分镜',
      'content': '简介 (正文)',
      'coverUrl': '正文图片 (URL)',
    };

    // 初始选择逻辑
    final Set<String> selectedFields = {};
    if (existingPageId == null) {
      // 新建模式默认全选
      selectedFields.addAll(fieldLabels.keys);
      selectedFields.remove('coverUrl'); // 默认不勾选正文图片
    } else {
      // 更新模式默认勾选
      selectedFields.addAll(['score', 'link', 'bangumiId']);
    }

    final List<String> topTags = _detail!.tags.take(10).toList();
    final Set<String> selectedTags = {};

    final TextEditingController bindIdController = TextEditingController();
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
                      // 区域 A: 目标定位
                      _buildDialogSectionTitle('目标定位'),
                      if (isUpdateMode)
                        ListTile(
                          leading: const Icon(Icons.check_circle, color: Colors.green),
                          title: const Text('已关联 Notion 页面'),
                          subtitle: Text('ID: ${existingPageId.substring(0, 8)}...'),
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
                          child: Column(
                            children: [
                              RadioListTile<bool>(
                                title: const Text('新建页面'),
                                value: false,
                                dense: true,
                              ),
                              RadioListTile<bool>(
                                title: const Text('绑定到已有页面'),
                                value: true,
                                dense: true,
                              ),
                            ],
                          ),
                        ),
                        if (isBindMode)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: TextField(
                              controller: bindIdController,
                              decoration: const InputDecoration(
                                labelText: 'Notion Page ID',
                                hintText: '输入 32 位 ID 或页面 URL',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                      ],
                      const Divider(),

                      // 区域 B: 字段更新选择
                      _buildDialogSectionTitle('字段更新选择'),
                      Wrap(
                        spacing: 8,
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

                      // 区域 C: 标签选择
                      _buildDialogSectionTitle('标签选择 (Top 10)'),
                      if (topTags.isEmpty)
                        const Text('暂无标签', style: TextStyle(fontSize: 12, color: Colors.grey))
                      else
                        Wrap(
                          spacing: 8,
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
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'fields': selectedFields,
                      'tags': selectedTags,
                      'pageId': isBindMode ? bindIdController.text.trim() : existingPageId,
                      'isBind': isBindMode,
                    });
                  },
                  child: Text(isUpdateMode ? '确认更新' : '确认导入'),
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
      final String? pageId = result['pageId'];

      // 如果是绑定模式，需要先验证 ID
      String? targetPageId = pageId;
      if (result['isBind'] == true && (targetPageId == null || targetPageId.isEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请输入有效的 Notion Page ID')),
          );
        }
        return;
      }

      if (result['isBind'] == true && targetPageId != null) {
        final normalized = _notionApi.normalizePageId(targetPageId);
        if (normalized == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notion Page ID 无效')),
            );
          }
          return;
        }
        targetPageId = normalized;
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

      // 构造临时的 detail 对象，包含选中的标签
      final detailToImport = BangumiSubjectDetail(
        id: _detail!.id,
        name: _detail!.name,
        nameCn: _detail!.nameCn,
        summary: _detail!.summary,
        imageUrl: _detail!.imageUrl,
        airDate: _detail!.airDate,
        epsCount: _detail!.epsCount,
        tags: selectedTags ?? [], // 使用选中的标签
        studio: _detail!.studio,
        director: _detail!.director,
        script: _detail!.script,
        storyboard: _detail!.storyboard,
        animationProduction: _detail!.animationProduction,
        score: _detail!.score,
        rank: _detail!.rank,
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
          const SnackBar(content: Text('操作成功！')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('操作失败，请稍后重试'),
            backgroundColor: Theme.of(context).colorScheme.error,
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
                Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _load, child: const Text('重试')),
              ],
            ),
          ),
        ),
      );
    }

    if (_detail == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('暂无详情数据')),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, _detail!),
          SliverToBoxAdapter(
            child: _buildContent(context, _detail!),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, BangumiSubjectDetail detail) {
    final title = detail.nameCn.isNotEmpty ? detail.nameCn : detail.name;
    return SliverAppBar(
      expandedHeight: 420,
      pinned: true,
      stretch: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
          StretchMode.fadeTitle,
        ],
        centerTitle: false,
        titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16, end: 16),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.black.withValues(alpha: 0.2),
          ),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              shadows: [Shadow(blurRadius: 8, color: Colors.black54, offset: Offset(0, 2))],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 背景模糊图
            if (detail.imageUrl.isNotEmpty)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Opacity(
                  opacity: 0.7,
                  child: Image.network(
                    detail.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            // 渐变遮罩
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.3, 0.7, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4),
                    Theme.of(context).colorScheme.surface,
                  ],
                ),
              ),
            ),
            // 居中封面图 - 比例更大
            Center(
              child: Hero(
                tag: 'subject-${detail.id}',
                child: Container(
                  width: 180,
                  height: 260,
                  margin: const EdgeInsets.only(bottom: 60),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 30,
                        spreadRadius: 2,
                        offset: const Offset(0, 12),
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
                      ? const Icon(Icons.image, size: 64, color: Colors.white)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, BangumiSubjectDetail detail) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 快速信息卡片组
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatCard(context, '评分', detail.score.toString(), Icons.star_rounded, Colors.orange),
                const SizedBox(width: 12),
                _buildStatCard(context, '集数', detail.epsCount.toString(), Icons.playlist_play_rounded, Colors.blue),
                const SizedBox(width: 12),
                _buildStatCard(context, '放送', detail.airDate.split('-').first, Icons.calendar_month_rounded, Colors.green),
                const SizedBox(width: 12),
                _buildStatCard(context, '排名', '#${detail.rank ?? "N/A"}', Icons.trending_up_rounded, Colors.purple),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 简介
          _buildSectionTitle(context, '简介'),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => _isSummaryExpanded = !_isSummaryExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.summary.isEmpty ? '暂无简介' : detail.summary,
                  maxLines: _isSummaryExpanded ? null : 4,
                  overflow: _isSummaryExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.7,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 0.3,
                      ),
                ),
                if (detail.summary.length > 100)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _isSummaryExpanded ? '收起' : '展开全部',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 制作团队
          _buildSectionTitle(context, '制作团队'),
          const SizedBox(height: 12),
          _buildInfoGrid(detail),
          const SizedBox(height: 28),

          // 标签
          _buildSectionTitle(context, '标签'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: detail.tags.isEmpty
                ? [const Chip(label: Text('暂无标签'))]
                : detail.tags
                    .map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ))
                    .toList(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.outline,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(BangumiSubjectDetail detail) {
    final items = [
      if (detail.animationProduction.isNotEmpty) MapEntry('动画制作', detail.animationProduction),
      if (detail.director.isNotEmpty) MapEntry('导演', detail.director),
      if (detail.script.isNotEmpty) MapEntry('脚本', detail.script),
      if (detail.storyboard.isNotEmpty) MapEntry('分镜', detail.storyboard),
      MapEntry('Bangumi ID', detail.id.toString()),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    item.key,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    item.value,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.4,
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

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () async {
                final url = Uri.parse('https://bgm.tv/subject/${widget.subjectId}');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              icon: const Icon(Icons.open_in_browser_rounded),
              label: const Text('BGM'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _importing ? null : _showImportConfirmDialog,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
                icon: _importing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _importing ? '正在导入...' : '导入到 Notion',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
