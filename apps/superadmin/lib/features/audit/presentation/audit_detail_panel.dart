import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../../app/prototype/superadmin_prototype_store.dart';

final class AuditDetailPanel extends StatelessWidget {
  const AuditDetailPanel({required this.event, required this.onClose, super.key});

  final PrototypeAuditEvent event;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Detalhe do evento', style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'Fechar detalhe',
                    color: colors.error,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: CoeloSpacing.space4),
              _RiskBadge(risk: event.risk),
              const SizedBox(height: CoeloSpacing.space4),
              _Field('ID', event.id),
              _Field('Instante', _formatInstant(event.occurredAt)),
              _Field('Ator fake', event.actor),
              _Field('Escopo', event.scope),
              _Field('Motivo', event.reason),
              _Field('Origem', event.origin),
              _Field('MFA simulado', event.mfa ? 'Sim' : 'Não'),
              if (event.relatedReference case final reference?)
                _Field('Referência relacionada', reference),
              const SizedBox(height: CoeloSpacing.space3),
              _ChangeSection(title: 'Before minimizado', values: event.before),
              const SizedBox(height: CoeloSpacing.space3),
              _ChangeSection(title: 'After minimizado', values: event.after),
            ],
          ),
        ),
      ),
    );
  }
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

final class _ChangeSection extends StatelessWidget {
  const _ChangeSection({required this.title, required this.values});

  final String title;
  final Map<String, String> values;

  @override
  Widget build(BuildContext context) => Semantics(
    label: title,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: CoeloSpacing.space2),
            if (values.isEmpty)
              const Text('Sem alterações registradas.')
            else
              for (final entry in values.entries) Text('${entry.key}: ${entry.value}'),
          ],
        ),
      ),
    ),
  );
}

final class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.risk});

  final PrototypeAuditRisk risk;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, icon, background, foreground) = switch (risk) {
      PrototypeAuditRisk.low => (
        'Risco baixo',
        Icons.shield_outlined,
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      PrototypeAuditRisk.medium => (
        'Risco médio',
        Icons.warning_amber_rounded,
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      PrototypeAuditRisk.high => (
        'Risco alto',
        Icons.gpp_bad_outlined,
        colors.errorContainer,
        colors.onErrorContainer,
      ),
    };
    return Semantics(
      label: label,
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(CoeloRadius.full),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CoeloSpacing.space3,
              vertical: CoeloSpacing.space1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foreground),
                const SizedBox(width: CoeloSpacing.space1),
                Text(label, style: TextStyle(color: foreground)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatInstant(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}
