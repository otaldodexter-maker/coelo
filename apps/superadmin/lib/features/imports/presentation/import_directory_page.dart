import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_placeholder_file_actions.dart';

import '../domain/import_job.dart';
import '../domain/import_repository.dart';
import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = box.maxWidth < CoeloBreakpoints.medium.minWidth ? box.maxWidth : 256.0;
      if (_unauthorized) {
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: const Padding(
            padding: EdgeInsets.all(CoeloSpacing.space4),
            child: CoeloStatePanel(
              title: 'Acesso não autorizado',
              message: 'Seu perfil não possui permissão para consultar importações.',
              icon: Icons.lock_outline_rounded,
            ),
          ),
        );
      }
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoeloAdminListingToolbar(
                search: SizedBox(
                  width: width,
                  child: CoeloSearchField(
                    controller: _search,
                    semanticLabel: 'Buscar importações e exportações',
                    hintText: 'Buscar por arquivo',
                    onChanged: (_) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(
                        const Duration(milliseconds: 350),
                        () => _load(reset: true),
                      );
                    },
                  ),
                ),
                filters: [
                  SizedBox(
                    width: width,
                    child: CoeloAdminMultiSelectFilter<ImportEntity>(
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
                  ),
                  SizedBox(
                    width: width,
                    child: CoeloAdminSingleSelectField<ImportFileFixture?>(
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
                  ),
                ],
                actions: [
                  const SuperadminPlaceholderFileActions(
                    resourceLabel: 'importações e exportações',
                  ),
                  if (_hasFilters)
                    TextButton.icon(
                      onPressed: _clear,
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('Limpar filtros'),
                    ),
                ],
              ),
              const SizedBox(height: CoeloSpacing.space4),
              Expanded(child: _content()),
            ],
          ),
        ),
      );
    },
  );

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return Column(
        children: [
          _create(),
          const SizedBox(height: CoeloSpacing.space4),
          Expanded(
            child: CoeloStatePanel(
              title: 'Importações indisponíveis',
              message: 'Não foi possível consultar o histórico autorizado.',
              icon: Icons.cloud_off_outlined,
              actionLabel: 'Tentar novamente',
              onAction: _load,
            ),
          ),
        ],
      );
    }
    if (_page.items.isEmpty) {
      return Column(
        children: [
          _create(),
          const SizedBox(height: CoeloSpacing.space4),
          Expanded(
            child: CoeloStatePanel(
              title: _hasFilters ? 'Sem resultados' : 'Nenhuma importação ainda',
              message: _hasFilters
                  ? 'Ajuste os filtros e tente novamente.'
                  : 'Quando houver jobs, eles aparecerão aqui.',
              icon: _hasFilters ? Icons.search_off_outlined : Icons.file_upload_outlined,
              actionLabel: _hasFilters ? 'Limpar filtros' : null,
              onAction: _hasFilters ? _clear : null,
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        _create(),
        const SizedBox(height: CoeloSpacing.space4),
        Expanded(
          child: CoeloAdminResizableTable<ImportJob>(
            key: const Key('import-table'),
            items: _page.items,
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
          ),
        ),
        _pagination(),
      ],
    );
  }

  Widget _create() => CoeloAdminCreateAction(
    label: 'Nova importação',
    description: 'Envie um arquivo para validação',
    icon: Icons.upload_file_outlined,
    variant: CoeloAdminCreateActionVariant.banner,
    onPressed: _newImport,
  );
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

  Widget _pagination() {
    final totalPages = _page.nextCursor == null ? _index + 1 : _index + 2;
    return SuperadminListingPaginationFooter(
      semanticKey: const Key('imports-directory-pagination-footer'),
      horizontalPadding: CoeloSpacing.space4,
      compactCurrentPage: _index + 1,
      compactTotalPages: totalPages,
      compactOnPrevious: _index > 0 ? _previousPage : null,
      compactOnNext: _page.nextCursor != null ? _nextPage : null,
      child: CoeloAdminPagination(
        currentPage: _index + 1,
        totalPages: totalPages,
        onPrevious: _index > 0 ? _previousPage : null,
        onNext: _page.nextCursor != null ? _nextPage : null,
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
