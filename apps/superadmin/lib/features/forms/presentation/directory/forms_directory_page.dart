import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import '../../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../../../../shared/presentation/widgets/superadmin_placeholder_file_actions.dart';
import '../../data/development_forms_api.dart';
import 'forms_lifecycle_actions.dart';

enum FormsDirectoryDisplay { table, cards }

enum FormsDirectoryLoadStatus { loading, data, empty, noResults, unauthorized, failure }

final class FormsDirectoryPage extends StatefulWidget {
  const FormsDirectoryPage({
    required this.api,
    this.canManage = false,
    this.canManageLifecycle = false,
    this.canTransferCrossInstitution = false,
    this.onCreate,
    this.onOpen,
    this.onEdit,
    this.onManageSchedules,
    this.onLifecycleCompleted,
    this.visualMetadata = const {},
    super.key,
  });

  final FormsApi? api;
  final bool canManage;
  final bool canManageLifecycle;
  final bool canTransferCrossInstitution;
  final VoidCallback? onCreate;
  final ValueChanged<FormDirectoryItem>? onOpen;
  final ValueChanged<FormDirectoryItem>? onEdit;
  final ValueChanged<FormDirectoryItem>? onManageSchedules;
  final VoidCallback? onLifecycleCompleted;
  final Map<String, DevelopmentFormVisualMetadata> visualMetadata;

  @override
  State<FormsDirectoryPage> createState() => _FormsDirectoryPageState();
}

