import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../../institutions/data/fake_institution_directory_repository.dart';
import '../../institutions/domain/institution_record.dart';
import '../../support/domain/support_ticket.dart';
import '../domain/group_directory.dart';

enum GroupFormSaveResult { created, updated }

final class GroupFormPage extends StatefulWidget {
  const GroupFormPage({
    required this.institutions,
    required this.repository,
    required this.logout,
    required this.onCancel,
    required this.onSaved,
    this.groupId,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    super.key,
  });

  final FakeInstitutionDirectoryRepository institutions;
  final GroupDirectoryRepository repository;
  final LogoutAction logout;
  final VoidCallback onCancel;
  final ValueChanged<GroupFormSaveResult> onSaved;
  final String? groupId;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;

  @override
  State<GroupFormPage> createState() => _GroupFormPageState();
}

final class _GroupFormPageState extends State<GroupFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _typeController;
  late InstitutionRecord _institution;
  late InstitutionUnit _unit;
  late GroupStatus _status;
  GroupRecord? _original;
  bool _dirty = false;
  bool _saving = false;
  String? _saveError;

  bool get _editing => widget.groupId != null;

  @override
  void initState() {
    super.initState();
    _original = widget.groupId == null ? null : widget.repository.findById(widget.groupId!);
    final record = _original;
    _institution = record == null
        ? widget.institutions.records.first
        : widget.institutions.findById(record.institutionId)!;
    _unit = record == null
        ? _institution.units.first
        : _institution.units.firstWhere((unit) => unit.id == record.unitId);
    _status = record?.status ?? GroupStatus.active;
    _nameController = TextEditingController(text: record?.name ?? '');
    _typeController = TextEditingController(text: record?.groupType ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<bool> _confirmExit() async {
    if (!_dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CoeloAdminDialogShell(
        dialogKey: const Key('group-exit-dialog'),
        title: 'Sair sem salvar?',
        body: const Text('As alterações feitas neste grupo serão perdidas se você sair agora.'),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Continuar editando'),
        ),
        primaryAction: FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sair sem salvar'),
        ),
      ),
    );
    return discard ?? false;
  }

  Future<void> _cancel() async {
    if (await _confirmExit()) widget.onCancel();
  }

  Future<void> _selectDestination(String destination) async {
    if (await _confirmExit()) widget.onDestinationSelected?.call(destination);
  }

  Future<void> _save() async {
    setState(() => _saveError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final original = _original;
      final record = original == null
          ? GroupRecord(
              id: widget.repository.createId(
                _institution.id,
                _unit.id,
                _nameController.text.trim(),
              ),
              institutionId: _institution.id,
              institutionName: _institution.publicName,
              unitId: _unit.id,
              unitName: _unit.name,
              name: _nameController.text.trim(),
              groupType: _typeController.text.trim(),
              status: _status,
              createdAt: now,
              updatedAt: now,
            )
          : original.copyWith(
              name: _nameController.text.trim(),
              groupType: _typeController.text.trim(),
              status: _status,
              updatedAt: now,
            );
      await widget.repository.upsert(record);
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _saving = false;
      });
      widget.onSaved(original == null ? GroupFormSaveResult.created : GroupFormSaveResult.updated);
    } on Exception {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Não foi possível salvar o grupo. Revise os dados e tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _editing ? 'Editar grupo' : 'Criar grupo';
    return SuperadminShell(
      logout: widget.logout,
      title: title,
      subtitle: _editing
          ? 'Atualize os dados do grupo selecionado.'
          : 'Adicione um novo grupo ao Coelo.',
      currentDestination: 'groups',
      showChatLauncher: false,
      onDestinationSelected: _selectDestination,
      onBugReportSubmitted: widget.onBugReportSubmitted,
      child: _editing && _original == null
          ? CoeloStatePanel(
              key: const Key('group-form-not-found'),
              title: 'Grupo não encontrado',
              message: 'O registro solicitado não existe nesta sessão local.',
              icon: Icons.search_off_rounded,
              actionLabel: 'Voltar aos grupos',
              onAction: widget.onCancel,
            )
          : PopScope(
              canPop: !_dirty,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _cancel();
              },
              child: Form(
                key: _formKey,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
                        ? CoeloSpacing.space10
                        : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
                        ? CoeloSpacing.space6
                        : CoeloSpacing.space4;
                    return Padding(
                      key: const Key('group-form-golden-root'),
                      padding: EdgeInsets.fromLTRB(padding, padding, padding, CoeloSpacing.space4),
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              key: const Key('group-form-scroll'),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 880),
                                  child: _formSurface(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: CoeloSpacing.space4),
                          _footer(),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }

  Widget _formSurface() {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Dados do grupo', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: CoeloSpacing.space1),
            Text(
              'Vincule o grupo à hierarquia permitida e informe seus dados operacionais.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: CoeloSpacing.space4),
              Semantics(
                liveRegion: true,
                child: MaterialBanner(
                  content: Text(_saveError!),
                  actions: [
                    TextButton(
                      onPressed: () => setState(() => _saveError = null),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: CoeloSpacing.space6),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 600;
                final width = twoColumns
                    ? (constraints.maxWidth - CoeloSpacing.space3) / 2
                    : constraints.maxWidth;
                final fields = _fields();
                return Wrap(
                  spacing: CoeloSpacing.space3,
                  runSpacing: CoeloSpacing.space4,
                  children: [for (final field in fields) SizedBox(width: width, child: field)],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _fields() {
    final locked = _editing;
    return [
      IgnorePointer(
        ignoring: locked,
        child: Opacity(
          opacity: locked ? .65 : 1,
          child: CoeloAdminSingleSelectField<InstitutionRecord>(
            key: const Key('group-institution-field'),
            label: 'Instituição',
            value: _institution,
            options: widget.institutions.records,
            optionLabel: (value) => value.publicName,
            enabled: !locked,
            prefixIcon: Icons.account_balance_outlined,
            onChanged: (value) => setState(() {
              _institution = value;
              _unit = value.units.first;
              _dirty = true;
            }),
          ),
        ),
      ),
      IgnorePointer(
        ignoring: locked,
        child: Opacity(
          opacity: locked ? .65 : 1,
          child: CoeloAdminSingleSelectField<InstitutionUnit>(
            key: const Key('group-unit-field'),
            label: 'Unidade',
            value: _unit,
            options: _institution.units,
            optionLabel: (value) => value.name,
            enabled: !locked,
            prefixIcon: Icons.apartment_outlined,
            onChanged: (value) => setState(() {
              _unit = value;
              _dirty = true;
            }),
          ),
        ),
      ),
      CoeloFormTextField(
        fieldKey: const Key('group-name-field'),
        controller: _nameController,
        labelText: 'Nome do grupo',
        prefixIcon: Icons.groups_outlined,
        textInputAction: TextInputAction.next,
        validator: _required('Informe o nome do grupo.'),
        onChanged: (_) => _markDirty(),
      ),
      CoeloFormTextField(
        fieldKey: const Key('group-type-field'),
        controller: _typeController,
        labelText: 'Tipo do grupo',
        hintText: 'Ex.: class',
        prefixIcon: Icons.category_outlined,
        textInputAction: TextInputAction.done,
        validator: _required('Informe o tipo do grupo.'),
        onChanged: (_) => _markDirty(),
        onFieldSubmitted: (_) => _save(),
      ),
      CoeloAdminSingleSelectField<GroupStatus>(
        key: const Key('group-status-field'),
        label: 'Status',
        value: _status,
        options: GroupStatus.values,
        optionLabel: (value) => value.label,
        prefixIcon: Icons.toggle_on_outlined,
        onChanged: (value) => setState(() {
          _status = value;
          _dirty = true;
        }),
      ),
    ];
  }

  FormFieldValidator<String> _required(String message) =>
      (value) => value == null || value.trim().isEmpty ? message : null;

  Widget _footer() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 880),
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: CoeloSpacing.space3,
        runSpacing: CoeloSpacing.space2,
        children: [
          OutlinedButton(
            key: const Key('group-form-cancel'),
            onPressed: _saving ? null : _cancel,
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            key: const Key('group-form-save'),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: CoeloSize.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Salvando…' : 'Salvar grupo'),
          ),
        ],
      ),
    );
  }
}
