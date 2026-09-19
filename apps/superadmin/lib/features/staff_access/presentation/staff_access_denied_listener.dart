import 'package:flutter/material.dart';

import '../domain/staff_access_denied.dart';
import '../domain/staff_access_popup_text.dart';

/// Ouve [staffAccessDenied] e mostra o mesmo popup do contexto bloqueado
/// (motivo do servidor, nunca "sem permissão"). [onDismissed] leva de volta ao
/// seletor de contexto quando a superfície tem um.
final class StaffAccessDeniedListener extends StatefulWidget {
  const StaffAccessDeniedListener({required this.child, this.onDismissed, this.enabled, super.key});

  final Widget child;
  final void Function(StaffAccessDenial denial)? onDismissed;

  /// Quando devolve false, este listener ignora a negação (outro, mais
  /// específico, trata — ex.: a rota do Principal dentro do Superadmin).
  final bool Function()? enabled;

  @override
  State<StaffAccessDeniedListener> createState() => _StaffAccessDeniedListenerState();
}

final class _StaffAccessDeniedListenerState extends State<StaffAccessDeniedListener> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    staffAccessDenied.addListener(_onDenied);
  }

  @override
  void dispose() {
    staffAccessDenied.removeListener(_onDenied);
    super.dispose();
  }

  Future<void> _onDenied() async {
    final denial = staffAccessDenied.value;
    if (denial == null || _showing || !mounted) return;
    if (widget.enabled != null && !widget.enabled!()) return;
    _showing = true;
    staffAccessDenied.value = null;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const Key('staff-access-denied-dialog'),
          surfaceTintColor: Colors.transparent,
          title: const Text('Este contexto não está disponível agora'),
          content: Text(
            staffAccessBlockedMessage(denial.popup),
            key: const Key('staff-access-denied-message'),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('staff-access-denied-switch'),
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Trocar contexto'),
              ),
            ),
          ],
        ),
      );
      if (mounted) widget.onDismissed?.call(denial);
    } finally {
      _showing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
