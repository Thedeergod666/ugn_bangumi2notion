import 'mapping_schema.dart';

const int mappingSchemaVersion = 2;

class FieldBinding {
  final String propertyName;
  final String? readOverride;
  final String? writeOverride;
  final bool writeEnabledDefault;

  const FieldBinding({
    this.propertyName = '',
    this.readOverride,
    this.writeOverride,
    this.writeEnabledDefault = true,
  });

  bool get isEmpty {
    return propertyName.trim().isEmpty &&
        (readOverride ?? '').trim().isEmpty &&
        (writeOverride ?? '').trim().isEmpty;
  }

  FieldBinding copyWith({
    String? propertyName,
    String? readOverride,
    String? writeOverride,
    bool? writeEnabledDefault,
    bool clearReadOverride = false,
    bool clearWriteOverride = false,
  }) {
    return FieldBinding(
      propertyName: propertyName ?? this.propertyName,
      readOverride:
          clearReadOverride ? null : (readOverride ?? this.readOverride),
      writeOverride:
          clearWriteOverride ? null : (writeOverride ?? this.writeOverride),
      writeEnabledDefault: writeEnabledDefault ?? this.writeEnabledDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'propertyName': propertyName,
      'readOverride': readOverride,
      'writeOverride': writeOverride,
      'writeEnabledDefault': writeEnabledDefault,
    };
  }

  factory FieldBinding.fromJson(Map<String, dynamic> json) {
    String? normalizeOptional(dynamic value) {
      if (value == null) return null;
      final text = value.toString();
      return text.isEmpty ? null : text;
    }

    return FieldBinding(
      propertyName: json['propertyName']?.toString() ?? '',
      readOverride: normalizeOptional(json['readOverride']),
      writeOverride: normalizeOptional(json['writeOverride']),
      writeEnabledDefault: json['writeEnabledDefault'] is bool
          ? json['writeEnabledDefault'] as bool
          : true,
    );
  }
}

class ModuleFieldOverride {
  final String? propertyName;
  final String? readOverride;
  final String? writeOverride;

  const ModuleFieldOverride({
    this.propertyName,
    this.readOverride,
    this.writeOverride,
  });

  bool get isEmpty {
    return (propertyName ?? '').trim().isEmpty &&
        (readOverride ?? '').trim().isEmpty &&
        (writeOverride ?? '').trim().isEmpty;
  }

  ModuleFieldOverride copyWith({
    String? propertyName,
    String? readOverride,
    String? writeOverride,
    bool clearPropertyName = false,
    bool clearReadOverride = false,
    bool clearWriteOverride = false,
  }) {
    return ModuleFieldOverride(
      propertyName:
          clearPropertyName ? null : (propertyName ?? this.propertyName),
      readOverride:
          clearReadOverride ? null : (readOverride ?? this.readOverride),
      writeOverride:
          clearWriteOverride ? null : (writeOverride ?? this.writeOverride),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'propertyName': propertyName,
      'readOverride': readOverride,
      'writeOverride': writeOverride,
    };
  }

  factory ModuleFieldOverride.fromJson(Map<String, dynamic> json) {
    String? normalizeOptional(dynamic value) {
      if (value == null) return null;
      final text = value.toString();
      return text.isEmpty ? null : text;
    }

    return ModuleFieldOverride(
      propertyName: normalizeOptional(json['propertyName']),
      readOverride: normalizeOptional(json['readOverride']),
      writeOverride: normalizeOptional(json['writeOverride']),
    );
  }
}

class MappingMigrationResult {
  final MappingConfig config;
  final bool migrated;
  final List<String> notes;

  const MappingMigrationResult({
    required this.config,
    required this.migrated,
    required this.notes,
  });
}

class MappingConfig {
  final int schemaVersion;
  final Map<MappingSlotKey, FieldBinding> commonBindings;
  final Map<MappingModuleId, Map<MappingSlotKey, ModuleFieldOverride>>
      moduleOverrides;
  final Map<String, String> moduleParams;

  MappingConfig({
    int? schemaVersion,
    Map<MappingSlotKey, FieldBinding>? commonBindings,
    Map<MappingModuleId, Map<MappingSlotKey, ModuleFieldOverride>>?
        moduleOverrides,
    Map<String, String>? moduleParams,
  })  : schemaVersion = schemaVersion ?? mappingSchemaVersion,
        commonBindings = _normalizeCommonBindings(commonBindings),
        moduleOverrides = _normalizeModuleOverrides(moduleOverrides),
        moduleParams = _normalizeModuleParams(moduleParams);

  static Map<MappingSlotKey, FieldBinding> _defaultCommonBindings() {
    return {
      for (final slot in MappingSlotKey.values)
        slot: FieldBinding(
          writeEnabledDefault:
              mappingSlotMetaByKey[slot]?.writeSlot ?? false,
        ),
    };
  }

  static Map<MappingSlotKey, FieldBinding> _normalizeCommonBindings(
    Map<MappingSlotKey, FieldBinding>? value,
  ) {
    final result = _defaultCommonBindings();
    if (value != null) {
      for (final entry in value.entries) {
        result[entry.key] = entry.value;
      }
    }
    return Map.unmodifiable(result);
  }

  static Map<MappingModuleId, Map<MappingSlotKey, ModuleFieldOverride>>
      _normalizeModuleOverrides(
    Map<MappingModuleId, Map<MappingSlotKey, ModuleFieldOverride>>? value,
  ) {
    final result = <MappingModuleId, Map<MappingSlotKey, ModuleFieldOverride>>{};
    if (value != null) {
      for (final moduleEntry in value.entries) {
        final slots = <MappingSlotKey, ModuleFieldOverride>{};
        for (final slotEntry in moduleEntry.value.entries) {
          if (!slotEntry.value.isEmpty) {
            slots[slotEntry.key] = slotEntry.value;
          }
        }
        if (slots.isNotEmpty) {
          result[moduleEntry.key] = Map.unmodifiable(slots);
        }
      }
    }
    return Map.unmodifiable(result);
  }

