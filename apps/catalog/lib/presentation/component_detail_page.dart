import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../catalog/catalog_entry.dart';
import '../catalog/catalog_registry.dart';

final class ComponentDetailPage extends StatefulWidget {
  const ComponentDetailPage({
    required this.entry,
    required this.registry,
    this.previewWidth = 375,
    this.copySnippet,
    super.key,
  });

  final CatalogEntry entry;
  final Map<String, CatalogExample> registry;
  final double previewWidth;
  final Future<void> Function(String value)? copySnippet;

  @override
  State<ComponentDetailPage> createState() => _ComponentDetailPageState();
}

final class _ComponentDetailPageState extends State<ComponentDetailPage> {
  var _copied = false;
  var _copyFailed = false;

  Future<void> _copySnippet() async {
    try {
      await (widget.copySnippet ?? (value) => Clipboard.setData(ClipboardData(text: value)))(
        widget.entry.example,
      );
      if (mounted) {
        setState(() {
          _copied = true;
          _copyFailed = false;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _copied = false;
          _copyFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final colors = Theme.of(context).colorScheme;
    final statusColors = Theme.of(context).extension<CoeloStatusColors>();
    final example = switch (entry.status) {
      CatalogStatus.proposed || CatalogStatus.approved => null,
      CatalogStatus.implemented ||
      CatalogStatus.catalogStale ||
      CatalogStatus.deprecated => widget.registry[entry.id],
    };

    return Scaffold(
      appBar: AppBar(title: Text(entry.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(CoeloSpacing.space6),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: CoeloBreakpoints.large.minWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.id, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: CoeloSpacing.space2),
                CoeloStatusChip(
                  label: entry.status.label,
                  backgroundColor: statusColors?.infoContainer ?? colors.primaryContainer,
                  foregroundColor: statusColors?.onInfoContainer ?? colors.onPrimaryContainer,
                ),
                const SizedBox(height: CoeloSpacing.space6),
                Text(entry.purpose, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: CoeloSpacing.space6),
                _MetadataSection(label: 'Categoria', values: [entry.category]),
                _MetadataSection(label: 'Pacote', values: [entry.ownerPackage]),
                _MetadataSection(label: 'Consumidores', values: entry.consumers),
                _MetadataSection(
                  label: 'Variantes aprovadas',
                  values: entry.variants.isEmpty ? const ['Nenhuma'] : entry.variants,
                ),
                _MetadataSection(label: 'Estados', values: entry.states),
                _MetadataSection(label: 'Tokens', values: entry.tokens),
                _MetadataSection(label: 'Arquivos', values: [entry.publicFile, ...entry.tests]),
                if (entry.replacement case final replacement?)
                  _MetadataSection(label: 'Substituto', values: [replacement]),
                const SizedBox(height: CoeloSpacing.space4),
                Text('Quando usar', style: Theme.of(context).textTheme.titleMedium),
                Text(entry.useWhen),
                const SizedBox(height: CoeloSpacing.space3),
                Text('Quando não usar', style: Theme.of(context).textTheme.titleMedium),
                Text(entry.doNotUseWhen),
                const SizedBox(height: CoeloSpacing.space3),
                Text('Acessibilidade', style: Theme.of(context).textTheme.titleMedium),
                Text(entry.accessibility),
                const SizedBox(height: CoeloSpacing.space6),
                Text('Snippet mínimo', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: CoeloSpacing.space2),
                SelectableText(entry.example),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('catalog-copy-snippet'),
                    onPressed: _copySnippet,
                    icon: const Icon(Icons.copy_outlined),
                    label: Text(_copied ? 'Snippet copiado' : 'Copiar snippet'),
                  ),
                ),
                if (_copyFailed)
                  Semantics(liveRegion: true, child: Text('Não foi possível copiar o snippet.')),
                const SizedBox(height: CoeloSpacing.space6),
                Text('Exemplo interativo', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: CoeloSpacing.space3),
                if (example == null)
                  const Text('Ainda não renderizável')
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      key: const Key('catalog-preview-frame'),
                      width: widget.previewWidth,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(CoeloSpacing.space4),
                          child: KeyedSubtree(
                            key: Key('catalog-real-component-${entry.id}'),
                            child: example.builder(context),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _MetadataSection extends StatelessWidget {
  const _MetadataSection({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          Text(values.join(', ')),
        ],
      ),
    );
  }
}
