import 'dart:convert';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import 'chat_catalog_examples.dart';

typedef CatalogExampleBuilder = Widget Function(BuildContext context);

const catalogRegistryManifestJson = r'''
{
  "core.search-field": [],
  "core.form-text-field": [],
  "core.status-chip": [],
  "core.state-panel": [],
  "core.chat-avatar": [],
  "core.conversation-tile": [],
  "core.conversation-header": [],
  "core.message-bubble": [],
  "core.chat-composer": [],
  "admin.listing-toolbar": [],
  "admin.multi-select-filter": [],
  "admin.single-select-field": [],
  "admin.pagination": [],
  "admin.create-action": [],
  "admin.file-actions": [],
  "admin.resizable-table": [],
  "admin.kanban-board": [],
  "admin.work-item-card": [],
  "admin.assignee-stack": [],
  "admin.workspace-layout": [],
  "admin.context-picker": []
}
''';

final class CatalogExample {
  const CatalogExample({required this.builder, required this.approvedVariants});

  final CatalogExampleBuilder builder;
  final List<String> approvedVariants;
}

Map<String, CatalogExample> buildCatalogRegistry() {
  final builders = <String, CatalogExampleBuilder>{
    'core.search-field': (_) => const _SearchFieldExample(),
    'core.form-text-field': (_) => const _FormTextFieldExample(),
    'core.status-chip': (_) => const _StatusChipExample(),
    'core.state-panel': (_) => const _StatePanelExample(),
    'admin.listing-toolbar': (_) => const _ListingToolbarExample(),
    'admin.multi-select-filter': (_) => const _MultiSelectFilterExample(),
    'admin.single-select-field': (_) => const _SingleSelectFieldExample(),
    'admin.pagination': (_) => const _PaginationExample(),
    'admin.create-action': (_) => const _CreateActionExample(),
    'admin.file-actions': (_) => const _FileActionsExample(),
    'admin.resizable-table': (_) => const _ResizableTableExample(),
    'admin.kanban-board': (_) => const _KanbanBoardExample(),
    'admin.work-item-card': (_) => const _WorkItemCardExample(),
    'admin.assignee-stack': (_) => const _AssigneeStackExample(),
    'admin.workspace-layout': (_) => const _WorkspaceLayoutExample(),
    ...buildChatCatalogExamples(),
  };
  final decoded = jsonDecode(catalogRegistryManifestJson) as Map<String, Object?>;
  final variants = decoded.map(
    (id, values) =>
        MapEntry(id, List<String>.unmodifiable((values as List<Object?>).cast<String>())),
  );
  if (builders.length != variants.length || builders.keys.any((id) => !variants.containsKey(id))) {
    throw StateError('O manifesto e os builders do catálogo estão divergentes.');
  }
  return {
    for (final builder in builders.entries)
      builder.key: CatalogExample(builder: builder.value, approvedVariants: variants[builder.key]!),
  };
}

final class _FormTextFieldExample extends StatefulWidget {
  const _FormTextFieldExample();

  @override
  State<_FormTextFieldExample> createState() => _FormTextFieldExampleState();
}

final class _FormTextFieldExampleState extends State<_FormTextFieldExample> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CoeloFormTextField(
    controller: controller,
    labelText: 'E-mail',
    hintText: 'seu.email@coelo.me',
    prefixIcon: Icons.mail_outline_rounded,
  );
}

final class _SearchFieldExample extends StatefulWidget {
  const _SearchFieldExample();

  @override
  State<_SearchFieldExample> createState() => _SearchFieldExampleState();
}

final class _SearchFieldExampleState extends State<_SearchFieldExample> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CoeloSearchField(
      controller: _controller,
      onChanged: (_) {},
      semanticLabel: 'Buscar no exemplo',
      hintText: 'Buscar',
    );
  }
}

final class _StatusChipExample extends StatelessWidget {
  const _StatusChipExample();

