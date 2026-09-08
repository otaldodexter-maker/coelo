import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

Future<String?> showAgendaReservationConflictOverrideDialog(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push<String>(createAgendaReservationConflictOverrideRoute(context));

DialogRoute<String> createAgendaReservationConflictOverrideRoute(BuildContext context) =>
    DialogRoute<String>(
      context: context,
      themes: InheritedTheme.capture(
        from: context,
        to: Navigator.of(context, rootNavigator: true).context,
      ),
      barrierColor:
          DialogTheme.of(context).barrierColor ??
          Theme.of(context).colorScheme.scrim.withValues(alpha: 0.54),
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      builder: (_) => const _AgendaReservationConflictOverrideDialog(),
    );

final class _AgendaReservationConflictOverrideDialog extends StatefulWidget {
  const _AgendaReservationConflictOverrideDialog();

  @override
  State<_AgendaReservationConflictOverrideDialog> createState() =>
      _AgendaReservationConflictOverrideDialogState();
}

final class _AgendaReservationConflictOverrideDialogState
    extends State<_AgendaReservationConflictOverrideDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    dialogKey: const Key('agenda-reservation-override-dialog'),
    title: 'Substituir conflito de reserva?',
    closeTooltip: 'Fechar substituição de conflito',
    body: CoeloFormTextField(
      key: const Key('agenda-reservation-override-reason'),
      controller: _reason,
      labelText: 'Motivo da substituição',
      hintText: 'Obrigatório para o histórico da reserva.',
      prefixIcon: Icons.notes_rounded,
      maxLines: 2,
    ),
    secondaryAction: OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Manter horários'),
    ),
    primaryAction: FilledButton(
      key: const Key('agenda-reservation-override-confirm'),
      onPressed: () {
        final value = _reason.text.trim();
        if (value.isNotEmpty) Navigator.of(context).pop(value);
      },
      child: const Text('Substituir reserva'),
    ),
  );
}
