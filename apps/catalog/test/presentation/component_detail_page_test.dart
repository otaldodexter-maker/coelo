import 'package:coelo_catalog/catalog/catalog_entry.dart';
import 'package:coelo_catalog/catalog/catalog_registry.dart';
import 'package:coelo_catalog/presentation/component_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a real implemented component and copies its minimal snippet', (
    tester,
  ) async {
    final clipboard = _Clipboard();
    await tester.pumpWidget(
      MaterialApp(
        home: ComponentDetailPage(
          entry: _implementedEntry,
          registry: buildCatalogRegistry(),
          copySnippet: clipboard.copy,
        ),
      ),
    );

    expect(find.byKey(const Key('catalog-real-component-core.search-field')), findsOneWidget);
    expect(find.text('CoeloSearchField'), findsWidgets);
    final copy = find.byKey(const Key('catalog-copy-snippet'));
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pump();

    expect(clipboard.value, _implementedEntry.example);
    expect(find.text('Snippet copiado'), findsOneWidget);
  });

  testWidgets('keeps approved entries as metadata without a renderable builder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ComponentDetailPage(entry: _approvedEntry, registry: buildCatalogRegistry()),
      ),
    );

    expect(find.text('Ainda não renderizável'), findsOneWidget);
    expect(find.byKey(const Key('catalog-real-component-admin.multi-select-filter')), findsNothing);
  });

  for (final status in [CatalogStatus.catalogStale, CatalogStatus.deprecated]) {
    testWidgets('renders the real component while its status is ${status.name}', (tester) async {
      final entry = _implementedEntry.copyWith(status: status);
      await tester.pumpWidget(
        MaterialApp(
          home: ComponentDetailPage(
            entry: entry,
            registry: {
              entry.id: CatalogExample(
                builder: (_) => const Text('Implementacao real preservada'),
                approvedVariants: const [],
              ),
            },
          ),
        ),
      );

      expect(find.byKey(Key('catalog-real-component-${entry.id}')), findsOneWidget);
      expect(find.text('Implementacao real preservada'), findsOneWidget);
    });
  }

  testWidgets('shows category, approved variants, and replacement as metadata', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ComponentDetailPage(entry: _metadataEntry, registry: buildCatalogRegistry()),
      ),
    );

    expect(find.text('Categoria'), findsOneWidget);
    expect(find.text('pattern'), findsOneWidget);
    expect(find.text('Variantes aprovadas'), findsOneWidget);
    expect(find.text('compact, expanded'), findsOneWidget);
    expect(find.text('Substituto'), findsOneWidget);
    expect(find.text('core.search-field'), findsOneWidget);
  });

  testWidgets('announces a clipboard failure without exposing an exception', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ComponentDetailPage(
          entry: _implementedEntry,
          registry: buildCatalogRegistry(),
          copySnippet: (_) async => throw StateError('clipboard unavailable'),
        ),
      ),
    );

    final copy = find.byKey(const Key('catalog-copy-snippet'));
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pump();

    expect(find.text('Não foi possível copiar o snippet.'), findsOneWidget);
    expect(tester.getSemantics(find.text('Não foi possível copiar o snippet.')), isNotNull);
  });
}

final _implementedEntry = CatalogEntry(
  id: 'core.search-field',
  name: 'CoeloSearchField',
  category: 'component',
  status: CatalogStatus.implemented,
  ownerPackage: 'coelo_ui_core',
  consumers: const ['superadmin'],
  purpose: 'Busca textual',
  useWhen: 'Buscar',
  doNotUseWhen: 'Selecionar',
  variants: const [],
  states: const ['enabled'],
  tokens: const ['color.primary'],
  accessibility: 'Rotulo',
  publicFile: 'packages/coelo_ui_core/lib/coelo_ui_core.dart',
  tests: const [],
  example: "CoeloSearchField(semanticLabel: 'Buscar')",
);

final _approvedEntry = CatalogEntry(
  id: 'admin.multi-select-filter',
  name: 'CoeloAdminMultiSelectFilter',
  category: 'component',
  status: CatalogStatus.approved,
  ownerPackage: 'coelo_ui_admin',
  consumers: const ['admin', 'superadmin'],
  purpose: 'Selecionar varias opcoes',
  useWhen: 'Filtrar',
  doNotUseWhen: 'Dominio',
  variants: const [],
  states: const ['closed'],
  tokens: const ['size.touch-min'],
  accessibility: 'Teclado',
  publicFile: 'packages/coelo_ui_admin/lib/coelo_ui_admin.dart',
  tests: const [],
  example: 'CoeloAdminMultiSelectFilter()',
);

final _metadataEntry = CatalogEntry(
  id: 'legacy.pattern',
  name: 'LegacyPattern',
  category: 'pattern',
  status: CatalogStatus.deprecated,
  ownerPackage: 'coelo_ui_core',
  consumers: const ['shared'],
  purpose: 'Pattern legacy',
  useWhen: 'Nunca para código novo',
  doNotUseWhen: 'Use o substituto',
  variants: const ['compact', 'expanded'],
  states: const ['default'],
  tokens: const ['color.primary'],
  accessibility: 'Texto',
  publicFile: 'packages/coelo_ui_core/lib/coelo_ui_core.dart',
  tests: const [],
  example: 'LegacyPattern()',
  replacement: 'core.search-field',
);

extension on CatalogEntry {
  CatalogEntry copyWith({required CatalogStatus status}) {
    return CatalogEntry(
      id: id,
      name: name,
      category: category,
      status: status,
      ownerPackage: ownerPackage,
      consumers: consumers,
      purpose: purpose,
      useWhen: useWhen,
      doNotUseWhen: doNotUseWhen,
      variants: variants,
      states: states,
      tokens: tokens,
      accessibility: accessibility,
      publicFile: publicFile,
      tests: tests,
      example: example,
      replacement: status == CatalogStatus.deprecated ? 'core.status-chip' : replacement,
    );
  }
}

final class _Clipboard {
  String? value;

  Future<void> copy(String value) async {
    this.value = value;
  }
}
