import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../../../shared/presentation/widgets/superadmin_placeholder_file_actions.dart';
import '../../data/development_forms_api.dart';
import '../../data/forms_editor_context.dart';
import '../../data/forms_directory_reader.dart';
import 'forms_lifecycle_actions.dart';

enum FormsDirectoryLoadStatus { loading, data, empty, noResults, unauthorized, failure }

final class FormsDirectoryPage extends StatefulWidget {
  const FormsDirectoryPage({
    required this.api,
    this.reader,
    this.canManage = false,
    this.canManageLifecycle = false,
    this.canTransferCrossInstitution = false,
    this.onCreate,
    this.onOpen,
    this.onEdit,
    this.onManageSchedules,
    this.onResponses,
    this.onLifecycleCompleted,
    this.visualMetadata = const {},
    super.key,
  });

  final FormsApi? api;
  final FormsDirectoryReader? reader;
  final bool canManage;
  final bool canManageLifecycle;
  final bool canTransferCrossInstitution;
  final VoidCallback? onCreate;
  final ValueChanged<FormDirectoryItem>? onOpen;
  final ValueChanged<FormDirectoryItem>? onEdit;
  final ValueChanged<FormDirectoryItem>? onManageSchedules;
  final ValueChanged<FormDirectoryItem>? onResponses;
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
  CoeloAdminDirectoryDisplay _display = CoeloAdminDirectoryDisplay.table;
  FormsDirectoryLoadStatus _status = FormsDirectoryLoadStatus.loading;
  FormCursorPage<FormDirectoryItem>? _page;
  String? _message;
  int _pageIndex = 0;
  Timer? _searchDebounce;
  int _loadGeneration = 0;
  int _contextGeneration = 0;
  FormsEditorContext? _authorizedContext;

  bool get _canManage =>
      widget.reader == null &&
      (widget.canManage ||
          (_authorizedContext?.institutions.any((institution) => institution.canManageForms) ??
              false));
  bool get _canManageLifecycle =>
      widget.reader == null &&
      (widget.canManageLifecycle ||
          (_authorizedContext?.institutions.any((institution) => institution.canManageForms) ??
              false));
  bool get _canTransferCrossInstitution =>
      widget.reader == null &&
      (widget.canTransferCrossInstitution ||
          (_authorizedContext?.canTransferCrossInstitution ?? false));

