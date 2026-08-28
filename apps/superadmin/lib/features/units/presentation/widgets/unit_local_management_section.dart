import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../../app/shell/superadmin_notice.dart';

enum UnitLocalManagementKind { administrators, people, invitations, groups, activities }

final class UnitLocalEntry {
  const UnitLocalEntry({required this.name, required this.detail, this.id, this.readOnly = false});

  final String? id;
  final String name;
  final String detail;
  final bool readOnly;
}

/// Local-only prototype used by the Unit form. It deliberately owns no
/// repository, authorization, or integration concern.
final class UnitLocalManagementSection extends StatefulWidget {
  const UnitLocalManagementSection({
    required this.kind,
    required this.onChanged,
    this.inheritedEntries = const [],
    this.initialEntries = const [],
    this.onOpenCreateFlow,
    this.onOpenEditFlow,
    super.key,
  });

  final UnitLocalManagementKind kind;
  final List<UnitLocalEntry> inheritedEntries;
  final List<UnitLocalEntry> initialEntries;
  final VoidCallback? onOpenCreateFlow;
  final ValueChanged<String>? onOpenEditFlow;
  final VoidCallback onChanged;

  @override
  State<UnitLocalManagementSection> createState() => _UnitLocalManagementSectionState();
}

final class _UnitLocalManagementSectionState extends State<UnitLocalManagementSection> {
  late final List<UnitLocalEntry> _entries = [...widget.initialEntries];

  String get _title => switch (widget.kind) {
    UnitLocalManagementKind.administrators => 'Administradores da unidade',
    UnitLocalManagementKind.people => 'Pessoas da unidade',
    UnitLocalManagementKind.invitations => 'Convites da unidade',
    UnitLocalManagementKind.groups => 'Turmas da unidade',
    UnitLocalManagementKind.activities => 'Atividades da unidade',
  };

  String get _description => switch (widget.kind) {
    UnitLocalManagementKind.administrators =>
      'Administradores herdados são somente leitura; inclusões manuais recebem acesso Owner.',
    UnitLocalManagementKind.people =>
      'Cadastre, localize e organize pessoas e seus Perfis de Acesso neste protótipo local.',
    UnitLocalManagementKind.invitations =>
      'Crie, reenvie ou revogue convites escopados visualmente a esta unidade.',
    UnitLocalManagementKind.groups =>
      'Inclua ou ajuste Turmas mantendo o contexto de instituição e unidade.',
    UnitLocalManagementKind.activities =>
      'Inclua ou ajuste Atividades mantendo o contexto de instituição e unidade.',
  };

  String get _addLabel => switch (widget.kind) {
    UnitLocalManagementKind.administrators => 'Adicionar administrador',
    UnitLocalManagementKind.people => 'Cadastrar pessoa',
    UnitLocalManagementKind.invitations => 'Criar convite',
    UnitLocalManagementKind.groups => 'Criar turma',
    UnitLocalManagementKind.activities => 'Criar atividade',
  };

