import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// Confirmation for taking a Principal publication off the air.
///
/// The reason is required, so the audit trail never depends on the operator
/// remembering to fill it in, and the destructive action stays disabled until
/// there is one. Removal itself is decided by the server through profile,
/// hierarchy and RLS; this dialog only collects intent.
Future<String?> askPrincipalRemovalReason(
  BuildContext context, {
  required String title,
  required String description,
  Key? dialogKey,
  Key? reasonKey,
  Key? cancelKey,
  Key? confirmKey,
}) => showDialog<String>(
  context: context,
  builder: (context) => _PrincipalRemovalDialog(
    title: title,
    description: description,
    dialogKey: dialogKey,
    reasonKey: reasonKey,
    cancelKey: cancelKey,
    confirmKey: confirmKey,
  ),
);

final class _PrincipalRemovalDialog extends StatefulWidget {
  const _PrincipalRemovalDialog({
    required this.title,
    required this.description,
    this.dialogKey,
    this.reasonKey,
    this.cancelKey,
    this.confirmKey,
  });

  final String title;
  final String description;
  final Key? dialogKey;
  final Key? reasonKey;
  final Key? cancelKey;
  final Key? confirmKey;

  @override
  State<_PrincipalRemovalDialog> createState() => _PrincipalRemovalDialogState();
}

final class _PrincipalRemovalDialogState extends State<_PrincipalRemovalDialog> {
  // The dialog owns the controller so it outlives the awaited route and is
  // disposed only once the route is gone.
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reason = _controller.text.trim();
    return AlertDialog(
      key: widget.dialogKey,
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.description),
            const SizedBox(height: CoeloSpacing.space3),
            TextField(
              key: widget.reasonKey,
              controller: _controller,
              autofocus: true,
              maxLength: 240,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                helperText: 'Fica registrado na auditoria.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: widget.cancelKey,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: widget.confirmKey,
          onPressed: reason.isEmpty ? null : () => Navigator.of(context).pop(reason),
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          child: const Text('Remover'),
        ),
      ],
    );
  }
}
