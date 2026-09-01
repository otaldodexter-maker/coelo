import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../domain/agenda_repository.dart';
import '../domain/agenda_models.dart';

enum _AgendaPermissionsAccess { available, unavailable, unauthorized }

final class AgendaPermissionsPage extends StatelessWidget {
  const AgendaPermissionsPage({required AgendaRepository store, super.key})
    : _store = store,
      _access = _AgendaPermissionsAccess.available;

  const AgendaPermissionsPage.unavailable({super.key})
    : _store = null,
      _access = _AgendaPermissionsAccess.unavailable;

  const AgendaPermissionsPage.unauthorized({super.key})
    : _store = null,
      _access = _AgendaPermissionsAccess.unauthorized;

  final AgendaRepository? _store;
  final _AgendaPermissionsAccess _access;

  AgendaRepository get store => _store!;

  @override
  Widget build(BuildContext context) => switch (_access) {
    _AgendaPermissionsAccess.unavailable => const _BlockedPermissionsContent(
      key: Key('agenda-permissions-unavailable'),
      icon: Icons.cloud_off_outlined,
      title: 'Permissões indisponíveis',
      message:
          'A composição está pronta, mas a leitura produtiva permanece bloqueada até existir integração autorizada.',
    ),
    _AgendaPermissionsAccess.unauthorized => const _BlockedPermissionsContent(
      key: Key('agenda-permissions-unauthorized'),
      icon: Icons.lock_outline_rounded,
      title: 'Acesso não autorizado',
      message: '403 · Você conhece esta área, mas não possui permissão para consultar seus dados.',
    ),
    _AgendaPermissionsAccess.available => AnimatedBuilder(
      animation: _store!,
      builder: (context, _) => _PermissionsContent(store: _store),
    ),
  };
}

final class _BlockedPermissionsContent extends StatelessWidget {
  const _BlockedPermissionsContent({
    required super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title, message;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
          ? CoeloSpacing.space10
          : constraints.maxWidth < CoeloBreakpoints.medium.minWidth
          ? CoeloSpacing.space4
          : CoeloSpacing.space6;
      return ListView(
        padding: EdgeInsets.all(padding),
        children: [
          Text('Permissões da Agenda', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: CoeloSpacing.space1),
          const Text(
            'Consulta somente leitura: a fonte de verdade é Perfis e Permissões. A Agenda apenas mostra a capacidade efetiva e sua origem.',
          ),
          const SizedBox(height: CoeloSpacing.space6),
          _PermissionsState(
            key: const Key('agenda-permissions-unavailable-content'),
            icon: icon,
            title: title,
            message: message,
          ),
        ],
      );
    },
  );
}

final class _PermissionsState extends StatelessWidget {
  const _PermissionsState({
    required super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title, message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(CoeloSpacing.space6),
    child: CoeloStatePanel(icon: icon, title: title, message: message),
  );
}

final class _PermissionsContent extends StatelessWidget {
  const _PermissionsContent({required this.store});
  final AgendaRepository store;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
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
          Text('Permissões da Agenda', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: CoeloSpacing.space1),
          const Text(
            'Consulta somente leitura: a fonte de verdade é Perfis e Permissões. A Agenda apenas mostra a capacidade efetiva e sua origem.',
          ),
          const SizedBox(height: CoeloSpacing.space6),
          if (compact)
            for (final node in store.contexts) ...[
              _PermissionCard(store: store, node: node),
              const SizedBox(height: CoeloSpacing.space3),
            ]
          else
            _PermissionMatrix(store: store),
        ],
      );
    },
  );
}

final class _PermissionMatrix extends StatelessWidget {
  const _PermissionMatrix({required this.store});
  final AgendaRepository store;

  Widget _cell(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
    child: Align(alignment: Alignment.centerLeft, child: child),
  );

  @override
  Widget build(BuildContext context) => CoeloAdminResizableTable<AgendaContext>(
    key: const Key('agenda-permissions-table'),
    items: store.contexts,
    rowKey: (node) => node.id,
    headerHeight: 64,
    rowHeight: 104,
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
              _sentence(node.level.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
    columns: [
      for (final capability in AgendaCapability.values)
        CoeloAdminTableColumn<AgendaContext>(
          id: capability.name,
          label: _shortCapabilityLabel(capability),
          initialWidth: 250,
          minWidth: 220,
          maxWidth: 340,
          cellBuilder: (_, node) => _cell(
            _PermissionResolutionView(
              store: store,
              node: node,
              capability: capability,
              compact: true,
            ),
          ),
        ),
    ],
  );
}

final class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.store, required this.node});
  final AgendaRepository store;
  final AgendaContext node;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: Key('agenda-permission-card-${node.id}'),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(node.name, style: Theme.of(context).textTheme.titleMedium),
          Text(_sentence(node.level.name)),
          const SizedBox(height: CoeloSpacing.space3),
          for (final capability in AgendaCapability.values) ...[
            _PermissionResolutionView(store: store, node: node, capability: capability),
            if (capability != AgendaCapability.values.last)
              const Divider(height: CoeloSpacing.space5),
          ],
        ],
      ),
    ),
  );
}