  @override
  void initState() {
    super.initState();
    unawaited(_loadAuthorizedContext());
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant FormsDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.api, widget.api) || !identical(oldWidget.reader, widget.reader)) {
      _searchDebounce?.cancel();
      _loadGeneration++;
      _contextGeneration++;
      _search.clear();
      _operationalStatuses = {};
      _period = null;
      _page = null;
      _message = null;
      _cursors
        ..clear()
        ..add(null);
      _pageIndex = 0;
      _authorizedContext = null;
      unawaited(_loadAuthorizedContext());
      unawaited(_load());
    }
  }

  Future<void> _loadAuthorizedContext() async {
    final api = widget.api;
    final generation = _contextGeneration;
    if (widget.reader != null || api is! FormsEditorContextApi) return;
    try {
      final authorizedContext = await (api as FormsEditorContextApi).getEditorContext();
      if (mounted &&
          generation == _contextGeneration &&
          widget.reader == null &&
          identical(api, widget.api)) {
        setState(() => _authorizedContext = authorizedContext);
      }
    } on FormApiException {
      // Directory reads keep their own explicit unauthorized/error state.
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _contextGeneration++;
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = widget.api;
    final reader = widget.reader;
    final generation = ++_loadGeneration;
    if (api == null && reader == null) {
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
      final query = FormDirectoryQuery(
        search: search.isEmpty ? null : search,
        operationalStatuses: operationalStatuses,
        startsOnOrAfter: period?.start,
        endsOnOrBefore: period?.end,
        cursor: cursor,
      );
      final page = await (reader != null ? reader.listDirectory(query) : api!.listDirectory(query));
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(api, widget.api) ||
          !identical(reader, widget.reader)) {
        return;
      }
      setState(() {
        _page = page;
        _status = page.items.isNotEmpty
            ? FormsDirectoryLoadStatus.data
            : (search.isNotEmpty || operationalStatuses.isNotEmpty || period != null)
            ? FormsDirectoryLoadStatus.noResults
            : FormsDirectoryLoadStatus.empty;
      });
    } on FormApiException catch (error) {
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(api, widget.api) ||
          !identical(reader, widget.reader)) {
        return;
      }
      setState(() {
        _page = null;
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

  void _clearFilters() {
    _search.clear();
    setState(() {
      _operationalStatuses = {};
      _period = null;
    });
    _resetAndLoad();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final showsPagination =
        _status == FormsDirectoryLoadStatus.data &&
        page != null &&
        (_pageIndex > 0 || page.nextCursor != null);
    final canCreate = _canManage && widget.onCreate != null;
    final canManageLifecycle =
        _canManageLifecycle || (_canManage && widget.api is DevelopmentFormsApi);
    final canTransferCrossInstitution =
        _canTransferCrossInstitution || (_canManage && widget.api is DevelopmentFormsApi);
    final api = widget.reader == null ? widget.api : null;
    final onManageSchedules = widget.reader == null ? widget.onManageSchedules : null;
    final items = page?.items ?? const <FormDirectoryItem>[];
    final showsActions =
        canManageLifecycle || onManageSchedules != null || widget.onResponses != null;

    Widget actions(FormDirectoryItem item) => FormsLifecycleActions(
      api: api,
      formId: item.id,
      formTitle: item.title,
      managementVersion: item.managementVersion,
      canManage: canManageLifecycle,
      canTransferCrossInstitution: canTransferCrossInstitution,
      onEdit: widget.onEdit == null ? null : () => widget.onEdit!(item),
      onManageSchedules: onManageSchedules == null ? null : () => onManageSchedules(item),
      onResponses: widget.onResponses == null ? null : () => widget.onResponses!(item),
      onCompleted: _resetAndLoad,
    );

    return CoeloAdminDirectory<CoeloAdminDirectoryDisplay>(
      scrollKey: const Key('forms-directory-content-scroll'),
      cardsKey: const Key('forms-directory-view-cards'),
      tableKey: const Key('forms-directory-view-table'),
      gridKey: const Key('forms-directory-card-grid'),
      status: switch (_status) {
        FormsDirectoryLoadStatus.loading => CoeloAdminDirectoryStatus.loading,
        FormsDirectoryLoadStatus.data => CoeloAdminDirectoryStatus.success,
        FormsDirectoryLoadStatus.empty => CoeloAdminDirectoryStatus.empty,
        FormsDirectoryLoadStatus.noResults => CoeloAdminDirectoryStatus.noResults,
        FormsDirectoryLoadStatus.unauthorized => CoeloAdminDirectoryStatus.unauthorized,
        FormsDirectoryLoadStatus.failure => CoeloAdminDirectoryStatus.failure,
      },
      messages: const CoeloAdminDirectoryMessages(
        empty: 'Nenhum formulário disponível',
        emptyIcon: Icons.dynamic_form_outlined,
        noResults: 'Nenhum resultado',
        noResultsIcon: Icons.search_off_rounded,
        failure: 'Não foi possível carregar os formulários',
        failureIcon: Icons.error_outline_rounded,
        unauthorized: 'Acesso não autorizado',
        unauthorizedIcon: Icons.lock_outline_rounded,
      ),
      errorMessage: switch (_status) {
        FormsDirectoryLoadStatus.failure => _message,
        FormsDirectoryLoadStatus.unauthorized => 'Seu perfil não possui forms.read neste escopo.',
        _ => null,
      },
      onRetry: _load,
      onClearFilters: _clearFilters,
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
        SizedBox(
          width: 240,
          child: CoeloDateRangeField(
            value: _period,
            onChanged: (value) {
              setState(() => _period = value);
              _resetAndLoad();
            },
            firstDate: DateTime(2020),
            lastDate: DateTime(2100, 12, 31),
          ),
        ),
      ],
      display: _display,
      onDisplayChanged: (value) => setState(() => _display = value),
      groupedTableView: CoeloAdminDirectoryDisplay.table,
      selectedTableView: CoeloAdminDirectoryDisplay.table,
      tableViews: const [
        CoeloAdminDirectoryTableViewOption(
          value: CoeloAdminDirectoryDisplay.table,
          label: 'Tabela',
        ),
      ],
      onTableViewSelected: (_) => setState(() => _display = CoeloAdminDirectoryDisplay.table),
      fileActions: superadminPlaceholderFileActionList(context, 'formulários'),
      create: canCreate
          ? CoeloAdminDirectoryCreate(
              label: 'Criar formulário',
              description: 'Criar e configurar um formulário.',
              icon: Icons.dynamic_form_outlined,
              onPressed: widget.onCreate!,
              tileKey: const Key('forms-directory-create'),
              bannerKey: const Key('forms-directory-create'),
            )
          : null,
      cards: [
        for (final item in items)
          _FormCard(
            item: item,
            metadata: _visualMetadataFor(item),
            onOpen: widget.onOpen,
            actions: showsActions ? actions(item) : null,
          ),
      ],
      table: _FormTableRows(
        items: items,
        metadataFor: _visualMetadataFor,
        onOpen: widget.onOpen,
        actions: showsActions ? actions : null,
      ),
      pagination: showsPagination
          ? CoeloAdminDirectoryPagination(
              footerKey: const Key('forms-directory-pagination-footer'),
              currentPage: _pageIndex + 1,
              totalPages: page.nextCursor == null ? _pageIndex + 1 : _pageIndex + 2,
              onPageSelected: (value) => value > _pageIndex + 1 ? _next() : _previous(),
            )
          : null,
    );
  }

  DevelopmentFormVisualMetadata? _visualMetadataFor(FormDirectoryItem item) =>
      widget.visualMetadata[item.id] ?? developmentFormVisualMetadata(item.id);
}

/// Card de domínio de um formulário; largura, grade e o Criar vêm do composto.
final class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.item,
    required this.metadata,
    required this.onOpen,
    required this.actions,
  });

  final FormDirectoryItem item;
  final DevelopmentFormVisualMetadata? metadata;
  final ValueChanged<FormDirectoryItem>? onOpen;
  final Widget? actions;

  @override
  Widget build(BuildContext context) => CoeloAdminInteractiveCard(
    key: Key('forms-directory-card-${item.id}'),
    surfaceKey: Key('forms-directory-card-surface-${item.id}'),
    minHeight: CoeloAdminDirectoryMetrics.cardMinHeight,
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
              Expanded(child: Text(item.title, style: Theme.of(context).textTheme.titleMedium)),
              const SizedBox(width: CoeloSpacing.space2),
              _FormOperationalStatusIndicator(item: item),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space3),
          Text(_kindLabel(item.kind)),
          const SizedBox(height: CoeloSpacing.space4),
          Text('Atualizado em ${_shortDate(item.updatedAt)}'),
          if (actions case final actions?) ...[
            const SizedBox(height: CoeloSpacing.space2),
            Align(alignment: Alignment.centerRight, child: actions),
          ],
        ],
      ),
    ),
  );
}