final class _FormsDirectoryPageState extends State<FormsDirectoryPage> {
  final _search = TextEditingController();
  final _cursors = <String?>[null];
  Set<FormOperationalStatus> _operationalStatuses = {};
  DateTimeRange? _period;
  FormsDirectoryDisplay _display = FormsDirectoryDisplay.table;
  FormsDirectoryLoadStatus _status = FormsDirectoryLoadStatus.loading;
  FormCursorPage<FormDirectoryItem>? _page;
  String? _message;
  int _pageIndex = 0;
  Timer? _searchDebounce;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant FormsDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.api, widget.api)) {
      _searchDebounce?.cancel();
      _loadGeneration++;
      _search.clear();
      _operationalStatuses = {};
      _period = null;
      _page = null;
      _message = null;
      _cursors
        ..clear()
        ..add(null);
      _pageIndex = 0;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = widget.api;
    final generation = ++_loadGeneration;
    if (api == null) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _status = FormsDirectoryLoadStatus.failure;
        _message = 'O serviço de Formulários não está disponível neste ambiente.';
      });
      return;
    }
    final search = _search.text.trim();
    final operationalStatuses = Set<FormOperationalStatus>.of(_operationalStatuses);
    final period = _period;
    final cursor = _cursors[_pageIndex];
    setState(() => _status = FormsDirectoryLoadStatus.loading);
    try {
      final page = await api.listDirectory(
        FormDirectoryQuery(
          search: search.isEmpty ? null : search,
          operationalStatuses: operationalStatuses,
          startsOnOrAfter: period?.start,
          endsOnOrBefore: period?.end,
          cursor: cursor,
        ),
      );
      if (!mounted || generation != _loadGeneration || !identical(api, widget.api)) return;
      setState(() {
        _page = page;
        _status = page.items.isNotEmpty
            ? FormsDirectoryLoadStatus.data
            : (search.isNotEmpty || operationalStatuses.isNotEmpty || period != null)
            ? FormsDirectoryLoadStatus.noResults
            : FormsDirectoryLoadStatus.empty;
      });
    } on FormApiException catch (error) {
      if (!mounted || generation != _loadGeneration || !identical(api, widget.api)) return;
      setState(() {
        _status = error.kind == FormApiFailureKind.unauthorized
            ? FormsDirectoryLoadStatus.unauthorized
            : FormsDirectoryLoadStatus.failure;
        _message = error.message;
      });
    }
  }

  void _resetAndLoad() {
    _cursors
      ..clear()
      ..add(null);
    _pageIndex = 0;
    unawaited(_load());
  }

  void _onSearch(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _resetAndLoad);
  }

  void _next() {
    final cursor = _page?.nextCursor;
    if (cursor == null) return;
    if (_cursors.length == _pageIndex + 1) _cursors.add(cursor);
    _pageIndex++;
    unawaited(_load());
  }

  void _previous() {
    if (_pageIndex == 0) return;
    _pageIndex--;
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final contentPadding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
          ? CoeloSpacing.space10
          : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
          ? CoeloSpacing.space6
          : CoeloSpacing.space4;
      final unauthorized = _status == FormsDirectoryLoadStatus.unauthorized;
      final page = _page;
      final showsPagination =
          _status == FormsDirectoryLoadStatus.data &&
          page != null &&
          (_pageIndex > 0 || page.nextCursor != null);
      return Column(
        children: [
          Expanded(
            child: ListView(
              key: const Key('forms-directory-content-scroll'),
              padding: EdgeInsets.fromLTRB(
                contentPadding,
                contentPadding,
                contentPadding,
                showsPagination ? 0 : contentPadding,
              ),
              children: [
                if (unauthorized)
                  _content(includePagination: false)
                else ...[
                  _toolbar(),
                  const SizedBox(height: CoeloSpacing.space4),
                  _content(includePagination: false),
                ],
              ],
            ),
          ),
          if (showsPagination)
            SuperadminListingPaginationFooter(
              semanticKey: const Key('forms-directory-pagination-footer'),
              horizontalPadding: contentPadding,
              compactCurrentPage: _pageIndex + 1,
              compactTotalPages: page.nextCursor == null ? _pageIndex + 1 : _pageIndex + 2,
              compactOnPrevious: _pageIndex > 0 ? _previous : null,
              compactOnNext: page.nextCursor != null ? _next : null,
              child: CoeloAdminPagination(
                currentPage: _pageIndex + 1,
                totalPages: page.nextCursor == null ? _pageIndex + 1 : _pageIndex + 2,
                onPrevious: _pageIndex > 0 ? _previous : null,
                onNext: page.nextCursor != null ? _next : null,
              ),
            ),
        ],
      );
    },
  );

  Widget _toolbar() => CoeloAdminListingToolbar(
    search: CoeloSearchField(
      key: const Key('forms-directory-search'),
      controller: _search,
      semanticLabel: 'Buscar formulários',
      hintText: 'Buscar formulários',
      onChanged: _onSearch,
    ),
    filters: [
      CoeloAdminMultiSelectField<FormOperationalStatus>(
        label: 'Situação',
        options: FormOperationalStatus.values,
        selectedValues: _operationalStatuses,
        optionLabel: _operationalStatusLabel,
        onChanged: (value) {
          setState(() => _operationalStatuses = value);
          _resetAndLoad();
        },
      ),
      CoeloDateRangeField(
        value: _period,
        onChanged: (value) {
          setState(() => _period = value);
          _resetAndLoad();
        },
        firstDate: DateTime(2020),
        lastDate: DateTime(2100, 12, 31),
      ),
    ],
    actions: [
      const SuperadminPlaceholderFileActions(resourceLabel: 'formulários'),
      SuperadminDirectoryViewToggle<FormsDirectoryDisplay>(
        cardsKey: const Key('forms-directory-view-cards'),
        tableKey: const Key('forms-directory-view-table'),
        cardsSelected: _display == FormsDirectoryDisplay.cards,
        groupedView: FormsDirectoryDisplay.table,
        selectedTableView: FormsDirectoryDisplay.table,
        tableViews: const [
          SuperadminDirectoryTableViewOption(value: FormsDirectoryDisplay.table, label: 'Tabela'),
        ],
        onCardsSelected: () => setState(() => _display = FormsDirectoryDisplay.cards),
        onTableViewSelected: (_) => setState(() => _display = FormsDirectoryDisplay.table),
      ),
    ],
  );

  Widget _content({required bool includePagination}) => switch (_status) {
    FormsDirectoryLoadStatus.loading => const CoeloStatePanel(
      title: 'Carregando formulários',
      message: 'Aguarde enquanto os dados autorizados são carregados.',
      loading: true,
    ),
    FormsDirectoryLoadStatus.empty => _stateWithCreate(
      const CoeloStatePanel(
        title: 'Nenhum formulário disponível',
        message: 'Não há formulários para consultar neste escopo.',
        icon: Icons.dynamic_form_outlined,
      ),
    ),
    FormsDirectoryLoadStatus.noResults => _stateWithCreate(
      CoeloStatePanel(
        title: 'Nenhum resultado',
        message: 'Ajuste a busca, o status ou o período.',
        icon: Icons.search_off_rounded,
        actionLabel: 'Limpar filtros',
        onAction: () {
          _search.clear();
          setState(() {
            _operationalStatuses = {};
            _period = null;
          });
          _resetAndLoad();
        },
      ),
    ),
    FormsDirectoryLoadStatus.unauthorized => const CoeloStatePanel(
      title: 'Acesso não autorizado',
      message: 'Seu perfil não possui forms.read neste escopo.',
      icon: Icons.lock_outline_rounded,
    ),
    FormsDirectoryLoadStatus.failure => _stateWithCreate(
      CoeloStatePanel(
        title: 'Não foi possível carregar os formulários',
        message: _message ?? 'Tente novamente.',
        icon: Icons.error_outline_rounded,
        actionLabel: 'Tentar novamente',
        onAction: _load,
      ),
    ),
    FormsDirectoryLoadStatus.data => FormsDirectoryResults(
      page: _page!,
      display: _display,
      canManage: widget.canManage,
      canManageLifecycle:
          widget.canManageLifecycle || (widget.canManage && widget.api is DevelopmentFormsApi),
      canTransferCrossInstitution:
          widget.canTransferCrossInstitution ||
          (widget.canManage && widget.api is DevelopmentFormsApi),
      api: widget.api,
      pageNumber: _pageIndex + 1,
      onPrevious: _pageIndex > 0 ? _previous : null,
      onNext: _page!.nextCursor != null ? _next : null,
      includePagination: includePagination,
      onCreate: widget.onCreate,
      onOpen: widget.onOpen,
      onEdit: widget.onEdit,
      onManageSchedules: widget.onManageSchedules,
      onLifecycleCompleted: _resetAndLoad,
      visualMetadata: widget.visualMetadata,
    ),
  };

  Widget _stateWithCreate(Widget state) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.canManage && widget.onCreate != null) ...[
        CoeloAdminCreateAction(
          key: const Key('forms-directory-create'),
          label: 'Novo formulário',
          description: 'Criar e configurar um formulário.',
          variant: CoeloAdminCreateActionVariant.banner,
          onPressed: widget.onCreate,
        ),
        const SizedBox(height: CoeloSpacing.space4),
      ],
      state,
    ],
  );
}

