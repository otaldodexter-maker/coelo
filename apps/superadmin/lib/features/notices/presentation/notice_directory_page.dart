import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../data/fake_notice_repository.dart';
import '../domain/platform_notice.dart';

enum _NoticeStatusFilter { all, draft, scheduled, active, paused, ended, canceled }

enum NoticeDirectoryViewState { content, loading, error, forbidden }

extension _NoticeStatusFilterLabel on _NoticeStatusFilter {
  String get label => switch (this) {
    _NoticeStatusFilter.all => 'Todos',
    _NoticeStatusFilter.draft => 'Rascunho',
    _NoticeStatusFilter.scheduled => 'Agendado',
    _NoticeStatusFilter.active => 'Ativo',
    _NoticeStatusFilter.paused => 'Pausado',
    _NoticeStatusFilter.ended => 'Expirado',
    _NoticeStatusFilter.canceled => 'Inativo',
  };

  NoticeStatus? get status => switch (this) {
    _NoticeStatusFilter.all => null,
    _NoticeStatusFilter.draft => NoticeStatus.draft,
    _NoticeStatusFilter.scheduled => NoticeStatus.scheduled,
    _NoticeStatusFilter.active => NoticeStatus.active,
    _NoticeStatusFilter.paused => NoticeStatus.paused,
    _NoticeStatusFilter.ended => NoticeStatus.ended,
    _NoticeStatusFilter.canceled => NoticeStatus.cancelled,
  };
}

enum _NoticeTargetFilter { all, web, mobile, tablet }

extension _NoticeTargetFilterValue on _NoticeTargetFilter {
  NoticeTargetDevice? get device => switch (this) {
    _NoticeTargetFilter.all => null,
    _NoticeTargetFilter.web => NoticeTargetDevice.web,
    _NoticeTargetFilter.mobile => NoticeTargetDevice.mobile,
    _NoticeTargetFilter.tablet => NoticeTargetDevice.tablet,
  };

  String get label => switch (this) {
    _NoticeTargetFilter.all => 'Todos os dispositivos',
    _NoticeTargetFilter.web => 'Web',
    _NoticeTargetFilter.mobile => 'Mobile',
    _NoticeTargetFilter.tablet => 'Tablet',
  };
}

enum _NoticePeriodFilter { all, now, upcoming, ended }

extension _NoticePeriodFilterLabel on _NoticePeriodFilter {
  String get label => switch (this) {
    _NoticePeriodFilter.all => 'Per\u00edodo',
    _NoticePeriodFilter.now => 'Ativos agora',
    _NoticePeriodFilter.upcoming => 'Pr\u00f3ximos',
    _NoticePeriodFilter.ended => 'Expirados',
  };
}

enum _NoticeCardAction { edit, duplicate, publish, pause, resume, cancel }

final class NoticeDirectoryPage extends StatefulWidget {
  const NoticeDirectoryPage({
    required this.repository,
    this.onCreate,
    this.onEdit,
    this.viewState = NoticeDirectoryViewState.content,
    super.key,
  });

  final FakeNoticeRepository repository;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;
  final NoticeDirectoryViewState viewState;

  @override
  State<NoticeDirectoryPage> createState() => _NoticeDirectoryPageState();
}

