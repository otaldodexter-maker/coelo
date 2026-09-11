import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_notice.dart';

import '../domain/import_job.dart';
import '../domain/import_repository.dart';

final class ImportDirectoryPage extends StatefulWidget {
  const ImportDirectoryPage({required this.repository, required this.onNewImport, super.key});
  final ImportRepository repository;
  final ValueChanged<ImportCreationPreset> onNewImport;
  @override
  State<ImportDirectoryPage> createState() => _ImportDirectoryPageState();
}

final class _ImportDirectoryPageState extends State<ImportDirectoryPage> {
  final _search = TextEditingController();
  final _entities = <ImportEntity>{};
  ImportFileFixture? _format;
  var _loading = true;
  var _failed = false;
  var _unauthorized = false;
  var _page = const ImportJobPage(items: <ImportJob>[]);
  final _cursors = <String?>[null];
  var _index = 0;
  var _loadGeneration = 0;
  Timer? _searchDebounce;

  bool get _executionAvailable =>
      widget.repository is! ImportExecutionCapabilities ||
      (widget.repository as ImportExecutionCapabilities).supportedImportEntities.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_executionAvailable) {
      _load();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  bool get _hasFilters => _search.text.trim().isNotEmpty || _entities.isNotEmpty || _format != null;

  Future<void> _load({bool reset = false, String? cursor}) async {
    final generation = ++_loadGeneration;
    if (reset) {
      _cursors
        ..clear()
        ..add(null);
      _index = 0;
    }
    setState(() {
      _loading = true;
      _failed = false;
      _unauthorized = false;
    });
    try {
      final query = ImportJobQuery(
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        entities: Set<ImportEntity>.unmodifiable(_entities),
        file: _format,
        cursor: cursor ?? _cursors[_index],
      );
      final result = await widget.repository.fetchPage(query);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _page = result;
        _loading = false;
      });
    } on ImportRepositoryUnauthorizedException {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _page = const ImportJobPage(items: <ImportJob>[]);
        _loading = false;
        _unauthorized = true;
      });
    } on Object {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _page = const ImportJobPage(items: <ImportJob>[]);
        _loading = false;
        _failed = true;
      });
    }
  }

  void _clear() {
    setState(() {
      _search.clear();
      _entities.clear();
      _format = null;
    });
    _load(reset: true);
  }

  Future<void> _newImport() async {
    final choice = await showDialog<ImportCreationPreset>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );
    if (mounted && choice != null) widget.onNewImport(choice);
  }

  void _showDeferred() {
    showSuperadminNotice(context, 'Disponível depois do MVP', icon: Icons.info_outline_rounded);
  }

  var _display = CoeloAdminDirectoryDisplay.table;

  /// Importações sobre o composto `CoeloAdminDirectory` (decisão do Owner de
  /// 10/09/2026): a feature entrega busca, filtros, Limpar filtros, Arquivos,
  /// o Criar, as linhas da tabela, os cards e a paginação; toolbar, toggle,
  /// banner/card Criar, card de estado e rodapé são do composto e aparecem
  /// em todos os estados, inclusive na indisponibilidade honesta do MVP.
  @override
  Widget build(BuildContext context) {
    final status = !_executionAvailable
        ? CoeloAdminDirectoryStatus.empty
        : _unauthorized
        ? CoeloAdminDirectoryStatus.unauthorized
        : _loading
        ? CoeloAdminDirectoryStatus.loading
        : _failed
        ? CoeloAdminDirectoryStatus.failure
        : _page.items.isEmpty
        ? (_hasFilters ? CoeloAdminDirectoryStatus.noResults : CoeloAdminDirectoryStatus.empty)
        : CoeloAdminDirectoryStatus.success;
    final totalPages = _page.nextCursor == null ? _index + 1 : _index + 2;
    return CoeloAdminDirectory<CoeloAdminDirectoryDisplay>(
      key: const Key('imports-directory'),
      scrollKey: const Key('imports-directory-scroll'),
      toolbarKey: const Key('imports-toolbar'),
      filterControlsKey: const Key('imports-filter-controls'),
      cardsKey: const Key('imports-view-cards'),
      tableKey: const Key('imports-view-table'),
      gridKey: const Key('imports-card-list'),
      loadingKey: const Key('imports-state-loading'),
      status: status,
      messages: CoeloAdminDirectoryMessages(
        empty: _executionAvailable ? 'Nenhuma importação ainda' : 'Importações adiadas',
        emptyIcon: _executionAvailable ? Icons.file_upload_outlined : Icons.schedule_outlined,
        noResults: 'Nenhuma importação corresponde aos filtros aplicados.',
        noResultsIcon: Icons.search_off_outlined,
        failure: 'Importações indisponíveis',
        failureIcon: Icons.cloud_off_outlined,
        unauthorized: 'Seu perfil não possui permissão para consultar importações.',
        unauthorizedIcon: Icons.lock_outline_rounded,
      ),
      errorMessage: switch (status) {
        CoeloAdminDirectoryStatus.empty when !_executionAvailable =>
          'Importação e exportação reais estarão disponíveis depois do MVP. '
              'Nenhum arquivo será selecionado ou processado nesta etapa.',
        CoeloAdminDirectoryStatus.empty => 'Quando houver jobs, eles aparecerão aqui.',
        CoeloAdminDirectoryStatus.failure => 'Não foi possível consultar o histórico autorizado.',
        _ => null,
      },
      onRetry: _executionAvailable ? _load : null,
      onClearFilters: _clear,
      search: CoeloSearchField(
        controller: _search,
        semanticLabel: 'Buscar importações e exportações',
        hintText: 'Buscar por arquivo',
        onChanged: (_) {
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 350), () => _load(reset: true));
        },
      ),
      filters: [
        CoeloAdminMultiSelectFilter<ImportEntity>(
          label: 'Entidade',
          options: ImportEntity.values,
          selectedValues: _entities,
          optionLabel: (value) => value.label,
          onChanged: (values) {
            setState(() {
              _entities
                ..clear()
                ..addAll(values);
            });
            _load(reset: true);
          },
        ),
        CoeloAdminSingleSelectField<ImportFileFixture?>(
          label: 'Arquivo',
          value: _format,
          options: const [null, ImportFileFixture.csv, ImportFileFixture.xlsx],
          optionLabel: (value) => value == null ? 'Todos' : value.name.toUpperCase(),
          onChanged: (value) {
            setState(() => _format = value);
            _load(reset: true);
          },
          searchable: false,
        ),
      ],
      trailing: [
        if (_hasFilters)
          TextButton.icon(
            onPressed: _clear,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Limpar filtros'),
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
      // Importação/exportação reais adiadas (ADR 0034): botões visíveis e honestos.
      fileActions: [
        CoeloAdminFileAction(
          label: 'Importar',
          icon: Icons.upload_file_outlined,
          onPressed: _showDeferred,
        ),
        CoeloAdminFileAction(
          label: 'Exportar CSV',
          icon: Icons.table_view_outlined,
          onPressed: _showDeferred,
        ),
        CoeloAdminFileAction(
          label: 'Exportar XLSX',
          icon: Icons.grid_on_outlined,
          onPressed: _showDeferred,
        ),
      ],
      create: CoeloAdminDirectoryCreate(
        label: 'Nova importação',
        description: _executionAvailable
            ? 'Envie um arquivo para validação'
            : 'Disponível depois do MVP',
        icon: Icons.upload_file_outlined,
        onPressed: _executionAvailable ? _newImport : _showDeferred,
        tileKey: const Key('imports-create-state'),
        bannerKey: const Key('imports-create-table'),
      ),
      cards: [for (final job in _page.items) _ImportJobCard(job: job)],
      table: _ImportJobRows(jobs: _page.items),
      pagination: status == CoeloAdminDirectoryStatus.success
          ? CoeloAdminDirectoryPagination(
              footerKey: const Key('imports-directory-pagination-footer'),
              currentPage: _index + 1,
              totalPages: totalPages,
              // Paginação por cursor: um passo por vez, como na Auditoria.
              onPageSelected: (page) {
                if (page < _index + 1 && _index > 0) _previousPage();
                if (page > _index + 1 && _page.nextCursor != null) _nextPage();
              },
            )
          : null,
    );
  }

  void _previousPage() {
    setState(() => _index--);
    _load(cursor: _cursors[_index]);
  }

  void _nextPage() {
    final next = _page.nextCursor!;
    setState(() {
      _cursors
        ..removeRange(_index + 1, _cursors.length)
        ..add(next);
      _index++;
    });
    _load(cursor: next);
  }
}

