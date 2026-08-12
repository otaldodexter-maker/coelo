import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../domain/audit.dart';

final class AuditTimeline extends StatelessWidget {
  const AuditTimeline({required this.events, required this.onSelected, super.key});

  final List<AuditEvent> events;
  final ValueChanged<AuditEvent> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Linha do tempo de auditoria',
    container: true,
    explicitChildNodes: true,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(1, (constraints.maxWidth / 340).floor());
        final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space6) / columns;
        return Wrap(
          key: const Key('audit-card-list'),
          spacing: CoeloSpacing.space6,
          runSpacing: CoeloSpacing.space6,
          children: [
            for (final event in events)
              SizedBox(
                width: width,
                child: CoeloAdminInteractiveCard(
                  key: Key('audit-card-${event.id}'),
                  semanticLabel: 'Abrir evento de auditoria ${event.id}',
                  minHeight: 216,
                  onPressed: () => onSelected(event),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CoeloSpacing.space6,
                      vertical: CoeloSpacing.space4,
                    ),
                    child: _TimelineEvent(event: event),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

final class _TimelineEvent extends StatelessWidget {
  const _TimelineEvent({required this.event});

  final AuditEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(child: Text(event.actionCode, style: theme.textTheme.titleSmall)),
            _OutcomeBadge(outcome: event.outcome),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space3),
        Text(event.actor.displayName),
        Text(event.actor.roleCode, style: theme.textTheme.bodySmall),
        const SizedBox(height: CoeloSpacing.space3),
        const Divider(height: 1),
        const SizedBox(height: CoeloSpacing.space3),
        Text(auditResourceLabel(event), overflow: TextOverflow.ellipsis),
        Text(auditInstantLabel(event.occurredAt), style: theme.textTheme.bodySmall),
      ],
    );
  }
}

final class _OutcomeBadge extends StatelessWidget {
  const _OutcomeBadge({required this.outcome});

  final AuditOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (outcome) {
      AuditOutcome.success => (colors.secondaryContainer, colors.onSecondaryContainer, Icons.check),
      AuditOutcome.failure => (colors.errorContainer, colors.onErrorContainer, Icons.error_outline),
      AuditOutcome.denied => (colors.errorContainer, colors.onErrorContainer, Icons.block),
    };
    return Semantics(
      label: auditOutcomeLabel(outcome),
      child: DecoratedBox(
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: SizedBox.square(
          dimension: CoeloSpacing.space6,
          child: Icon(icon, size: CoeloSize.iconSm, color: foreground),
        ),
      ),
    );
  }
}

String auditOutcomeLabel(AuditOutcome value) => switch (value) {
  AuditOutcome.success => 'Sucesso',
  AuditOutcome.failure => 'Falha',
  AuditOutcome.denied => 'Negado',
};

String auditOriginLabel(String value) => switch (value) {
  'edge_function' => 'Edge Function',
  'database' => 'Banco de dados',
  'application' => 'Aplicação',
  _ => value,
};

String auditResourceLabel(AuditEvent event) {
  final type = event.resourceType;
  final id = event.resourceId;
  return type == null || id == null ? 'Sem recurso registrado' : '$type: $id';
}

String auditInstantLabel(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}