  @override
  Widget build(BuildContext context) {
    final status = Theme.of(context).extension<CoeloStatusColors>()!;
    return CoeloStatusChip(
      label: 'Ativa',
      backgroundColor: status.successContainer,
      foregroundColor: status.onSuccessContainer,
      icon: Icons.check_circle_outline,
    );
  }
}

final class _StatePanelExample extends StatelessWidget {
  const _StatePanelExample();

  @override
  Widget build(BuildContext context) {
    return const CoeloStatePanel(
      title: 'Sem resultados',
      message: 'Ajuste os filtros para tentar novamente.',
      icon: Icons.search_off_outlined,
    );
  }
}

final class _ListingToolbarExample extends StatefulWidget {
  const _ListingToolbarExample();

  @override
  State<_ListingToolbarExample> createState() => _ListingToolbarExampleState();
}

final class _ListingToolbarExampleState extends State<_ListingToolbarExample> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CoeloAdminListingToolbar(
      search: SizedBox(
        width: CoeloBreakpoints.compact.maxWidth,
        child: CoeloSearchField(
          controller: _controller,
          onChanged: (_) {},
          semanticLabel: 'Buscar instituições',
          hintText: 'Buscar instituições',
        ),
      ),
      filters: [OutlinedButton(onPressed: () {}, child: const Text('Status'))],
      actions: [FilledButton(onPressed: () {}, child: const Text('Criar instituição'))],
    );
  }
}

final class _MultiSelectFilterExample extends StatefulWidget {
  const _MultiSelectFilterExample();

  @override
  State<_MultiSelectFilterExample> createState() => _MultiSelectFilterExampleState();
}

final class _MultiSelectFilterExampleState extends State<_MultiSelectFilterExample> {
  Set<String> _selected = const {'Ativa'};

  @override
  Widget build(BuildContext context) {
    return CoeloAdminMultiSelectFilter<String>(
      label: 'Status',
      options: const ['Ativa', 'Em análise', 'Inativa'],
      selectedValues: _selected,
      optionLabel: (value) => value,
      onChanged: (value) => setState(() => _selected = value),
      searchHintText: 'Buscar status',
    );
  }
}

final class _SingleSelectFieldExample extends StatefulWidget {
  const _SingleSelectFieldExample();

  @override
  State<_SingleSelectFieldExample> createState() => _SingleSelectFieldExampleState();
}

final class _SingleSelectFieldExampleState extends State<_SingleSelectFieldExample> {
  var value = 'Rascunho';

  @override
  Widget build(BuildContext context) => CoeloAdminSingleSelectField<String>(
    label: 'Status',
    value: value,
    options: const ['Rascunho', 'Em implantação', 'Ativa'],
    optionLabel: (option) => option,
    onChanged: (option) => setState(() => value = option),
  );
}

final class _PaginationExample extends StatefulWidget {
  const _PaginationExample();

  @override
  State<_PaginationExample> createState() => _PaginationExampleState();
}

final class _PaginationExampleState extends State<_PaginationExample> {
  var _page = 1;
  var _pageSize = 20;

  @override
  Widget build(BuildContext context) {
    return CoeloAdminPagination(
      currentPage: _page,
      totalPages: 4,
      onPrevious: _page == 1 ? null : () => setState(() => _page--),
      onNext: _page == 4 ? null : () => setState(() => _page++),
      pageSize: _pageSize,
      pageSizeOptions: const [11, 20, 50, 100],
      onPageSizeChanged: (value) => setState(() {
        _pageSize = value;
        _page = 1;
      }),
    );
  }
}

final class _CreateActionExample extends StatefulWidget {
  const _CreateActionExample();

  @override
  State<_CreateActionExample> createState() => _CreateActionExampleState();
}

final class _CreateActionExampleState extends State<_CreateActionExample> {
  var _activations = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CoeloAdminCreateAction(
          label: 'Criar instituição',
          onPressed: () => setState(() => _activations++),
        ),
        const SizedBox(height: CoeloSpacing.space2),
        Text('Ativações: $_activations'),
      ],
    );
  }
}

