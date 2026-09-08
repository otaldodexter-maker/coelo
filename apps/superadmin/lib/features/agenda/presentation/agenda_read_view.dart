import 'dart:async';
import 'dart:math' as math;
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../domain/agenda_models.dart';
import '../domain/agenda_read_repository.dart';
import 'agenda_read_controller.dart';

/// Isolated read projection. No routing, command repository or legacy DTO bridge.
final class AgendaReadView extends StatefulWidget {
  const AgendaReadView({
    required this.controller,
    required this.from,
    required this.to,
    this.institutionId,
    super.key,
  });
  final AgendaReadController controller;
  final DateTime from, to;
  final String? institutionId;
  @override
  State<AgendaReadView> createState() => _AgendaReadViewState();
}

final class _AgendaReadViewState extends State<AgendaReadView> {
  final _search = TextEditingController();
  final _footerKey = GlobalKey();
  final _cardContexts = <String, BuildContext>{};
  String? _openedId;
  int _boundary = 0, _loadEpoch = 0, _pageSize = 11;
  double _footerHeight = 0;
  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _boundary = widget.controller.boundaryRevision;
    widget.controller.addListener(_changed);
    _scheduleLoad();
  }

  void _changed() {
    if (_boundary == widget.controller.boundaryRevision) return;
    _boundary = widget.controller.boundaryRevision;
    _search.clear();
    _cardContexts.clear();
    _openedId = null;
    _pageSize = 11;
    _loadEpoch++;
    if (widget.controller.pageStatus == AgendaProjectionStatus.idle) _scheduleLoad();
  }

  void _scheduleLoad() {
    final generation = ++_loadEpoch;
    final source = widget.controller;
    final revision = source.boundaryRevision;
    scheduleMicrotask(() {
      if (!mounted ||
          generation != _loadEpoch ||
          !identical(source, widget.controller) ||
          source.boundaryRevision != revision) {
        return;
      }
      _load();
    });
  }

  void _load({int offset = 0}) {
    _cardContexts.clear();
    _openedId = null;
    unawaited(
      widget.controller.loadPage(
        from: widget.from,
        to: widget.to,
        institutionId: widget.institutionId,
        search: _search.text,
        limit: _pageSize,
        offset: offset,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant AgendaReadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_changed);
      _search.clear();
      _cardContexts.clear();
      _openedId = null;
      _pageSize = 11;
      _attach();
    } else if (oldWidget.from != widget.from ||
        oldWidget.to != widget.to ||
        oldWidget.institutionId != widget.institutionId) {
      _search.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _loadEpoch++;
    widget.controller.removeListener(_changed);
    _cardContexts.clear();
    _search.dispose();
    _openedId = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const Key('agenda-read-surface'),
    color: Theme.of(context).colorScheme.surface,
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
              ? CoeloSpacing.space10
              : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
              ? CoeloSpacing.space6
              : CoeloSpacing.space4;
          final controller = widget.controller;
          if (controller.pageStatus == AgendaProjectionStatus.unauthorized) {
            return ListView(
              padding: EdgeInsets.all(inset),
              children: [_state(controller.pageStatus)],
            );
          }
          if (controller.detailStatus != AgendaProjectionStatus.idle) {
            return _detailView(context, inset);
          }
          final page = controller.page;
          final showFooter = page != null && page.total > 0 && page.items.isNotEmpty;
          if (showFooter) _measureFooter();
          return Stack(
            fit: StackFit.expand,
            children: [
              ListView(
                key: const Key('agenda-read-scroll'),
                padding: EdgeInsets.fromLTRB(
                  inset,
                  inset,
                  inset,
                  inset + (showFooter ? _footerHeight + CoeloSpacing.space4 : 0),
                ),
                children: [
                  Text('Eventos', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: CoeloSpacing.space1),
                  const Text('Consulta de Agenda · Somente leitura'),
                  const SizedBox(height: CoeloSpacing.space4),
                  CoeloAdminListingToolbar(
                    search: CoeloSearchField(
                      controller: _search,
                      semanticLabel: 'Buscar eventos da Agenda',
                      hintText: 'Buscar por título ou descrição',
                      onChanged: (_) => _load(),
                    ),
                    filters: const [],
                    actions: const [],
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  if (controller.pageStatus == AgendaProjectionStatus.ready && page != null)
                    _cards(page.items)
                  else
                    _state(controller.pageStatus),
                ],
              ),
              if (showFooter)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: NotificationListener<SizeChangedLayoutNotification>(
                    onNotification: (_) {
                      _measureFooter();
                      return false;
                    },
                    child: SizeChangedLayoutNotifier(
                      key: _footerKey,
                      child: _pagination(page, inset),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );

  void _measureFooter() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = _footerKey.currentContext?.size;
      if (size != null && size.height != _footerHeight) {
        setState(() => _footerHeight = size.height);
      }
    });
  }

  Widget _pagination(AgendaReadPage page, double inset) {
    final totalPages = math.max(1, (page.total / page.limit).ceil());
    final current = math.min(totalPages, page.offset ~/ page.limit + 1);
    void select(int number) => _load(offset: (number - 1) * page.limit);
    final previous = current > 1 ? () => select(current - 1) : null;
    final next = current < totalPages ? () => select(current + 1) : null;
    return SuperadminListingPaginationFooter(
      horizontalPadding: inset,
      compactCurrentPage: current,
      compactTotalPages: totalPages,
      compactOnPrevious: previous,
      compactOnNext: next,
      child: CoeloAdminPagination(
        currentPage: current,
        totalPages: totalPages,
        onPrevious: previous,
        onNext: next,
        onPageSelected: select,
        pageSize: page.limit,
        pageSizeOptions: const [11, 20, 50, 100],
        onPageSizeChanged: (value) {
          _pageSize = value;
          _load();
        },
      ),
    );
  }

  Widget _cards(List<AgendaReadItem> items) => LayoutBuilder(
    builder: (context, constraints) {
      // Institutions' approved grid dimensions, not a new card anatomy.
      final columns = math.max(1, (constraints.maxWidth / 340).floor());
      final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space6) / columns;
      return Wrap(
        spacing: CoeloSpacing.space6,
        runSpacing: CoeloSpacing.space6,
        children: [
          for (final item in items)
            SizedBox(
              width: width,
              child: CoeloAdminInteractiveCard(
                minHeight: 216,
                key: Key('agenda-read-item-${item.id}'),
                onPressed: () {
                  _openedId = item.id;
                  unawaited(widget.controller.openDetail(item.id));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoeloSpacing.space6,
                    vertical: CoeloSpacing.space4,
                  ),
                  child: Builder(
                    builder: (cardContext) {
                      _cardContexts[item.id] = cardContext;
                      return _summary(item, card: true);
                    },
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
  Widget _summary(AgendaReadItem item, {bool card = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(item.title, style: Theme.of(context).textTheme.titleMedium)),
          if (card) ...[const SizedBox(width: CoeloSpacing.space2), _indicator(item)],
        ],
      ),
      const SizedBox(height: CoeloSpacing.space2),
      Text(card ? item.type.label : '${item.type.label} · ${_status(item.status)}'),
      const SizedBox(height: CoeloSpacing.space2),
      Text('${_date(item.startsAt)} — ${_date(item.endsAt)} (UTC)'),
      const SizedBox(height: CoeloSpacing.space2),
      Text(item.location.isEmpty ? 'Local não informado' : item.location),
    ],
  );

  Widget _indicator(AgendaReadItem item) {
    final colors =
        Theme.of(context).extension<CoeloStatusColors>() ??
        (Theme.brightnessOf(context) == Brightness.dark
            ? CoeloStatusColors.dark
            : CoeloStatusColors.light);
    final (background, foreground) = switch (item.status) {
      AgendaItemStatus.draft => (colors.historyContainer, colors.onHistoryContainer),
      AgendaItemStatus.scheduled => (colors.warningContainer, colors.onWarningContainer),
      AgendaItemStatus.published => (colors.successContainer, colors.onSuccessContainer),
      AgendaItemStatus.canceled => (colors.errorContainer, colors.onErrorContainer),
    };
    return CoeloAdminExpandableStatusIndicator(
      label: _status(item.status),
      semanticLabel: 'Status: ${_status(item.status)}',
      backgroundColor: background,
      foregroundColor: foreground,
    );
  }

  Widget _state(AgendaProjectionStatus status, {bool detail = false}) {
    final page = widget.controller.page;
    if (!detail &&
        status == AgendaProjectionStatus.empty &&
        page != null &&
        (page.offset > 0 || page.total > 0)) {
      return CoeloStatePanel(
        title: 'Esta página não possui mais itens',
        message: 'A lista mudou. Consulte novamente a primeira página.',
        icon: Icons.event_note_outlined,
        actionLabel: 'Voltar à primeira página',
        onAction: () => _load(),
      );
    }
    final (title, message, icon) = switch (status) {
      AgendaProjectionStatus.loading => ('Carregando Agenda', '', Icons.event_outlined),
      AgendaProjectionStatus.unauthorized => (
        'Acesso à Agenda negado',
        'A sessão não pode consultar estes dados.',
        Icons.lock_outline,
      ),
      AgendaProjectionStatus.notFound => (
        'Item não encontrado',
        'O item não existe ou não pode ser revelado.',
        Icons.event_busy_outlined,
      ),
      AgendaProjectionStatus.empty => (
        'Nenhum item encontrado',
        'A consulta não retornou eventos neste período.',
        Icons.event_note_outlined,
      ),
      AgendaProjectionStatus.failure => (
        'Não foi possível carregar a Agenda',
        'Tente novamente para consultar dados atualizados.',
        Icons.cloud_off_outlined,
      ),
      _ => (
        'Consultar Agenda',
        'Carregue os dados autorizados para este período.',
        Icons.event_outlined,
      ),
    };
    return Semantics(
      liveRegion: true,
      label: status == AgendaProjectionStatus.loading ? title : null,
      child: CoeloStatePanel(
        title: title,
        message: message,
        icon: icon,
        loading: status == AgendaProjectionStatus.loading,
        actionLabel: status == AgendaProjectionStatus.failure ? 'Tentar novamente' : null,
        onAction: status == AgendaProjectionStatus.failure
            ? () => unawaited(
                detail ? widget.controller.retryDetail() : widget.controller.retryPage(),
              )
            : null,
      ),
    );
  }

  Widget _detailView(BuildContext context, double inset) {
    final result = widget.controller.detail;
    return ListView(
      key: const Key('agenda-read-detail'),
      padding: EdgeInsets.all(inset),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _returnToList,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Eventos'),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        if (result == null)
          _state(widget.controller.detailStatus, detail: true)
        else ...[
          _summary(result.item),
          const SizedBox(height: CoeloSpacing.space6),
          _section('Descrição', [
            Text(
              result.item.description.isEmpty
                  ? 'Nenhuma descrição informada.'
                  : result.item.description,
            ),
          ]),
          const SizedBox(height: CoeloSpacing.space4),
          _section('Contexto e audiência', [
            Text(_contextName(result.item)),
            const SizedBox(height: CoeloSpacing.space2),
            const Text('Detalhes individuais da audiência indisponíveis nesta consulta.'),
          ]),
          const SizedBox(height: CoeloSpacing.space4),
          _section('Agenda e respostas', [
            Text('Fuso cadastrado: ${result.item.timeZoneId}. Horários acima em UTC.'),
            Text(result.item.recurrence == null ? 'Sem recorrência.' : 'Evento recorrente.'),
            const Text('Respostas individuais não fazem parte desta consulta.'),
          ]),
          const SizedBox(height: CoeloSpacing.space4),
          _section('Histórico', [
            if (result.item.history == null)
              const Text('Histórico não consultado.')
            else if (result.item.history!.isEmpty)
              const Text('Nenhuma alteração registrada.')
            else
              for (final entry in result.item.history!)
                Text(
                  '${_history(entry.action)} · ${_date(entry.occurredAt)} UTC${entry.reason == null ? '' : ' · ${entry.reason}'}',
                ),
          ]),
        ],
      ],
    );
  }

  String _contextName(AgendaReadItem item) {
    for (final value in widget.controller.contexts?.contexts ?? <AgendaReadContext>[]) {
      if (value.id == item.contextId && value.institutionId == item.institutionId) {
        return value.name;
      }
    }
    return 'Contexto não disponível nesta consulta.';
  }

  void _returnToList() {
    final source = widget.controller;
    final id = _openedId ?? source.detail?.item.id;
    _openedId = null;
    final revision = source.boundaryRevision;
    source.closeDetail();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          !identical(source, widget.controller) ||
          source.boundaryRevision != revision ||
          source.detailStatus != AgendaProjectionStatus.idle) {
        return;
      }
      final cardContext = _cardContexts[id];
      if (cardContext == null || !cardContext.mounted) return;
      await Scrollable.ensureVisible(cardContext);
      if (!mounted ||
          !cardContext.mounted ||
          !identical(source, widget.controller) ||
          source.boundaryRevision != revision ||
          source.detailStatus != AgendaProjectionStatus.idle) {
        return;
      }
      Focus.maybeOf(cardContext)?.requestFocus();
    });
  }

  Widget _section(String title, List<Widget> children) => CoeloAdminInteractiveCard(
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: CoeloSpacing.space3),
          ...children,
        ],
      ),
    ),
  );
}

String _date(DateTime value) {
  final utc = value.toUtc();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(utc.day)}/${two(utc.month)}/${utc.year} ${two(utc.hour)}:${two(utc.minute)}';
}

String _status(AgendaItemStatus value) => switch (value) {
  AgendaItemStatus.draft => 'Rascunho',
  AgendaItemStatus.scheduled => 'Programado',
  AgendaItemStatus.published => 'Publicado',
  AgendaItemStatus.canceled => 'Cancelado',
};
String _history(String action) => switch (action) {
  'create' => 'Criação',
  'update' => 'Atualização',
  'cancel' => 'Cancelamento',
  'restore' => 'Restauração',
  'delete_draft' => 'Exclusão de rascunho',
  'request_publication' => 'Solicitação de publicação',
  'approve_publication' => 'Publicação aprovada',
  'reject_publication' => 'Publicação recusada',
  'approve_guardian_request' => 'Solicitação aprovada',
  'reject_guardian_request' => 'Solicitação recusada',
  'override_reservation' => 'Exceção de reserva',
  _ => 'Alteração registrada',
};
