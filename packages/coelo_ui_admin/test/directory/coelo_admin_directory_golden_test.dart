import 'dart:io';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Goldens do composto de diretório por largura (375/768/1024/1440), tema
/// claro e escuro, em cards, tabela, vazio e falha. As telas guardam golden
/// só do que é delas; a família vive aqui.
void main() {
  setUpAll(_loadGoldenFonts);

  for (final width in const [375.0, 768.0, 1024.0, 1440.0]) {
    for (final brightness in const [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;
      final w = width.toInt();

      testWidgets('cards e tabela em $w $theme', (tester) async {
        _configure(tester, width);
        await tester.pumpWidget(
          _app(brightness: brightness, display: CoeloAdminDirectoryDisplay.cards),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const Key('coelo-admin-directory-golden-root')),
          matchesGoldenFile('goldens/coelo_admin_directory_cards_${theme}_$w.png'),
        );

        await tester.pumpWidget(
          _app(brightness: brightness, display: CoeloAdminDirectoryDisplay.table),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const Key('coelo-admin-directory-golden-root')),
          matchesGoldenFile('goldens/coelo_admin_directory_table_${theme}_$w.png'),
        );
      });
    }
  }

  for (final status in const [
    CoeloAdminDirectoryStatus.empty,
    CoeloAdminDirectoryStatus.failure,
    CoeloAdminDirectoryStatus.noResults,
    CoeloAdminDirectoryStatus.loading,
    CoeloAdminDirectoryStatus.unauthorized,
  ]) {
    testWidgets('estado ${status.name} em 1440 claro com Criar primeiro', (tester) async {
      _configure(tester, 1440);
      await tester.pumpWidget(_app(status: status, display: CoeloAdminDirectoryDisplay.cards));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await expectLater(
        find.byKey(const Key('coelo-admin-directory-golden-root')),
        matchesGoldenFile('goldens/coelo_admin_directory_${status.name}_light_1440.png'),
      );
    });
  }

  testWidgets('falha em tabela mantém o banner Criar acima do estado', (tester) async {
    _configure(tester, 1440);
    await tester.pumpWidget(
      _app(status: CoeloAdminDirectoryStatus.failure, display: CoeloAdminDirectoryDisplay.table),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('coelo-admin-directory-golden-root')),
      matchesGoldenFile('goldens/coelo_admin_directory_failure_table_light_1440.png'),
    );
  });
}

void _configure(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _app({
  Brightness brightness = Brightness.light,
  CoeloAdminDirectoryStatus status = CoeloAdminDirectoryStatus.success,
  required CoeloAdminDirectoryDisplay display,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  themeAnimationStyle: AnimationStyle.noAnimation,
  builder: (context, child) => RepaintBoundary(
    key: const Key('coelo-admin-directory-golden-root'),
    child: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: true, textScaler: TextScaler.noScaling),
      child: child!,
    ),
  ),
  home: Scaffold(
    body: _DirectoryHost(key: ValueKey(display), status: status, display: display),
  ),
);

final class _DirectoryHost extends StatefulWidget {
  const _DirectoryHost({required this.status, required this.display, super.key});

  final CoeloAdminDirectoryStatus status;
  final CoeloAdminDirectoryDisplay display;

  @override
  State<_DirectoryHost> createState() => _DirectoryHostState();
}