/// Linhas de domínio da tabela de Importações; o composto fornece o banner
/// Criar acima e o rodapé de paginação.
final class _ImportJobRows extends StatelessWidget {
  const _ImportJobRows({required this.jobs});

  final List<ImportJob> jobs;

  @override
  Widget build(BuildContext context) => CoeloAdminResizableTable<ImportJob>(
    key: const Key('import-table'),
    items: jobs,
    rowKey: (job) => 'import-row-${job.id}',
    headerHeight: 56,
    rowHeight: 64,
    showHorizontalScrollbar: true,
    pinnedColumn: CoeloAdminTableColumn<ImportJob>(
      id: 'file',
      label: 'Arquivo',
      initialWidth: 260,
      minWidth: 200,
      maxWidth: 340,
      cellBuilder: (_, job) => Text(job.displayFileName),
    ),
    columns: [
      CoeloAdminTableColumn<ImportJob>(
        id: 'entity',
        label: 'Entidade',
        initialWidth: 150,
        minWidth: 120,
        maxWidth: 200,
        cellBuilder: (_, job) => Text(job.entity.label),
      ),
      CoeloAdminTableColumn<ImportJob>(
        id: 'context',
        label: 'Destino',
        initialWidth: 180,
        minWidth: 140,
        maxWidth: 240,
        cellBuilder: (_, job) => Text(job.context),
      ),
      CoeloAdminTableColumn<ImportJob>(
        id: 'records',
        label: 'Registros',
        initialWidth: 120,
        minWidth: 110,
        maxWidth: 160,
        cellBuilder: (_, job) => Text('${job.previewRows.length} registros'),
      ),
      CoeloAdminTableColumn<ImportJob>(
        id: 'status',
        label: 'Status',
        initialWidth: 150,
        minWidth: 130,
        maxWidth: 180,
        cellBuilder: (_, job) => Text(_status(job.status)),
      ),
      CoeloAdminTableColumn<ImportJob>(
        id: 'created',
        label: 'Criado em',
        initialWidth: 150,
        minWidth: 130,
        maxWidth: 180,
        cellBuilder: (_, job) => Text(_date(job.createdAt)),
      ),
      CoeloAdminTableColumn<ImportJob>(
        id: 'actor',
        label: 'Responsável',
        initialWidth: 180,
        minWidth: 140,
        maxWidth: 240,
        cellBuilder: (_, job) => Text(job.actor),
      ),
    ],
  );
}

