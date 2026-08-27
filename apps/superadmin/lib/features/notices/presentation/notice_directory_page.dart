import 'dart:async';
import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../../../shared/presentation/widgets/superadmin_underline_tabs.dart';
import '../domain/notice_repository.dart';
import '../domain/platform_notice.dart';
import 'communication_type_badge.dart';
import 'notice_preview_dialog.dart';

enum _NoticeStatusFilter { all, draft, scheduled, active, paused, ended, canceled }

enum _CommunicationTypeFilter { all, notice, content, highlight, forYou }

extension on _CommunicationTypeFilter {
  String get label => switch (this) {
    _CommunicationTypeFilter.all => 'Todos',
    _CommunicationTypeFilter.notice => 'Avisos',
    _CommunicationTypeFilter.content => 'Conteúdos',
    _CommunicationTypeFilter.highlight => 'Destaques',
    _CommunicationTypeFilter.forYou => 'Para você',
  };

  CommunicationType? get type => switch (this) {
    _CommunicationTypeFilter.all => null,
    _CommunicationTypeFilter.notice => CommunicationType.notice,
    _CommunicationTypeFilter.content => CommunicationType.content,
    _CommunicationTypeFilter.highlight => CommunicationType.highlight,
    _CommunicationTypeFilter.forYou => CommunicationType.forYou,
  };
}

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

enum _NoticeCardAction { preview, edit, publish, pause, resume, cancel }

final class NoticeDirectoryPage extends StatefulWidget {
  const NoticeDirectoryPage({
    required this.repository,
    this.onCreate,
    this.onEdit,
    this.viewState = NoticeDirectoryViewState.content,
    super.key,
  });

  final NoticeRepository repository;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;
  final NoticeDirectoryViewState viewState;

  @override
  State<NoticeDirectoryPage> createState() => _NoticeDirectoryPageState();
}

