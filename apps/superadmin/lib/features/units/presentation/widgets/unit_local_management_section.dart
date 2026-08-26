import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

enum UnitLocalManagementKind { administrators, people, invitations, groups, activities }

final class UnitLocalEntry {
  const UnitLocalEntry({required this.name, required this.detail, this.id, this.readOnly = false});

  final String? id;
  final String name;
  final String detail;
  final bool readOnly;
}

/// Unit form row management component with explicit create/search/link actions
/// and pagination.
final class UnitLocalManagementSection extends StatefulWidget {
  const UnitLocalManagementSection({
    required this.kind,
    required this.onChanged,
    this.inheritedEntries = const [],
    this.initialEntries = const [],
    this.onOpenCreateFlow,
    this.onCreateProfessionalPerson,
    this.onOpenEditFlow,
    this.onOpenSearchFlow,
    super.key,
  });

  final UnitLocalManagementKind kind;
  final List<UnitLocalEntry> inheritedEntries;
  final List<UnitLocalEntry> initialEntries;
  final VoidCallback? onOpenCreateFlow;
  final void Function(String initialPersonRole)? onCreateProfessionalPerson;
  final ValueChanged<String>? onOpenEditFlow;
  final VoidCallback? onOpenSearchFlow;
  final VoidCallback onChanged;

  @override
  State<UnitLocalManagementSection> createState() => _UnitLocalManagementSectionState();
}

final class _UnitLocalManagementSectionState extends State<UnitLocalManagementSection> {
  late final List<UnitLocalEntry> _entries = [...widget.initialEntries];

  final TextEditingController _searchController = TextEditingController();
  static const int _pageSize = 6;
  int _page = 0;

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
      'Cadastre, localize e organize pessoas e seus Perfis de Acesso neste fluxo de unidade.',
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

  String get _kindCode => switch (widget.kind) {
    UnitLocalManagementKind.administrators => 'administrator',
    UnitLocalManagementKind.people => 'person',
    UnitLocalManagementKind.invitations => 'invite',
    UnitLocalManagementKind.groups => 'group',
    UnitLocalManagementKind.activities => 'activity',
  };

  bool get _supportsSearch => widget.kind != UnitLocalManagementKind.administrators;