  static Map<String, String> _normalizeModuleParams(
    Map<String, String>? value,
  ) {
    final result = <String, String>{
      mappingParamWatchingStatusValue: '',
      mappingParamWatchingStatusValueWatched: '已看',
    };
    if (value != null) {
      for (final entry in value.entries) {
        result[entry.key] = entry.value;
      }
    }
    return Map.unmodifiable(result);
  }

  FieldBinding bindingFor(MappingSlotKey slot) {
    return commonBindings[slot] ?? const FieldBinding();
  }

  ModuleFieldOverride? overrideFor(
    MappingModuleId module,
    MappingSlotKey slot,
  ) {
    return moduleOverrides[module]?[slot];
  }

  bool writeEnabledFor(MappingSlotKey slot) {
    return bindingFor(slot).writeEnabledDefault;
  }

  String moduleParam(String key, {String defaultValue = ''}) {
    final value = moduleParams[key];
    if (value == null || value.trim().isEmpty) return defaultValue;
    return value.trim();
  }

  String resolve(
    MappingSlotKey slot,
    MappingModuleId module, {
    required bool forWrite,
  }) {
    if (slot == MappingSlotKey.watchingStatusValue) {
      return moduleParam(mappingParamWatchingStatusValue, defaultValue: '');
    }
    if (slot == MappingSlotKey.watchingStatusValueWatched) {
      return moduleParam(
        mappingParamWatchingStatusValueWatched,
        defaultValue: '已看',
      );
    }

    final common = bindingFor(slot);
    final override = overrideFor(module, slot);
    if (forWrite) {
      return _firstNonEmpty([
        override?.writeOverride,
        override?.propertyName,
        common.writeOverride,
        common.propertyName,
      ]);
    }
    return _firstNonEmpty([
      override?.readOverride,
      override?.propertyName,
      common.readOverride,
      common.propertyName,
    ]);
  }