final class _NoticeDirectoryPageState extends State<NoticeDirectoryPage> {
  final _search = TextEditingController();
  _NoticeStatusFilter _statusFilter = _NoticeStatusFilter.all;
  _CommunicationTypeFilter _typeFilter = _CommunicationTypeFilter.all;
  Timer? _searchDebounce;
  int _loadGeneration = 0;
  final Map<String, String> _actionRequestIds = {};
  int _page = 1;
  int _pageSize = 24;
  List<PlatformNotice> _items = const [];
  final List<(DateTime?, String?)> _cursorHistory = [];
  DateTime? _nextCursorOccurredAt;
  String? _nextCursorId;
  DateTime? _currentCursorOccurredAt;
  String? _currentCursorId;
  bool _runningAction = false;
  NoticeDirectoryViewState _state = NoticeDirectoryViewState.loading;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final contentPadding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
          ? CoeloSpacing.space10
          : compact
          ? CoeloSpacing.space4
          : CoeloSpacing.space6;
      if (_state == NoticeDirectoryViewState.forbidden) {
        return Container(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            key: const Key('notice-directory-content-inset'),
            padding: EdgeInsets.all(contentPadding),
            child: _content(
              context,
              compact: compact,
              all: const <PlatformNotice>[],
              notices: const <PlatformNotice>[],
            ),
          ),
        );
      }
      final all = _items;
      final notices = _items;
      final totalPages = _nextCursorId == null ? _page : _page + 1;
      final showsPagination = _state == NoticeDirectoryViewState.content && notices.isNotEmpty;
      return Container(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                key: const Key('notice-directory-content-inset'),
                padding: EdgeInsets.fromLTRB(
                  contentPadding,
                  contentPadding,
                  contentPadding,
                  showsPagination ? 0 : contentPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _toolbar(compact: compact),
                    const SizedBox(height: CoeloSpacing.space4),
                    SuperadminUnderlineTabs<_CommunicationTypeFilter>(
                      tabs: [
                        for (final type in _CommunicationTypeFilter.values)
                          SuperadminUnderlineTab(value: type, label: type.label),
                      ],
                      selected: _typeFilter,
                      onSelected: (value) {
                        setState(() => _typeFilter = value);
                        _load(reset: true);
                      },
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    Expanded(
                      child: _content(context, compact: compact, all: all, notices: notices),
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
                  pageSizeOptions: const [12, 24, 48],
                  onPrevious: _page > 1 ? _previousPage : null,
                  onNext: _nextCursorId != null ? _nextPage : null,
                  onPageSelected: null,
                  onPageSizeChanged: (size) {
                    _pageSize = size;
                    _load(reset: true);
                  },
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _toolbar({required bool compact}) {
    return CoeloAdminListingToolbar(
      search: SizedBox(
        width: compact ? double.infinity : CoeloSpacing.space20 * 4,
        height: CoeloSize.touchMin,
        child: CoeloSearchField(
          controller: _search,
          hintText: 'Buscar comunicação',
          semanticLabel: 'Buscar comunicação por título, conteúdo ou contexto',
          onChanged: (_) {
            _searchDebounce?.cancel();
            _searchDebounce = Timer(const Duration(milliseconds: 300), () => _load(reset: true));
          },
        ),
      ),
      filters: [
        SizedBox(
          width: compact ? double.infinity : 220,
          child: CoeloAdminSingleSelectField<_NoticeStatusFilter>(
            value: _statusFilter,
            label: 'Estado',
            options: _NoticeStatusFilter.values,
            optionLabel: (value) => value.label,
            onChanged: (value) {
              _statusFilter = value;
              _load(reset: true);
            },
            prefixIcon: Icons.bar_chart_rounded,
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
    required List<PlatformNotice> notices,
  }) => switch (widget.viewState == NoticeDirectoryViewState.content ? _state : widget.viewState) {
    NoticeDirectoryViewState.loading => const CoeloStatePanel(
      title: 'Carregando comunicações',
      message: 'Aguarde enquanto as comunicações são carregadas.',
      loading: true,
    ),
    NoticeDirectoryViewState.error => _stateWithCreate(
      compact: compact,
      state: CoeloStatePanel(
        title: 'N\u00e3o foi poss\u00edvel carregar',
        message: _errorMessage ?? 'Não foi possível carregar as comunicações.',
        actionLabel: 'Tentar novamente',
        onAction: () => _load(reset: true),
      ),
    ),
    NoticeDirectoryViewState.forbidden => CoeloStatePanel(
      title: 'Sem permiss\u00e3o',
      message: _errorMessage ?? 'Você não tem permissão para ver comunicações.',
      icon: Icons.lock_outline_rounded,
    ),
    NoticeDirectoryViewState.content when all.isEmpty && !_hasActiveQuery => _stateWithCreate(
      compact: compact,
      state: const CoeloStatePanel(
        title: 'Nenhuma comunicação',
        message: 'Ainda não existem comunicações cadastradas.',
        icon: Icons.campaign_outlined,
      ),
    ),
    NoticeDirectoryViewState.content when notices.isEmpty => _stateWithCreate(
      compact: compact,
      state: const CoeloStatePanel(
        title: 'Nenhum resultado',
        message: 'Nenhuma comunicação encontrada com estes filtros.',
        icon: Icons.search_off_rounded,
      ),
    ),
    NoticeDirectoryViewState.content =>
      compact ? _cards(context, notices: notices, compact: true) : _table(context, notices),
  };

  Widget _stateWithCreate({required bool compact, required Widget state}) {
    final children = <Widget>[_createAction(), state];
    if (compact) {
      return ListView.separated(
        key: const Key('notice-directory-state-list'),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space6),
        itemBuilder: (_, index) => children[index],
      );
    }
    return GridView.builder(
      key: const Key('notice-directory-state-grid'),
      itemCount: children.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
        mainAxisExtent: 280,
        mainAxisSpacing: CoeloSpacing.space6,
        crossAxisSpacing: CoeloSpacing.space6,
      ),
      itemBuilder: (_, index) => children[index],
    );
  }

  Widget _createAction() => ConstrainedBox(
    key: const Key('create-notice-card'),
    constraints: const BoxConstraints(minHeight: 216),
    child: CoeloAdminCreateAction(
      label: 'Nova comunicação',
      description: 'Criar aviso, conteúdo, destaque ou item Para você.',
      icon: Icons.post_add_rounded,
      onPressed: widget.onCreate,
    ),
  );

  Widget _cards(
    BuildContext context, {
    required List<PlatformNotice> notices,
    required bool compact,
  }) {
    final cards = <Widget>[
      _createAction(),
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

  Widget _table(BuildContext context, List<PlatformNotice> notices) => Column(
    children: [
      CoeloAdminCreateAction(
        key: const Key('create-notice-banner'),
        label: 'Nova comunicação',
        description: 'Criar aviso, conteúdo, destaque ou item Para você.',
        icon: Icons.post_add_rounded,
        variant: CoeloAdminCreateActionVariant.banner,
        onPressed: widget.onCreate,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      Expanded(
        child: SingleChildScrollView(
          child: CoeloAdminResizableTable<PlatformNotice>(
            key: ValueKey(
              'communication-directory-table-${_typeFilter.type?.storageValue ?? 'all'}',
            ),
            items: notices,
            rowKey: (notice) => 'communication-row-${notice.id}',
            pinnedColumn: CoeloAdminTableColumn(
              id: 'item',
              label: 'Item',
              initialWidth: 280,
              minWidth: 220,
              maxWidth: 420,
              cellBuilder: (_, notice) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notice.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    notice.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            columns: [
              CoeloAdminTableColumn(
                id: 'type',
                label: 'Tipo',
                initialWidth: 150,
                minWidth: 130,
                maxWidth: 190,
                cellBuilder: (_, notice) => CommunicationTypeBadge(type: notice.type),
              ),
              _textColumn('priority', 'Prioridade', 130, (notice) => notice.priority.label),
              _textColumn(
                'validity',
                'Vigência',
                180,
                (notice) => notice.endsAt == null
                    ? 'Desde ${_formatDate(notice.startsAt)}'
                    : '${_formatDate(notice.startsAt)} – ${_formatDate(notice.endsAt!)}',
              ),
              _textColumn('recurrence', 'Recorrência', 170, (notice) => notice.recurrenceLabel),
              _textColumn('context', 'Contexto', 180, (notice) => notice.audienceLabel),
              CoeloAdminTableColumn(
                id: 'status',
                label: 'Status',
                initialWidth: 140,
                minWidth: 120,
                maxWidth: 180,
                cellBuilder: (context, notice) => Align(
                  alignment: Alignment.centerLeft,
                  child: _statusIndicator(context, notice.status),
                ),
              ),
              CoeloAdminTableColumn(
                id: 'actions',
                label: 'Ações',
                initialWidth: 88,
                minWidth: 80,
                maxWidth: 104,
                cellBuilder: (_, notice) => _rowActionMenu(notice),
              ),
            ],
            headerHeight: 56,
            rowHeight: 72,
            onRowPressed: widget.onEdit == null ? null : (notice) => widget.onEdit!(notice.id),
          ),
        ),
      ),
    ],
  );

  CoeloAdminTableColumn<PlatformNotice> _textColumn(
    String id,
    String label,
    double width,
    String Function(PlatformNotice) value,
  ) => CoeloAdminTableColumn(
    id: id,
    label: label,
    initialWidth: width,
    minWidth: width - 30,
    maxWidth: width + 100,
    cellBuilder: (_, notice) => Text(value(notice), maxLines: 2, overflow: TextOverflow.ellipsis),
  );

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
            CommunicationTypeBadge(type: notice.type),
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
        CoeloAdminFlyoutItem(
          value: _NoticeCardAction.preview,
          icon: Icons.visibility_outlined,
          label: notice.isPopup ? 'Pré-visualizar popup' : 'Prévia administrativa',
        ),
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
        tooltip: 'Ações da comunicação',
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.more_horiz_rounded),
      ),
    );
  }

  Set<_NoticeCardAction> _rowActions(PlatformNotice notice) {
    final actions = <_NoticeCardAction>{_NoticeCardAction.preview};
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

  Future<void> _runAction(_NoticeCardAction action, PlatformNotice notice) async {
    if (_runningAction) return;
    final cancellationReason = action == _NoticeCardAction.cancel
        ? await _requestCancellationReason()
        : null;
    if (action == _NoticeCardAction.cancel && cancellationReason == null) return;
    if (!mounted) return;
    setState(() => _runningAction = true);
    final requestKey = '${notice.id}:${action.name}';
    final requestId = _actionRequestIds.putIfAbsent(requestKey, _requestId);
    try {
      switch (action) {
        case _NoticeCardAction.preview:
          _actionRequestIds.remove(requestKey);
          await showNoticePreview(context, notice);
          return;
        case _NoticeCardAction.edit:
          _actionRequestIds.remove(requestKey);
          widget.onEdit?.call(notice.id);
          return;
        case _NoticeCardAction.publish:
          final updated = await widget.repository.publish(
            notice,
            requestId: requestId,
            expectedVersion: notice.managementVersion,
          );
          _actionRequestIds.remove(requestKey);
          _refresh('Publicação agendada: ${updated.title}');
          return;
        case _NoticeCardAction.pause:
          final updated = await widget.repository.changeStatus(
            notice.id,
            requestId: requestId,
            status: NoticeStatus.paused,
            expectedVersion: notice.managementVersion,
          );
          _actionRequestIds.remove(requestKey);
          _refresh('Comunicação pausada: ${updated.title}');
          return;
        case _NoticeCardAction.resume:
          final updated = await widget.repository.changeStatus(
            notice.id,
            requestId: requestId,
            status: NoticeStatus.scheduled,
            expectedVersion: notice.managementVersion,
          );
          _actionRequestIds.remove(requestKey);
          _refresh('Reativação agendada: ${updated.title}');
          return;
        case _NoticeCardAction.cancel:
          final updated = await widget.repository.changeStatus(
            notice.id,
            requestId: requestId,
            status: NoticeStatus.cancelled,
            expectedVersion: notice.managementVersion,
            reason: cancellationReason,
          );
          _actionRequestIds.remove(requestKey);
          _refresh('Comunicação inativada: ${updated.title}');
          return;
      }
    } on NoticeRepositoryException catch (error) {
      _feedback(error.safeMessage);
    } on Object {
      _feedback(const NoticeUnexpectedException().safeMessage);
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  void _refresh(String message) {
    _feedback(message);
    _load(reset: true);
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

  NoticeDirectoryQuery get _query => NoticeDirectoryQuery(
    search: _search.text.trim().isEmpty ? null : _search.text.trim(),
    types: _typeFilter.type == null ? const {} : {_typeFilter.type!},
    statuses: _statusFilter.status == null ? const {} : {_statusFilter.status!},
    cursorOccurredAt: _currentCursorOccurredAt,
    cursorId: _currentCursorId,
    pageSize: _pageSize,
  );

  bool get _hasActiveQuery =>
      _search.text.trim().isNotEmpty ||
      _statusFilter != _NoticeStatusFilter.all ||
      _typeFilter != _CommunicationTypeFilter.all;

  Future<String?> _requestCancellationReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()?.scrim,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final reason = controller.text.trim();
          return CoeloAdminDialogShell(
            title: 'Inativar aviso',
            body: CoeloFormTextField(
              fieldKey: const Key('notice-inactivate-reason'),
              controller: controller,
              labelText: 'Motivo da inativação',
              hintText: 'Informe o motivo para a trilha de auditoria',
              prefixIcon: Icons.edit_note_rounded,
              maxLines: 3,
              onChanged: (_) => setDialogState(() {}),
            ),
            secondaryAction: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Voltar'),
            ),
            primaryAction: FilledButton(
              key: const Key('notice-inactivate-confirm'),
              onPressed: reason.length >= 3 && reason.length <= 500
                  ? () => Navigator.of(dialogContext).pop(reason)
                  : null,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) return null;
                  if (states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused) ||
                      states.contains(WidgetState.pressed)) {
                    return Theme.of(context).colorScheme.errorContainer;
                  }
                  return Theme.of(context).colorScheme.error;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) return null;
                  if (states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused) ||
                      states.contains(WidgetState.pressed)) {
                    return Theme.of(context).colorScheme.error;
                  }
                  return Theme.of(context).colorScheme.onError;
                }),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
              child: const Text('Inativar aviso'),
            ),
          );
        },
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _load({required bool reset}) async {
    final generation = ++_loadGeneration;
    if (reset) {
      _page = 1;
      _cursorHistory.clear();
      _currentCursorOccurredAt = null;
      _currentCursorId = null;
    }
    if (mounted) {
      setState(() {
        _state = NoticeDirectoryViewState.loading;
        _errorMessage = null;
      });
    }
    try {
      final result = await widget.repository.fetchPage(_query);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _items = result.items;
        _nextCursorOccurredAt = result.nextCursorOccurredAt;
        _nextCursorId = result.nextCursorId;
        _state = NoticeDirectoryViewState.content;
      });
    } on NoticeUnauthorizedException catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _items = const [];
        _errorMessage = error.safeMessage;
        _state = NoticeDirectoryViewState.forbidden;
      });
    } on NoticeRepositoryException catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _items = const [];
        _errorMessage = error.safeMessage;
        _state = NoticeDirectoryViewState.error;
      });
    } on Object {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _items = const [];
        _errorMessage = const NoticeUnexpectedException().safeMessage;
        _state = NoticeDirectoryViewState.error;
      });
    }
  }

  void _nextPage() {
    final nextId = _nextCursorId;
    if (nextId == null) return;
    _cursorHistory.add((_currentCursorOccurredAt, _currentCursorId));
    _currentCursorOccurredAt = _nextCursorOccurredAt;
    _currentCursorId = nextId;
    _page += 1;
    _load(reset: false);
  }

  void _previousPage() {
    if (_cursorHistory.isEmpty) return;
    final previous = _cursorHistory.removeLast();
    _currentCursorOccurredAt = previous.$1;
    _currentCursorId = previous.$2;
    _page -= 1;
    _load(reset: false);
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _requestId() {
    final random = math.Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40;
    values[8] = (values[8] & 0x3f) | 0x80;
    final hex = values.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