/// Linhas e colunas de domínio dos formulários sobre a tabela compartilhada.
final class _FormTableRows extends StatelessWidget {
  const _FormTableRows({
    required this.items,
    required this.metadataFor,
    required this.onOpen,
    required this.actions,
  });

  final List<FormDirectoryItem> items;
  final DevelopmentFormVisualMetadata? Function(FormDirectoryItem item) metadataFor;
  final ValueChanged<FormDirectoryItem>? onOpen;
  final Widget Function(FormDirectoryItem item)? actions;

  @override
  Widget build(BuildContext context) => CoeloAdminResizableTable<FormDirectoryItem>(
    items: items,
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
        cellBuilder: (_, item) => Text(metadataFor(item)?.contextLabel ?? '—'),
      ),
      CoeloAdminTableColumn(
        id: 'audience',
        label: 'Público',
        initialWidth: 140,
        minWidth: 140,
        maxWidth: 240,
        cellBuilder: (_, item) => Text(metadataFor(item)?.audienceLabel ?? '—'),
      ),
      CoeloAdminTableColumn(
        id: 'responses',
        label: 'Respostas',
        initialWidth: 104,
        minWidth: 104,
        maxWidth: 160,
        cellBuilder: (_, item) => Text(metadataFor(item)?.responseCount.toString() ?? '—'),
      ),
      CoeloAdminTableColumn(
        id: 'schedules',
        label: 'Agendamentos',
        initialWidth: 130,
        minWidth: 130,
        maxWidth: 190,
        cellBuilder: (_, item) => Text(metadataFor(item)?.scheduleCount.toString() ?? '—'),
      ),
      CoeloAdminTableColumn(
        id: 'created',
        label: 'Criado em',
        initialWidth: 128,
        minWidth: 128,
        maxWidth: 190,
        cellBuilder: (_, item) {
          final createdAt = metadataFor(item)?.createdAt;
          return Text(createdAt == null ? '—' : _shortDate(createdAt));
        },
      ),
      if (actions case final actions?)
        CoeloAdminTableColumn(
          id: 'actions',
          label: 'Ações',
          initialWidth: 72,
          minWidth: 72,
          maxWidth: 72,
          cellBuilder: (_, item) => Align(alignment: Alignment.center, child: actions(item)),
        ),
    ],
    headerHeight: 56,
    rowHeight: 64,
    onRowPressed: onOpen,
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
    body: FormsDirectoryPage(
      api: null,
      reader: _PreviewFormsReader(),
      canManage: true,
      onCreate: () {},
    ),
  ),
);

@Preview(name: 'Formulários · cards · compacto dark', size: Size(375, 760))
Widget formsDirectoryCompactDarkPreview() => MaterialApp(
  theme: CoeloTheme.dark,
  home: Scaffold(
    body: FormsDirectoryPage(
      api: null,
      reader: _PreviewFormsReader(),
      canManage: true,
      onCreate: () {},
    ),
  ),
);

final class _PreviewFormsReader implements FormsDirectoryReader {
  @override
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query) async =>
      FormCursorPage(items: _previewForms, nextCursor: null);
}

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