  String _firstNonEmpty(List<String?> values) {
    for (final raw in values) {
      final value = (raw ?? '').trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  MappingConfig updateBinding(MappingSlotKey slot, FieldBinding binding) {
    final nextBindings = Map<MappingSlotKey, FieldBinding>.from(commonBindings);
    nextBindings[slot] = binding;
    return MappingConfig(
      schemaVersion: schemaVersion,
      commonBindings: nextBindings,
      moduleOverrides: moduleOverrides,
      moduleParams: moduleParams,
    );
  }

  MappingConfig updateModuleOverride(
    MappingModuleId module,
    MappingSlotKey slot,
    ModuleFieldOverride override,
  ) {
    final next = <MappingModuleId, Map<MappingSlotKey, ModuleFieldOverride>>{
      for (final entry in moduleOverrides.entries)
        entry.key: Map<MappingSlotKey, ModuleFieldOverride>.from(entry.value),
    };
    final slots = next.putIfAbsent(
      module,
      () => <MappingSlotKey, ModuleFieldOverride>{},
    );
    if (override.isEmpty) {
      slots.remove(slot);
    } else {
      slots[slot] = override;
    }
    if (slots.isEmpty) {
      next.remove(module);
    }

    return MappingConfig(
      schemaVersion: schemaVersion,
      commonBindings: commonBindings,
      moduleOverrides: next,
      moduleParams: moduleParams,
    );
  }

  MappingConfig updateModuleParam(String key, String value) {
    final nextParams = Map<String, String>.from(moduleParams);
    nextParams[key] = value;
    return MappingConfig(
      schemaVersion: schemaVersion,
      commonBindings: commonBindings,
      moduleOverrides: moduleOverrides,
      moduleParams: nextParams,
    );
  }

  MappingConfig copyWith({
    int? schemaVersion,
    Map<MappingSlotKey, FieldBinding>? commonBindings,
    Map<MappingModuleId, Map<MappingSlotKey, ModuleFieldOverride>>?
        moduleOverrides,
    Map<String, String>? moduleParams,
    String? title,
    bool? titleEnabled,
    String? airDate,
    bool? airDateEnabled,
    String? airDateRange,
    bool? airDateRangeEnabled,
    String? tags,
    bool? tagsEnabled,
    String? imageUrl,
    bool? imageUrlEnabled,
    String? bangumiId,
    bool? bangumiIdEnabled,
    String? score,
    bool? scoreEnabled,
    String? totalEpisodes,
    bool? totalEpisodesEnabled,
    String? link,
    bool? linkEnabled,
    String? animationProduction,
    bool? animationProductionEnabled,
    String? director,
    bool? directorEnabled,
    String? script,
    bool? scriptEnabled,
    String? storyboard,
    bool? storyboardEnabled,
    String? description,
    bool? descriptionEnabled,
    String? idPropertyName,
    String? notionId,
    String? watchingStatus,
    String? watchingStatusValue,
    String? watchingStatusValueWatched,
    String? watchedEpisodes,
    String? followDate,
    String? lastWatchedAt,
    String? bangumiUpdatedAt,
    String? globalIdPropertyName,
    NotionDailyRecommendationBindings? dailyRecommendationBindings,
    NotionWatchBindings? watchBindings,
  }) {
    var next = MappingConfig(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      commonBindings: commonBindings ?? this.commonBindings,
      moduleOverrides: moduleOverrides ?? this.moduleOverrides,
      moduleParams: moduleParams ?? this.moduleParams,
    );

    void setSlot(MappingSlotKey slot, String? value) {
      if (value == null) return;
      next = next.updateBinding(
        slot,
        next.bindingFor(slot).copyWith(propertyName: value),
      );
    }

    void setEnabled(MappingSlotKey slot, bool? value) {
      if (value == null) return;
      next = next.updateBinding(
        slot,
        next.bindingFor(slot).copyWith(writeEnabledDefault: value),
      );
    }

    setSlot(MappingSlotKey.title, title);
    setEnabled(MappingSlotKey.title, titleEnabled);
    setSlot(MappingSlotKey.airDate, airDate);
    setEnabled(MappingSlotKey.airDate, airDateEnabled);
    setSlot(MappingSlotKey.airDateRange, airDateRange);
    setEnabled(MappingSlotKey.airDateRange, airDateRangeEnabled);
    setSlot(MappingSlotKey.tags, tags);
    setEnabled(MappingSlotKey.tags, tagsEnabled);
    setSlot(MappingSlotKey.cover, imageUrl);
    setEnabled(MappingSlotKey.cover, imageUrlEnabled);
    setSlot(MappingSlotKey.bangumiId, bangumiId);
    setEnabled(MappingSlotKey.bangumiId, bangumiIdEnabled);
    setSlot(MappingSlotKey.score, score);
    setEnabled(MappingSlotKey.score, scoreEnabled);
    setSlot(MappingSlotKey.totalEpisodes, totalEpisodes);
    setEnabled(MappingSlotKey.totalEpisodes, totalEpisodesEnabled);
    setSlot(MappingSlotKey.link, link);
    setEnabled(MappingSlotKey.link, linkEnabled);
    setSlot(MappingSlotKey.animationProduction, animationProduction);
    setEnabled(MappingSlotKey.animationProduction, animationProductionEnabled);
    setSlot(MappingSlotKey.director, director);
    setEnabled(MappingSlotKey.director, directorEnabled);
    setSlot(MappingSlotKey.script, script);
    setEnabled(MappingSlotKey.script, scriptEnabled);
    setSlot(MappingSlotKey.storyboard, storyboard);
    setEnabled(MappingSlotKey.storyboard, storyboardEnabled);
    setSlot(MappingSlotKey.description, description);
    setEnabled(MappingSlotKey.description, descriptionEnabled);
    setSlot(MappingSlotKey.idProperty, idPropertyName);
    setSlot(MappingSlotKey.notionId, notionId);
    setSlot(MappingSlotKey.watchingStatus, watchingStatus);
    setSlot(MappingSlotKey.watchedEpisodes, watchedEpisodes);
    setSlot(MappingSlotKey.followDate, followDate);
    setSlot(MappingSlotKey.lastWatchedAt, lastWatchedAt);
    setSlot(MappingSlotKey.bangumiUpdatedAt, bangumiUpdatedAt);
    setSlot(MappingSlotKey.globalIdProperty, globalIdPropertyName);

    if (watchingStatusValue != null) {
      next = next.updateModuleParam(
        mappingParamWatchingStatusValue,
        watchingStatusValue,
      );
    }
    if (watchingStatusValueWatched != null) {
      next = next.updateModuleParam(
        mappingParamWatchingStatusValueWatched,
        watchingStatusValueWatched,
      );
    }

    if (dailyRecommendationBindings != null) {
      setSlot(MappingSlotKey.title, dailyRecommendationBindings.title);
      setSlot(MappingSlotKey.yougnScore, dailyRecommendationBindings.yougnScore);
      setSlot(
        MappingSlotKey.bangumiScore,
        dailyRecommendationBindings.bangumiScore,
      );
      setSlot(MappingSlotKey.bangumiRank, dailyRecommendationBindings.bangumiRank);
      setSlot(MappingSlotKey.followDate, dailyRecommendationBindings.followDate);
      setSlot(MappingSlotKey.airDate, dailyRecommendationBindings.airDate);
      setSlot(
        MappingSlotKey.airDateRange,
        dailyRecommendationBindings.airDateRange,
      );
      setSlot(MappingSlotKey.tags, dailyRecommendationBindings.tags);
      setSlot(MappingSlotKey.type, dailyRecommendationBindings.type);
      setSlot(MappingSlotKey.shortReview, dailyRecommendationBindings.shortReview);
      setSlot(MappingSlotKey.longReview, dailyRecommendationBindings.longReview);
      setSlot(MappingSlotKey.cover, dailyRecommendationBindings.cover);
      setSlot(
        MappingSlotKey.animationProduction,
        dailyRecommendationBindings.animationProduction,
      );
      setSlot(MappingSlotKey.director, dailyRecommendationBindings.director);
      setSlot(MappingSlotKey.script, dailyRecommendationBindings.script);
      setSlot(MappingSlotKey.storyboard, dailyRecommendationBindings.storyboard);
      setSlot(MappingSlotKey.bangumiId, dailyRecommendationBindings.bangumiId);
      setSlot(MappingSlotKey.subjectId, dailyRecommendationBindings.subjectId);
    }

    if (watchBindings != null) {
      setSlot(MappingSlotKey.title, watchBindings.title);
      setSlot(MappingSlotKey.cover, watchBindings.cover);
      setSlot(MappingSlotKey.bangumiId, watchBindings.bangumiId);
      setSlot(MappingSlotKey.watchedEpisodes, watchBindings.watchedEpisodes);
      setSlot(MappingSlotKey.totalEpisodes, watchBindings.totalEpisodes);
      setSlot(MappingSlotKey.watchingStatus, watchBindings.watchingStatus);
      setSlot(MappingSlotKey.followDate, watchBindings.followDate);
      setSlot(MappingSlotKey.lastWatchedAt, watchBindings.lastWatchedAt);
      setSlot(MappingSlotKey.tags, watchBindings.tags);
      setSlot(MappingSlotKey.yougnScore, watchBindings.yougnScore);
    }

    return next;
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'commonBindings': {
        for (final entry in commonBindings.entries)
          entry.key.name: entry.value.toJson(),
      },
      'moduleOverrides': {
        for (final entry in moduleOverrides.entries)
          entry.key.name: {
            for (final slotEntry in entry.value.entries)
              slotEntry.key.name: slotEntry.value.toJson(),
          },
      },
      'moduleParams': moduleParams,
    };
  }

  factory MappingConfig.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version == mappingSchemaVersion) {
      final rawBindings = json['commonBindings'] as Map<String, dynamic>? ?? {};
      final bindings = <MappingSlotKey, FieldBinding>{};
      for (final entry in rawBindings.entries) {
        final slot = mappingSlotKeyFromName(entry.key);
        final raw = entry.value;
        if (raw is Map<String, dynamic>) {
          bindings[slot] = FieldBinding.fromJson(raw);
        } else if (raw is Map) {
          bindings[slot] =
              FieldBinding.fromJson(raw.cast<String, dynamic>());
        }
      }

      final rawOverrides =
          json['moduleOverrides'] as Map<String, dynamic>? ?? {};
      final overrides =
          <MappingModuleId, Map<MappingSlotKey, ModuleFieldOverride>>{};
      for (final moduleEntry in rawOverrides.entries) {
        final module = mappingModuleIdFromName(moduleEntry.key);
        final moduleValue = moduleEntry.value;
        if (moduleValue is! Map) continue;
        final slotMap = <MappingSlotKey, ModuleFieldOverride>{};
        for (final slotEntry in moduleValue.entries) {
          final slot = mappingSlotKeyFromName(slotEntry.key.toString());
          final raw = slotEntry.value;
          if (raw is Map<String, dynamic>) {
            final parsed = ModuleFieldOverride.fromJson(raw);
            if (!parsed.isEmpty) slotMap[slot] = parsed;
          } else if (raw is Map) {
            final parsed = ModuleFieldOverride.fromJson(
              raw.cast<String, dynamic>(),
            );
            if (!parsed.isEmpty) slotMap[slot] = parsed;
          }
        }
        if (slotMap.isNotEmpty) overrides[module] = slotMap;
      }

      final rawParams = json['moduleParams'] as Map<String, dynamic>? ?? {};
      final params = <String, String>{};
      for (final entry in rawParams.entries) {
        params[entry.key] = entry.value?.toString() ?? '';
      }

      return MappingConfig(
        schemaVersion: mappingSchemaVersion,
        commonBindings: bindings,
        moduleOverrides: overrides,
        moduleParams: params,
      );
    }

