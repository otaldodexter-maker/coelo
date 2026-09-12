import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../people/domain/person_directory.dart';
import '../../domain/chat_repository.dart';

/// Criar grupo (P8): instituicao, titulo e membros vindos do diretorio de
/// Pessoas autorizado. O dialogo so monta o comando; quem cria e o servidor
/// (superadmin_chat_create_group_v2), que deriva o escopo e valida os vinculos.
///
/// ponytail: escopo de unidade/turma/atividade fica para quando a tela pedir;
/// hoje o grupo nasce no escopo da instituicao.
final class SuperadminChatCreateGroupDialog extends StatefulWidget {
  const SuperadminChatCreateGroupDialog({
    required this.people,
    required this.requestId,
    super.key,
  });

  final PersonDirectoryRepository people;
  final String requestId;

  static Future<ChatCreateGroupCommand?> show(
    BuildContext context, {
    required PersonDirectoryRepository people,
    required String requestId,
  }) => showDialog<ChatCreateGroupCommand>(
    context: context,
    builder: (_) => SuperadminChatCreateGroupDialog(people: people, requestId: requestId),
  );

  @override
  State<SuperadminChatCreateGroupDialog> createState() => _SuperadminChatCreateGroupDialogState();
}

final class _SuperadminChatCreateGroupDialogState extends State<SuperadminChatCreateGroupDialog> {
  final _title = TextEditingController();
  List<PersonFilterOption> _institutions = const [];
  String? _institutionId;
  List<PersonDirectoryItem> _people = const [];
  final _selected = <String>{};
  var _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadInstitutions();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _loadInstitutions() async {
    try {
      final options = await widget.people.fetchFilterOptions();
      if (!mounted) return;
      setState(() {
        _institutions = options.institutions;
        _loading = false;
      });
      if (options.institutions.length == 1) _selectInstitution(options.institutions.first.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _selectInstitution(String? id) async {
    setState(() {
      _institutionId = id;
      _error = null;
      _people = const [];
      _selected.clear();
      _loading = id != null;
    });
    if (id == null) return;
    try {
      final page = await widget.people.fetchPage(
        PersonDirectoryQuery(institutionIds: {id}, pageSize: 50),
      );
      if (!mounted || _institutionId != id) return;
      setState(() {
        _people = page.items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || _institutionId != id) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  bool get _canSubmit =>
      _institutionId != null && _title.text.trim().isNotEmpty && _selected.isNotEmpty;

  void _submit() {
    Navigator.of(context).pop(
      ChatCreateGroupCommand(
        requestId: widget.requestId,
        institutionId: _institutionId!,
        title: _title.text.trim(),
        personIds: _selected.toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('superadmin-chat-create-group-dialog'),
      title: const Text('Criar grupo'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoeloFormTextField(
              key: const Key('superadmin-chat-create-group-title'),
              controller: _title,
              labelText: 'Nome do grupo',
              prefixIcon: Icons.group_outlined,
              maxLength: 120,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: CoeloSpacing.space3),
            DropdownButtonFormField<String>(
              key: const Key('superadmin-chat-create-group-institution'),
              initialValue: _institutionId,
              decoration: const InputDecoration(labelText: 'Instituição'),
              items: [
                for (final option in _institutions)
                  DropdownMenuItem(value: option.id, child: Text(option.label)),
              ],
              onChanged: _selectInstitution,
            ),
            const SizedBox(height: CoeloSpacing.space3),
            if (_error != null)
              Text(
                _institutions.isEmpty
                    ? 'Não foi possível carregar as instituições disponíveis para você.'
                    : 'Não foi possível carregar as pessoas desta instituição.',
              )
            else if (_loading)
              const Padding(
                padding: EdgeInsets.all(CoeloSpacing.space4),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_institutionId != null && _people.isEmpty)
              const Text('Nenhuma pessoa com vínculo ativo nesta instituição.')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final person in _people)
                      CheckboxListTile(
                        key: Key('superadmin-chat-create-group-person-${person.id}'),
                        value: _selected.contains(person.id),
                        title: Text(person.displayName),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (checked) => setState(() {
                          checked == true ? _selected.add(person.id) : _selected.remove(person.id);
                        }),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          key: const Key('superadmin-chat-create-group-submit'),
          onPressed: _canSubmit ? _submit : null,
          child: Text(_selected.isEmpty ? 'Criar grupo' : 'Criar grupo (${_selected.length})'),
        ),
      ],
    );
  }
}
