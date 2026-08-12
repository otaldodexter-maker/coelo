import 'dart:async';
import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../domain/notice_repository.dart';
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

enum _NoticeCardAction { edit, publish, pause, resume, cancel }

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
      final contentPadding = compact ? CoeloSpacing.space4 : CoeloSpacing.space6;
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
                    _toolbar(compact: compact),
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
          hintText: 'Buscar aviso',
          semanticLabel: 'Buscar aviso por t\u00edtulo ou destinat\u00e1rio',
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
      title: 'Carregando avisos',
      message: 'Aguarde enquanto os avisos s\u00e3o carregados.',
      loading: true,
    ),
    NoticeDirectoryViewState.error => _stateWithCreate(
      compact: compact,
      state: CoeloStatePanel(
        title: 'N\u00e3o foi poss\u00edvel carregar',
        message: _errorMessage ?? 'N\u00e3o foi poss\u00edvel carregar os avisos.',
        actionLabel: 'Tentar novamente',
        onAction: () => _load(reset: true),
      ),
    ),
    NoticeDirectoryViewState.forbidden => CoeloStatePanel(
      title: 'Sem permiss\u00e3o',
      message: _errorMessage ?? 'Voc\u00ea n\u00e3o tem permiss\u00e3o para ver avisos.',
      icon: Icons.lock_outline_rounded,
    ),
    NoticeDirectoryViewState.content when all.isEmpty && !_hasActiveQuery => _stateWithCreate(
      compact: compact,
      state: const CoeloStatePanel(
        title: 'Nenhum aviso',
        message: 'Ainda n\u00e3o existem avisos cadastrados.',
        icon: Icons.campaign_outlined,
      ),
    ),
    NoticeDirectoryViewState.content when notices.isEmpty => _stateWithCreate(
      compact: compact,
      state: const CoeloStatePanel(
        title: 'Nenhum resultado',
        message: 'Nenhum aviso encontrado com estes filtros.',
        icon: Icons.search_off_rounded,
      ),
    ),
    NoticeDirectoryViewState.content => _cards(context, notices: notices, compact: compact),
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
        mainAxisExtent: 260,
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
      label: 'Novo aviso',
      description: 'Criar novo aviso.',
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
    final actions = <_NoticeCardAction>{};
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
          _refresh('Aviso pausado: ${updated.title}');
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
          _refresh('Aviso inativado: ${updated.title}');
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
    statuses: _statusFilter.status == null ? const {} : {_statusFilter.status!},
    cursorOccurredAt: _currentCursorOccurredAt,
    cursorId: _currentCursorId,
    pageSize: _pageSize,
  );

  bool get _hasActiveQuery =>
      _search.text.trim().isNotEmpty || _statusFilter != _NoticeStatusFilter.all;

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