final class _DirectoryHostState extends State<_DirectoryHost> {
  final _search = TextEditingController();
  late CoeloAdminDirectoryDisplay _display = widget.display;
  CoeloAdminDirectoryStatusTab _tab = CoeloAdminDirectoryStatusTab.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDirectory<String>(
    status: widget.status,
    messages: const CoeloAdminDirectoryMessages(
      empty: 'Ainda não há registros cadastrados.',
      noResults: 'Nenhum registro encontrado com estes filtros.',
      failure: 'Não foi possível carregar os registros. Tente novamente.',
      unauthorized: 'Você não tem permissão para visualizar este diretório.',
    ),
    search: TextField(
      controller: _search,
      decoration: const InputDecoration(
        hintText: 'Buscar por nome',
        prefixIcon: Icon(Icons.search_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(999))),
        isDense: true,
      ),
    ),
    filters: [
      _FilterStub(label: 'Todos os tipos'),
      _FilterStub(label: 'Todas as UFs'),
    ],
    display: _display,
    onDisplayChanged: (value) => setState(() => _display = value),
    groupedTableView: 'grouped',
    selectedTableView: 'grouped',
    tableViews: const [CoeloAdminDirectoryTableViewOption(value: 'grouped', label: 'Agrupado')],
    onTableViewSelected: (_) {},
    fileActions: [
      CoeloAdminFileAction(label: 'Importar', icon: Icons.upload_file_outlined, onPressed: () {}),
      CoeloAdminFileAction(label: 'Exportar XLSX', icon: Icons.grid_on_outlined, onPressed: () {}),
    ],
    tabs: CoeloAdminDirectoryStatusTabs(
      selected: _tab,
      onSelected: (value) => setState(() => _tab = value),
    ),
    create: CoeloAdminDirectoryCreate(
      label: 'Criar registro',
      description: 'Adicionar novo registro ao sistema.',
      icon: Icons.add_business_outlined,
      onPressed: () {},
    ),
    onRetry: () {},
    onClearFilters: () {},
    cards: [for (var index = 0; index < 5; index++) _SampleCard(index: index)],
    table: _SampleTable(),
    pagination: CoeloAdminDirectoryPagination(
      currentPage: 1,
      totalPages: 2,
      pageSize: 11,
      pageSizeOptions: const [11, 20, 50, 100],
      onPageSelected: (_) {},
      onPageSizeChanged: (_) {},
    ),
  );
}

final class _FilterStub extends StatelessWidget {
  const _FilterStub({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(CoeloSize.touchMin),
        padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
        shape: const StadiumBorder(),
        foregroundColor: colors.onSurfaceVariant,
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const Icon(Icons.arrow_drop_down_rounded),
        ],
      ),
    );
  }
}

final class _SampleCard extends StatelessWidget {
  const _SampleCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return CoeloAdminInteractiveCard(
      onPressed: () {},
      minHeight: CoeloAdminDirectoryMetrics.cardMinHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CoeloSpacing.space6,
          vertical: CoeloSpacing.space4,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.secondaryContainer,
                  foregroundColor: colors.onSecondaryContainer,
                  child: Text('R${index + 1}'),
                ),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registro ${index + 1}',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Centro, Cidade/UF',
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space4),
            const Divider(height: 1),
            const SizedBox(height: CoeloSpacing.space4),
            Text('Detalhe ${index + 1}', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

final class _SampleTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) => CoeloAdminResizableTable<int>(
    items: const [0, 1, 2, 3, 4],
    rowKey: (item) => 'row-$item',
    pinnedColumn: CoeloAdminTableColumn<int>(
      id: 'name',
      label: 'Registro',
      initialWidth: 220,
      minWidth: 180,
      maxWidth: 600,
      sortable: true,
      cellBuilder: (context, item) => Text('Registro ${item + 1}'),
    ),
    columns: [
      for (final column in const ['Tipo', 'Unidades', 'Turmas', 'Status'])
        CoeloAdminTableColumn<int>(
          id: column.toLowerCase(),
          label: column,
          initialWidth: 160,
          minWidth: 100,
          maxWidth: 600,
          sortable: false,
          cellBuilder: (context, item) => Text('$column ${item + 1}'),
        ),
    ],
    headerHeight: 56,
    rowHeight: 64,
    sortColumnId: 'name',
    sortAscending: true,
    onSort: (_) {},
  );
}

Future<void> _loadGoldenFonts() async {
  final nunitoBytes = File(
    '../../assets/brand/fonts/nunito-sans/NunitoSans-VariableFont_YTLC,opsz,wdth,wght.ttf',
  ).readAsBytesSync();
  final nunitoSans = FontLoader('Nunito Sans')
    ..addFont(Future.value(ByteData.sublistView(nunitoBytes)));
  await nunitoSans.load();

  final flutterArtifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final materialIcons = File(
    '${flutterArtifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  final materialIconsLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await materialIconsLoader.load();
}
