import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_services.dart';
import '../../../app/app_settings.dart';
import '../../../core/widgets/navigation_shell.dart';
import '../../../models/bangumi_models.dart';
import '../../detail/presentation/detail_page.dart';
import '../providers/calendar_view_model.dart';
import 'calendar_view.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CalendarViewModel(
        bangumiApi: context.read<AppServices>().bangumiApi,
        notionApi: context.read<AppServices>().notionApi,
      )..load(context.read<AppSettings>()),
      child: const _CalendarPageBody(),
    );
  }
}

class _CalendarPageBody extends StatelessWidget {
  const _CalendarPageBody();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Consumer<CalendarViewModel>(
      builder: (context, model, _) {
        return NavigationShell(
          title: '放送',
          selectedRoute: '/calendar',
          actions: [
            IconButton(
              tooltip: '刷新',
              onPressed: model.isLoading ? null : () => model.load(settings),
              icon: const Icon(Icons.refresh),
            ),
          ],
          child: _buildBody(context, model, settings),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    CalendarViewModel model,
    AppSettings settings,
  ) {
    if (model.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (model.errorMessage != null) {
      return _buildCenteredMessage(
        context,
        icon: Icons.error_outline,
        title: model.errorMessage!,
        actionLabel: '重试',
        onAction: () => model.load(settings),
      );
    }

    if (model.days.isEmpty) {
      return _buildCenteredMessage(
        context,
        icon: Icons.inbox_outlined,
        title: '暂无放送数据',
        actionLabel: '刷新',
        onAction: () => model.load(settings),
      );
    }

    final selectedDay = model.days.firstWhere(
      (day) => model.normalizeWeekdayId(day.weekday.id) == model.selectedWeekday,
      orElse: () => const BangumiCalendarDay(
        weekday: BangumiCalendarWeekday(id: 0, en: '', cn: '', ja: ''),
        items: [],
      ),
    );
    final selectedItems =
        model.weekdayItems[model.selectedWeekday] ?? selectedDay.items;

    // Prefetch: avoid calling viewModel methods from the View layer.
    for (final item in selectedItems) {
      model.scheduleDetailLoad(item.id);
      model.scheduleLatestEpisodeLoad(item.id);
      model.scheduleAirEndDateLoad(
        item.id,
        totalEpisodes: model.detailCache[item.id]?.epsCount ?? item.epsCount,
      );
    }
    for (final item in model.boundItems) {
      model.scheduleDetailLoad(item.id);
      model.scheduleLatestEpisodeLoad(item.id);
    }

    final viewState = CalendarViewState(
      notionConfigured: model.notionConfigured,
      showRatings: settings.showRatings,
      calendarViewMode: settings.calendarViewMode,
      selectedWeekday: model.selectedWeekday,
      selectedWeekdayInfo: selectedDay.weekday,
      selectedItems: selectedItems,
      boundItems: model.boundItems,
      boundIds: model.boundIds,
      weekdayBoundCounts: model.weekdayBoundCounts,
      watchedEpisodes: model.watchedEpisodes,
      yougnScores: model.yougnScores,
      lastWatchedAt: model.lastWatchedAt,
      detailCache: model.detailCache,
      latestEpisodeCache: model.latestEpisodeCache,
      airEndDateCache: model.airEndDateCache,
    );

    final callbacks = CalendarViewCallbacks(
      onWeekdaySelected: model.selectWeekday,
      onCalendarViewModeChanged: settings.setCalendarViewMode,
      onTapSubject: (subjectId) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DetailPage(subjectId: subjectId),
          ),
        );
      },
      onLongPressBoundSubject: (subjectId) =>
          unawaited(_handleIncrement(context, model, subjectId)),
    );

    return CalendarView(state: viewState, callbacks: callbacks);
  }

  Widget _buildCenteredMessage(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh),
                  label: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleIncrement(
    BuildContext context,
    CalendarViewModel model,
    int subjectId,
  ) async {
    try {
      final result = await model.incrementWatchedEpisodes(subjectId);
      if (!context.mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未配置 Notion 追番字段')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已追集数 +1'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => unawaited(model.revertWatchedEpisodes(result)),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('更新失败，请稍后重试')),
      );
    }
  }
}

