import 'dart:async';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../domain/import_repository.dart';
import '../domain/import_job.dart';

enum _ImportPeriodFilter { all, last7Days, last30Days, last90Days, thisMonth }

enum _ImportFileFilter { all, csv, xlsx }

final class ImportDirectoryPage extends StatefulWidget {
  const ImportDirectoryPage({required this.repository, required this.onNewImport, super.key});
  final ImportRepository repository;
  final ValueChanged<ImportCreationPreset> onNewImport;
  @override
  State<ImportDirectoryPage> createState() => _ImportDirectoryPageState();
}

final class _ImportDirectoryPageState extends State<ImportDirectoryPage> {
  final _search = TextEditingController();
  final Set<ImportEntity> _entityFilters = {};
  bool _loading = true;
  bool _unavailable = false;
  List<ImportJob> _jobs = const [];

  _ImportPeriodFilter _periodFilter = _ImportPeriodFilter.all;
  _ImportFileFilter _fileFilter = _ImportFileFilter.all;
  int _page = 1;
  static const _pageSize = 8;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _page = 1));
    unawaited(_loadJobs());
  }

  @override
  void didUpdateWidget(covariant ImportDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      unawaited(_loadJobs());
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _search.text.isNotEmpty ||
      _periodFilter != _ImportPeriodFilter.all ||
      _fileFilter != _ImportFileFilter.all ||
      _entityFilters.isNotEmpty;

  Future<void> _loadJobs() async {
    setState(() => _loading = true);
    try {
      final jobs = await widget.repository.fetchJobs();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _unavailable = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _jobs = const [];
        _unavailable = true;
        _loading = false;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _entityFilters.clear();
      _periodFilter = _ImportPeriodFilter.all;
      _fileFilter = _ImportFileFilter.all;
      _search.clear();
      _page = 1;
    });
  }

  bool _matchEntities(ImportJob job) =>
      _entityFilters.isEmpty || _entityFilters.contains(job.entity);

  bool _matchFile(ImportJob job) {
    final fileFilter = _fileFilter;
    if (fileFilter == _ImportFileFilter.all) return true;
    return fileFilter == _ImportFileFilter.csv
        ? job.file == ImportFileFixture.csv
        : job.file == ImportFileFixture.xlsx;
  }

  bool _matchPeriod(ImportJob job) {
    final period = _periodFilter;
    if (period == _ImportPeriodFilter.all) return true;
    final now = DateTime.now();
    final start = _periodStart(period, now);
    final end = _periodEnd(period, now);
    final createdAt = job.createdAt;
    return !createdAt.isBefore(_startOfDay(start)) && !createdAt.isAfter(_endOfDay(end));
  }

  DateTime _periodStart(_ImportPeriodFilter period, DateTime now) => switch (period) {
    _ImportPeriodFilter.last7Days => now.subtract(const Duration(days: 6)),
    _ImportPeriodFilter.last30Days => now.subtract(const Duration(days: 29)),
    _ImportPeriodFilter.last90Days => now.subtract(const Duration(days: 89)),
    _ImportPeriodFilter.thisMonth => DateTime(now.year, now.month, 1),
    _ImportPeriodFilter.all => now,
  };

  DateTime _periodEnd(_ImportPeriodFilter period, DateTime now) => switch (period) {
    _ImportPeriodFilter.last7Days ||
    _ImportPeriodFilter.last30Days ||
    _ImportPeriodFilter.last90Days => now,
    _ImportPeriodFilter.thisMonth => DateTime(now.year, now.month + 1, 0),
    _ImportPeriodFilter.all => now,
  };

  String _periodFilterLabel(_ImportPeriodFilter period) => switch (period) {
    _ImportPeriodFilter.all => 'Período',
    _ImportPeriodFilter.last7Days => 'Últimos 7 dias',
    _ImportPeriodFilter.last30Days => 'Últimos 30 dias',
    _ImportPeriodFilter.last90Days => 'Últimos 90 dias',
    _ImportPeriodFilter.thisMonth => 'Este màs',
  };

  String _fileFilterLabel(_ImportFileFilter filter) => switch (filter) {
    _ImportFileFilter.all => 'Arquivo',
    _ImportFileFilter.csv => 'CSV',
    _ImportFileFilter.xlsx => 'XLSX',
  };

  bool _matchSearch(ImportJob job) {
    final query = _search.text.toLowerCase().trim();
    if (query.isEmpty) return true;
    return job.entity.label.toLowerCase().contains(query) ||
        job.file.fileName.toLowerCase().contains(query) ||
        job.context.toLowerCase().contains(query) ||
        job.actor.toLowerCase().contains(query);
  }

  Future<void> _openNewImportDialog() async {
    final selected = await showDialog<ImportCreationPreset>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .54),
      builder: (dialogContext) => _ImportCreationDialog(
        onClosed: (preset) {
          Navigator.of(dialogContext).pop(preset);
        },
      ),
    );
    if (!mounted || selected == null) return;
    widget.onNewImport(selected);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final searchWidth = compact ? constraints.maxWidth : 280.0;
      final filterWidth = compact ? constraints.maxWidth : CoeloSpacing.space20 * 2;
      if (_loading) {
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      if (_unavailable) {
        return ColoredBox(
          key: const Key('imports-unavailable'),
          color: Theme.of(context).colorScheme.surface,
          child: CoeloStatePanel(
            title: 'Importações indisponíveis',
            message: 'Não foi possível carregar os processamentos autorizados. Tente novamente.',
            icon: Icons.cloud_off_outlined,
            actionLabel: 'Tentar novamente',
            onAction: _loadJobs,
          ),
        );
      }
      final jobs = _jobs;
      final filteredJobs = jobs
          .where(_matchSearch)
          .where(_matchFile)
          .where(_matchEntities)
          .where(_matchPeriod)
          .toList();
      final totalPages = (filteredJobs.length / _pageSize).ceil();
      final currentPage = totalPages == 0
          ? 1
          : _page > totalPages
          ? totalPages
          : _page;
      final visibleJobs = filteredJobs.skip((currentPage - 1) * _pageSize).take(_pageSize).toList();
      return ColoredBox(
        key: const Key('import-directory-surface'),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoeloAdminListingToolbar(
                search: SizedBox(
                  width: searchWidth,
                  height: CoeloSize.touchMin,
                  child: CoeloSearchField(
                    controller: _search,
                    semanticLabel: 'Buscar importações',
                    hintText: 'Buscar importação',
                    onChanged: (_) => setState(() => _page = 1),
                  ),
                ),
                filters: [
                  SizedBox(
                    width: filterWidth,
                    child: CoeloAdminMultiSelectFilter<ImportEntity>(
                      label: 'Escopo',
                      options: ImportEntity.values,
                      selectedValues: _entityFilters,
                      optionLabel: (value) => value.label,
                      onChanged: (values) => setState(
                        () => _entityFilters
                          ..clear()
                          ..addAll(values),
                      ),
                      searchHintText: 'Buscar escopo',
                    ),
                  ),
                  SizedBox(
                    width: filterWidth,
                    child: CoeloAdminSingleSelectField<_ImportFileFilter>(
                      label: 'Tipo de arquivo',
                      value: _fileFilter,
                      options: _ImportFileFilter.values,
                      optionLabel: _fileFilterLabel,
                      onChanged: (value) => setState(() => _fileFilter = value),
                      searchable: false,
                    ),
                  ),
                  SizedBox(
                    width: filterWidth,
                    child: CoeloAdminSingleSelectField<_ImportPeriodFilter>(
                      label: 'Período',
                      value: _periodFilter,
                      options: _ImportPeriodFilter.values,
                      optionLabel: _periodFilterLabel,
                      onChanged: (value) => setState(() => _periodFilter = value),
                      searchable: false,
                    ),
                  ),
                ],
                actions: [
                  if (_hasFilters)
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('Limpar filtros'),
                    ),
                ],
              ),
              const SizedBox(height: CoeloSpacing.space3),
              _ImportMetrics(jobs: jobs),
              const SizedBox(height: CoeloSpacing.space4),
              Expanded(
                child: filteredJobs.isEmpty
                    ? SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: constraints.maxWidth,
                              child: CoeloAdminCreateAction(
                                label: 'Nova importação',
                                description: 'Escolha entidade e arquivo',
                                icon: Icons.upload_file_outlined,
                                variant: CoeloAdminCreateActionVariant.banner,
                                onPressed: _openNewImportDialog,
                              ),
                            ),
                            const SizedBox(height: CoeloSpacing.space4),
                            CoeloStatePanel(
                              title: 'Sem resultados',
                              message: 'Ajuste a busca ou os filtros para localizar importações.',
                              icon: Icons.search_off_outlined,
                              actionLabel: _hasFilters ? 'Limpar filtros' : null,
                              onAction: _hasFilters ? _clearFilters : null,
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: _ImportTable(jobs: visibleJobs, onNew: _openNewImportDialog),
                          ),
                          if (totalPages > 1) ...[
                            const SizedBox(height: CoeloSpacing.space3),
                            CoeloAdminPagination(
                              currentPage: currentPage,
                              totalPages: totalPages,
                              onPrevious: currentPage > 1
                                  ? () => setState(() => _page = currentPage - 1)
                                  : null,
                              onNext: currentPage < totalPages
                                  ? () => setState(() => _page = currentPage + 1)
                                  : null,
                              onPageSelected: (page) => setState(() => _page = page),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

final class _ImportCreationDialog extends StatefulWidget {
  const _ImportCreationDialog({required this.onClosed});
  final ValueChanged<ImportCreationPreset> onClosed;

  @override
  State<_ImportCreationDialog> createState() => _ImportCreationDialogState();
}

final class _ImportCreationDialogState extends State<_ImportCreationDialog> {
  ImportCreationPreset? _selectedPreset;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedPreset;
    final selectedValue = selected;
    return CoeloAdminDialogShell(
      dialogKey: const Key('import-new-dialog'),
      closeButtonKey: const Key('import-new-close'),
      title: 'Nova importação',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Escolha o caminho de origem para iniciar a importação.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: CoeloSpacing.space4),
          for (final preset in ImportCreationPreset.values) ...[
            const SizedBox(height: CoeloSpacing.space2),
            _ImportCreationPresetTile(
              key: Key('import-preset-${preset.name}'),
              label: preset.label,
              subtitle: _presetDescription(preset),
              selected: selected == preset,
              onTap: () => setState(() => _selectedPreset = preset),
              preset: preset,
            ),
          ],
        ],
      ),
      primaryAction: FilledButton(
        onPressed: selectedValue == null ? null : () => widget.onClosed(selectedValue),
        child: const Text('Continuar'),
      ),
      secondaryAction: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
    );
  }
}

