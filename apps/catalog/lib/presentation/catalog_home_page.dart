import 'dart:convert';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../catalog/catalog_entry.dart';
import '../catalog/catalog_filter.dart';
import '../catalog/catalog_foundation.dart';
import '../catalog/catalog_registry.dart';
import '../catalog/catalog_sync_status.dart';
import 'catalog_foundation_page.dart';
import 'component_detail_page.dart';
import 'widgets/catalog_stale_banner.dart';

typedef CatalogEntriesLoader = Future<List<CatalogEntry>> Function();
typedef CatalogSyncReportLoader = Future<CatalogSyncReport> Function();

final class CatalogHomePage extends StatefulWidget {
  const CatalogHomePage({
    required this.entries,
    required this.registry,
    this.foundations = const {},
    this.entriesLoader,
    this.syncReport = const CatalogSyncReport.synchronized(),
    this.syncReportLoader,
    this.onSignOut,
    super.key,
  }) : assetPath = null;

  const CatalogHomePage.fromIndexAsset({
    required this.registry,
    this.foundations = const {},
    this.entriesLoader,
    this.syncReportLoader,
    this.onSignOut,
    super.key,
  }) : entries = null,
       syncReport = null,
       assetPath = 'assets/coelo-ui.index.jsonl';

  final List<CatalogEntry>? entries;
  final Map<String, CatalogExample> registry;
  final Map<String, CatalogFoundation> foundations;
  final String? assetPath;
  final CatalogEntriesLoader? entriesLoader;
  final CatalogSyncReport? syncReport;
  final CatalogSyncReportLoader? syncReportLoader;
  final VoidCallback? onSignOut;

  @override
  State<CatalogHomePage> createState() => _CatalogHomePageState();
}

final class _CatalogHomePageState extends State<CatalogHomePage> {
  static const _viewports = <double>[375, 768, 1024, 1440];

  final _searchController = TextEditingController();
  List<CatalogEntry>? _loadedEntries;
  CatalogSyncReport _syncReport = const CatalogSyncReport.synchronized();
  var _loadState = _CatalogLoadState.loading;
  var _loadGeneration = 0;
  CatalogFilter _filter = CatalogFilter.all;
  CatalogStatus? _status;
  ThemeMode _themeMode = ThemeMode.light;
  double _previewWidth = _viewports.first;

  @override
  void initState() {
    super.initState();
    _syncReport = widget.syncReport ?? CatalogSyncReport.unavailable();
    _loadEntries();
  }

