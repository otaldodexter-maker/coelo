import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../data/agenda_prototype_store.dart';
import '../domain/agenda_models.dart';

final class AgendaPermissionsPage extends StatelessWidget {
  const AgendaPermissionsPage({required this.store, super.key});
  final AgendaPrototypeStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final effectiveWidth = constraints.maxWidth / textScale;
        final tableBreakpoint = textScale > 1
            ? CoeloBreakpoints.expanded.minWidth
            : CoeloBreakpoints.medium.minWidth;
        final compact = effectiveWidth < tableBreakpoint;
        final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
            ? CoeloSpacing.space10
            : compact
            ? CoeloSpacing.space4
            : CoeloSpacing.space6;
        return ListView(
          key: const Key('agenda-permissions-scroll'),
          padding: EdgeInsets.all(padding),
          children: [
            Text('Permissões', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: CoeloSpacing.space1),
            const Text(
              'A herança é descendente: um nível pode restringir, nunca ampliar permissões.',
            ),
            const SizedBox(height: CoeloSpacing.space6),
            if (compact)
              for (final node in store.contexts) ...[
                _PermissionCard(store: store, node: node),
                const SizedBox(height: CoeloSpacing.space3),
              ]
            else
              _PermissionMatrix(store: store),
            const SizedBox(height: CoeloSpacing.space6),
            Text('Tipos disponíveis', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: CoeloSpacing.space2),
            Wrap(
              spacing: CoeloSpacing.space2,
              runSpacing: CoeloSpacing.space2,
              children: [for (final type in AgendaItemType.values) Chip(label: Text(type.label))],
            ),
          ],
        );
      },
    ),
  );
}

final class _PermissionMatrix extends StatelessWidget {
  const _PermissionMatrix({required this.store});
  final AgendaPrototypeStore store;

  Widget _cell(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
    child: Align(alignment: Alignment.centerLeft, child: child),
  );

  @override
  Widget build(BuildContext context) => CoeloAdminResizableTable<AgendaContext>(
    key: const Key('agenda-permissions-table'),
    items: store.contexts,
    rowKey: (node) => node.id,
    headerHeight: 56,
    rowHeight: 88,
    pinnedColumn: CoeloAdminTableColumn<AgendaContext>(
      id: 'context',
      label: 'Contexto',
      initialWidth: 220,
      minWidth: 180,
      maxWidth: 320,
      cellBuilder: (context, node) => _cell(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(node.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              _label(node.level.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
    columns: [
      CoeloAdminTableColumn<AgendaContext>(
        id: 'publish',
        label: 'Publicar itens',
        initialWidth: 290,
        minWidth: 240,
        maxWidth: 380,
        cellBuilder: (_, node) => _cell(
          _PermissionControl(
            store: store,
            node: node,
            capability: AgendaCapability.publishAgendaItems,
            compact: true,
          ),
        ),
      ),
      CoeloAdminTableColumn<AgendaContext>(
        id: 'birthday',
        label: 'Aprovar aniversário',
        initialWidth: 330,
        minWidth: 270,
        maxWidth: 420,
        cellBuilder: (_, node) => _cell(
          _PermissionControl(
            store: store,
            node: node,
            capability: AgendaCapability.approveGuardianBirthdayRequest,
            compact: true,
          ),
        ),
      ),
    ],
  );
}

final class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.store, required this.node});
  final AgendaPrototypeStore store;
  final AgendaContext node;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(node.name, style: Theme.of(context).textTheme.titleMedium),
          Text(_label(node.level.name)),
          const SizedBox(height: CoeloSpacing.space3),
          _PermissionControl(
            store: store,
            node: node,
            capability: AgendaCapability.publishAgendaItems,
          ),
          _PermissionControl(
            store: store,
            node: node,
            capability: AgendaCapability.approveGuardianBirthdayRequest,
          ),
        ],
      ),
    ),
  );
}

final class _PermissionControl extends StatelessWidget {
  const _PermissionControl({
    required this.store,
    required this.node,
    required this.capability,
    this.compact = false,
  });
  final AgendaPrototypeStore store;
  final AgendaContext node;
  final AgendaCapability capability;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final resolution = store.resolveCapability(node.id, capability);
    final blocked = resolution.state == PermissionState.blockedByAncestor;
    final capabilityLabel = switch (capability) {
      AgendaCapability.publishAgendaItems => 'Publicar itens',
      AgendaCapability.approveGuardianBirthdayRequest => 'Aprovar solicitação de aniversário',
      AgendaCapability.overrideReservationConflict => 'Sobrescrever conflito de reserva',
    };
    final detail = switch (resolution.state) {
      PermissionState.allowed => 'Permitido neste nível',
      PermissionState.inherited =>
        'Herdado de ${resolution.grantedByContextName ?? 'nível superior'}',
      PermissionState.restrictedHere => 'Restringido neste nível',
      PermissionState.blockedByAncestor =>
        'Bloqueado por ${resolution.blockedByContextName ?? 'ancestral'}',
    };
    return Semantics(
      key: Key('agenda-permission-semantics-${node.id}-${capability.name}'),
      label: '$capabilityLabel em ${node.name}. $detail',
      enabled: !blocked,
      toggled: resolution.isAllowed,
      onTap: blocked
          ? null
          : () => store.setCapabilityRestricted(node.id, capability, resolution.isAllowed),
      child: ExcludeSemantics(
        child: CoeloAdminToggleField(
          key: Key('agenda-permission-${node.id}-${capability.name}'),
          label: compact ? detail : capabilityLabel,
          description: compact ? null : detail,
          value: resolution.isAllowed,
          onChanged: blocked
              ? null
              : (value) => store.setCapabilityRestricted(node.id, capability, !value),
        ),
      ),
    );
  }
}

String _label(String value) =>
    '${value[0].toUpperCase()}${value.substring(1).replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)!.toLowerCase()}')}';