final class _FileActionsExample extends StatelessWidget {
  const _FileActionsExample();

  @override
  Widget build(BuildContext context) => CoeloAdminFileActions(
    actions: [
      CoeloAdminFileAction(
        label: 'Importar arquivo',
        icon: Icons.upload_file_rounded,
        onPressed: () {},
      ),
      CoeloAdminFileAction(label: 'Exportar CSV', icon: Icons.download_rounded, onPressed: () {}),
    ],
  );
}

final class _KanbanBoardExample extends StatelessWidget {
  const _KanbanBoardExample();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 360,
    child: CoeloAdminKanbanBoard<String, String>(
      statuses: const ['Novo', 'Em andamento'],
      statusLabel: (status) => status,
      itemsForStatus: (status) => status == 'Novo' ? const ['Chamado #1042'] : const [],
      itemBuilder: (context, item) => CoeloAdminWorkItemCard<String>(
        eyebrow: 'Suporte',
        title: item,
        summary: 'Acompanhe o atendimento operacional.',
        onTap: () {},
      ),
      onItemAccepted: (_, _) {},
    ),
  );
}

final class _WorkItemCardExample extends StatelessWidget {
  const _WorkItemCardExample();

  @override
  Widget build(BuildContext context) => CoeloAdminWorkItemCard<String>(
    eyebrow: 'Instituição',
    title: 'Cadastro em revisão',
    summary: 'Documentação recebida e aguardando validação.',
    metadata: const ['Hoje', 'Prioridade normal'],
    onTap: () {},
  );
}

final class _AssigneeStackExample extends StatelessWidget {
  const _AssigneeStackExample();

  @override
  Widget build(BuildContext context) => const CoeloAdminAssigneeStack(
    items: [
      CoeloAdminAssigneeItem(label: 'Ana Lima', initials: 'AL', roleLabel: 'Atendimento'),
      CoeloAdminAssigneeItem(label: 'Caio Melo', initials: 'CM', roleLabel: 'Operações'),
    ],
  );
}

final class _WorkspaceLayoutExample extends StatelessWidget {
  const _WorkspaceLayoutExample();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 320,
    child: CoeloAdminWorkspaceLayout(
      toolbar: const Padding(
        padding: EdgeInsets.all(CoeloSpacing.space3),
        child: Text('Toolbar operacional'),
      ),
      body: const ColoredBox(
        color: Colors.transparent,
        child: Center(child: Text('Lista ou quadro')),
      ),
      detailVisible: true,
      detail: const Center(child: Text('Detalhes')),
    ),
  );
}

final class _ResizableTableExample extends StatelessWidget {
  const _ResizableTableExample();

  @override
  Widget build(BuildContext context) {
    return CoeloAdminResizableTable<_ExampleRow>(
      items: const [_ExampleRow('Aquarela', 'Ativa'), _ExampleRow('Sementinha', 'Em análise')],
      rowKey: (row) => row.name,
      pinnedColumn: CoeloAdminTableColumn(
        id: 'institution',
        label: 'Instituição',
        initialWidth: CoeloBreakpoints.compact.maxWidth,
        minWidth: CoeloSpacing.space20,
        maxWidth: CoeloBreakpoints.medium.maxWidth,
        cellBuilder: (_, row) => Text(row.name),
      ),
      columns: [
        CoeloAdminTableColumn(
          id: 'status',
          label: 'Status',
          initialWidth: CoeloBreakpoints.compact.minWidth + CoeloSpacing.space20,
          minWidth: CoeloSpacing.space16,
          maxWidth: CoeloBreakpoints.compact.maxWidth,
          cellBuilder: (_, row) => Text(row.status),
        ),
      ],
      headerHeight: CoeloSize.touchMin,
      rowHeight: CoeloSize.touchMin,
      onRowPressed: (_) {},
    );
  }
}

final class _ExampleRow {
  const _ExampleRow(this.name, this.status);

  final String name;
  final String status;
}
