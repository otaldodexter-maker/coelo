import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../catalog/catalog_entry.dart';
import '../catalog/catalog_foundation.dart';

final class CatalogFoundationPage extends StatelessWidget {
  const CatalogFoundationPage({
    required this.entry,
    required this.foundation,
    this.previewWidth = 375,
    super.key,
  });

  final CatalogEntry entry;
  final CatalogFoundation foundation;
  final double previewWidth;

  @override
  Widget build(BuildContext context) {
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
                Text(entry.purpose, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: CoeloSpacing.space4),
                const Text(
                  'Orientação aprovada. Esta página não cria uma nova API '
                  'pública nem transforma amostras Material em componentes Coelo.',
                ),
                const SizedBox(height: CoeloSpacing.space4),
                _Guidance(label: 'Quando usar', value: entry.useWhen),
                _Guidance(label: 'Quando não usar', value: entry.doNotUseWhen),
                _Guidance(label: 'Acessibilidade', value: entry.accessibility),
                _Guidance(label: 'Tokens', value: entry.tokens.join(', ')),
                if (foundation.referencedComponentIds.isNotEmpty)
                  _Guidance(
                    label: 'Componentes reais relacionados',
                    value: foundation.referencedComponentIds.join(', '),
                  ),
                const SizedBox(height: CoeloSpacing.space4),
                Text('Referência interativa', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: CoeloSpacing.space3),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    key: const Key('catalog-foundation-preview-frame'),
                    width: previewWidth,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(CoeloSpacing.space4),
                        child: KeyedSubtree(
                          key: Key('catalog-foundation-content-${entry.id}'),
                          child: foundation.builder(context),
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

final class _Guidance extends StatelessWidget {
  const _Guidance({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          Text(value),
        ],
      ),
    );
  }
}
