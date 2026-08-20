import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';

enum FormsDirectoryDisplay { table, cards }

enum FormsDirectoryLoadStatus { loading, data, empty, noResults, unauthorized, failure }

final class FormsDirectoryPage extends StatefulWidget {
  const FormsDirectoryPage({
    required this.api,
    this.canManage = false,
    this.onCreate,
    this.onOpen,
    super.key,
  });

  final FormsApi? api;
  final bool canManage;
  final VoidCallback? onCreate;
  final ValueChanged<FormDirectoryItem>? onOpen;

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

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = widget.api;
    if (api == null) {
      setState(() {
        _status = FormsDirectoryLoadStatus.failure;
        _message = 'O serviço de Formulários não está disponível neste ambiente.';
      });
      return;
    }
    setState(() => _status = FormsDirectoryLoadStatus.loading);
    try {
      final page = await api.listDirectory(
        FormDirectoryQuery(
          search: _search.text.trim().isEmpty ? null : _search.text.trim(),
          operationalStatuses: _operationalStatuses,
          startsOnOrAfter: _period?.start,
          endsOnOrBefore: _period?.end,
          cursor: _cursors[_pageIndex],
        ),
      );
      if (!mounted) return;
      setState(() {
        _page = page;
        _status = page.items.isNotEmpty
            ? FormsDirectoryLoadStatus.data
            : (_search.text.isNotEmpty || _operationalStatuses.isNotEmpty || _period != null)
            ? FormsDirectoryLoadStatus.noResults
            : FormsDirectoryLoadStatus.empty;
      });
    } on FormApiException catch (error) {
      if (!mounted) return;
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
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(CoeloSpacing.space5),
    children: [
      Text('Formulários', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: CoeloSpacing.space2),
      Text(
        'Crie, distribua e acompanhe formulários e enquetes rápidas.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: CoeloSpacing.space5),
      CoeloAdminListingToolbar(
        search: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: CoeloSearchField(
            key: const Key('forms-directory-search'),
            controller: _search,
            semanticLabel: 'Buscar formulários',
            hintText: 'Buscar formulários',
            onChanged: _onSearch,
          ),
        ),
        filters: [
          SizedBox(
            width: 220,
            child: CoeloAdminMultiSelectField<FormOperationalStatus>(
              label: 'Situação',
              options: FormOperationalStatus.values,
              selectedValues: _operationalStatuses,
              optionLabel: _operationalStatusLabel,
              onChanged: (value) {
                setState(() => _operationalStatuses = value);
                _resetAndLoad();
              },
            ),
          ),
          SizedBox(
            width: 260,
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
        actions: [
          SuperadminDirectoryViewToggle<FormsDirectoryDisplay>(
            cardsKey: const Key('forms-directory-view-cards'),
            tableKey: const Key('forms-directory-view-table'),
            cardsSelected: _display == FormsDirectoryDisplay.cards,
            groupedView: FormsDirectoryDisplay.table,
            selectedTableView: FormsDirectoryDisplay.table,
            tableViews: const [
              SuperadminDirectoryTableViewOption(
                value: FormsDirectoryDisplay.table,
                label: 'Tabela',
              ),
            ],
            onCardsSelected: () => setState(() => _display = FormsDirectoryDisplay.cards),
            onTableViewSelected: (_) => setState(() => _display = FormsDirectoryDisplay.table),
          ),
          if (widget.canManage)
            FilledButton.icon(
              onPressed: widget.onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Novo formulário'),
            ),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space5),
      _content(),
    ],
  );

  Widget _content() => switch (_status) {
    FormsDirectoryLoadStatus.loading => const CoeloStatePanel(
      title: 'Carregando formulários',
      message: 'Aguarde enquanto os dados autorizados são carregados.',
      loading: true,
    ),
    FormsDirectoryLoadStatus.empty => CoeloStatePanel(
      title: 'Nenhum formulário criado',
      message: 'Crie o primeiro formulário ou enquete rápida.',
      icon: Icons.dynamic_form_outlined,
      actionLabel: widget.canManage ? 'Criar formulário' : null,
      onAction: widget.canManage ? widget.onCreate : null,
    ),
    FormsDirectoryLoadStatus.noResults => CoeloStatePanel(
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
    FormsDirectoryLoadStatus.unauthorized => const CoeloStatePanel(
      title: 'Acesso não autorizado',
      message: 'Seu perfil não possui forms.read neste escopo.',
      icon: Icons.lock_outline_rounded,
    ),
    FormsDirectoryLoadStatus.failure => CoeloStatePanel(
      title: 'Não foi possível carregar os formulários',
      message: _message ?? 'Tente novamente.',
      icon: Icons.error_outline_rounded,
      actionLabel: 'Tentar novamente',
      onAction: _load,
    ),
    FormsDirectoryLoadStatus.data => FormsDirectoryResults(
      page: _page!,
      display: _display,
      canManage: widget.canManage,
      pageNumber: _pageIndex + 1,
      onPrevious: _pageIndex > 0 ? _previous : null,
      onNext: _page!.nextCursor != null ? _next : null,
      onCreate: widget.onCreate,
      onOpen: widget.onOpen,
    ),
  };
}

final class FormsDirectoryResults extends StatelessWidget {
  const FormsDirectoryResults({
    required this.page,
    required this.display,
    required this.canManage,
    required this.pageNumber,
    this.onPrevious,
    this.onNext,
    this.onCreate,
    this.onOpen,
    super.key,
  });

  final FormCursorPage<FormDirectoryItem> page;
  final FormsDirectoryDisplay display;
  final bool canManage;
  final int pageNumber;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onCreate;
  final ValueChanged<FormDirectoryItem>? onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (display == FormsDirectoryDisplay.cards) _cards(context) else _table(context),
      if (onPrevious != null || onNext != null)
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
      final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space4) / columns;
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      final cardHeight = textScale >= 2 ? null : 188.0;
      return Wrap(
        spacing: CoeloSpacing.space4,
        runSpacing: CoeloSpacing.space4,
        children: [
          if (canManage)
            SizedBox(
              width: width,
              height: cardHeight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 188),
                child: CoeloAdminCreateAction(label: 'Novo formulário', onPressed: onCreate),
              ),
            ),
          for (final item in page.items)
            SizedBox(
              width: width,
              child: CoeloAdminInteractiveCard(
                semanticLabel: 'Abrir ${item.title}',
                onPressed: onOpen == null ? null : () => onOpen!(item),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 188),
                  child: Padding(
                    padding: const EdgeInsets.all(CoeloSpacing.space4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: CoeloSpacing.space3),
                        Text(_kindLabel(item.kind)),
                        Text(_operationalStatusLabel(item.operationalStatus)),
                        const SizedBox(height: CoeloSpacing.space4),
                        Text('Atualizado em ${_shortDate(item.updatedAt)}'),
                      ],
                    ),
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
      initialWidth: 320,
      minWidth: 200,
      maxWidth: 480,
      cellBuilder: (_, item) => Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
    ),
    columns: [
      CoeloAdminTableColumn(
        id: 'kind',
        label: 'Tipo',
        initialWidth: 150,
        minWidth: 120,
        maxWidth: 220,
        cellBuilder: (_, item) => Text(_kindLabel(item.kind)),
      ),
      CoeloAdminTableColumn(
        id: 'status',
        label: 'Situação',
        initialWidth: 140,
        minWidth: 110,
        maxWidth: 180,
        cellBuilder: (_, item) => Text(_operationalStatusLabel(item.operationalStatus)),
      ),
      CoeloAdminTableColumn(
        id: 'identity',
        label: 'Identificação',
        initialWidth: 160,
        minWidth: 130,
        maxWidth: 220,
        cellBuilder: (_, item) =>
            Text(item.identityMode == FormIdentityMode.anonymous ? 'Anônimo' : 'Identificado'),
      ),
      CoeloAdminTableColumn(
        id: 'updated',
        label: 'Atualização',
        initialWidth: 150,
        minWidth: 120,
        maxWidth: 210,
        cellBuilder: (_, item) => Text(_shortDate(item.updatedAt)),
      ),
    ],
    headerHeight: 56,
    rowHeight: 68,
    onRowPressed: onOpen,
  );
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