final class FormsDirectoryResults extends StatelessWidget {
  const FormsDirectoryResults({
    required this.page,
    required this.display,
    required this.canManage,
    this.canManageLifecycle = false,
    this.canTransferCrossInstitution = false,
    this.api,
    required this.pageNumber,
    this.onPrevious,
    this.onNext,
    this.onCreate,
    this.onOpen,
    this.onEdit,
    this.onManageSchedules,
    this.onLifecycleCompleted,
    this.includePagination = true,
    this.visualMetadata = const {},
    super.key,
  });

  final FormCursorPage<FormDirectoryItem> page;
  final FormsDirectoryDisplay display;
  final bool canManage;
  final bool canManageLifecycle;
  final bool canTransferCrossInstitution;
  final FormsApi? api;
  final int pageNumber;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onCreate;
  final ValueChanged<FormDirectoryItem>? onOpen;
  final ValueChanged<FormDirectoryItem>? onEdit;
  final ValueChanged<FormDirectoryItem>? onManageSchedules;
  final VoidCallback? onLifecycleCompleted;
  final bool includePagination;
  final Map<String, DevelopmentFormVisualMetadata> visualMetadata;

  DevelopmentFormVisualMetadata? _visualMetadata(FormDirectoryItem item) =>
      visualMetadata[item.id] ?? developmentFormVisualMetadata(item.id);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (display == FormsDirectoryDisplay.cards)
        _cards(context)
      else ...[
        if (canManage) ...[
          CoeloAdminCreateAction(
            key: const Key('forms-directory-create'),
            label: 'Novo formulário',
            description: 'Criar e configurar um formulário.',
            variant: CoeloAdminCreateActionVariant.banner,
            onPressed: onCreate,
          ),
          const SizedBox(height: CoeloSpacing.space4),
        ],
        _table(context),
      ],
      if (includePagination && (onPrevious != null || onNext != null))
        Padding(
          padding: const EdgeInsets.only(top: CoeloSpacing.space5),
          child: CoeloAdminPagination(
            currentPage: pageNumber,
            totalPages: onNext == null ? pageNumber : pageNumber + 1,
            onPrevious: onPrevious,
            onNext: onNext,
          ),
        ),
    ],
  );

  Widget _cards(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1100
          ? 3
          : constraints.maxWidth >= 680
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space6) / columns;
      return Wrap(
        key: const Key('forms-directory-card-grid'),
        spacing: CoeloSpacing.space6,
        runSpacing: CoeloSpacing.space6,
        children: [
          if (canManage)
            SizedBox(
              width: width,
              height: 216,
              child: CoeloAdminCreateAction(
                key: const Key('forms-directory-create'),
                label: 'Novo formulário',
                variant: CoeloAdminCreateActionVariant.tile,
                onPressed: onCreate,
              ),
            ),
          for (final item in page.items)
            SizedBox(
              width: width,
              child: CoeloAdminInteractiveCard(
                key: Key('forms-directory-card-${item.id}'),
                surfaceKey: Key('forms-directory-card-surface-${item.id}'),
                minHeight: 216,
                onPressed: onOpen == null ? null : () => onOpen!(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoeloSpacing.space6,
                    vertical: CoeloSpacing.space4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(item.title, style: Theme.of(context).textTheme.titleMedium),
                          ),
                          const SizedBox(width: CoeloSpacing.space2),
                          _FormOperationalStatusIndicator(item: item),
                        ],
                      ),
                      const SizedBox(height: CoeloSpacing.space3),
                      Text(_kindLabel(item.kind)),
                      const SizedBox(height: CoeloSpacing.space4),
                      Text('Atualizado em ${_shortDate(item.updatedAt)}'),
                      if (canManageLifecycle || onManageSchedules != null) ...[
                        const SizedBox(height: CoeloSpacing.space2),
                        Align(alignment: Alignment.centerRight, child: _actions(item)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _table(BuildContext context) => CoeloAdminResizableTable<FormDirectoryItem>(
    items: page.items,
    rowKey: (item) => item.id,
    pinnedColumn: CoeloAdminTableColumn(
      id: 'title',
      label: 'Nome',
      initialWidth: 228,
      minWidth: 200,
      maxWidth: 360,
      cellBuilder: (_, item) => Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
    ),
    columns: [
      CoeloAdminTableColumn(
        id: 'status',
        label: 'Situação',
        initialWidth: 132,
        minWidth: 110,
        maxWidth: 180,
        cellBuilder: (_, item) => _FormOperationalStatusChip(status: item.operationalStatus),
      ),
      CoeloAdminTableColumn(
        id: 'context',
        label: 'Contexto',
        initialWidth: 160,
        minWidth: 150,
        maxWidth: 280,
        cellBuilder: (_, item) => Text(_visualMetadata(item)?.contextLabel ?? '—'),
      ),
      CoeloAdminTableColumn(
        id: 'audience',
        label: 'Público',
        initialWidth: 140,
        minWidth: 140,
        maxWidth: 240,
        cellBuilder: (_, item) => Text(_visualMetadata(item)?.audienceLabel ?? '—'),
      ),
      CoeloAdminTableColumn(
        id: 'responses',
        label: 'Respostas',
        initialWidth: 104,
        minWidth: 104,
        maxWidth: 160,
        cellBuilder: (_, item) => Text(_visualMetadata(item)?.responseCount.toString() ?? '—'),
      ),
      CoeloAdminTableColumn(
        id: 'schedules',
        label: 'Agendamentos',
        initialWidth: 130,
        minWidth: 130,
        maxWidth: 190,
        cellBuilder: (_, item) => Text(_visualMetadata(item)?.scheduleCount.toString() ?? '—'),
      ),
      CoeloAdminTableColumn(
        id: 'created',
        label: 'Criado em',
        initialWidth: 128,
        minWidth: 128,
        maxWidth: 190,
        cellBuilder: (_, item) {
          final createdAt = _visualMetadata(item)?.createdAt;
          return Text(createdAt == null ? '—' : _shortDate(createdAt));
        },
      ),
      if (canManageLifecycle || onManageSchedules != null)
        CoeloAdminTableColumn(
          id: 'actions',
          label: 'Ações',
          initialWidth: 72,
          minWidth: 72,
          maxWidth: 72,
          cellBuilder: (_, item) => Align(alignment: Alignment.center, child: _actions(item)),
        ),
    ],
    headerHeight: 56,
    rowHeight: 64,
    onRowPressed: onOpen,
  );

  Widget _actions(FormDirectoryItem item) => FormsLifecycleActions(
    api: api,
    formId: item.id,
    formTitle: item.title,
    managementVersion: item.managementVersion,
    canManage: canManageLifecycle,
    canTransferCrossInstitution: canTransferCrossInstitution,
    onEdit: onEdit == null ? null : () => onEdit!(item),
    onManageSchedules: onManageSchedules == null ? null : () => onManageSchedules!(item),
    onCompleted: onLifecycleCompleted,
  );
}

final class _FormOperationalStatusIndicator extends StatelessWidget {
  const _FormOperationalStatusIndicator({required this.item});

  final FormDirectoryItem item;

  @override
  Widget build(BuildContext context) {
    final label = _operationalStatusLabel(item.operationalStatus);
    final (background, foreground) = _operationalStatusColors(context, item.operationalStatus);
    return CoeloAdminExpandableStatusIndicator(
      label: label,
      backgroundColor: background,
      foregroundColor: foreground,
      semanticLabel: 'Status: $label',
      surfaceKey: Key('forms-directory-card-status-${item.id}'),
    );
  }
}

final class _FormOperationalStatusChip extends StatelessWidget {
  const _FormOperationalStatusChip({required this.status});

  final FormOperationalStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _operationalStatusColors(context, status);
    return CoeloStatusChip(
      label: _operationalStatusLabel(status),
      backgroundColor: background,
      foregroundColor: foreground,
    );
  }
}

(Color, Color) _operationalStatusColors(BuildContext context, FormOperationalStatus status) {
  final colors =
      Theme.of(context).extension<CoeloStatusColors>() ??
      (Theme.brightnessOf(context) == Brightness.dark
          ? CoeloStatusColors.dark
          : CoeloStatusColors.light);
  return switch (status) {
    FormOperationalStatus.draft => (colors.historyContainer, colors.onHistoryContainer),
    FormOperationalStatus.scheduled => (colors.warningContainer, colors.onWarningContainer),
    FormOperationalStatus.active => (colors.successContainer, colors.onSuccessContainer),
    FormOperationalStatus.closed => (colors.infoContainer, colors.onInfoContainer),
    FormOperationalStatus.archived => (colors.historyContainer, colors.onHistoryContainer),
  };
}

String _operationalStatusLabel(FormOperationalStatus status) => switch (status) {
  FormOperationalStatus.draft => 'Rascunho',
  FormOperationalStatus.scheduled => 'Programado',
  FormOperationalStatus.active => 'Ativo',
  FormOperationalStatus.closed => 'Encerrado',
  FormOperationalStatus.archived => 'Arquivado',
};

String _kindLabel(FormKind kind) => kind == FormKind.quickPoll ? 'Enquete rápida' : 'Formulário';
String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

@Preview(name: 'Formulários · diretório · desktop', size: Size(1440, 900))
Widget formsDirectoryDesktopPreview() => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      child: FormsDirectoryResults(
        page: FormCursorPage(items: _previewForms, nextCursor: 'next'),
        display: FormsDirectoryDisplay.table,
        canManage: true,
        pageNumber: 1,
        onNext: () {},
      ),
    ),
  ),
);

@Preview(name: 'Formulários · cards · compacto dark', size: Size(375, 760))
Widget formsDirectoryCompactDarkPreview() => MaterialApp(
  theme: CoeloTheme.dark,
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: FormsDirectoryResults(
        page: FormCursorPage(items: _previewForms, nextCursor: null),
        display: FormsDirectoryDisplay.cards,
        canManage: true,
        pageNumber: 1,
      ),
    ),
  ),
);

final _previewForms = [
  FormDirectoryItem(
    id: 'form-1',
    title: 'Autorização para passeio',
    kind: FormKind.form,
    status: FormStatus.published,
    operationalStatus: FormOperationalStatus.scheduled,
    identityMode: FormIdentityMode.identified,
    updatedAt: DateTime(2026, 8, 13),
    managementVersion: 4,
  ),
  FormDirectoryItem(
    id: 'form-2',
    title: 'Como foi a semana?',
    kind: FormKind.quickPoll,
    status: FormStatus.draft,
    operationalStatus: FormOperationalStatus.draft,
    identityMode: FormIdentityMode.anonymous,
    updatedAt: DateTime(2026, 8, 12),
    managementVersion: 2,
  ),
];
