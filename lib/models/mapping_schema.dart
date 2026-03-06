enum MappingModuleId {
  importWrite,
  recommendationRead,
  watchRead,
  watchWrite,
  batchImport,
  identityBinding,
  searchRead,
}

enum MappingSlotKey {
  title,
  cover,
  bangumiId,
  score,
  bangumiScore,
  bangumiRank,
  yougnScore,
  tags,
  type,
  airDate,
  airDateRange,
  totalEpisodes,
  watchedEpisodes,
  followDate,
  lastWatchedAt,
  watchingStatus,
  watchingStatusValue,
  watchingStatusValueWatched,
  link,
  animationProduction,
  director,
  script,
  storyboard,
  shortReview,
  longReview,
  description,
  subjectId,
  bangumiUpdatedAt,
  notionId,
  globalIdProperty,
  idProperty,
}

class MappingModuleMeta {
  final MappingModuleId id;
  final String label;
  final String description;
  final List<MappingSlotKey> criticalSlots;

  const MappingModuleMeta({
    required this.id,
    required this.label,
    required this.description,
    required this.criticalSlots,
  });
}

class MappingSlotMeta {
  final MappingSlotKey key;
  final String label;
  final List<String> allowedNotionTypes;
  final List<MappingModuleId> modules;
  final bool writeSlot;
  final String _sourceTypeTag;
  final String _helpText;

  const MappingSlotMeta({
    required this.key,
    required this.label,
    required this.allowedNotionTypes,
    required this.modules,
    required this.writeSlot,
    String sourceTypeTag = '',
    String helpText = '',
  })  : _sourceTypeTag = sourceTypeTag,
        _helpText = helpText;

  String get sourceTypeTag {
    if (_sourceTypeTag.isNotEmpty) return _sourceTypeTag;
    if (key == MappingSlotKey.watchingStatusValue ||
        key == MappingSlotKey.watchingStatusValueWatched) {
      return 'param';
    }
    if (allowedNotionTypes.contains('title')) return 'title';
    if (allowedNotionTypes.contains('date')) return 'date';
    if (allowedNotionTypes.contains('multi_select')) return 'multi-select';
    if (allowedNotionTypes.contains('url')) return 'url';
    if (allowedNotionTypes.contains('number')) return 'number';
    if (allowedNotionTypes.contains('files')) return 'image';
    return 'text';
  }

  String get helpText {
    if (_helpText.isNotEmpty) return _helpText;
    final moduleLabels = modules
        .map((module) => mappingModuleMetaById[module]?.label ?? module.name)
        .toList();
    final usage = moduleLabels.isEmpty ? '' : '（用于${moduleLabels.join(' / ')}）';
    return '$label 的映射配置$usage';
  }
}

class ModuleValidationIssue {
  final MappingModuleId module;
  final MappingSlotKey? slot;
  final String message;
  final bool blocking;

  const ModuleValidationIssue({
    required this.module,
    required this.slot,
    required this.message,
    this.blocking = true,
  });
}

const String mappingParamWatchingStatusValue = 'watchingStatusValue';
const String mappingParamWatchingStatusValueWatched =
    'watchingStatusValueWatched';

const List<MappingModuleMeta> mappingModuleMetas = [
  MappingModuleMeta(
    id: MappingModuleId.importWrite,
    label: '导入写入',
    description: 'Bangumi -> Notion 导入与更新写入字段',
    criticalSlots: [MappingSlotKey.title, MappingSlotKey.bangumiId],
  ),
  MappingModuleMeta(
    id: MappingModuleId.recommendationRead,
    label: '推荐读取',
    description: '每日推荐与评分分布读取字段',
    criticalSlots: [MappingSlotKey.title, MappingSlotKey.yougnScore],
  ),
  MappingModuleMeta(
    id: MappingModuleId.watchRead,
    label: '最近观看读取',
    description: '放送页/推荐页最近观看模块读取字段',
    criticalSlots: [
      MappingSlotKey.bangumiId,
      MappingSlotKey.title,
      MappingSlotKey.watchingStatus,
      MappingSlotKey.watchingStatusValue,
    ],
  ),
  MappingModuleMeta(
    id: MappingModuleId.watchWrite,
    label: '追番进度写入',
    description: '追番 +1 时写入 Notion 进度字段',
    criticalSlots: [MappingSlotKey.watchedEpisodes],
  ),
  MappingModuleMeta(
    id: MappingModuleId.batchImport,
    label: '批量导入',
    description: '批量绑定 Bangumi ID 与候选匹配',
    criticalSlots: [MappingSlotKey.title, MappingSlotKey.bangumiId],
  ),
  MappingModuleMeta(
    id: MappingModuleId.identityBinding,
    label: '身份绑定',
    description: '通过唯一标识查找和更新 Notion 页面',
    criticalSlots: [
      MappingSlotKey.idProperty,
      MappingSlotKey.notionId,
      MappingSlotKey.globalIdProperty,
    ],
  ),
  MappingModuleMeta(
    id: MappingModuleId.searchRead,
    label: 'Notion 搜索',
    description: 'Notion 搜索页按标题字段检索',
    criticalSlots: [MappingSlotKey.title],
  ),
];

