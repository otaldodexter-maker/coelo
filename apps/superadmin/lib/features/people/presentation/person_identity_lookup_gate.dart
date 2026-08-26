import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/person_identity.dart';

typedef PersonCreationFormBuilder = Widget Function(BuildContext context);

final class PersonIdentityLookupGate extends StatefulWidget {
  const PersonIdentityLookupGate({
    required this.repository,
    required this.formBuilder,
    required this.onExistingPerson,
    required this.onCancel,
    this.institutionId,
    this.unitId,
    super.key,
  });

  final PersonIdentityRepository repository;
  final PersonCreationFormBuilder formBuilder;
  final ValueChanged<String> onExistingPerson;
  final VoidCallback onCancel;
  final String? institutionId;
  final String? unitId;

  @override
  State<PersonIdentityLookupGate> createState() => _PersonIdentityLookupGateState();
}

final class _PersonIdentityLookupGateState extends State<PersonIdentityLookupGate> {
  final _query = TextEditingController();
  var _kind = PersonIdentityLookupKind.email;
  var _loading = false;
  var _creationAuthorized = false;
  String? _error;
  List<PersonIdentityCandidate> _candidates = const [];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final query = _query.text.trim();
    if (_loading || query.isEmpty) {
      setState(() => _error = query.isEmpty ? 'Informe um identificador para continuar.' : null);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _candidates = const [];
    });
    try {
      final candidates = await widget.repository.resolve(
        kind: _kind,
        query: query,
        institutionId: widget.institutionId,
        unitId: widget.unitId,
      );
      if (!mounted) return;
      final denied = candidates.any(
        (candidate) => candidate.access == PersonIdentityResolutionAccess.noAccess,
      );
      setState(() {
        _candidates = denied ? const [] : candidates;
        _creationAuthorized = candidates.isEmpty;
        if (denied) _error = 'Você não tem permissão para resolver esta identidade.';
      });
    } on PersonIdentityAccessDeniedException {
      if (mounted) setState(() => _error = 'Você não tem permissão para resolver esta identidade.');
    } on Object {
      if (mounted) {
        setState(() => _error = 'Não foi possível verificar a identidade. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_creationAuthorized) return widget.formBuilder(context);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel},
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: CoeloAdminDialogShell(
                dialogKey: const Key('person-identity-lookup-dialog'),
                title: 'Verificar identidade',
                body: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Procure a identidade global antes de cadastrar. A verificação não cria nem altera dados.',
                      ),
                      const SizedBox(height: CoeloSpacing.space4),
                      CoeloAdminSingleSelectField<PersonIdentityLookupKind>(
                        label: 'Identificador',
                        value: _kind,
                        options: PersonIdentityLookupKind.values,
                        optionLabel: _kindLabel,
                        onChanged: (value) => setState(() => _kind = value),
                      ),
                      const SizedBox(height: CoeloSpacing.space4),
                      CoeloFormTextField(
                        fieldKey: const Key('person-identity-lookup-field'),
                        controller: _query,
                        labelText: 'Valor para verificação',
                        prefixIcon: Icons.person_search_outlined,
                        errorText: _error,
                      ),
                      if (_candidates.isNotEmpty) ...[
                        const SizedBox(height: CoeloSpacing.space4),
                        for (final candidate in _candidates)
                          _IdentityCandidateTile(
                            candidate: candidate,
                            onOpen: candidate.access == PersonIdentityResolutionAccess.editGlobal
                                ? () => widget.onExistingPerson(candidate.personId)
                                : null,
                          ),
                      ],
                    ],
                  ),
                ),
                secondaryAction: OutlinedButton(
                  key: const Key('person-identity-lookup-cancel'),
                  onPressed: widget.onCancel,
                  child: const Text('Cancelar'),
                ),
                primaryAction: FilledButton.icon(
                  key: const Key('person-identity-lookup-submit'),
                  onPressed: _loading ? null : _resolve,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search_rounded),
                  label: Text(_loading ? 'Verificando…' : 'Verificar'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _kindLabel(PersonIdentityLookupKind kind) => switch (kind) {
  PersonIdentityLookupKind.handle => '@ usuário',
  PersonIdentityLookupKind.email => 'E-mail',
  PersonIdentityLookupKind.phone => 'Celular',
  PersonIdentityLookupKind.cpf => 'CPF',
  PersonIdentityLookupKind.name => 'Nome',
};

final class _IdentityCandidateTile extends StatelessWidget {
  const _IdentityCandidateTile({required this.candidate, required this.onOpen});

  final PersonIdentityCandidate candidate;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => CoeloStatePanel(
    key: Key('person-identity-candidate-${candidate.personId}'),
    title: candidate.displayName,
    message: '${candidate.maskedMatch} · Identidade já existente',
    icon: onOpen == null ? Icons.lock_outline_rounded : Icons.person_outline_rounded,
    actionLabel: onOpen == null ? null : 'Abrir pessoa',
    onAction: onOpen,
  );
}
