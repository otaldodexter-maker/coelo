import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../invites/presentation/invite_request_id.dart';
import '../domain/person_handle.dart';

/// Cartão "Identificador (@)" do detalhe da pessoa (ADR 0034, Decisão 16):
/// mostra o @ atual, quando pode trocar e abre o diálogo de troca com
/// verificação de disponibilidade enquanto digita. O servidor autoriza.
final class PersonHandleSection extends StatefulWidget {
  const PersonHandleSection({required this.repository, required this.personId, super.key});

  final PersonHandleRepository repository;
  final String personId;

  @override
  State<PersonHandleSection> createState() => _PersonHandleSectionState();
}

final class _PersonHandleSectionState extends State<PersonHandleSection> {
  PersonHandle? _handle;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant PersonHandleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.personId != widget.personId ||
        !identical(oldWidget.repository, widget.repository)) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final handle = await widget.repository.fetch(widget.personId);
      if (!mounted) return;
      setState(() {
        _handle = handle;
        _loading = false;
      });
    } on PersonHandleException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _change() async {
    final current = _handle;
    if (current == null) return;
    final changed = await showDialog<PersonHandle>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (_) => _ChangeHandleDialog(repository: widget.repository, current: current),
    );
    if (changed != null && mounted) setState(() => _handle = changed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final handle = _handle;
    return Card(
      key: const Key('person-handle-section'),
      margin: const EdgeInsets.only(bottom: CoeloSpacing.space3),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text('Identificador (@)', style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: CoeloSpacing.space4),
            if (_loading)
              const Text('Consultando o @…')
            else if (_error case final error?)
              Text(error, key: const Key('person-handle-error'))
            else if (handle == null)
              const Text('Esta pessoa não tem @.', key: Key('person-handle-none'))
            else ...[
              Row(
                children: [
                  const Icon(Icons.alternate_email_rounded, size: 20),
                  const SizedBox(width: CoeloSpacing.space2),
                  Expanded(
                    child: SelectableText(
                      handle.handle,
                      key: const Key('person-handle-value'),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  if (handle.canEdit)
                    OutlinedButton.icon(
                      key: const Key('person-handle-change'),
                      onPressed: handle.inCooldown ? null : _change,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Alterar @'),
                    ),
                ],
              ),
              const SizedBox(height: CoeloSpacing.space2),
              Text(
                handle.inCooldown
                    ? 'Trocado em ${_date(handle.lastChangedAt)}; nova troca a partir de ${_date(handle.canChangeAt)}.'
                    : 'Pode ser trocado uma vez a cada 30 dias.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _date(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}

final class _ChangeHandleDialog extends StatefulWidget {
  const _ChangeHandleDialog({required this.repository, required this.current});

  final PersonHandleRepository repository;
  final PersonHandle current;

  @override
  State<_ChangeHandleDialog> createState() => _ChangeHandleDialogState();
}

final class _ChangeHandleDialogState extends State<_ChangeHandleDialog> {
  late final TextEditingController _handleController;
  final TextEditingController _reasonController = TextEditingController();
  Timer? _debounce;
  int _checkEpoch = 0;
  PersonHandleAvailability? _availability;
  bool _checking = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _handleController = TextEditingController(text: widget.current.handle);
    _handleController.addListener(_scheduleCheck);
    _reasonController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _handleController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  String get _typed => _handleController.text.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();

  bool get _unchanged => _typed == widget.current.handle;

  void _scheduleCheck() {
    _debounce?.cancel();
    final epoch = ++_checkEpoch;
    setState(() {
      _availability = null;
      _error = null;
    });
    if (_unchanged || _typed.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 400), () => unawaited(_check(epoch)));
  }

  Future<void> _check(int epoch) async {
    setState(() => _checking = true);
    try {
      final result = await widget.repository.checkAvailability(
        _typed,
        personId: widget.current.personId,
      );
      if (!mounted || epoch != _checkEpoch) return;
      setState(() {
        _availability = result;
        _checking = false;
      });
    } on PersonHandleException catch (error) {
      if (!mounted || epoch != _checkEpoch) return;
      setState(() {
        _error = error.message;
        _checking = false;
      });
    }
  }

  bool get _canSave =>
      !_saving &&
      !_unchanged &&
      _availability == PersonHandleAvailability.available &&
      _reasonController.text.trim().isNotEmpty;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final changed = await widget.repository.change(
        requestId: newInviteRequestId(),
        personId: widget.current.personId,
        handle: _typed,
        reason: _reasonController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(changed);
    } on PersonHandleException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final availability = _availability;
    final helper = _checking
        ? 'Verificando disponibilidade…'
        : _unchanged
        ? 'Este é o @ atual.'
        : availability?.message;
    return CoeloAdminDialogShell(
      dialogKey: const Key('person-handle-dialog'),
      title: 'Alterar @',
      closeTooltip: 'Fechar',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('person-handle-field'),
            controller: _handleController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Novo @',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              helperText: helper,
              helperMaxLines: 2,
              errorText: availability != null && availability != PersonHandleAvailability.available
                  ? availability.message
                  : null,
            ),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          TextField(
            key: const Key('person-handle-reason'),
            controller: _reasonController,
            decoration: const InputDecoration(labelText: 'Motivo da troca'),
          ),
          const SizedBox(height: CoeloSpacing.space2),
          Text(
            'A troca fica registrada e só pode ser feita uma vez a cada 30 dias.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_error case final error?) ...[
            const SizedBox(height: CoeloSpacing.space2),
            Text(
              error,
              key: const Key('person-handle-dialog-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      secondaryAction: OutlinedButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      primaryAction: FilledButton(
        key: const Key('person-handle-save'),
        onPressed: _canSave ? _save : null,
        child: const Text('Salvar @'),
      ),
    );
  }
}