    return MappingConfig.migrateFromLegacy(
      v1Config: json,
      legacyDailyBindings: const {},
    ).config;
  }

  static MappingMigrationResult migrateFromLegacy({
    Map<String, dynamic>? v1Config,
    Map<String, dynamic>? legacyDailyBindings,
  }) {
    final sourceConfig = v1Config ?? const <String, dynamic>{};
    final watchBindings =
        _legacyMap(sourceConfig['watchBindings']) ?? const <String, dynamic>{};
    final dailyInConfig = _legacyMap(sourceConfig['dailyRecommendationBindings']);
    final dailyFromLegacy = legacyDailyBindings ?? const <String, dynamic>{};
    final dailyBindings = (dailyInConfig != null && dailyInConfig.isNotEmpty)
        ? dailyInConfig
        : dailyFromLegacy;

    String pick(List<String?> values) {
      for (final raw in values) {
        final text = (raw ?? '').trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    String fromWatch(String key) => watchBindings[key]?.toString() ?? '';
    String fromDaily(String key) => dailyBindings[key]?.toString() ?? '';
    String fromConfig(String key) => sourceConfig[key]?.toString() ?? '';

    bool boolFromConfig(String key, bool fallback) {
      final raw = sourceConfig[key];
      if (raw is bool) return raw;
      return fallback;
    }

    var next = MappingConfig();
    int migrationCount = 0;

    void setSlot(
      MappingSlotKey slot,
      String value, {
      bool? writeEnabledDefault,
    }) {
      final normalized = value.trim();
      final binding = next.bindingFor(slot).copyWith(
            propertyName: normalized,
            writeEnabledDefault:
                writeEnabledDefault ?? next.bindingFor(slot).writeEnabledDefault,
          );
      next = next.updateBinding(slot, binding);
      migrationCount += 1;
    }

    void setWriteEnabled(MappingSlotKey slot, bool enabled) {
      next = next.updateBinding(
        slot,
        next.bindingFor(slot).copyWith(writeEnabledDefault: enabled),
      );
    }

    // Priority: watchBindings > dailyBindings > old config
    setSlot(
      MappingSlotKey.title,
      pick([fromWatch('title'), fromDaily('title'), fromConfig('title')]),
      writeEnabledDefault: boolFromConfig('titleEnabled', true),
    );
    setSlot(
      MappingSlotKey.cover,
      pick([fromWatch('cover'), fromDaily('cover'), fromConfig('imageUrl')]),
      writeEnabledDefault: boolFromConfig('imageUrlEnabled', true),
    );
    setSlot(
      MappingSlotKey.bangumiId,
      pick([
        fromWatch('bangumiId'),
        fromDaily('bangumiId'),
        fromConfig('bangumiId'),
        fromConfig('idPropertyName'),
      ]),
      writeEnabledDefault: boolFromConfig('bangumiIdEnabled', true),
    );
    setSlot(
      MappingSlotKey.score,
      fromConfig('score'),
      writeEnabledDefault: boolFromConfig('scoreEnabled', true),
    );
    setSlot(MappingSlotKey.bangumiScore, fromDaily('bangumiScore'));
    setSlot(MappingSlotKey.bangumiRank, fromDaily('bangumiRank'));
    setSlot(
      MappingSlotKey.yougnScore,
      pick([fromWatch('yougnScore'), fromDaily('yougnScore')]),
    );
    setSlot(
      MappingSlotKey.tags,
      pick([fromWatch('tags'), fromDaily('tags'), fromConfig('tags')]),
      writeEnabledDefault: boolFromConfig('tagsEnabled', true),
    );
    setSlot(MappingSlotKey.type, fromDaily('type'));
    setSlot(
      MappingSlotKey.airDate,
      pick([fromDaily('airDate'), fromConfig('airDate')]),
      writeEnabledDefault: boolFromConfig('airDateEnabled', true),
    );
    setSlot(
      MappingSlotKey.airDateRange,
      pick([fromDaily('airDateRange'), fromConfig('airDateRange')]),
      writeEnabledDefault: boolFromConfig('airDateRangeEnabled', true),
    );
    setSlot(
      MappingSlotKey.totalEpisodes,
      pick([fromWatch('totalEpisodes'), fromConfig('totalEpisodes')]),
      writeEnabledDefault: boolFromConfig('totalEpisodesEnabled', true),
    );
    setSlot(
      MappingSlotKey.watchedEpisodes,
      pick([fromWatch('watchedEpisodes'), fromConfig('watchedEpisodes')]),
    );
    setSlot(
      MappingSlotKey.followDate,
      pick([
        fromWatch('followDate'),
        fromDaily('followDate'),
        fromConfig('followDate')
      ]),
    );
    setSlot(
      MappingSlotKey.lastWatchedAt,
      pick([fromWatch('lastWatchedAt'), fromConfig('lastWatchedAt')]),
    );
    setSlot(
      MappingSlotKey.watchingStatus,
      pick([fromWatch('watchingStatus'), fromConfig('watchingStatus')]),
    );
    setSlot(
      MappingSlotKey.link,
      fromConfig('link'),
      writeEnabledDefault: boolFromConfig('linkEnabled', true),
    );
    setSlot(
      MappingSlotKey.animationProduction,
      pick([fromDaily('animationProduction'), fromConfig('animationProduction')]),
      writeEnabledDefault: boolFromConfig('animationProductionEnabled', true),
    );
    setSlot(
      MappingSlotKey.director,
      pick([fromDaily('director'), fromConfig('director')]),
      writeEnabledDefault: boolFromConfig('directorEnabled', true),
    );
    setSlot(
      MappingSlotKey.script,
      pick([fromDaily('script'), fromConfig('script')]),
      writeEnabledDefault: boolFromConfig('scriptEnabled', true),
    );
    setSlot(
      MappingSlotKey.storyboard,
      pick([fromDaily('storyboard'), fromConfig('storyboard')]),
      writeEnabledDefault: boolFromConfig('storyboardEnabled', true),
    );
    setSlot(MappingSlotKey.shortReview, fromDaily('shortReview'));
    setSlot(MappingSlotKey.longReview, fromDaily('longReview'));
    setSlot(
      MappingSlotKey.description,
      fromConfig('description'),
      writeEnabledDefault: boolFromConfig('descriptionEnabled', true),
    );
    setSlot(MappingSlotKey.subjectId, fromDaily('subjectId'));
    setSlot(
      MappingSlotKey.bangumiUpdatedAt,
      fromConfig('bangumiUpdatedAt'),
      writeEnabledDefault: true,
    );
    setSlot(MappingSlotKey.notionId, fromConfig('notionId'));
    setSlot(MappingSlotKey.globalIdProperty, fromConfig('globalIdPropertyName'));
    setSlot(MappingSlotKey.idProperty, fromConfig('idPropertyName'));

    setWriteEnabled(
      MappingSlotKey.title,
      boolFromConfig('titleEnabled', true),
    );
    setWriteEnabled(
      MappingSlotKey.cover,
      boolFromConfig('imageUrlEnabled', true),
    );
    setWriteEnabled(
      MappingSlotKey.bangumiId,
      boolFromConfig('bangumiIdEnabled', true),
    );
    setWriteEnabled(
      MappingSlotKey.score,
      boolFromConfig('scoreEnabled', true),
    );
    setWriteEnabled(
      MappingSlotKey.tags,
      boolFromConfig('tagsEnabled', true),
    );
    setWriteEnabled(
      MappingSlotKey.airDate,
      boolFromConfig('airDateEnabled', true),
    );
    setWriteEnabled(
      MappingSlotKey.airDateRange,
      boolFromConfig('airDateRangeEnabled', true),
    );
    setWriteEnabled(
      MappingSlotKey.totalEpisodes,
      boolFromConfig('totalEpisodesEnabled', true),
    );
    setWriteEnabled(
      MappingSlotKey.link,
      boolFromConfig('linkEnabled', true),
    );
    setWriteEnabled(
      MappingSlotKey.animationProduction,
      boolFromConfig('animationProductionEnabled', true),
    );
    setWriteEnabled(
      MappingSlotKey.director,
      boolFromConfig('directorEnabled', true),
    );
    setWriteEnabled(
      MappingSlotKey.script,
      boolFromConfig('scriptEnabled', true),
    );
    setWriteEnabled(
      MappingSlotKey.storyboard,
      boolFromConfig('storyboardEnabled', true),
    );
    setWriteEnabled(
      MappingSlotKey.description,
      boolFromConfig('descriptionEnabled', true),
    );

    next = next
        .updateModuleParam(
          mappingParamWatchingStatusValue,
          sourceConfig['watchingStatusValue']?.toString() ?? '',
        )
        .updateModuleParam(
          mappingParamWatchingStatusValueWatched,
          sourceConfig['watchingStatusValueWatched']?.toString() ?? '已看',
        );

    final notes = <String>[
      'Migrated legacy mapping config to schema v2.',
      'Conflict priority: watchBindings > dailyBindings > old config.',
      'Updated slots: $migrationCount',
    ];

    return MappingMigrationResult(
      config: next,
      migrated: true,
      notes: notes,
    );
  }

  static Map<String, dynamic>? _legacyMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  NotionDailyRecommendationBindings toDailyRecommendationBindings() {
    return NotionDailyRecommendationBindings(
      title: resolve(
        MappingSlotKey.title,
        MappingModuleId.recommendationRead,
        forWrite: false,
      ),
      yougnScore: resolve(
        MappingSlotKey.yougnScore,
        MappingModuleId.recommendationRead,
        forWrite: false,
      ),
      bangumiScore: resolve(
        MappingSlotKey.bangumiScore,
        MappingModuleId.recommendationRead,
        forWrite: false,
      ),
      bangumiRank: resolve(
        MappingSlotKey.bangumiRank,
        MappingModuleId.recommendationRead,
        forWrite: false,
      ),
      followDate: resolve(
        MappingSlotKey.followDate,
        MappingModuleId.recommendationRead,
        forWrite: false,
      ),
      airDate: resolve(
        MappingSlotKey.airDate,
        MappingModuleId.recommendationRead,
        forWrite: false,
      ),
      airDateRange: resolve(
        MappingSlotKey.airDateRange,
        MappingModuleId.recommendationRead,
        forWrite: false,
      ),
      tags: resolve(
        MappingSlotKey.tags,
        MappingModuleId.recommendationRead,
        forWrite: false,
      ),
      type: resolve(
        MappingSlotKey.type,
        MappingModuleId.recommendationRead,
        forWrite: false,
      ),
      shortReview: resolve(
        MappingSlotKey.shortReview,
        MappingModuleId.recommendationRead,
        forWrite: false,
      ),
      longReview: resolve(
        MappingSlotKey.longReview,
        MappingModuleId.recommendationRead,
        forWrite: false,
      ),
      cover: resolve(
        MappingSlotKey.cover,
        MappingModuleId.recommendationRead,
        forWrite: false,
      ),
      animationProduction: resolve(
        MappingSlotKey.animationProduction,
        MappingModuleId.recommendationRead,
        forWrite: false,
      ),
      director: resolve(
        MappingSlotKey.director,
        MappingModuleId.recommendationRead,
        forWrite: false,
      ),
      script: resolve(
        MappingSlotKey.script,
        MappingModuleId.recommendationRead,
        forWrite: false,
      ),
      storyboard: resolve(
        MappingSlotKey.storyboard,
        MappingModuleId.recommendationRead,
        forWrite: false,
      ),
      bangumiId: resolve(
        MappingSlotKey.bangumiId,
        MappingModuleId.recommendationRead,
        forWrite: false,
      ),
      subjectId: resolve(
        MappingSlotKey.subjectId,
        MappingModuleId.recommendationRead,
        forWrite: false,
      ),
    );
  }

  NotionWatchBindings toWatchBindings() {
    return NotionWatchBindings(
      title: resolve(
        MappingSlotKey.title,
        MappingModuleId.watchRead,
        forWrite: false,
      ),
      cover: resolve(
        MappingSlotKey.cover,
        MappingModuleId.watchRead,
        forWrite: false,
      ),
      bangumiId: resolve(
        MappingSlotKey.bangumiId,
        MappingModuleId.watchRead,
        forWrite: false,
      ),
      watchedEpisodes: resolve(
        MappingSlotKey.watchedEpisodes,
        MappingModuleId.watchRead,
        forWrite: false,
      ),
      totalEpisodes: resolve(
        MappingSlotKey.totalEpisodes,
        MappingModuleId.watchRead,
        forWrite: false,
      ),
      watchingStatus: resolve(
        MappingSlotKey.watchingStatus,
        MappingModuleId.watchRead,
        forWrite: false,
      ),
      followDate: resolve(
        MappingSlotKey.followDate,
        MappingModuleId.watchRead,
        forWrite: false,
      ),
      lastWatchedAt: resolve(
        MappingSlotKey.lastWatchedAt,
        MappingModuleId.watchRead,
        forWrite: false,
      ),
      tags: resolve(
        MappingSlotKey.tags,
        MappingModuleId.watchRead,
        forWrite: false,
      ),
      yougnScore: resolve(
        MappingSlotKey.yougnScore,
        MappingModuleId.watchRead,
        forWrite: false,
      ),
    );
  }

  // Compatibility getters used by existing code paths.
  String get title => bindingFor(MappingSlotKey.title).propertyName;
  bool get titleEnabled => bindingFor(MappingSlotKey.title).writeEnabledDefault;
  String get airDate => bindingFor(MappingSlotKey.airDate).propertyName;
  bool get airDateEnabled =>
      bindingFor(MappingSlotKey.airDate).writeEnabledDefault;
  String get airDateRange => bindingFor(MappingSlotKey.airDateRange).propertyName;
  bool get airDateRangeEnabled =>
      bindingFor(MappingSlotKey.airDateRange).writeEnabledDefault;
  String get tags => bindingFor(MappingSlotKey.tags).propertyName;
  bool get tagsEnabled => bindingFor(MappingSlotKey.tags).writeEnabledDefault;
  String get imageUrl => bindingFor(MappingSlotKey.cover).propertyName;
  bool get imageUrlEnabled => bindingFor(MappingSlotKey.cover).writeEnabledDefault;
  String get bangumiId => bindingFor(MappingSlotKey.bangumiId).propertyName;
  bool get bangumiIdEnabled =>
      bindingFor(MappingSlotKey.bangumiId).writeEnabledDefault;
  String get score => bindingFor(MappingSlotKey.score).propertyName;
  bool get scoreEnabled => bindingFor(MappingSlotKey.score).writeEnabledDefault;
  String get totalEpisodes =>
      bindingFor(MappingSlotKey.totalEpisodes).propertyName;
  bool get totalEpisodesEnabled =>
      bindingFor(MappingSlotKey.totalEpisodes).writeEnabledDefault;
  String get link => bindingFor(MappingSlotKey.link).propertyName;
  bool get linkEnabled => bindingFor(MappingSlotKey.link).writeEnabledDefault;
  String get animationProduction =>
      bindingFor(MappingSlotKey.animationProduction).propertyName;
  bool get animationProductionEnabled =>
      bindingFor(MappingSlotKey.animationProduction).writeEnabledDefault;
  String get director => bindingFor(MappingSlotKey.director).propertyName;
  bool get directorEnabled =>
      bindingFor(MappingSlotKey.director).writeEnabledDefault;
  String get script => bindingFor(MappingSlotKey.script).propertyName;
  bool get scriptEnabled => bindingFor(MappingSlotKey.script).writeEnabledDefault;
  String get storyboard => bindingFor(MappingSlotKey.storyboard).propertyName;
  bool get storyboardEnabled =>
      bindingFor(MappingSlotKey.storyboard).writeEnabledDefault;
  String get description => bindingFor(MappingSlotKey.description).propertyName;
  bool get descriptionEnabled =>
      bindingFor(MappingSlotKey.description).writeEnabledDefault;
  String get idPropertyName => bindingFor(MappingSlotKey.idProperty).propertyName;
  String get notionId => bindingFor(MappingSlotKey.notionId).propertyName;
  String get watchingStatus =>
      bindingFor(MappingSlotKey.watchingStatus).propertyName;
  String get watchingStatusValue =>
      moduleParam(mappingParamWatchingStatusValue, defaultValue: '');
  String get watchingStatusValueWatched => moduleParam(
        mappingParamWatchingStatusValueWatched,
        defaultValue: '已看',
      );
  String get watchedEpisodes =>
      bindingFor(MappingSlotKey.watchedEpisodes).propertyName;
  String get followDate => bindingFor(MappingSlotKey.followDate).propertyName;
  String get lastWatchedAt =>
      bindingFor(MappingSlotKey.lastWatchedAt).propertyName;
  String get bangumiUpdatedAt =>
      bindingFor(MappingSlotKey.bangumiUpdatedAt).propertyName;
  String get globalIdPropertyName =>
      bindingFor(MappingSlotKey.globalIdProperty).propertyName;
  NotionDailyRecommendationBindings get dailyRecommendationBindings =>
      toDailyRecommendationBindings();
  NotionWatchBindings get watchBindings => toWatchBindings();
}

class NotionWatchBindings {
  final String title;
  final String cover;
  final String bangumiId;
  final String watchedEpisodes;
  final String totalEpisodes;
  final String watchingStatus;
  final String followDate;
  final String lastWatchedAt;
  final String tags;
  final String yougnScore;

  const NotionWatchBindings({
    this.title = '',
    this.cover = '',
    this.bangumiId = '',
    this.watchedEpisodes = '',
    this.totalEpisodes = '',
    this.watchingStatus = '',
    this.followDate = '',
    this.lastWatchedAt = '',
    this.tags = '',
    this.yougnScore = '',
  });

  bool get isEmpty {
    return title.isEmpty &&
        cover.isEmpty &&
        bangumiId.isEmpty &&
        watchedEpisodes.isEmpty &&
        totalEpisodes.isEmpty &&
        watchingStatus.isEmpty &&
        followDate.isEmpty &&
        lastWatchedAt.isEmpty &&
        tags.isEmpty &&
        yougnScore.isEmpty;
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'cover': cover,
      'bangumiId': bangumiId,
      'watchedEpisodes': watchedEpisodes,
      'totalEpisodes': totalEpisodes,
      'watchingStatus': watchingStatus,
      'followDate': followDate,
      'lastWatchedAt': lastWatchedAt,
      'tags': tags,
      'yougnScore': yougnScore,
    };
  }

  factory NotionWatchBindings.fromJson(Map<String, dynamic> json) {
    return NotionWatchBindings(
      title: json['title']?.toString() ?? '',
      cover: json['cover']?.toString() ?? '',
      bangumiId: json['bangumiId']?.toString() ?? '',
      watchedEpisodes: json['watchedEpisodes']?.toString() ?? '',
      totalEpisodes: json['totalEpisodes']?.toString() ?? '',
      watchingStatus: json['watchingStatus']?.toString() ?? '',
      followDate: json['followDate']?.toString() ?? '',
      lastWatchedAt: json['lastWatchedAt']?.toString() ?? '',
      tags: json['tags']?.toString() ?? '',
      yougnScore: json['yougnScore']?.toString() ?? '',
    );
  }

  NotionWatchBindings copyWith({
    String? title,
    String? cover,
    String? bangumiId,
    String? watchedEpisodes,
    String? totalEpisodes,
    String? watchingStatus,
    String? followDate,
    String? lastWatchedAt,
    String? tags,
    String? yougnScore,
  }) {
    return NotionWatchBindings(
      title: title ?? this.title,
      cover: cover ?? this.cover,
      bangumiId: bangumiId ?? this.bangumiId,
      watchedEpisodes: watchedEpisodes ?? this.watchedEpisodes,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      watchingStatus: watchingStatus ?? this.watchingStatus,
      followDate: followDate ?? this.followDate,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
      tags: tags ?? this.tags,
      yougnScore: yougnScore ?? this.yougnScore,
    );
  }
}