String _presetDescription(ImportCreationPreset preset) => switch (preset) {
  ImportCreationPreset.institutions => 'Importações de instituições existentes.',
  ImportCreationPreset.units => 'Importações de unidades vinculadas.',
  ImportCreationPreset.groups => 'Importações de Turmas.',
  ImportCreationPreset.activities => 'Importações de Atividades.',
  ImportCreationPreset.newInstitution => 'Criar nova instituição e importar dados relacionados.',
  ImportCreationPreset.newFamily => 'Criar nova família e continuar por etapas.',
  ImportCreationPreset.fileByStep => 'Enviar arquivos por etapa para revisão guiada.',
};

final class _ImportCreationPresetTile extends StatelessWidget {
  const _ImportCreationPresetTile({
    super.key,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.preset,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final ImportCreationPreset preset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectedColor = selected ? colors.primary : colors.outline;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, ${selected ? 'selecionado' : 'não selecionado'}',
      child: CoeloAdminInteractiveCard(
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: CoeloSpacing.space1),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: selectedColor,
              ),
              if (preset == ImportCreationPreset.newInstitution ||
                  preset == ImportCreationPreset.fileByStep)
                Padding(
                  padding: const EdgeInsets.only(left: CoeloSpacing.space2),
                  child: Icon(Icons.arrow_forward_rounded, color: colors.outline),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ImportMetrics extends StatelessWidget {
  const _ImportMetrics({required this.jobs});

  final List<ImportJob> jobs;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: CoeloSpacing.space3,
    runSpacing: CoeloSpacing.space3,
    children: [
      _ImportMetric(
        key: const Key('import-metric-total'),
        label: 'Processamentos',
        value: '${jobs.length}',
        icon: Icons.inventory_2_outlined,
      ),
      _ImportMetric(
        key: const Key('import-metric-in-progress'),
        label: 'Em andamento',
        value: '${jobs.where((job) => job.status == ImportJobStatus.inProgress).length}',
        icon: Icons.pending_actions_outlined,
      ),
      _ImportMetric(
        key: const Key('import-metric-rejected'),
        label: 'Registros rejeitados',
        value: '${jobs.fold<int>(0, (sum, job) => sum + job.result.rejected)}',
        icon: Icons.report_gmailerrorred_outlined,
      ),
    ],
  );
}

final class _ImportMetric extends StatelessWidget {
  const _ImportMetric({required this.label, required this.value, required this.icon, super.key});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox(
      width: 208,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: Row(
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(width: CoeloSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: theme.textTheme.titleLarge),
                    Text(label, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ImportTable extends StatelessWidget {
  const _ImportTable({required this.jobs, required this.onNew});
  final List<ImportJob> jobs;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: constraints.maxWidth,
            child: CoeloAdminCreateAction(
              label: 'Nova importação',
              description: 'Escolha entidade e arquivo',
              icon: Icons.upload_file_outlined,
              variant: CoeloAdminCreateActionVariant.banner,
              onPressed: onNew,
            ),
          ),
          const SizedBox(height: CoeloSpacing.space4),
          Align(
            alignment: Alignment.topCenter,
            child: CoeloAdminResizableTable<ImportJob>(
              key: const Key('import-table'),
              items: jobs,
              rowKey: (job) => 'import-row-${job.id}',
              headerHeight: 56,
              rowHeight: 56,
              showHorizontalScrollbar: true,
              pinnedColumn: CoeloAdminTableColumn<ImportJob>(
                id: 'file',
                label: 'Arquivo',
                initialWidth: 280,
                minWidth: 220,
                maxWidth: 320,
                cellBuilder: (context, job) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.file.fileName,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Escopo: ${job.context}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              columns: [
                CoeloAdminTableColumn<ImportJob>(
                  id: 'type',
                  label: 'Tipo',
                  initialWidth: 120,
                  minWidth: 100,
                  maxWidth: 140,
                  cellBuilder: (context, job) => Text(job.file.name.toUpperCase()),
                ),
                CoeloAdminTableColumn<ImportJob>(
                  id: 'entity',
                  label: 'Escopo',
                  initialWidth: 160,
                  minWidth: 130,
                  maxWidth: 220,
                  cellBuilder: (context, job) => Text(job.entity.label),
                ),
                CoeloAdminTableColumn<ImportJob>(
                  id: 'actor',
                  label: 'Quem importou',
                  initialWidth: 180,
                  minWidth: 130,
                  maxWidth: 240,
                  cellBuilder: (context, job) => Text(job.actor),
                ),
                CoeloAdminTableColumn<ImportJob>(
                  id: 'status',
                  label: 'Status',
                  initialWidth: 180,
                  minWidth: 120,
                  maxWidth: 220,
                  cellBuilder: (context, job) => _ImportStatusChip(status: job.status),
                ),
                CoeloAdminTableColumn<ImportJob>(
                  id: 'startedBy',
                  label: 'Iniciado por',
                  initialWidth: 180,
                  minWidth: 130,
                  maxWidth: 220,
                  cellBuilder: (context, job) => Text(job.actor),
                ),
                CoeloAdminTableColumn<ImportJob>(
                  id: 'createdAt',
                  label: 'Criado em',
                  initialWidth: 140,
                  minWidth: 120,
                  maxWidth: 180,
                  cellBuilder: (context, job) => Text(_formatDate(job.createdAt)),
                ),
                CoeloAdminTableColumn<ImportJob>(
                  id: 'destination',
                  label: 'Destino',
                  initialWidth: 180,
                  minWidth: 140,
                  maxWidth: 220,
                  cellBuilder: (context, job) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(job.context, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        job.entity.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                CoeloAdminTableColumn<ImportJob>(
                  id: 'result',
                  label: 'Resultado/erro',
                  initialWidth: 220,
                  minWidth: 180,
                  maxWidth: 280,
                  cellBuilder: (context, job) => Text(_importResultSummary(job)),
                ),
                CoeloAdminTableColumn<ImportJob>(
                  id: 'actions',
                  label: 'Ações',
                  initialWidth: 160,
                  minWidth: 140,
                  maxWidth: 180,
                  cellBuilder: (context, job) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

final class _ImportStatusChip extends StatelessWidget {
  const _ImportStatusChip({required this.status});
  final ImportJobStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColors =
        Theme.of(context).extension<CoeloStatusColors>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? CoeloStatusColors.dark
            : CoeloStatusColors.light);
    final (background, foreground) = switch (status) {
      ImportJobStatus.completed => (statusColors.successContainer, statusColors.onSuccessContainer),
      ImportJobStatus.rejected => (colors.errorContainer, colors.onErrorContainer),
      ImportJobStatus.error => (colors.errorContainer, colors.onErrorContainer),
      ImportJobStatus.inProgress => (
        statusColors.warningContainer,
        statusColors.onWarningContainer,
      ),
      ImportJobStatus.draft => (colors.surfaceContainer, colors.onSurfaceVariant),
    };
    final label = switch (status) {
      ImportJobStatus.draft => 'Pendente',
      ImportJobStatus.inProgress => 'Em andamento',
      ImportJobStatus.completed => 'Concluído',
      ImportJobStatus.rejected => 'Rejeitado',
      ImportJobStatus.error => 'Erro',
    };
    return CoeloStatusChip(label: label, backgroundColor: background, foregroundColor: foreground);
  }
}

String _importResultSummary(ImportJob job) {
  final result = job.result;
  if (job.status == ImportJobStatus.draft) return 'Pendente';
  final details = <String>[
    if (result.created > 0) '${result.created} criados',
    if (result.updated > 0) '${result.updated} atualizados',
    if (result.ignored > 0) '${result.ignored} ignorados',
    if (result.rejected > 0) '${result.rejected} rejeitados',
  ];
  if (details.isEmpty) return 'Sem resumo';
  final joined = details.join(' · ');
  if (result.rejected > 0) return 'Erro: $joined';
  return joined;
}

DateTime _startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _endOfDay(DateTime date) => DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