final class _ImportJobCard extends StatelessWidget {
  const _ImportJobCard({required this.job});

  final ImportJob job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CoeloAdminInteractiveCard(
      key: Key('import-card-${job.id}'),
      semanticLabel: 'Importação ${job.displayFileName}',
      minHeight: 168,
      onPressed: null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CoeloSpacing.space6,
          vertical: CoeloSpacing.space4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              job.displayFileName,
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: CoeloSpacing.space2),
            Text('${job.entity.label} · ${job.context}', style: theme.textTheme.bodySmall),
            const SizedBox(height: CoeloSpacing.space2),
            Text(
              '${job.previewRows.length} registros · ${_status(job.status)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: CoeloSpacing.space2),
            Text('${_date(job.createdAt)} · ${job.actor}', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

String _status(ImportJobStatus value) => switch (value) {
  ImportJobStatus.draft => 'Pendente',
  ImportJobStatus.inProgress => 'Em andamento',
  ImportJobStatus.completed => 'Concluído',
  ImportJobStatus.rejected => 'Reprovado',
  ImportJobStatus.error => 'Erro',
};
String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

final class _ImportDialog extends StatelessWidget {
  const _ImportDialog();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CoeloAdminDialogShell(
      dialogKey: const Key('import-new-dialog'),
      closeButtonKey: const Key('import-new-close'),
      title: 'Nova importação',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final preset in ImportCreationPreset.values)
            Padding(
              padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
              child: CoeloAdminInteractiveCard(
                onPressed: () => Navigator.of(context).pop(preset),
                child: Padding(
                  padding: const EdgeInsets.all(CoeloSpacing.space3),
                  child: Align(alignment: Alignment.centerLeft, child: Text(preset.label)),
                ),
              ),
            ),
        ],
      ),
      primaryAction: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: colors.errorContainer,
          foregroundColor: colors.error,
        ),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
    );
  }
}