final class _NoticeDirectoryPageState extends State<NoticeDirectoryPage> {
  final _search = TextEditingController();
  _NoticeStatusFilter _statusFilter = _NoticeStatusFilter.all;
  _NoticeTargetFilter _targetFilter = _NoticeTargetFilter.all;
  _NoticePeriodFilter _periodFilter = _NoticePeriodFilter.all;
  int _page = 1;
  int _pageSize = 8;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final contentPadding = compact ? CoeloSpacing.space4 : CoeloSpacing.space6;
      final all = widget.repository.list();
      final filtered = _filteredNotices();
      final notices = _visiblePage(filtered);
      final totalPages = math.max(1, (filtered.length / _pageSize).ceil());
      final showsPagination =
          widget.viewState == NoticeDirectoryViewState.content && filtered.isNotEmpty;
      return Container(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  contentPadding,
                  contentPadding,
                  contentPadding,
                  showsPagination ? 0 : contentPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Avisos', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: CoeloSpacing.space1),
                    Text(
                      'Gerencie os avisos exibidos nas experi\u00eancias Coelo.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    _toolbar(all, compact: compact),
                    const SizedBox(height: CoeloSpacing.space4),
                    Expanded(
                      child: _content(
                        context,
                        compact: compact,
                        all: all,
                        filtered: filtered,
                        notices: notices,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showsPagination)
              SuperadminListingPaginationFooter(
                horizontalPadding: contentPadding,
                semanticKey: const Key('notice-directory-pagination'),
                child: CoeloAdminPagination(
                  currentPage: _page,
                  totalPages: totalPages,
                  pageSize: _pageSize,
                  pageSizeOptions: const [8, 16, 24],
                  onPrevious: _page > 1 ? () => setState(() => _page--) : null,
                  onNext: _page < totalPages ? () => setState(() => _page++) : null,
                  onPageSelected: (page) => setState(() => _page = page),
                  onPageSizeChanged: (size) => setState(() {
                    _pageSize = size;
                    _page = 1;
                  }),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _toolbar(List<PlatformNotice> all, {required bool compact}) {
    final counts = <_NoticeStatusFilter, int>{
      for (final filter in _NoticeStatusFilter.values)
        filter: filter.status == null
            ? all.length
            : all.where((notice) => notice.status == filter.status).length,
    };
    return CoeloAdminListingToolbar(
      search: SizedBox(
        width: compact ? double.infinity : CoeloSpacing.space20 * 4,
        height: CoeloSize.touchMin,
        child: CoeloSearchField(
          controller: _search,
          hintText: 'Buscar aviso',
          semanticLabel: 'Buscar aviso por t\u00edtulo ou destinat\u00e1rio',
          onChanged: (_) => _resetPage(() {}),
        ),
      ),
      filters: [
        SizedBox(
          width: compact ? double.infinity : 220,
          child: CoeloAdminSingleSelectField<_NoticeStatusFilter>(
            value: _statusFilter,
            label: 'Estado',
            options: _NoticeStatusFilter.values,
            optionLabel: (value) => '${value.label} (${counts[value]})',
            onChanged: (value) => _resetPage(() => _statusFilter = value),
            prefixIcon: Icons.bar_chart_rounded,
          ),
        ),
        SizedBox(
          width: compact ? double.infinity : 190,
          child: CoeloAdminSingleSelectField<_NoticeTargetFilter>(
            value: _targetFilter,
            label: 'Plataforma',
            options: _NoticeTargetFilter.values,
            optionLabel: (value) => value.label,
            onChanged: (value) => _resetPage(() => _targetFilter = value),
            prefixIcon: Icons.devices_rounded,
          ),
        ),
        SizedBox(
          width: compact ? double.infinity : 210,
          child: CoeloAdminSingleSelectField<_NoticePeriodFilter>(
            value: _periodFilter,
            label: 'Per\u00edodo',
            options: _NoticePeriodFilter.values,
            optionLabel: (value) => value.label,
            onChanged: (value) => _resetPage(() => _periodFilter = value),
            prefixIcon: Icons.calendar_month_rounded,
          ),
        ),
      ],
      actions: const [],
    );
  }

  Widget _content(
    BuildContext context, {
    required bool compact,
    required List<PlatformNotice> all,
    required List<PlatformNotice> filtered,
    required List<PlatformNotice> notices,
  }) => switch (widget.viewState) {
    NoticeDirectoryViewState.loading => const CoeloStatePanel(
      title: 'Carregando avisos',
      message: 'Aguarde enquanto os avisos s\u00e3o carregados.',
      loading: true,
    ),
    NoticeDirectoryViewState.error => const CoeloStatePanel(
      title: 'N\u00e3o foi poss\u00edvel carregar',
      message: 'N\u00e3o foi poss\u00edvel carregar os avisos.',
    ),
    NoticeDirectoryViewState.forbidden => const CoeloStatePanel(
      title: 'Sem permiss\u00e3o',
      message: 'Voc\u00ea n\u00e3o tem permiss\u00e3o para ver avisos.',
      icon: Icons.lock_outline_rounded,
    ),
    NoticeDirectoryViewState.content when all.isEmpty => const CoeloStatePanel(
      title: 'Nenhum aviso',
      message: 'Ainda n\u00e3o existem avisos cadastrados.',
      icon: Icons.campaign_outlined,
    ),
    NoticeDirectoryViewState.content when filtered.isEmpty => const CoeloStatePanel(
      title: 'Nenhum resultado',
      message: 'Nenhum aviso encontrado com estes filtros.',
      icon: Icons.search_off_rounded,
    ),
    NoticeDirectoryViewState.content => _cards(context, notices: notices, compact: compact),
  };

  Widget _cards(
    BuildContext context, {
    required List<PlatformNotice> notices,
    required bool compact,
  }) {
    final cards = <Widget>[
      ConstrainedBox(
        key: const Key('create-notice-card'),
        constraints: const BoxConstraints(minHeight: 216),
        child: CoeloAdminCreateAction(
          label: 'Novo aviso',
          description: 'Criar novo aviso.',
          icon: Icons.post_add_rounded,
          onPressed: widget.onCreate,
        ),
      ),
      ...notices.map((notice) => _noticeCard(context, notice)),
    ];
    if (compact) {
      return ListView.separated(
        key: const Key('notice-card-list'),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space6),
        itemBuilder: (_, index) => cards[index],
      );
    }
    return GridView.builder(
      key: const Key('notice-card-grid'),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
        mainAxisExtent: 260,
        mainAxisSpacing: CoeloSpacing.space6,
        crossAxisSpacing: CoeloSpacing.space6,
      ),
      itemBuilder: (_, index) => cards[index],
    );
  }

  Widget _noticeCard(BuildContext context, PlatformNotice notice) {
    final theme = Theme.of(context);
    return CoeloAdminInteractiveCard(
      onPressed: widget.onEdit == null ? null : () => widget.onEdit!(notice.id),
      minHeight: 216,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CoeloSpacing.space6,
          vertical: CoeloSpacing.space4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    notice.title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space2),
                _statusIndicator(context, notice.status),
                const SizedBox(width: CoeloSpacing.space2),
                _rowActionMenu(notice),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space2),
            Text(
              '${notice.audienceLabel} \u00b7 ${notice.audience.label}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: CoeloSpacing.space3),
            const Divider(height: 1),
            const SizedBox(height: CoeloSpacing.space3),
            Text(
              '${notice.targetDevice.label} \u00b7 ${_formatDate(notice.startsAt)}${notice.endsAt == null ? ' \u00b7 sem data limite' : ' \u00b7 at\u00e9 ${_formatDate(notice.endsAt!)}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: CoeloSpacing.space1),
            Text(
              'Recorr\u00eancia: ${notice.recurrenceLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: CoeloSpacing.space1),
            Text(
              'Entregues: ${notice.deliveredCount} \u00b7 Aceites: ${notice.acceptedCount}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowActionMenu(PlatformNotice notice) {
    final actions = _rowActions(notice);
    return CoeloAdminFlyout<_NoticeCardAction>(
      items: [
        if (actions.contains(_NoticeCardAction.edit))
          const CoeloAdminFlyoutItem(
            value: _NoticeCardAction.edit,
            icon: Icons.edit_outlined,
            label: 'Editar',
          ),
        if (actions.contains(_NoticeCardAction.publish))
          const CoeloAdminFlyoutItem(
            value: _NoticeCardAction.publish,
            icon: Icons.send_rounded,
            label: 'Publicar',
          ),
        if (actions.contains(_NoticeCardAction.pause))
          const CoeloAdminFlyoutItem(
            value: _NoticeCardAction.pause,
            icon: Icons.pause_circle_outline_rounded,
            label: 'Pausar',
          ),
        if (actions.contains(_NoticeCardAction.resume))
          const CoeloAdminFlyoutItem(
            value: _NoticeCardAction.resume,
            icon: Icons.play_circle_outline_rounded,
            label: 'Reativar',
          ),
        const CoeloAdminFlyoutItem(
          value: _NoticeCardAction.duplicate,
          icon: Icons.copy_all_outlined,
          label: 'Duplicar',
        ),
        if (actions.contains(_NoticeCardAction.cancel))
          const CoeloAdminFlyoutItem(
            value: _NoticeCardAction.cancel,
            icon: Icons.block,
            label: 'Inativar',
            startsGroup: true,
            tone: CoeloAdminFlyoutTone.negative,
          ),
      ],
      onSelected: (action) => _runAction(action, notice),
      builder: (context, controller) => IconButton(
        tooltip: 'A\u00e7\u00f5es do aviso',
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.more_horiz_rounded),
      ),
    );
  }

  Set<_NoticeCardAction> _rowActions(PlatformNotice notice) {
    final actions = <_NoticeCardAction>{_NoticeCardAction.duplicate};
    if (notice.canEdit) {
      actions
        ..add(_NoticeCardAction.edit)
        ..add(_NoticeCardAction.publish);
    }
    if (notice.status == NoticeStatus.active) actions.add(_NoticeCardAction.pause);
    if (notice.status == NoticeStatus.paused) actions.add(_NoticeCardAction.resume);
    if (const {
      NoticeStatus.draft,
      NoticeStatus.scheduled,
      NoticeStatus.active,
      NoticeStatus.paused,
    }.contains(notice.status)) {
      actions.add(_NoticeCardAction.cancel);
    }
    return actions;
  }

  void _runAction(_NoticeCardAction action, PlatformNotice notice) {
    try {
      switch (action) {
        case _NoticeCardAction.edit:
          widget.onEdit?.call(notice.id);
          return;
        case _NoticeCardAction.duplicate:
          final updated = widget.repository.duplicate(notice.id);
          _refresh('Aviso duplicado: ${updated.title}');
          return;
        case _NoticeCardAction.publish:
          final updated = widget.repository.publish(notice.id);
          _refresh('Aviso publicado: ${updated.title}');
          return;
        case _NoticeCardAction.pause:
          final updated = widget.repository.pause(notice.id);
          _refresh('Aviso pausado: ${updated.title}');
          return;
        case _NoticeCardAction.resume:
          final updated = widget.repository.resume(notice.id);
          _refresh('Aviso reativado: ${updated.title}');
          return;
        case _NoticeCardAction.cancel:
          final updated = widget.repository.cancel(notice.id);
          _refresh('Aviso inativado: ${updated.title}');
          return;
      }
    } on StateError catch (error) {
      _refresh(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  void _refresh(String message) {
    _feedback(message);
    setState(() {});
  }

  void _feedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _statusIndicator(BuildContext context, NoticeStatus status) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      NoticeStatus.draft => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
      NoticeStatus.scheduled => (colors.secondaryContainer, colors.onSecondaryContainer),
      NoticeStatus.active => (colors.primaryContainer, colors.onPrimaryContainer),
      NoticeStatus.paused => (colors.tertiaryContainer, colors.onTertiaryContainer),
      NoticeStatus.ended => (colors.surfaceDim, colors.onSurfaceVariant),
      NoticeStatus.cancelled => (colors.errorContainer, colors.onErrorContainer),
    };
    return CoeloAdminExpandableStatusIndicator(
      label: status.label,
      backgroundColor: background,
      foregroundColor: foreground,
      semanticLabel: 'Status ${status.label.toLowerCase()}',
    );
  }

  List<PlatformNotice> _filteredNotices() {
    final now = DateTime.now();
    final target = _targetFilter.device;
    return widget.repository
        .list(search: _search.text, status: _statusFilter.status, target: target)
        .where((notice) {
          final inPeriod = switch (_periodFilter) {
            _NoticePeriodFilter.all => true,
            _NoticePeriodFilter.now =>
              notice.status == NoticeStatus.active &&
                  (notice.endsAt == null || !notice.endsAt!.isBefore(now)),
            _NoticePeriodFilter.upcoming => notice.status == NoticeStatus.scheduled,
            _NoticePeriodFilter.ended => notice.status == NoticeStatus.ended,
          };
          return inPeriod;
        })
        .toList(growable: false);
  }

  List<PlatformNotice> _visiblePage(List<PlatformNotice> filtered) {
    final totalPages = math.max(1, (filtered.length / _pageSize).ceil());
    _page = _page.clamp(1, totalPages);
    final start = (_page - 1) * _pageSize;
    return filtered.skip(start).take(_pageSize).toList(growable: false);
  }

  void _resetPage(VoidCallback update) {
    setState(() {
      update();
      _page = 1;
    });
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