const List<MappingSlotMeta> mappingSlotMetas = [
  MappingSlotMeta(
    key: MappingSlotKey.title,
    label: '标题',
    allowedNotionTypes: ['title', 'rich_text'],
    modules: [
      MappingModuleId.importWrite,
      MappingModuleId.recommendationRead,
      MappingModuleId.watchRead,
      MappingModuleId.batchImport,
      MappingModuleId.searchRead,
    ],
    writeSlot: true,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.cover,
    label: '封面',
    allowedNotionTypes: ['files', 'url', 'rich_text'],
    modules: [
      MappingModuleId.importWrite,
      MappingModuleId.recommendationRead,
      MappingModuleId.watchRead,
    ],
    writeSlot: true,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.bangumiId,
    label: 'Bangumi ID',
    allowedNotionTypes: ['number', 'rich_text', 'formula', 'rollup'],
    modules: [
      MappingModuleId.importWrite,
      MappingModuleId.recommendationRead,
      MappingModuleId.watchRead,
      MappingModuleId.batchImport,
    ],
    writeSlot: true,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.score,
    label: '评分',
    allowedNotionTypes: ['number', 'rich_text', 'formula', 'rollup'],
    modules: [MappingModuleId.importWrite],
    writeSlot: true,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.bangumiScore,
    label: 'Bangumi 评分',
    allowedNotionTypes: ['number', 'rich_text', 'formula', 'rollup'],
    modules: [MappingModuleId.recommendationRead],
    writeSlot: false,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.bangumiRank,
    label: 'Bangumi 排名',
    allowedNotionTypes: ['number', 'rich_text', 'formula', 'rollup'],
    modules: [MappingModuleId.recommendationRead],
    writeSlot: false,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.yougnScore,
    label: 'Yougn 评分',
    allowedNotionTypes: ['number', 'rich_text', 'formula', 'rollup'],
    modules: [
      MappingModuleId.recommendationRead,
      MappingModuleId.watchRead,
    ],
    writeSlot: false,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.tags,
    label: '标签',
    allowedNotionTypes: ['multi_select', 'select', 'rich_text', 'relation'],
    modules: [
      MappingModuleId.importWrite,
      MappingModuleId.recommendationRead,
      MappingModuleId.watchRead,
    ],
    writeSlot: true,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.type,
    label: '类型',
    allowedNotionTypes: ['select', 'multi_select', 'rich_text', 'title'],
    modules: [
      MappingModuleId.recommendationRead,
      MappingModuleId.batchImport,
    ],
    writeSlot: false,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.airDate,
    label: '放送开始',
    allowedNotionTypes: ['date', 'rich_text', 'formula', 'rollup'],
    modules: [
      MappingModuleId.importWrite,
      MappingModuleId.recommendationRead,
    ],
    writeSlot: true,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.airDateRange,
    label: '放送区间',
    allowedNotionTypes: ['date', 'rich_text', 'formula', 'rollup'],
    modules: [
      MappingModuleId.importWrite,
      MappingModuleId.recommendationRead,
    ],
    writeSlot: true,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.totalEpisodes,
    label: '总集数',
    allowedNotionTypes: ['number', 'rich_text', 'formula', 'rollup'],
    modules: [MappingModuleId.importWrite, MappingModuleId.watchRead],
    writeSlot: true,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.watchedEpisodes,
    label: '已追集数',
    allowedNotionTypes: ['number', 'rich_text', 'formula', 'rollup'],
    modules: [MappingModuleId.watchRead, MappingModuleId.watchWrite],
    writeSlot: false,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.followDate,
    label: '追番日期',
    allowedNotionTypes: ['date', 'rich_text', 'formula', 'rollup'],
    modules: [MappingModuleId.recommendationRead, MappingModuleId.watchRead],
    writeSlot: false,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.lastWatchedAt,
    label: '最近观看时间',
    allowedNotionTypes: ['date', 'rich_text', 'formula', 'rollup'],
    modules: [MappingModuleId.watchRead, MappingModuleId.watchWrite],
    writeSlot: false,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.watchingStatus,
    label: '追番状态',
    allowedNotionTypes: ['status', 'select', 'multi_select', 'rich_text'],
    modules: [MappingModuleId.watchRead],
    writeSlot: false,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.watchingStatusValue,
    label: '在看状态值',
    allowedNotionTypes: ['rich_text'],
    modules: [MappingModuleId.watchRead],
    writeSlot: false,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.watchingStatusValueWatched,
    label: '已看状态值',
    allowedNotionTypes: ['rich_text'],
    modules: [MappingModuleId.watchRead],
    writeSlot: false,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.link,
    label: 'Bangumi 链接',
    allowedNotionTypes: ['url', 'rich_text'],
    modules: [MappingModuleId.importWrite],
    writeSlot: true,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.animationProduction,
    label: '动画制作',
    allowedNotionTypes: ['rich_text', 'select', 'multi_select', 'title'],
    modules: [MappingModuleId.importWrite, MappingModuleId.recommendationRead],
    writeSlot: true,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.director,
    label: '导演',
    allowedNotionTypes: ['rich_text', 'select', 'multi_select', 'title'],
    modules: [MappingModuleId.importWrite, MappingModuleId.recommendationRead],
    writeSlot: true,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.script,
    label: '脚本',
    allowedNotionTypes: ['rich_text', 'select', 'multi_select', 'title'],
    modules: [MappingModuleId.importWrite, MappingModuleId.recommendationRead],
    writeSlot: true,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.storyboard,
    label: '分镜',
    allowedNotionTypes: ['rich_text', 'select', 'multi_select', 'title'],
    modules: [MappingModuleId.importWrite, MappingModuleId.recommendationRead],
    writeSlot: true,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.shortReview,
    label: '短评',
    allowedNotionTypes: ['rich_text', 'title'],
    modules: [MappingModuleId.recommendationRead],
    writeSlot: false,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.longReview,
    label: '长评',
    allowedNotionTypes: ['rich_text', 'title'],
    modules: [MappingModuleId.recommendationRead],
    writeSlot: false,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.description,
    label: '简介/正文',
    allowedNotionTypes: ['rich_text', 'title'],
    modules: [MappingModuleId.importWrite],
    writeSlot: true,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.subjectId,
    label: 'Subject ID',
    allowedNotionTypes: ['number', 'rich_text', 'formula', 'rollup'],
    modules: [MappingModuleId.recommendationRead],
    writeSlot: false,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.bangumiUpdatedAt,
    label: 'Bangumi 更新日期',
    allowedNotionTypes: ['date', 'rich_text'],
    modules: [MappingModuleId.importWrite],
    writeSlot: true,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.notionId,
    label: 'Notion ID 字段',
    allowedNotionTypes: ['title', 'rich_text', 'url'],
    modules: [MappingModuleId.identityBinding, MappingModuleId.batchImport],
    writeSlot: false,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.globalIdProperty,
    label: '全局唯一 ID 字段',
    allowedNotionTypes: ['title', 'rich_text', 'url'],
    modules: [MappingModuleId.identityBinding],
    writeSlot: false,
  ),
  MappingSlotMeta(
    key: MappingSlotKey.idProperty,
    label: 'Bangumi ID 查询字段',
    allowedNotionTypes: ['number', 'rich_text', 'formula', 'rollup'],
    modules: [MappingModuleId.identityBinding],
    writeSlot: false,
  ),
];

final Map<MappingModuleId, MappingModuleMeta> mappingModuleMetaById = {
  for (final meta in mappingModuleMetas) meta.id: meta,
};

final Map<MappingSlotKey, MappingSlotMeta> mappingSlotMetaByKey = {
  for (final meta in mappingSlotMetas) meta.key: meta,
};

MappingModuleId mappingModuleIdFromName(String name) {
  return MappingModuleId.values.firstWhere(
    (value) => value.name == name,
    orElse: () => MappingModuleId.importWrite,
  );
}

MappingSlotKey mappingSlotKeyFromName(String name) {
  return MappingSlotKey.values.firstWhere(
    (value) => value.name == name,
    orElse: () => MappingSlotKey.title,
  );
}