class NotionDailyRecommendationBindings {
  final String title;
  final String yougnScore;
  final String bangumiScore;
  final String bangumiRank;
  final String followDate;
  final String airDate;
  final String airDateRange;
  final String tags;
  final String type;
  final String shortReview;
  final String longReview;
  final String cover;
  final String animationProduction;
  final String director;
  final String script;
  final String storyboard;
  final String? bangumiId;
  final String? subjectId;

  const NotionDailyRecommendationBindings({
    this.title = '',
    this.yougnScore = '',
    this.bangumiScore = '',
    this.bangumiRank = '',
    this.followDate = '',
    this.airDate = '',
    this.airDateRange = '',
    this.tags = '',
    this.type = '',
    this.shortReview = '',
    this.longReview = '',
    this.cover = '',
    this.animationProduction = '',
    this.director = '',
    this.script = '',
    this.storyboard = '',
    this.bangumiId,
    this.subjectId,
  });

  bool get isEmpty {
    return title.isEmpty &&
        yougnScore.isEmpty &&
        bangumiScore.isEmpty &&
        bangumiRank.isEmpty &&
        followDate.isEmpty &&
        airDate.isEmpty &&
        airDateRange.isEmpty &&
        tags.isEmpty &&
        type.isEmpty &&
        shortReview.isEmpty &&
        longReview.isEmpty &&
        cover.isEmpty &&
        animationProduction.isEmpty &&
        director.isEmpty &&
        script.isEmpty &&
        storyboard.isEmpty &&
        (bangumiId == null || bangumiId!.isEmpty) &&
        (subjectId == null || subjectId!.isEmpty);
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'yougnScore': yougnScore,
      'bangumiScore': bangumiScore,
      'bangumiRank': bangumiRank,
      'followDate': followDate,
      'airDate': airDate,
      'airDateRange': airDateRange,
      'tags': tags,
      'type': type,
      'shortReview': shortReview,
      'longReview': longReview,
      'cover': cover,
      'animationProduction': animationProduction,
      'director': director,
      'script': script,
      'storyboard': storyboard,
      'bangumiId': bangumiId,
      'subjectId': subjectId,
    };
  }

  factory NotionDailyRecommendationBindings.fromJson(
    Map<String, dynamic> json,
  ) {
    String? normalizeOptionalString(dynamic value) {
      if (value == null) return null;
      final text = value.toString();
      return text.isEmpty ? null : text;
    }

    return NotionDailyRecommendationBindings(
      title: json['title']?.toString() ?? '',
      yougnScore: json['yougnScore']?.toString() ?? '',
      bangumiScore: json['bangumiScore']?.toString() ?? '',
      bangumiRank: json['bangumiRank']?.toString() ?? '',
      followDate: json['followDate']?.toString() ?? '',
      airDate: json['airDate']?.toString() ?? '',
      airDateRange: json['airDateRange']?.toString() ?? '',
      tags: json['tags']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      shortReview: json['shortReview']?.toString() ?? '',
      longReview: json['longReview']?.toString() ?? '',
      cover: json['cover']?.toString() ?? '',
      animationProduction: json['animationProduction']?.toString() ?? '',
      director: json['director']?.toString() ?? '',
      script: json['script']?.toString() ?? '',
      storyboard: json['storyboard']?.toString() ?? '',
      bangumiId: normalizeOptionalString(json['bangumiId']),
      subjectId: normalizeOptionalString(json['subjectId']),
    );
  }

  NotionDailyRecommendationBindings copyWith({
    String? title,
    String? yougnScore,
    String? bangumiScore,
    String? bangumiRank,
    String? followDate,
    String? airDate,
    String? airDateRange,
    String? tags,
    String? type,
    String? shortReview,
    String? longReview,
    String? cover,
    String? animationProduction,
    String? director,
    String? script,
    String? storyboard,
    String? bangumiId,
    String? subjectId,
  }) {
    return NotionDailyRecommendationBindings(
      title: title ?? this.title,
      yougnScore: yougnScore ?? this.yougnScore,
      bangumiScore: bangumiScore ?? this.bangumiScore,
      bangumiRank: bangumiRank ?? this.bangumiRank,
      followDate: followDate ?? this.followDate,
      airDate: airDate ?? this.airDate,
      airDateRange: airDateRange ?? this.airDateRange,
      tags: tags ?? this.tags,
      type: type ?? this.type,
      shortReview: shortReview ?? this.shortReview,
      longReview: longReview ?? this.longReview,
      cover: cover ?? this.cover,
      animationProduction: animationProduction ?? this.animationProduction,
      director: director ?? this.director,
      script: script ?? this.script,
      storyboard: storyboard ?? this.storyboard,
      bangumiId: bangumiId ?? this.bangumiId,
      subjectId: subjectId ?? this.subjectId,
    );
  }
}
