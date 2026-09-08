import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../domain/principal_profile_repository.dart';

/// Editor for the institutional biography.
///
/// The dialog only collects intent. Whether this actor may edit is decided by
/// the server through profile, hierarchy and RLS, and the text is revalidated
/// there before anything is written.
Future<String?> askPrincipalProfileBio(BuildContext context, {required String currentBio}) =>
    showDialog<String>(
      context: context,
      builder: (context) => _PrincipalProfileBioDialog(currentBio: currentBio),
    );

final class _PrincipalProfileBioDialog extends StatefulWidget {
  const _PrincipalProfileBioDialog({required this.currentBio});

  final String currentBio;

  @override
  State<_PrincipalProfileBioDialog> createState() => _PrincipalProfileBioDialogState();
}

final class _PrincipalProfileBioDialogState extends State<_PrincipalProfileBioDialog> {
  // The dialog owns the controller so it outlives the awaited route and is
  // disposed only once the route is gone.
  late final _controller = TextEditingController(text: widget.currentBio);

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
    final text = _controller.text.trim();
    final issue = PrincipalProfileBioPolicy.validate(text);
    return AlertDialog(
      key: const Key('principal-profile-bio-dialog'),
      title: const Text('Editar biografia'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Aparece no perfil da instituicao para quem pode ve-lo.'),
            const SizedBox(height: CoeloSpacing.space3),
            TextField(
              key: const Key('principal-profile-bio-field'),
              controller: _controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              // Not capped by maxLength on purpose: a silent truncation would
              // hide the refusal instead of explaining it.
              decoration: InputDecoration(
                labelText: 'Biografia',
                helperText:
                    'Ate ${PrincipalProfileBioPolicy.maximumCharacters} caracteres. '
                    'A alteracao fica registrada.',
                errorText: switch (issue) {
                  PrincipalProfileBioIssue.tooLong =>
                    'Passa de ${PrincipalProfileBioPolicy.maximumCharacters} caracteres.',
                  // An empty field is the starting state of a rewrite, not an
                  // error to shout at the operator while they type.
                  PrincipalProfileBioIssue.empty || null => null,
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('principal-profile-bio-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('principal-profile-bio-save'),
          onPressed: issue == null ? () => Navigator.of(context).pop(_controller.text) : null,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
