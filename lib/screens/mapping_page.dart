import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_services.dart';
import '../app/app_settings.dart';
import '../models/mapping_config.dart';
import '../services/notion_api.dart';
import '../services/settings_storage.dart';
import '../widgets/navigation_shell.dart';
import '../models/notion_models.dart';
import '../widgets/error_detail_dialog.dart';
import '../widgets/notion_mapping_panel.dart';

class MappingPage extends StatefulWidget {
  const MappingPage({super.key});

  @override
  State<MappingPage> createState() => _MappingPageState();
}

class _MappingPageState extends State<MappingPage>
    with SingleTickerProviderStateMixin {
  late final NotionApi _notionApi;
  final SettingsStorage _settingsStorage = SettingsStorage();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  List<NotionProperty> _notionProperties = [];
  MappingConfig _currentConfig = MappingConfig();
  NotionDailyRecommendationBindings _notionBindings =
      const NotionDailyRecommendationBindings();
  String _notionToken = '';
  String _notionDatabaseId = '';
  late final TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _notionApi = context.read<AppServices>().notionApi;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_currentTabIndex != _tabController.index) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final settings = context.read<AppSettings>();
      _notionToken = settings.notionToken;
      _notionDatabaseId = settings.notionDatabaseId;
      _currentConfig = await _settingsStorage.getMappingConfig();
      _notionBindings = await _settingsStorage.getDailyRecommendationBindings();

      if (_notionToken.isNotEmpty && _notionDatabaseId.isNotEmpty) {
        if (!forceRefresh) {
          _notionProperties = await _settingsStorage.getNotionProperties();
        }

        if (forceRefresh || _notionProperties.isEmpty) {
          _notionProperties = await _notionApi.getDatabaseProperties(
            token: _notionToken,
            databaseId: _notionDatabaseId,
          );
          await _settingsStorage.saveNotionProperties(_notionProperties);
        }
      } else {
        _notionProperties = [];
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('加载失败，请稍后重试'),
            action: SnackBarAction(
              label: '详情',
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
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveConfig() async {
    try {
      await _settingsStorage.saveMappingConfig(_currentConfig);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('保存失败，请稍后重试'),
            action: SnackBarAction(
              label: '详情',
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
    }
  }

  Future<void> _saveNotionBindings({bool showSuccess = true}) async {
    try {
      await _settingsStorage.saveDailyRecommendationBindings(_notionBindings);
      if (mounted && showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('保存失败，请稍后重试'),
            action: SnackBarAction(
              label: '详情',
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
    }
  }

  Future<void> _updateNotionBindings(
    NotionDailyRecommendationBindings bindings,
  ) async {
    setState(() => _notionBindings = bindings);
    await _saveNotionBindings(showSuccess: false);
  }

  @override
  Widget build(BuildContext context) {
    return NavigationShell(
      title: '映射配置',
      selectedRoute: '/mapping',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: '刷新属性',
          onPressed: _isLoading ? null : () => _loadData(forceRefresh: true),
        ),
        IconButton(
          icon: const Icon(Icons.save),
          tooltip: '保存配置',
          onPressed: _isLoading
              ? null
              : _currentTabIndex == 0
                  ? _saveConfig
                  : (_notionToken.isEmpty || _notionDatabaseId.isEmpty)
                      ? null
                      : () => _saveNotionBindings(showSuccess: true),
        ),
        const SizedBox(width: 8),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Bangumi 映射'),
                Tab(text: 'Notion 映射'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBangumiPanel(context),
                NotionMappingPanel(
                  isLoading: _isLoading,
                  isConfigured:
                      _notionToken.isNotEmpty && _notionDatabaseId.isNotEmpty,
                  properties: _notionProperties,
                  bindings: _notionBindings,
                  onBindingsChanged: _updateNotionBindings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBangumiPanel(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notionToken.isEmpty || _notionDatabaseId.isEmpty) {
      return const Center(child: Text('请先在设置页面配置 Notion Token 和 Database ID'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        const maxContentWidth = 980.0;
        final contentWidth =
            maxWidth > maxContentWidth ? maxContentWidth : maxWidth;

        final content = ConstrainedBox(
          constraints: BoxConstraints.tightFor(width: contentWidth),
          child: Column(
            children: [
              // Row 1: Column Headers (Bangumi Property / Notion Property)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: LayoutBuilder(
                  builder: (context, headerConstraints) {
                    final isNarrow = headerConstraints.maxWidth < 720;
                    return Row(
                      children: [
                        const SizedBox(width: 48), // 对齐带有复选框的字段
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Bangumi属性',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: Text(
                            'Notion属性',
                            textAlign:
                                isNarrow ? TextAlign.right : TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // Row 2: Divider
              const Divider(),
              // Row 3: Section Title "数据导入配置 (Data Import Config)"
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Text(
                  '数据导入配置 (Data Import Config)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              // Row 4: The list of mapping fields
              _buildMappingItem(
                '标题 (Name)',
                _currentConfig.title,
                _currentConfig.titleEnabled,
                (val) {
                  setState(() =>
                      _currentConfig = _currentConfig.copyWith(title: val));
                },
                (enabled) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(titleEnabled: enabled));
                },
              ),
              _buildMappingItem(
                '放送开始 (Date)',
                _currentConfig.airDate,
                _currentConfig.airDateEnabled,
                (val) {
                  setState(() =>
                      _currentConfig = _currentConfig.copyWith(airDate: val));
                },
                (enabled) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(airDateEnabled: enabled));
                },
              ),
              _buildMappingItem(
                '\u653e\u9001\u5f00\u59cb\uff08\u542b\u7ed3\u675f\uff09 (Date)',
                _currentConfig.airDateRange,
                _currentConfig.airDateRangeEnabled,
                (val) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(airDateRange: val));
                },
                (enabled) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(airDateRangeEnabled: enabled));
                },
              ),
              _buildMappingItem(
                '标签 (Multi-select)',
                _currentConfig.tags,
                _currentConfig.tagsEnabled,
                (val) {
                  setState(() =>
                      _currentConfig = _currentConfig.copyWith(tags: val));
                },
                (enabled) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(tagsEnabled: enabled));
                },
              ),
              _buildMappingItem(
                '封面 (Files & media)',
                _currentConfig.imageUrl,
                _currentConfig.imageUrlEnabled,
                (val) {
                  setState(() =>
                      _currentConfig = _currentConfig.copyWith(imageUrl: val));
                },
                (enabled) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(imageUrlEnabled: enabled));
                },
              ),
              _buildMappingItem(
                'Bangumi ID (Number)',
                _currentConfig.bangumiId,
                _currentConfig.bangumiIdEnabled,
                (val) {
                  setState(() =>
                      _currentConfig = _currentConfig.copyWith(bangumiId: val));
                },
                (enabled) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(bangumiIdEnabled: enabled));
                },
              ),
              _buildMappingItem(
                '评分 (Number)',
                _currentConfig.score,
                _currentConfig.scoreEnabled,
                (val) {
                  setState(() =>
                      _currentConfig = _currentConfig.copyWith(score: val));
                },
                (enabled) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(scoreEnabled: enabled));
                },
              ),
              _buildMappingItem(
                '\u603b\u96c6\u6570 (Number)',
                _currentConfig.totalEpisodes,
                _currentConfig.totalEpisodesEnabled,
                (val) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(totalEpisodes: val));
                },
                (enabled) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(totalEpisodesEnabled: enabled));
                },
              ),
              _buildMappingItem(
                '链接 (Url)',
                _currentConfig.link,
                _currentConfig.linkEnabled,
                (val) {
                  setState(() =>
                      _currentConfig = _currentConfig.copyWith(link: val));
                },
                (enabled) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(linkEnabled: enabled));
                },
              ),
              _buildMappingItem(
                '动画制作 (Rich Text)',
                _currentConfig.animationProduction,
                _currentConfig.animationProductionEnabled,
                (val) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(animationProduction: val));
                },
                (enabled) {
                  setState(() => _currentConfig = _currentConfig.copyWith(
                      animationProductionEnabled: enabled));
                },
              ),
              _buildMappingItem(
                '导演 (Rich Text)',
                _currentConfig.director,
                _currentConfig.directorEnabled,
                (val) {
                  setState(() =>
                      _currentConfig = _currentConfig.copyWith(director: val));
                },
                (enabled) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(directorEnabled: enabled));
                },
              ),
              _buildMappingItem(
                '脚本 (Rich Text)',
                _currentConfig.script,
                _currentConfig.scriptEnabled,
                (val) {
                  setState(() =>
                      _currentConfig = _currentConfig.copyWith(script: val));
                },
                (enabled) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(scriptEnabled: enabled));
                },
              ),
              _buildMappingItem(
                '分镜 (Rich Text)',
                _currentConfig.storyboard,
                _currentConfig.storyboardEnabled,
                (val) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(storyboard: val));
                },
                (enabled) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(storyboardEnabled: enabled));
                },
              ),
              _buildMappingItem(
                '简介/描述 (Summary)',
                _currentConfig.description,
                _currentConfig.descriptionEnabled,
                (val) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(description: val));
                },
                (enabled) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(descriptionEnabled: enabled));
                },
              ),
              const Divider(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Text(
                  '身份绑定配置 (Identity Binding Config)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              _buildMappingItem(
                'Bangumi ID 属性 (For Page Binding)',
                _currentConfig.idPropertyName,
                true,
                (val) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(idPropertyName: val));
                },
                null,
              ),
              _buildMappingItem(
                'Notion ID 属性 (For Page Binding)',
                _currentConfig.notionId,
                true,
                (val) {
                  setState(() =>
                      _currentConfig = _currentConfig.copyWith(notionId: val));
                },
                null,
              ),
              const Divider(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Text(
                  '放送页筛选/进度配置 (Calendar Config)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              _buildMappingItem(
                '追番状态字段 (Select/Status)',
                _currentConfig.watchingStatus,
                true,
                (val) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(watchingStatus: val));
                },
                null,
              ),
              _buildTextInputItem(
                '追番状态值 (例如：在看)',
                _currentConfig.watchingStatusValue,
                (val) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(watchingStatusValue: val));
                },
              ),
              _buildMappingItem(
                '已追集数字段 (Number)',
                _currentConfig.watchedEpisodes,
                true,
                (val) {
                  setState(() => _currentConfig =
                      _currentConfig.copyWith(watchedEpisodes: val));
                },
                null,
              ),
              const SizedBox(height: 24),
            ],
          ),
        );

        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: content,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMappingItem(
    String label,
    String currentValue,
    bool isEnabled,
    ValueChanged<String?> onChanged,
    ValueChanged<bool?>? onEnabledChanged,
  ) {
    final List<NotionProperty> items = [
      NotionProperty(name: '', type: ''),
      NotionProperty(name: '正文', type: 'page_content'),
      ..._notionProperties
    ];

    final bool exists = items.any((p) => p.name == currentValue);
    if (currentValue.isNotEmpty && !exists) {
      items.add(NotionProperty(name: currentValue, type: 'unknown'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;
          final labelWidget = Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isEnabled ? null : Theme.of(context).disabledColor,
            ),
          );
          final dropdown = DropdownButtonFormField<String>(
            initialValue: currentValue,
            items: items.map((prop) {
              return DropdownMenuItem(
                value: prop.name,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        prop.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (prop.type.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${prop.type})',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
            onChanged: isEnabled ? onChanged : null,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
          );

          final leading = onEnabledChanged != null
              ? Checkbox(
                  value: isEnabled,
                  onChanged: onEnabledChanged,
                )
              : const SizedBox(width: 48);

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    leading,
                    Expanded(child: labelWidget),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: dropdown,
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              leading,
              Expanded(
                flex: 4,
                child: labelWidget,
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: dropdown,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTextInputItem(
    String label,
    String currentValue,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;
          final labelWidget = Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          );
          final input = TextFormField(
            initialValue: currentValue,
            onChanged: onChanged,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: input,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 4,
                child: labelWidget,
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: input,
              ),
            ],
          );
        },
      ),
    );
  }
}