  @override
  void didUpdateWidget(covariant CatalogHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries != widget.entries ||
        oldWidget.assetPath != widget.assetPath ||
        oldWidget.entriesLoader != widget.entriesLoader ||
        oldWidget.syncReport != widget.syncReport ||
        oldWidget.syncReportLoader != widget.syncReportLoader) {
      _loadEntries();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loadState = _CatalogLoadState.loading;
      _loadedEntries = null;
      _syncReport = widget.syncReport ?? CatalogSyncReport.unavailable();
    });
    try {
      final syncReportFuture = _loadSyncReport();
      final entries = widget.entries ?? await (widget.entriesLoader?.call() ?? _loadIndexAsset());
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _loadedEntries = entries;
        _loadState = _CatalogLoadState.data;
      });
      final syncReport = await syncReportFuture;
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _syncReport = syncReport;
      });
    } on Object {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _loadState = _CatalogLoadState.error;
      });
    }
  }

  Future<CatalogSyncReport> _loadSyncReport() async {
    if (widget.syncReport case final report?) {
      return report;
    }
    try {
      if (widget.syncReportLoader case final loader?) {
        return await loader();
      }
      final contents = await rootBundle.loadString('assets/catalog-sync-report.json');
      return CatalogSyncReport.fromJson(jsonDecode(contents) as Map<String, Object?>);
    } on Object {
      return CatalogSyncReport.unavailable();
    }
  }

  Future<List<CatalogEntry>> _loadIndexAsset() async {
    final contents = await rootBundle.loadString(widget.assetPath!);
    return contents
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => CatalogEntry.fromJson(jsonDecode(line) as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _loadedEntries;
    final theme = _themeMode == ThemeMode.dark ? CoeloTheme.dark : CoeloTheme.light;
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          if (_loadState == _CatalogLoadState.loading) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Catálogo Coelo'),
                actions: [
                  if (widget.onSignOut != null)
                    IconButton(
                      tooltip: 'Sair',
                      onPressed: widget.onSignOut,
                      icon: const Icon(Icons.logout),
                    ),
                ],
              ),
              body: Center(
                child: Semantics(label: 'Carregando catálogo', child: Text('Carregando catálogo')),
              ),
            );
          }
          if (_loadState == _CatalogLoadState.error) {
            return Scaffold(
              appBar: AppBar(title: const Text('Catálogo Coelo')),
              body: Center(
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Não foi possível carregar o catálogo'),
                      const SizedBox(height: CoeloSpacing.space4),
                      OutlinedButton(
                        key: const Key('catalog-retry-load'),
                        onPressed: _loadEntries,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          final loadedEntries = entries!;
          final results = _filter.apply(
            loadedEntries,
            status: _status,
            query: _searchController.text,
          );
          final sections = <({String category, String label})>[
            (category: 'foundation', label: 'Fundamentos'),
            (category: 'component', label: 'Componentes'),
            (category: 'pattern', label: 'Padrões'),
            (category: 'product', label: 'Produtos'),
            (category: 'governance', label: 'Governança'),
          ];
          return Scaffold(
            appBar: AppBar(
              title: const Text('Catálogo Coelo'),
              actions: [
                IconButton(
                  key: const Key('catalog-theme-toggle'),
                  tooltip: _themeMode == ThemeMode.light ? 'Usar tema escuro' : 'Usar tema claro',
                  onPressed: () => setState(() {
                    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
                  }),
                  icon: Icon(
                    _themeMode == ThemeMode.light
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                  ),
                ),
                if (widget.onSignOut != null)
                  IconButton(
                    tooltip: 'Sair',
                    onPressed: widget.onSignOut,
                    icon: const Icon(Icons.logout),
                  ),
              ],
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final padding = constraints.maxWidth < CoeloBreakpoints.medium.minWidth
                    ? CoeloSpacing.space4
                    : CoeloSpacing.space6;
                return ListView(
                  padding: EdgeInsets.all(padding),
                  children: [
                    CatalogStaleBanner(report: _syncReport),
                    if (_syncReport.isStale) const SizedBox(height: CoeloSpacing.space4),
                    Text(
                      'Fundamentos e componentes reais',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: CoeloSpacing.space2),
                    Text(
                      'Explore componentes publicados pelos seus barrels. Entradas aprovadas permanecem metadados até terem builder real.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: CoeloSpacing.space6),
                    _CatalogControls(
                      controller: _searchController,
                      filter: _filter,
                      status: _status,
                      previewWidth: _previewWidth,
                      onSearchChanged: (_) => setState(() {}),
                      onFilterChanged: (value) => setState(() => _filter = value),
                      onStatusChanged: (value) => setState(() => _status = value),
                      onViewportChanged: (value) => setState(() => _previewWidth = value),
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    _MotionStatus(disableAnimations: MediaQuery.disableAnimationsOf(context)),
                    const SizedBox(height: CoeloSpacing.space4),
                    Text('${results.length} itens', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: CoeloSpacing.space2),
                    for (final section in sections)
                      if (results.any((entry) => entry.category == section.category)) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                            top: CoeloSpacing.space4,
                            bottom: CoeloSpacing.space2,
                          ),
                          child: Text(section.label, style: Theme.of(context).textTheme.titleLarge),
                        ),
                        for (final entry in results.where(
                          (entry) => entry.category == section.category,
                        ))
                          _CatalogEntryCard(
                            entry: entry,
                            onTap: () => _openEntry(context, entry, theme),
                          ),
                      ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _openEntry(BuildContext context, CatalogEntry entry, ThemeData theme) {
    final foundation = widget.foundations[entry.id];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Theme(
          data: theme,
          child: foundation == null
              ? ComponentDetailPage(
                  entry: entry,
                  registry: widget.registry,
                  previewWidth: _previewWidth,
                )
              : CatalogFoundationPage(
                  entry: entry,
                  foundation: foundation,
                  previewWidth: _previewWidth,
                ),
        ),
      ),
    );
  }
}

enum _CatalogLoadState { loading, data, error }

final class _CatalogControls extends StatelessWidget {
  const _CatalogControls({
    required this.controller,
    required this.filter,
    required this.status,
    required this.previewWidth,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onStatusChanged,
    required this.onViewportChanged,
  });

  final TextEditingController controller;
  final CatalogFilter filter;
  final CatalogStatus? status;
  final double previewWidth;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<CatalogFilter> onFilterChanged;
  final ValueChanged<CatalogStatus?> onStatusChanged;
  final ValueChanged<double> onViewportChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: CoeloSpacing.space3,
      runSpacing: CoeloSpacing.space2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: CoeloBreakpoints.compact.maxWidth,
          child: CoeloSearchField(
            key: const Key('catalog-search'),
            controller: controller,
            onChanged: onSearchChanged,
            semanticLabel: 'Buscar componentes',
            hintText: 'Buscar por nome ou id',
          ),
        ),
        PopupMenuButton<CatalogFilter>(
          key: const Key('catalog-filter'),
          tooltip: 'Filtrar contexto',
          onSelected: onFilterChanged,
          itemBuilder: (context) => [
            for (final value in CatalogFilter.values)
              PopupMenuItem(value: value, child: Text(value.label)),
          ],
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.filter_list),
              const SizedBox(width: CoeloSpacing.space1),
              Text(filter.label),
            ],
          ),
        ),
        SizedBox(
          width: CoeloBreakpoints.compact.maxWidth,
          child: DropdownButton<CatalogStatus?>(
            key: const Key('catalog-status-filter'),
            isExpanded: true,
            value: status,
            hint: const Text('Status'),
            onChanged: onStatusChanged,
            selectedItemBuilder: (context) => [
              const Text('Todos os status', overflow: TextOverflow.ellipsis),
              for (final value in CatalogStatus.values)
                Text(value.label, overflow: TextOverflow.ellipsis),
            ],
            items: [
              const DropdownMenuItem<CatalogStatus?>(value: null, child: Text('Todos os status')),
              for (final value in CatalogStatus.values)
                DropdownMenuItem(value: value, child: Text(value.label)),
            ],
          ),
        ),
        ..._CatalogHomePageState._viewports.map(
          (width) => ChoiceChip(
            key: Key('catalog-viewport-${width.toInt()}'),
            label: Text('${width.toInt()} px'),
            selected: previewWidth == width,
            onSelected: (_) => onViewportChanged(width),
          ),
        ),
      ],
    );
  }
}

final class _MotionStatus extends StatelessWidget {
  const _MotionStatus({required this.disableAnimations});

  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: disableAnimations ? 'Movimento reduzido' : 'Movimento padrão',
      child: Text(
        disableAnimations ? 'Movimento reduzido' : 'Movimento padrão',
        key: const Key('catalog-motion-status'),
      ),
    );
  }
}

final class _CatalogEntryCard extends StatelessWidget {
  const _CatalogEntryCard({required this.entry, required this.onTap});

  final CatalogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: CoeloSpacing.space1),
              Text(entry.id, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: CoeloSpacing.space2),
              Text(entry.purpose),
              const SizedBox(height: CoeloSpacing.space2),
              Text('${entry.ownerPackage} · ${entry.status.label}'),
            ],
          ),
        ),
      ),
    );
  }
}
