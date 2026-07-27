import 'package:coelo_catalog/catalog/catalog_sync_status.dart';
import 'package:coelo_catalog/presentation/widgets/catalog_stale_banner.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the exact persistent stale warning and status', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: const Scaffold(
          body: CatalogStaleBanner(
            report: CatalogSyncReport(
              status: CatalogSyncStatus.catalogStale,
              diagnostics: [CatalogSyncDiagnostic(code: 'missing-index-entry', message: 'Ausente')],
              fingerprints: {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Componente implementado; índice e catálogo desatualizados.'), findsOneWidget);
    expect(find.text('catálogo desatualizado'), findsOneWidget);
    expect(find.byType(CloseButton), findsNothing);
    expect(find.byTooltip('Fechar'), findsNothing);

    final semantics = tester.getSemantics(find.byKey(const Key('catalog-stale-banner')));
    expect(semantics.flagsCollection.isLiveRegion, isTrue);
  });

  testWidgets('renders nothing while the catalog is synchronized', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: const CatalogStaleBanner(report: CatalogSyncReport.synchronized())),
    );

    expect(find.byKey(const Key('catalog-stale-banner')), findsNothing);
    expect(find.text('Componente implementado; índice e catálogo desatualizados.'), findsNothing);
  });
}