  List<UnitLocalEntry> get _filteredEntries {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return [..._entries];
    }
    return _entries.where((entry) {
      return entry.name.toLowerCase().contains(query) || entry.detail.toLowerCase().contains(query);
    }).toList();
  }

  int get _totalPages =>
      _filteredEntries.isEmpty ? 1 : ((_filteredEntries.length - 1) / _pageSize).floor() + 1;

  bool get _hasSearchAndPagination =>
      _supportsSearch && (_entries.isNotEmpty || _searchController.text.isNotEmpty);

  List<UnitLocalEntry> get _pagedEntries {
    if (_filteredEntries.isEmpty) return const [];
    final safePage = _page.clamp(0, _totalPages - 1);
    if (safePage != _page) {
      _page = safePage;
    }
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, _filteredEntries.length);
    return _filteredEntries.sublist(start, end);
  }

  void _search() {
    _page = 0;
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty) return;
    _searchController.clear();
    _page = 0;
  }

  void _nextPage() {
    if (_page + 1 >= _totalPages) return;
    _page++;
  }

  void _previousPage() {
    if (_page <= 0) return;
    _page--;
  }

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
          const _EmptyMessage('Nenhum administrador herdado nesta sessão.')
        else
          _entryTable(widget.inheritedEntries, inherited: true),
        const SizedBox(height: CoeloSpacing.space5),
        Text('Incluídos manualmente', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space3),
      ],
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
            OutlinedButton.icon(
              key: const Key('unit-import-people'),
              onPressed: _showImportPreview,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Importar CSV/XLSX'),
            ),
          ],
        ],
      ),
      const SizedBox(height: CoeloSpacing.space4),
      if (_hasSearchAndPagination) ...[
        CoeloFormTextField(
          fieldKey: Key('unit-$_kindCode-search'),
          controller: _searchController,
          onChanged: (_) => setState(_search),
          labelText: 'Buscar por nome',
          prefixIcon: Icons.search_rounded,
        ),
        const SizedBox(height: CoeloSpacing.space3),
        if (_filteredEntries.length > _pageSize)
          Row(
            children: [
              IconButton(
                onPressed: _page == 0 ? null : () => setState(_previousPage),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              const SizedBox(width: CoeloSpacing.space2),
              Text('Página ${_page + 1} de $_totalPages'),
              const SizedBox(width: CoeloSpacing.space2),
              IconButton(
                onPressed: _page + 1 >= _totalPages ? null : () => setState(_nextPage),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              if (_searchController.text.isNotEmpty)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(_clearSearch),
                      child: const Text('Limpar busca'),
                    ),
                  ),
                ),
            ],
          ),
      ],
      const SizedBox(height: CoeloSpacing.space4),
      _entryTable(_supportsSearch ? _pagedEntries : _entries),
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
    if (_requiresExternalOwnership) {
      widget.onOpenCreateFlow?.call();
      return;
    }
    if (widget.onOpenCreateFlow case final openFlow?) {
      if (widget.kind != UnitLocalManagementKind.people ||
          widget.onCreateProfessionalPerson == null) {
        openFlow();
        return;
      }
    }

    final result = await _showEntryDialog(
      context,
      kind: widget.kind,
      onCreateProfessionalPerson: widget.onCreateProfessionalPerson,
    );
    if (result == null || !mounted) return;
    setState(() => _entries.add(result));
    widget.onChanged();
  }

  Future<void> _edit(int index) async {
    if (_requiresExternalOwnership) {
      final entry = _entries[index];
      widget.onOpenEditFlow?.call(entry.id ?? entry.name);
      return;
    }
    if (widget.onOpenEditFlow case final openFlow?) {
      openFlow(_entries[index].id ?? _entries[index].name);
      return;
    }
    final result = await _showEntryDialog(context, kind: widget.kind, initial: _entries[index]);
    if (result != null) _update(index, result);
  }

  void _update(int index, UnitLocalEntry value) {
    if (_requiresExternalOwnership) return;
    setState(() => _entries[index] = value);
    widget.onChanged();
  }

  void _remove(int index) {
    if (_requiresExternalOwnership) return;
    setState(() => _entries.removeAt(index));
    widget.onChanged();
  }

  void _searchPerson() => widget.onOpenSearchFlow?.call();

  bool get _requiresExternalOwnership => switch (widget.kind) {
    UnitLocalManagementKind.people ||
    UnitLocalManagementKind.groups ||
    UnitLocalManagementKind.activities => true,
    _ => false,
  };

  Future<void> _showImportPreview() => showDialog<void>(
    context: context,
    barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
    builder: (dialogContext) => CoeloAdminDialogShell(
      dialogKey: const Key('unit-import-preview'),
      title: 'Importar pessoas',
      body: const Text('Prévia da importação em CSV/XLSX e vínculos antes da confirmação.'),
      primaryAction: FilledButton(
        onPressed: () => Navigator.of(dialogContext).pop(),
        child: const Text('Entendi'),
      ),
    ),
  );
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
  void Function(String initialPersonRole)? onCreateProfessionalPerson,
}) => showDialog<UnitLocalEntry>(
  context: context,
  barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
  builder: (context) => _UnitLocalEntryDialog(
    kind: kind,
    initial: initial,
    search: search,
    onCreateProfessionalPerson: onCreateProfessionalPerson,
  ),
);

final class _UnitLocalEntryDialog extends StatefulWidget {
  const _UnitLocalEntryDialog({
    required this.kind,
    required this.initial,
    required this.search,
    this.onCreateProfessionalPerson,
  });

  final UnitLocalManagementKind kind;
  final UnitLocalEntry? initial;
  final bool search;
  final void Function(String initialPersonRole)? onCreateProfessionalPerson;

  @override
  State<_UnitLocalEntryDialog> createState() => _UnitLocalEntryDialogState();
}

