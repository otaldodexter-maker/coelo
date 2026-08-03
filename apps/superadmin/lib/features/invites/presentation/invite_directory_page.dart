import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import '../data/fake_invite_repository.dart';
import '../domain/platform_invite.dart';

enum InviteDirectoryState { loading, content, empty, noResults, error, unauthorized }

final class InviteDirectoryPage extends StatefulWidget {
  const InviteDirectoryPage({
    required this.repository,
    this.onCreate,
    this.onOpen,
    this.state = InviteDirectoryState.content,
    super.key,
  });
  final FakeInviteRepository repository;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onOpen;
  final InviteDirectoryState state;
  @override
  State<InviteDirectoryPage> createState() => _InviteDirectoryPageState();
}

final class _InviteDirectoryPageState extends State<InviteDirectoryPage> {
  final _searchController = TextEditingController();
  InviteQuery _query = const InviteQuery();
  bool _cards = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.repository.list(_query);
    return LayoutBuilder(
      builder: (context, c) => Padding(
        padding: EdgeInsets.all(c.maxWidth < 768 ? CoeloSpacing.space4 : CoeloSpacing.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Convites', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: CoeloSpacing.space2),
            const Text('Acompanhe convites fictícios do preview local.'),
            const SizedBox(height: CoeloSpacing.space4),
            CoeloAdminListingToolbar(
              search: SizedBox(
                width: 280,
                child: CoeloSearchField(
                  controller: _searchController,
                  semanticLabel: 'Buscar convites',
                  hintText: 'Buscar convite',
                  onChanged: (v) =>
                      setState(() => _query = InviteQuery(search: v, statuses: _query.statuses)),
                ),
              ),
              filters: [
                for (final s in InviteStatus.values)
                  FilterChip(
                    label: Text(s.label),
                    selected: _query.statuses.contains(s),
                    onSelected: (yes) => setState(() {
                      final values = {..._query.statuses};
                      yes ? values.add(s) : values.remove(s);
                      _query = InviteQuery(search: _query.search, statuses: values);
                    }),
                  ),
              ],
              actions: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.grid_view_rounded),
                      label: Text('Cards'),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.table_rows_rounded),
                      label: Text('Tabela'),
                    ),
                  ],
                  selected: {_cards},
                  onSelectionChanged: (s) => setState(() => _cards = s.single),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space4),
            Expanded(
              child: _Body(
                state: widget.state,
                items: items,
                cards: _cards,
                onCreate: widget.onCreate,
                onOpen: widget.onOpen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.items,
    required this.cards,
    this.onCreate,
    this.onOpen,
  });
  final InviteDirectoryState state;
  final List<PlatformInvite> items;
  final bool cards;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onOpen;
  @override
  Widget build(BuildContext context) {
    if (state != InviteDirectoryState.content) {
      return CoeloStatePanel(
        title: switch (state) {
          InviteDirectoryState.loading => 'Carregando convites',
          InviteDirectoryState.empty => 'Nenhum convite',
          InviteDirectoryState.noResults => 'Nenhum resultado',
          InviteDirectoryState.error => 'Convites indisponíveis',
          InviteDirectoryState.unauthorized => 'Acesso não autorizado',
          InviteDirectoryState.content => '',
        },
        message: 'Este é um estado local de demonstração.',
        icon: Icons.mail_outline_rounded,
      );
    }
    if (items.isEmpty) {
      return const CoeloStatePanel(
        title: 'Nenhum resultado',
        message: 'Ajuste a busca ou os filtros.',
        icon: Icons.search_off_rounded,
      );
    }
    if (!cards) {
      return ListView(
        children: [
          CoeloAdminCreateAction(
            variant: CoeloAdminCreateActionVariant.banner,
            label: 'Novo convite',
            description: 'Inicie um convite local.',
            onPressed: onCreate,
          ),
          const SizedBox(height: CoeloSpacing.space4),
          for (final i in items)
            ListTile(
              title: Text(i.recipientMasked),
              subtitle: Text('${i.audience.label} · ${i.status.label}'),
              onTap: () => onOpen?.call(i.id),
            ),
        ],
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        mainAxisSpacing: CoeloSpacing.space6,
        crossAxisSpacing: CoeloSpacing.space6,
        mainAxisExtent: 216,
      ),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return CoeloAdminCreateAction(
            label: 'Novo convite',
            description: 'Convide uma pessoa para o preview.',
            onPressed: onCreate,
          );
        }
        final i = items[index - 1];
        return CoeloAdminInteractiveCard(
          onPressed: () => onOpen?.call(i.id),
          semanticLabel: 'Abrir convite ${i.recipientMasked}',
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.recipientMasked, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: CoeloSpacing.space2),
                Text(i.audience.label),
                Text(i.scope),
                const Spacer(),
                Text('${i.channel.label} · ${i.status.label}'),
              ],
            ),
          ),
        );
      },
    );
  }
}