  String get _addKey => switch (widget.kind) {
    UnitLocalManagementKind.administrators => 'unit-add-administrator',
    UnitLocalManagementKind.people => 'unit-add-person',
    UnitLocalManagementKind.invitations => 'unit-add-invite',
    UnitLocalManagementKind.groups => 'unit-add-group',
    UnitLocalManagementKind.activities => 'unit-add-activity',
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(_title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: CoeloSpacing.space1),
      Text(_description, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: CoeloSpacing.space5),
      if (widget.kind == UnitLocalManagementKind.administrators) ...[
        Text('Herdados da instituição', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space3),
        if (widget.inheritedEntries.isEmpty)
          const _EmptyMessage('Nenhum administrador herdado nesta sessão local.')
        else
          _entryTable(widget.inheritedEntries, inherited: true),
        const SizedBox(height: CoeloSpacing.space5),
        Text('Incluídos manualmente', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space3),
      ],
      _entryTable(_entries),
      const SizedBox(height: CoeloSpacing.space4),
      Wrap(
        spacing: CoeloSpacing.space2,
        runSpacing: CoeloSpacing.space2,
        children: [
          FilledButton.icon(
            key: Key(_addKey),
            onPressed: _add,
            icon: const Icon(Icons.add_rounded),
            label: Text(_addLabel),
          ),
          if (widget.kind == UnitLocalManagementKind.people) ...[
            OutlinedButton.icon(
              key: const Key('unit-search-person'),
              onPressed: _searchPerson,
              icon: const Icon(Icons.person_search_rounded),
              label: const Text('Buscar usuário'),
            ),
            CoeloAdminFileActions(
              actions: [
                CoeloAdminFileAction(
                  key: const Key('unit-import-people'),
                  label: 'Importar CSV/XLSX',
                  icon: Icons.upload_file_rounded,
                  onPressed: _showFileUnavailable,
                ),
                CoeloAdminFileAction(
                  key: const Key('unit-export-people'),
                  label: 'Exportar CSV/XLSX',
                  icon: Icons.download_outlined,
                  onPressed: _showFileUnavailable,
                ),
              ],
            ),
          ],
        ],
      ),
    ],
  );

  Widget _entryTable(List<UnitLocalEntry> entries, {bool inherited = false}) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'Tabela de $_title',
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
          border: Border.all(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              color: colors.surfaceContainer,
              padding: const EdgeInsets.symmetric(
                horizontal: CoeloSpacing.space4,
                vertical: CoeloSpacing.space3,
              ),
              child: Row(
                children: [
                  Expanded(child: Text('Nome', style: Theme.of(context).textTheme.labelLarge)),
                  Expanded(
                    child: Text('Vínculo / estado', style: Theme.of(context).textTheme.labelLarge),
                  ),
                  if (!inherited) const SizedBox(width: CoeloSize.touchMin * 2),
                ],
              ),
            ),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(CoeloSpacing.space4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Nenhum registro incluído nesta unidade.'),
                ),
              ),
            for (var index = 0; index < entries.length; index++) ...[
              if (index > 0) Divider(height: 1, color: colors.outlineVariant),
              Semantics(
                label: '${entries[index].name}, ${entries[index].detail}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
                  child: Row(
                    children: [
                      Icon(_icon, color: colors.primary),
                      const SizedBox(width: CoeloSpacing.space3),
                      Expanded(child: Text(entries[index].name)),
                      Expanded(child: Text(entries[index].detail)),
                      if (!inherited) ...[
                        if (widget.kind == UnitLocalManagementKind.invitations)
                          IconButton(
                            tooltip: 'Reenviar convite',
                            onPressed: () => _update(
                              index,
                              UnitLocalEntry(name: entries[index].name, detail: 'Reenviado'),
                            ),
                            icon: const Icon(Icons.forward_to_inbox_rounded),
                          )
                        else
                          IconButton(
                            tooltip: 'Editar ${entries[index].name}',
                            onPressed: () => _edit(index),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        IconButton(
                          tooltip: widget.kind == UnitLocalManagementKind.invitations
                              ? 'Revogar convite'
                              : 'Remover ${entries[index].name}',
                          onPressed: () => _remove(index),
                          style: IconButton.styleFrom(foregroundColor: colors.error),
                          icon: Icon(
                            widget.kind == UnitLocalManagementKind.invitations
                                ? Icons.block_rounded
                                : Icons.delete_outline_rounded,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (widget.kind) {
    UnitLocalManagementKind.administrators => Icons.admin_panel_settings_outlined,
    UnitLocalManagementKind.people => Icons.person_outline_rounded,
    UnitLocalManagementKind.invitations => Icons.mail_outline_rounded,
    UnitLocalManagementKind.groups => Icons.groups_outlined,
    UnitLocalManagementKind.activities => Icons.local_activity_outlined,
  };

  Future<void> _add() async {
    if (widget.onOpenCreateFlow case final openFlow?) {
      openFlow();
      return;
    }
    final result = await _showEntryDialog(context, kind: widget.kind);
    if (result == null) return;
    setState(() => _entries.add(result));
    widget.onChanged();
  }

  Future<void> _edit(int index) async {
    if (widget.onOpenEditFlow case final openFlow?) {
      openFlow(_entries[index].id ?? _entries[index].name);
      return;
    }
    final result = await _showEntryDialog(context, kind: widget.kind, initial: _entries[index]);
    if (result != null) _update(index, result);
  }

  void _update(int index, UnitLocalEntry value) {
    setState(() => _entries[index] = value);
    widget.onChanged();
  }

  void _remove(int index) {
    setState(() => _entries.removeAt(index));
    widget.onChanged();
  }

  Future<void> _searchPerson() async {
    final result = await _showEntryDialog(
      context,
      kind: UnitLocalManagementKind.people,
      search: true,
    );
    if (result == null) return;
    setState(() => _entries.add(result));
    widget.onChanged();
  }

  void _showFileUnavailable() {
    showSuperadminNotice(context, 'Indisponível nesta etapa', icon: Icons.info_outline_rounded);
  }
}

final class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
    child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
  );
}

Future<UnitLocalEntry?> _showEntryDialog(
  BuildContext context, {
  required UnitLocalManagementKind kind,
  UnitLocalEntry? initial,
  bool search = false,
}) => showDialog<UnitLocalEntry>(
  context: context,
  barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
  builder: (context) => _UnitLocalEntryDialog(kind: kind, initial: initial, search: search),
);

final class _UnitLocalEntryDialog extends StatefulWidget {
  const _UnitLocalEntryDialog({required this.kind, required this.initial, required this.search});

  final UnitLocalManagementKind kind;
  final UnitLocalEntry? initial;
  final bool search;

  @override
  State<_UnitLocalEntryDialog> createState() => _UnitLocalEntryDialogState();
}

final class _UnitLocalEntryDialogState extends State<_UnitLocalEntryDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.initial?.name);
  final TextEditingController _guardians = TextEditingController();
  final TextEditingController _children = TextEditingController();
  String _registrationType = 'Nova família';
  String _profile = 'Responsável';

  @override
  void dispose() {
    _name.dispose();
    _guardians.dispose();
    _children.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    dialogKey: const Key('unit-local-dialog'),
    title: widget.search ? 'Buscar usuário' : _dialogTitle,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.kind == UnitLocalManagementKind.people && !widget.search) ...[
          CoeloAdminSingleSelectField<String>(
            key: const Key('unit-person-registration-type'),
            label: 'Tipo de cadastro',
            value: _registrationType,
            options: const ['Nova família', 'Profissional', 'Profissional e responsável'],
            optionLabel: (value) => value,
            onChanged: (value) => setState(() => _registrationType = value),
            prefixIcon: Icons.account_tree_outlined,
          ),
          const SizedBox(height: CoeloSpacing.space4),
          if (_registrationType == 'Nova família') ...[
            CoeloFormTextField(
              fieldKey: const Key('unit-family-guardians'),
              controller: _guardians,
              labelText: 'Responsáveis',
              prefixIcon: Icons.family_restroom_rounded,
            ),
            const SizedBox(height: CoeloSpacing.space4),
            CoeloFormTextField(
              fieldKey: const Key('unit-family-children'),
              controller: _children,
              labelText: 'Crianças',
              prefixIcon: Icons.child_care_rounded,
            ),
          ] else ...[
            CoeloFormTextField(
              fieldKey: const Key('unit-local-name'),
              controller: _name,
              labelText: 'Nome',
              prefixIcon: _dialogIcon,
            ),
            if (_registrationType == 'Profissional e responsável') ...[
              const SizedBox(height: CoeloSpacing.space4),
              CoeloFormTextField(
                fieldKey: const Key('unit-family-children'),
                controller: _children,
                labelText: 'Crianças vinculadas',
                prefixIcon: Icons.child_care_rounded,
              ),
            ],
          ],
          const SizedBox(height: CoeloSpacing.space4),
          CoeloAdminSingleSelectField<String>(
            label: 'Perfil de Acesso',
            value: _profile,
            options: const ['Responsável', 'Aluno', 'Profissional', 'Profissional e responsável'],
            optionLabel: (value) => value,
            onChanged: (value) => setState(() => _profile = value),
            prefixIcon: Icons.manage_accounts_outlined,
          ),
        ] else
          CoeloFormTextField(
            fieldKey: const Key('unit-local-name'),
            controller: _name,
            labelText: widget.search ? '@, CPF, e-mail ou celular' : 'Nome',
            prefixIcon: widget.search ? Icons.search_rounded : _dialogIcon,
          ),
      ],
    ),
    secondaryAction: OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(
      key: const Key('unit-local-confirm'),
      onPressed: () {
        final name = _entryName;
        if (name.isEmpty || !_hasRequiredPeopleLinks) return;
        if (widget.search) {
          final existing = _existingFakeUser(name);
          Navigator.of(context).pop(
            UnitLocalEntry(
              name: existing ? 'Usuário encontrado' : 'Novo usuário',
              detail: existing
                  ? '${_maskIdentifier(name)} · convite local pendente'
                  : '${_maskIdentifier(name)} · cadastro local e convite pendentes',
            ),
          );
          return;
        }
        Navigator.of(context).pop(UnitLocalEntry(name: name, detail: _detail));
      },
      child: Text(
        widget.search
            ? 'Enviar convite'
            : widget.initial == null
            ? 'Adicionar'
            : 'Salvar',
      ),
    ),
  );

  String get _dialogTitle => switch (widget.kind) {
    UnitLocalManagementKind.administrators => 'Adicionar administrador',
    UnitLocalManagementKind.people => 'Cadastrar pessoa',
    UnitLocalManagementKind.invitations => 'Criar convite',
    UnitLocalManagementKind.groups => 'Criar turma',
    UnitLocalManagementKind.activities => 'Criar atividade',
  };

  IconData get _dialogIcon => switch (widget.kind) {
    UnitLocalManagementKind.administrators => Icons.admin_panel_settings_outlined,
    UnitLocalManagementKind.people => Icons.person_outline_rounded,
    UnitLocalManagementKind.invitations => Icons.mail_outline_rounded,
    UnitLocalManagementKind.groups => Icons.groups_outlined,
    UnitLocalManagementKind.activities => Icons.local_activity_outlined,
  };

  String get _detail {
    return switch (widget.kind) {
      UnitLocalManagementKind.administrators => 'Owner · inclusão manual',
      UnitLocalManagementKind.people => switch (_registrationType) {
        'Nova família' =>
          'Família · Responsável ↔ criança · ${_children.text.trim()} · Perfil de Acesso · $_profile',
        'Profissional e responsável' =>
          'Profissional e responsável · vínculo com ${_children.text.trim()} · Perfil de Acesso · $_profile',
        _ => 'Profissional · Perfil de Acesso · $_profile',
      },
      UnitLocalManagementKind.invitations => 'Enviado',
      UnitLocalManagementKind.groups => 'Turma desta unidade',
      UnitLocalManagementKind.activities => 'Atividade desta unidade',
    };
  }

  String get _entryName =>
      widget.kind == UnitLocalManagementKind.people &&
          !widget.search &&
          _registrationType == 'Nova família'
      ? _guardians.text.trim()
      : _name.text.trim();

  bool get _hasRequiredPeopleLinks =>
      widget.kind != UnitLocalManagementKind.people ||
      widget.search ||
      _registrationType == 'Profissional' ||
      _children.text.trim().isNotEmpty;
}

bool _existingFakeUser(String value) {
  final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9@]'), '');
  return normalized == '@ana' ||
      normalized == 'ana@coelome' ||
      normalized == '11999990000' ||
      normalized == '12345678909';
}

String _maskIdentifier(String value) {
  final normalized = value.trim();
  if (normalized.startsWith('@')) {
    return normalized.length <= 2 ? '@•••' : '@${normalized[1]}•••';
  }
  if (normalized.contains('@')) {
    final parts = normalized.split('@');
    final local = parts.first;
    final domain = parts.length > 1 ? parts.last : '';
    return '${local.isEmpty ? '•' : local[0]}•••@${domain.isEmpty ? '•••' : domain}';
  }
  final digits = normalized.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11) {
    return '${digits.substring(0, 3)}.•••.•••-${digits.substring(9)}';
  }
  if (digits.length >= 8) {
    return '(${digits.substring(0, 2)}) •••••-${digits.substring(digits.length - 4)}';
  }
  return '••••••';
}