enum _UnitPeopleRegistrationMode { family, professional, professionalWithFamily }

final class _UnitLocalEntryDialogState extends State<_UnitLocalEntryDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.initial?.name);
  final TextEditingController _professionalIdentifierController = TextEditingController();
  final List<TextEditingController> _guardianControllers = [];
  final List<TextEditingController> _guardianSearchControllers = [];
  final List<bool> _guardianAlreadyRegistered = [];
  final List<TextEditingController> _childrenControllers = [];
  final List<int> _childrenResponsibleIndexes = [];
  int _guardianCount = 1;
  int _childrenCount = 1;
  int _activeGuardianStep = 0;
  _UnitPeopleRegistrationMode _registrationMode = _UnitPeopleRegistrationMode.family;
  String _profile = 'Responsável';

  @override
  void initState() {
    super.initState();
    if (widget.kind == UnitLocalManagementKind.people && !widget.search) {
      _setRegistrationMode(_registrationMode);
      if (widget.initial != null) {
        _name.text = widget.initial!.name;
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _professionalIdentifierController.dispose();
    for (final controller in _guardianControllers) {
      controller.dispose();
    }
    for (final controller in _childrenControllers) {
      controller.dispose();
    }
    for (final controller in _guardianSearchControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _isFamilyRegistration =>
      widget.kind == UnitLocalManagementKind.people &&
      (_registrationMode == _UnitPeopleRegistrationMode.family ||
          _registrationMode == _UnitPeopleRegistrationMode.professionalWithFamily);

  bool get _isProfessionalRegistration =>
      widget.kind == UnitLocalManagementKind.people &&
      _registrationMode == _UnitPeopleRegistrationMode.professional;

  bool get _isProfessionalAndFamilyRegistration =>
      widget.kind == UnitLocalManagementKind.people &&
      _registrationMode == _UnitPeopleRegistrationMode.professionalWithFamily;

  bool get _guardianCanAdvance {
    if (!_isFamilyRegistration) return true;
    final index = _activeGuardianStep;
    if (index < 0 || index >= _guardianCount) return false;
    if (_guardianAlreadyRegistered[index]) {
      return _guardianSearchControllers[index].text.trim().isNotEmpty;
    }
    return _guardianControllers[index].text.trim().isNotEmpty;
  }

  bool get _familyComplete {
    return _activeGuardianStep >= _guardianCount - 1 &&
        _guardianCanAdvance &&
        _guardianNames.length == _guardianCount &&
        _childrenControllers.length == _childrenCount &&
        _childrenResponsibleIndexes.length == _childrenCount &&
        _childrenNames.length == _childrenCount;
  }

  bool get _professionalComplete =>
      _professionalName.isNotEmpty && _professionalIdentifierController.text.trim().isNotEmpty;

  void _setRegistrationMode(_UnitPeopleRegistrationMode value) {
    setState(() {
      _registrationMode = value;
      _activeGuardianStep = 0;
      if (_isFamilyRegistration) {
        _guardianCount = 1;
        _childrenCount = 1;
        _professionalIdentifierController.clear();
        _profile = _registrationMode == _UnitPeopleRegistrationMode.family
            ? 'Responsável'
            : 'Profissional e responsável';
        _syncGuardianEntries();
        _syncChildrenEntries();
        _syncChildrenResponsibleIndexes();
      } else {
        _clearFamilyCollections();
        _guardianCount = 0;
        _childrenCount = 0;
        _profile = 'Profissional';
      }
    });
  }

  void _clearFamilyCollections() {
    for (final controller in _guardianControllers) {
      controller.dispose();
    }
    for (final controller in _guardianSearchControllers) {
      controller.dispose();
    }
    for (final controller in _childrenControllers) {
      controller.dispose();
    }
    _guardianControllers.clear();
    _guardianSearchControllers.clear();
    _guardianAlreadyRegistered.clear();
    _childrenControllers.clear();
    _childrenResponsibleIndexes.clear();
  }

  void _updateGuardianCount(int value) {
    setState(() {
      _guardianCount = value;
      _activeGuardianStep = 0;
      _syncGuardianEntries();
      _syncChildrenResponsibleIndexes();
    });
  }

  void _updateChildrenCount(int value) {
    setState(() {
      _childrenCount = value;
      _syncChildrenEntries();
      _syncChildrenResponsibleIndexes();
    });
  }

  void _advanceGuardianStep() {
    if (!_guardianCanAdvance) return;
    if (_activeGuardianStep < _guardianCount - 1) {
      _activeGuardianStep++;
    }
  }

  void _syncGuardianEntries() {
    while (_guardianControllers.length < _guardianCount) {
      _guardianControllers.add(TextEditingController());
      _guardianSearchControllers.add(TextEditingController());
      _guardianAlreadyRegistered.add(false);
    }
    while (_guardianControllers.length > _guardianCount) {
      final index = _guardianControllers.length - 1;
      _guardianControllers.removeAt(index).dispose();
      _guardianSearchControllers.removeAt(index).dispose();
      _guardianAlreadyRegistered.removeAt(index);
    }
  }

  void _syncChildrenEntries() {
    while (_childrenControllers.length < _childrenCount) {
      _childrenControllers.add(TextEditingController());
    }
    while (_childrenControllers.length > _childrenCount) {
      _childrenControllers.removeLast().dispose();
    }
  }

  void _syncChildrenResponsibleIndexes() {
    while (_childrenResponsibleIndexes.length < _childrenCount) {
      _childrenResponsibleIndexes.add(0);
    }
    while (_childrenResponsibleIndexes.length > _childrenCount) {
      _childrenResponsibleIndexes.removeLast();
    }
    for (var i = 0; i < _childrenResponsibleIndexes.length; i++) {
      final maxGuardian = (_guardianCount - 1).clamp(0, 5);
      _childrenResponsibleIndexes[i] = _childrenResponsibleIndexes[i].clamp(0, maxGuardian);
    }
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
            value: switch (_registrationMode) {
              _UnitPeopleRegistrationMode.family => 'Nova família',
              _UnitPeopleRegistrationMode.professional => 'Profissional',
              _UnitPeopleRegistrationMode.professionalWithFamily => 'Profissional e responsável',
            },
            options: const ['Nova família', 'Profissional', 'Profissional e responsável'],
            optionLabel: (value) => value,
            onChanged: (value) => _setRegistrationMode(switch (value) {
              'Profissional' => _UnitPeopleRegistrationMode.professional,
              'Profissional e responsável' => _UnitPeopleRegistrationMode.professionalWithFamily,
              _ => _UnitPeopleRegistrationMode.family,
            }),
            prefixIcon: Icons.account_tree_outlined,
          ),
          const SizedBox(height: CoeloSpacing.space4),
          if (_isFamilyRegistration) ...[
            if (_isProfessionalAndFamilyRegistration) ...[
              CoeloFormTextField(
                fieldKey: const Key('unit-professional-name'),
                controller: _name,
                labelText: 'Nome do profissional',
                prefixIcon: Icons.badge_outlined,
              ),
              const SizedBox(height: CoeloSpacing.space2),
              CoeloFormTextField(
                fieldKey: const Key('unit-professional-identifier'),
                controller: _professionalIdentifierController,
                labelText: '@, CPF, e-mail ou celular',
                prefixIcon: Icons.contact_mail_rounded,
              ),
              const SizedBox(height: CoeloSpacing.space4),
            ],
            CoeloAdminSingleSelectField<int>(
              key: const Key('unit-family-guardians-count'),
              label: 'Quantos responsáveis',
              value: _guardianCount,
              options: const [1, 2, 3, 4, 5, 6],
              optionLabel: (value) => value.toString(),
              onChanged: _updateGuardianCount,
              prefixIcon: Icons.groups_2_rounded,
            ),
            const SizedBox(height: CoeloSpacing.space4),
            Text(
              'Responsável ${_activeGuardianStep + 1} de $_guardianCount',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: CoeloSpacing.space2),
            _responsibleInput(index: _activeGuardianStep),
            const SizedBox(height: CoeloSpacing.space2),
            if (_activeGuardianStep < _guardianCount - 1)
              FilledButton(
                key: const Key('unit-family-add-next-guardian'),
                onPressed: _guardianCanAdvance ? () => setState(_advanceGuardianStep) : null,
                child: Text(
                  _activeGuardianStep == _guardianCount - 1
                      ? 'Concluir responsáveis'
                      : 'Salvar e próximo responsável',
                ),
              ),
            if (_activeGuardianStep >= _guardianCount - 1) ...[
              const SizedBox(height: CoeloSpacing.space4),
              CoeloAdminSingleSelectField<int>(
                key: const Key('unit-family-children-count'),
                label: 'Quantas crianças',
                value: _childrenCount,
                options: const [1, 2, 3, 4, 5, 6],
                optionLabel: (value) => value.toString(),
                onChanged: _updateChildrenCount,
                prefixIcon: Icons.child_care_rounded,
              ),
              const SizedBox(height: CoeloSpacing.space4),
              Text('Crianças e vínculo', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: CoeloSpacing.space3),
              for (var index = 0; index < _childrenCount; index++) ...[
                CoeloFormTextField(
                  fieldKey: Key('unit-family-child-$index'),
                  controller: _childrenControllers[index],
                  labelText: 'Criança ${index + 1}',
                  prefixIcon: Icons.child_care_rounded,
                ),
                const SizedBox(height: CoeloSpacing.space2),
                CoeloAdminSingleSelectField<int>(
                  key: Key('unit-family-child-responsavel-$index'),
                  label: 'Responsável vinculado',
                  value: _childrenResponsibleIndexes[index],
                  options: List<int>.generate(_guardianCount, (guardianIndex) => guardianIndex),
                  optionLabel: (value) => 'Responsável ${value + 1}',
                  onChanged: (value) => setState(() => _childrenResponsibleIndexes[index] = value),
                  prefixIcon: Icons.badge_outlined,
                ),
                const SizedBox(height: CoeloSpacing.space4),
              ],
            ],
          ] else ...[
            CoeloFormTextField(
              fieldKey: const Key('unit-local-name'),
              controller: _name,
              labelText: 'Nome',
              prefixIcon: _dialogIcon,
            ),
            const SizedBox(height: CoeloSpacing.space2),
            CoeloFormTextField(
              fieldKey: const Key('unit-local-professional-identifier'),
              controller: _professionalIdentifierController,
              labelText: '@, CPF, e-mail ou celular',
              prefixIcon: Icons.contact_mail_rounded,
            ),
            const SizedBox(height: CoeloSpacing.space4),
          ],
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
        if (widget.kind == UnitLocalManagementKind.people &&
            (_isProfessionalRegistration || _isProfessionalAndFamilyRegistration)) {
          if (widget.onCreateProfessionalPerson != null) {
            widget.onCreateProfessionalPerson!(_resolvedPersonRole);
            Navigator.of(context).pop();
            return;
          }
          Navigator.of(context).pop(UnitLocalEntry(name: name, detail: _detail));
          return;
        }
        Navigator.of(context).pop(UnitLocalEntry(name: name, detail: _detail));
      },
      child: Text(
        widget.search
            ? 'Enviar convite'
            : widget.initial == null
            ? ((_isProfessionalRegistration || _isProfessionalAndFamilyRegistration)
                  ? 'Ir para cadastro de profissional'
                  : 'Adicionar')
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
      UnitLocalManagementKind.people => switch (_registrationMode) {
        _UnitPeopleRegistrationMode.family =>
          'Família -> Responsável -> Crianças: $_childrenWithResponsibleSummary',
        _UnitPeopleRegistrationMode.professionalWithFamily =>
          'Profissional: $_professionalName · Responsáveis: ${_guardianNames.join(', ')} · Perfil: $_profile',
        _UnitPeopleRegistrationMode.professional =>
          'Profissional: $_professionalName · Perfil: $_profile',
      },
      UnitLocalManagementKind.invitations => 'Enviado',
      UnitLocalManagementKind.groups => 'Turma desta unidade',
      UnitLocalManagementKind.activities => 'Atividade desta unidade',
    };
  }

  String get _entryName {
    if (widget.kind != UnitLocalManagementKind.people || widget.search) {
      return _name.text.trim();
    }

    return switch (_registrationMode) {
      _UnitPeopleRegistrationMode.family =>
        _guardianNames.isNotEmpty ? _guardianNames.first : 'Nova família',
      _UnitPeopleRegistrationMode.professionalWithFamily => _professionalName,
      _UnitPeopleRegistrationMode.professional => _professionalName,
    };
  }

  bool get _hasRequiredPeopleLinks =>
      widget.kind != UnitLocalManagementKind.people ||
      widget.search ||
      (_isFamilyRegistration && _familyComplete) ||
      (_isProfessionalRegistration && _professionalComplete) ||
      (_isProfessionalAndFamilyRegistration && _professionalComplete && _familyComplete);

  String get _resolvedPersonRole {
    if (_isProfessionalRegistration || _isProfessionalAndFamilyRegistration) {
      return 'educator';
    }
    if (_profile == 'Responsável') {
      return 'caregiver';
    }
    return 'educator';
  }

  Widget _responsibleInput({required int index}) {
    if (index < 0 || index >= _guardianControllers.length) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Responsável ${index + 1}', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: CoeloSpacing.space2),
        Row(
          children: [
            Expanded(
              child: CoeloFormTextField(
                key: Key('unit-family-guardian-$index'),
                controller: _guardianControllers[index],
                labelText: 'Nome do responsável ${index + 1}',
                prefixIcon: Icons.family_restroom_rounded,
              ),
            ),
            const SizedBox(width: CoeloSpacing.space2),
            Switch.adaptive(
              key: Key('unit-family-guardian-existing-switch-$index'),
              value: _guardianAlreadyRegistered[index],
              onChanged: (value) => setState(() {
                _guardianAlreadyRegistered[index] = value;
                if (!value) {
                  _guardianSearchControllers[index].clear();
                }
              }),
            ),
            const SizedBox(width: CoeloSpacing.space1),
            Text('Responsável já cadastrado?', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        if (_guardianAlreadyRegistered[index]) ...[
          const SizedBox(height: CoeloSpacing.space2),
          CoeloFormTextField(
            key: Key('unit-family-guardian-existing-$index'),
            controller: _guardianSearchControllers[index],
            labelText: 'Buscar por @, CPF, e-mail ou celular',
            prefixIcon: Icons.search_rounded,
          ),
        ],
      ],
    );
  }

  String get _professionalName => _name.text.trim();

  List<String> get _guardianNames => [
    for (var index = 0; index < _guardianControllers.length; index++)
      if (_guardianAlreadyRegistered[index])
        _guardianSearchControllers[index].text.trim()
      else
        _guardianControllers[index].text.trim(),
  ].where((value) => value.isNotEmpty).toList(growable: false);

  List<String> get _childrenNames => _childrenControllers
      .map((controller) => controller.text.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  String get _childrenWithResponsibleSummary {
    if (_childrenControllers.isEmpty) {
      return 'nenhum';
    }
    return [
      for (var index = 0; index < _childrenControllers.length; index++)
        '${_childrenControllers[index].text.trim().isEmpty ? 'Criança ${index + 1}' : _childrenControllers[index].text.trim()} -> ${_guardianNameForLink(index)}',
    ].join('; ');
  }

  String _guardianNameForLink(int childIndex) {
    if (_childrenResponsibleIndexes.isEmpty || childIndex >= _childrenResponsibleIndexes.length) {
      return 'Responsável não informado';
    }
    final guardianIndex = _childrenResponsibleIndexes[childIndex];
    if (guardianIndex >= _guardianNames.length) {
      return 'Responsável ${guardianIndex + 1}';
    }
    return _guardianNames[guardianIndex];
  }
}
