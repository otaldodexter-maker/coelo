import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../domain/audit.dart';
import 'audit_controller.dart';
import 'widgets/audit_actor_summary.dart';
import 'widgets/audit_safe_diff.dart';

final class AuditDetailPanel extends StatelessWidget {
  const AuditDetailPanel({
    required this.snapshot,
    required this.onClose,
    required this.onRetry,
    super.key,
  });

  final AuditDetailSnapshot snapshot;
  final VoidCallback onClose;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CoeloSpacing.space4,
                CoeloSpacing.space2,
                CoeloSpacing.space2,
                CoeloSpacing.space2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Detalhe do evento', style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'Fechar detalhe',
                    color: colors.error,
                    style: ButtonStyle(
                      minimumSize: const WidgetStatePropertyAll(Size.square(CoeloSize.touchMin)),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) =>
                            states.contains(WidgetState.hovered) ||
                                states.contains(WidgetState.focused)
                            ? colors.errorContainer
                            : Colors.transparent,
                      ),
                      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(child: _content(context)),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) => switch (snapshot.state) {
    AuditDetailLoadState.idle => const SizedBox.shrink(),
    AuditDetailLoadState.loading => const Center(child: Text('Carregando detalhe...')),
    AuditDetailLoadState.failure => _DetailState(
      message: 'Não foi possível carregar o detalhe.',
      actionLabel: 'Tentar novamente',
      onAction: onRetry,
    ),
    AuditDetailLoadState.unauthorized => const _DetailState(
      message: 'Você não tem permissão para consultar este detalhe.',
    ),
    AuditDetailLoadState.notFound => const _DetailState(message: 'O evento não foi encontrado.'),
    AuditDetailLoadState.content => _AuditDetailContent(detail: snapshot.value!),
  };
}

final class _AuditDetailContent extends StatelessWidget {
  const _AuditDetailContent({required this.detail});

  final AuditEventDetail detail;

  @override
  Widget build(BuildContext context) {
    final event = detail.event;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuditActorSummary(
            actorName: event.actor.displayName,
            actorRole: event.actor.id == null
                ? event.actor.roleCode
                : '${event.actor.roleCode} · ${event.actor.id}',
            actorContext: event.context.id == null
                ? event.context.kind
                : '${event.context.kind}: ${event.context.id}',
          ),
          const SizedBox(height: CoeloSpacing.space4),
          _Field('Instante', _formatInstant(event.occurredAt)),
          _Field('Ação', event.actionCode),
          _Field('Recurso', _resourceLabel(event)),
          _Field('Resultado', _outcomeLabel(event.outcome)),
          _Field('Origem', _originLabel(event.origin)),
          if (event.institution != null) _Field('Instituição', event.institution!.name),
          if (event.correlationId != null) _Field('Correlation ID', event.correlationId!),
          if (detail.reason != null) _Field('Motivo', detail.reason!),
          _Field('Integridade', detail.integrity.verified ? 'Verificada' : 'Não verificada'),
          const SizedBox(height: CoeloSpacing.space2),
          AuditSafeDiff(title: 'Antes', values: detail.before),
          const SizedBox(height: CoeloSpacing.space3),
          AuditSafeDiff(title: 'Depois', values: detail.after),
        ],
      ),
    );
  }
}

String _outcomeLabel(AuditOutcome value) => switch (value) {
  AuditOutcome.success => 'Sucesso',
  AuditOutcome.failure => 'Falha',
  AuditOutcome.denied => 'Negado',
};

String _originLabel(String value) => switch (value) {
  'edge_function' => 'Edge Function',
  'database' => 'Banco de dados',
  'application' => 'Aplicação',
  _ => value,
};

String _resourceLabel(AuditEvent event) {
  final type = event.resourceType;
  final id = event.resourceId;
  return type == null || id == null ? 'Sem recurso registrado' : '$type: $id';
}

String _formatInstant(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = two(offset.inHours.abs());
  final minutes = two(offset.inMinutes.abs() % 60);
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)} UTC$sign$hours:$minutes';
}

final class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: CoeloSpacing.space1),
        SelectableText(value),
      ],
    ),
  );
}

final class _DetailState extends StatelessWidget {
  const _DetailState({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: CoeloSpacing.space3),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