final class _PermissionResolutionView extends StatelessWidget {
  const _PermissionResolutionView({
    required this.store,
    required this.node,
    required this.capability,
    this.compact = false,
  });

  final AgendaRepository store;
  final AgendaContext node;
  final AgendaCapability capability;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final resolution = store.resolveCapability(node.id, capability);
    final detail = _resolutionDetail(resolution);
    final colors = Theme.of(context).colorScheme;
    final statusColor = switch (resolution.state) {
      PermissionState.allowed => colors.primaryContainer,
      PermissionState.inherited => colors.secondaryContainer,
      PermissionState.restrictedHere => colors.tertiaryContainer,
      PermissionState.blockedByAncestor => colors.errorContainer,
    };
    final foreground = switch (resolution.state) {
      PermissionState.allowed => colors.onPrimaryContainer,
      PermissionState.inherited => colors.onSecondaryContainer,
      PermissionState.restrictedHere => colors.onTertiaryContainer,
      PermissionState.blockedByAncestor => colors.onErrorContainer,
    };
    return Semantics(
      key: Key('agenda-permission-semantics-${node.id}-${_capabilityKey(capability)}'),
      container: true,
      label: '${_capabilityLabel(capability)} em ${node.name}. $detail. Somente leitura.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!compact)
              Text(_capabilityLabel(capability), style: Theme.of(context).textTheme.labelLarge),
            if (!compact) const SizedBox(height: CoeloSpacing.space1),
            CoeloStatusChip(
              label: _stateLabel(resolution.state),
              backgroundColor: statusColor,
              foregroundColor: foreground,
            ),
            const SizedBox(height: CoeloSpacing.space1),
            Text(
              detail,
              maxLines: compact ? 2 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _stateLabel(PermissionState state) => switch (state) {
  PermissionState.allowed => 'Permitido neste nível',
  PermissionState.inherited => 'Herdado',
  PermissionState.restrictedHere => 'Restringido neste nível',
  PermissionState.blockedByAncestor => 'Bloqueado',
};

String _resolutionDetail(PermissionResolution resolution) => switch (resolution.state) {
  PermissionState.allowed => 'Permitido neste nível',
  PermissionState.inherited => 'Herdado de ${resolution.grantedByContextName ?? 'nível superior'}',
  PermissionState.restrictedHere => 'Restringido neste nível',
  PermissionState.blockedByAncestor =>
    'Bloqueado por ${resolution.blockedByContextName ?? 'nível superior'}',
};

String _capabilityKey(AgendaCapability capability) => capability.name;

String _shortCapabilityLabel(AgendaCapability capability) => switch (capability) {
  AgendaCapability.createAgendaItems => 'Criar',
  AgendaCapability.editOwnAgendaItems => 'Editar próprios',
  AgendaCapability.editAllAgendaItems => 'Editar todos',
  AgendaCapability.publishAgendaItems => 'Publicar',
  AgendaCapability.cancelOrRestoreAgendaItems => 'Cancelar/restaurar',
  AgendaCapability.manageResponsesAndAuthorizations => 'Gerenciar respostas',
  AgendaCapability.overrideReservationConflict => 'Override de reserva',
};

String _capabilityLabel(AgendaCapability capability) => switch (capability) {
  AgendaCapability.createAgendaItems => 'Criar eventos',
  AgendaCapability.editOwnAgendaItems => 'Editar eventos próprios',
  AgendaCapability.editAllAgendaItems => 'Editar todos os eventos',
  AgendaCapability.publishAgendaItems => 'Publicar eventos',
  AgendaCapability.cancelOrRestoreAgendaItems => 'Cancelar ou restaurar eventos',
  AgendaCapability.manageResponsesAndAuthorizations => 'Gerenciar respostas e autorizações',
  AgendaCapability.overrideReservationConflict => 'Sobrescrever conflito de reserva',
};

String _sentence(String value) =>
    '${value[0].toUpperCase()}${value.substring(1).replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)!.toLowerCase()}')}';
