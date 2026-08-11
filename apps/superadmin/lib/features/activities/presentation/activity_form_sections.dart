import 'dart:typed_data';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/avatar_crop_dialog.dart';
import '../../institutions/presentation/widgets/institution_logo_picker_stub.dart'
    if (dart.library.html) '../../institutions/presentation/widgets/institution_logo_picker_web.dart';
import '../domain/activity_directory.dart';
import 'activity_form_controller.dart';
import 'activity_form_draft.dart';
import 'activity_form_page.dart';

final class ActivityFormSection extends StatelessWidget {
  const ActivityFormSection({
    required this.controller,
    required this.onCreateLocation,
    required this.imagePicker,
    super.key,
  });

  final ActivityFormController controller;
  final ActivityLocationCreator onCreateLocation;
  final InstitutionLogoPicker imagePicker;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: ValueKey(controller.currentStep),
    child: switch (controller.currentStep) {
      ActivityFormStep.identity => _IdentitySection(
        controller: controller,
        imagePicker: imagePicker,
      ),
      ActivityFormStep.structure => _StructureSection(
        controller: controller,
        onCreateLocation: onCreateLocation,
      ),
      ActivityFormStep.links => _LinksSection(controller: controller),
      ActivityFormStep.professionals => _ProfessionalsSection(controller: controller),
    },
  );
}

final class _IdentitySection extends StatelessWidget {
  const _IdentitySection({required this.controller, required this.imagePicker});

  final ActivityFormController controller;
  final InstitutionLogoPicker imagePicker;

  Future<void> _pickImage(BuildContext context) async {
    final file = await imagePicker();
    if (file == null || !context.mounted) return;
    final result = await showDialog<AvatarCropResult>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (context) => AvatarCropDialog(bytes: file.bytes),
    );
    if (result != null) controller.setImage(name: file.name, bytes: result.bytes);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionHeader(
        title: 'Identidade da atividade',
        description: 'Defina como a atividade será reconhecida nos contextos da instituição.',
      ),
      const SizedBox(height: CoeloSpacing.space5),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ActivityAvatar(bytes: controller.imageBytes),
          const SizedBox(width: CoeloSpacing.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Foto de perfil', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: CoeloSpacing.space1),
                Text(
                  'PNG, JPG ou WebP.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: CoeloSpacing.space2),
                OutlinedButton.icon(
                  key: const Key('activity-form-image'),
                  onPressed: () => _pickImage(context),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(controller.imageBytes == null ? 'Adicionar foto' : 'Trocar foto'),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space5),
      _ResponsiveGrid(
        children: [
          CoeloFormTextField(
            fieldKey: const Key('activity-form-name'),
            controller: controller.name,
            labelText: 'Nome',
            hintText: 'Como a atividade aparece no Coelo',
            prefixIcon: Icons.badge_outlined,
            errorText: controller.nameError,
            textInputAction: TextInputAction.next,
          ),
          CoeloAdminSingleSelectField<ActivityGovernance>(
            key: const Key('activity-form-governance'),
            label: 'Tipo da atividade',
            value: controller.governance,
            options: controller.governanceLocked
                ? const [ActivityGovernance.fixed]
                : const [ActivityGovernance.optional, ActivityGovernance.mandatory],
            optionLabel: (value) => switch (value) {
              ActivityGovernance.optional => 'Simples/Opcional',
              ActivityGovernance.mandatory => 'Obrigatória',
              ActivityGovernance.fixed => 'Fixa',
            },
            onChanged: controller.selectGovernance,
            enabled: !controller.governanceLocked,
            prefixIcon: Icons.rule_rounded,
          ),
          CoeloAdminSingleSelectField<ActivityCategory?>(
            key: const Key('activity-form-category'),
            label: 'Categoria',
            value: controller.category,
            options: const [null, ...ActivityCategory.values],
            optionLabel: (value) => value?.label ?? 'Selecione a categoria',
            onChanged: (value) {
              if (value != null) controller.selectCategory(value);
            },
            prefixIcon: Icons.category_outlined,
          ),
          CoeloAdminSingleSelectField<String>(
            key: const Key('activity-form-suggestion'),
            label: 'Atividade',
            value: controller.selectedActivitySuggestion ?? '',
            options: ['', ...controller.activitySuggestions],
            optionLabel: (value) => value.isEmpty ? 'Selecione a atividade' : value,
            onChanged: controller.selectActivitySuggestion,
            enabled: controller.category != null,
            prefixIcon: Icons.local_activity_outlined,
          ),
          if (controller.selectedActivitySuggestion == 'Outro')
            CoeloFormTextField(
              fieldKey: const Key('activity-form-other'),
              controller: controller.otherActivity,
              labelText: 'Outra atividade',
              hintText: 'Informe o nome da atividade',
              prefixIcon: Icons.edit_outlined,
            ),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloFormTextField(
        fieldKey: const Key('activity-form-description'),
        controller: controller.description,
        labelText: 'Descrição',
        hintText: 'Descreva o propósito da atividade',
        prefixIcon: Icons.notes_rounded,
        maxLines: 4,
        textInputAction: TextInputAction.newline,
      ),
    ],
  );
}

final class _StructureSection extends StatelessWidget {
  const _StructureSection({required this.controller, required this.onCreateLocation});

  final ActivityFormController controller;
  final ActivityLocationCreator onCreateLocation;

  Future<void> _createLocation(BuildContext context) async {
    if (controller.selectedUnitIds.isEmpty) return;
    final unitId = controller.selectedUnitIds.first;
    final option = await showDialog<ActivityFormLocationOption>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (context) => _CreateLocationDialog(
        unitId: unitId,
        unitName: controller.units.firstWhere((unit) => unit.id == unitId).name,
        onCreate: onCreateLocation,
      ),
    );
    if (option != null) controller.addLocation(option);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionHeader(
        title: 'Estrutura e locais',
        description: 'A atividade pertence à instituição e precisa de ao menos uma unidade.',
      ),
      const SizedBox(height: CoeloSpacing.space5),
      CoeloAdminSingleSelectField<String>(
        key: const Key('activity-form-institution'),
        label: 'Instituição',
        value: controller.selectedInstitutionId ?? '',
        options: ['', ...controller.options.institutions.map((item) => item.id)],
        optionLabel: (id) => id.isEmpty
            ? 'Selecione a instituição'
            : controller.options.institutions.firstWhere((item) => item.id == id).name,
        onChanged: controller.selectInstitution,
        enabled: !controller.institutionLocked,
        errorText: controller.institutionError,
        prefixIcon: Icons.apartment_outlined,
        searchable: true,
        searchHintText: 'Buscar instituição',
      ),
      const SizedBox(height: CoeloSpacing.space5),
      _SelectionSection(
        title: 'Unidades',
        description: 'Selecione todas as unidades em que a atividade estará disponível.',
        error: controller.unitsError,
        children: [
          for (final unit in controller.units)
            _SelectableCard(
              key: Key('activity-unit-${unit.id}'),
              label: unit.name,
              supportingText: 'Unidade da instituição selecionada',
              selected: controller.selectedUnitIds.contains(unit.id),
              onPressed: () => controller.toggleUnit(unit.id),
            ),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space5),
      LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
          final selector = CoeloAdminSingleSelectField<String>(
            key: const Key('activity-form-location'),
            label: 'Local interno (opcional)',
            value: controller.selectedLocationId ?? '',
            options: ['', ...controller.locations.map((item) => item.id)],
            optionLabel: (id) => id.isEmpty
                ? 'Sem local definido'
                : controller.locations.firstWhere((item) => item.id == id).name,
            onChanged: controller.selectLocation,
            enabled: controller.selectedUnitIds.isNotEmpty,
            prefixIcon: Icons.meeting_room_outlined,
          );
          final createAction = OutlinedButton.icon(
            key: const Key('activity-create-location'),
            onPressed: controller.selectedUnitIds.isEmpty ? null : () => _createLocation(context),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Cadastrar local'),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                selector,
                const SizedBox(height: CoeloSpacing.space3),
                SizedBox(width: double.infinity, child: createAction),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: selector),
              const SizedBox(width: CoeloSpacing.space3),
              createAction,
            ],
          );
        },
      ),
      const SizedBox(height: CoeloSpacing.space2),
      Text(
        'Locais são espaços internos da unidade, como laboratório, quadra ou sala temática.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

final class _LinksSection extends StatelessWidget {
  const _LinksSection({required this.controller});

  final ActivityFormController controller;

  @override
  Widget build(BuildContext context) {
    final institution = controller.options.institutions
        .where((item) => item.id == controller.selectedInstitutionId)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Vínculos da atividade',
          description: 'Confira a instituição, as unidades e selecione as turmas separadamente.',
        ),
        const SizedBox(height: CoeloSpacing.space5),
        _SummarySurface(
          icon: Icons.apartment_outlined,
          title: 'Instituição',
          value: institution?.name ?? 'Não selecionada',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _SelectionSection(
          title: 'Unidades vinculadas',
          description: 'Ajuste as unidades antes de escolher as turmas.',
          error: controller.unitsError,
          children: [
            for (final unit in controller.units)
              _SelectableCard(
                label: unit.name,
                supportingText: controller.selectedUnitIds.contains(unit.id)
                    ? 'Vinculada'
                    : 'Disponível',
                selected: controller.selectedUnitIds.contains(unit.id),
                onPressed: () => controller.toggleUnit(unit.id),
              ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space5),
        _SelectionSection(
          title: 'Turmas',
          description: 'A atividade só produz efeitos operacionais dentro das turmas vinculadas.',
          error: controller.groupsError,
          children: [
            for (final group in controller.groups)
              _SelectableCard(
                key: Key('activity-group-${group.id}'),
                label: group.name,
                supportingText: '${group.participantCount} participantes',
                selected: controller.selectedGroupIds.contains(group.id),
                onPressed: () => controller.toggleGroup(group.id),
              ),
          ],
        ),
      ],
    );
  }
}

final class _ProfessionalsSection extends StatelessWidget {
  const _ProfessionalsSection({required this.controller});

  final ActivityFormController controller;

  Future<void> _invite(BuildContext context, String groupId) => showDialog<void>(
    context: context,
    barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
    builder: (context) => _ProfessionalPickerDialog(controller: controller, groupId: groupId),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionHeader(
        title: 'Profissionais e revisão',
        description: 'Convide profissionais por turma e revise as permissões contextuais.',
      ),
      const SizedBox(height: CoeloSpacing.space3),
      Text(
        'As opções abaixo pertencem à turma. A autorização efetiva futura sempre respeitará a hierarquia da instituição, unidade e turma.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: CoeloSpacing.space5),
      for (final group in controller.groups.where(
        (group) => controller.selectedGroupIds.contains(group.id),
      )) ...[
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: CoeloSpacing.space3,
          runSpacing: CoeloSpacing.space2,
          children: [
            Text(group.name, style: Theme.of(context).textTheme.titleMedium),
            OutlinedButton.icon(
              key: Key('activity-invite-${group.id}'),
              onPressed: () => _invite(context, group.id),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Convidar profissional'),
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space3),
        if (!controller.assignments.any((item) => item.groupId == group.id))
          const _SummarySurface(
            icon: Icons.people_outline_rounded,
            title: 'Nenhum profissional convidado',
            value: 'Você pode concluir o vínculo depois.',
          ),
        for (final assignment in controller.assignments.where((item) => item.groupId == group.id))
          Padding(
            padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
            child: _ProfessionalPermissionCard(controller: controller, assignment: assignment),
          ),
        const SizedBox(height: CoeloSpacing.space4),
      ],
      const Divider(),
      const SizedBox(height: CoeloSpacing.space4),
      Text('Revisão', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: CoeloSpacing.space3),
      _ResponsiveGrid(
        children: [
          _SummarySurface(
            icon: Icons.apartment_outlined,
            title: 'Instituição',
            value:
                controller.options.institutions
                    .where((item) => item.id == controller.selectedInstitutionId)
                    .firstOrNull
                    ?.name ??
                'Não selecionada',
          ),
          _SummarySurface(
            icon: Icons.business_outlined,
            title: 'Unidades',
            value: '${controller.selectedUnitIds.length} selecionada(s)',
          ),
          _SummarySurface(
            icon: Icons.groups_outlined,
            title: 'Turmas',
            value: '${controller.selectedGroupIds.length} selecionada(s)',
          ),
          _SummarySurface(
            icon: Icons.people_outline_rounded,
            title: 'Profissionais',
            value: '${controller.assignments.length} atribuição(ões)',
          ),
        ],
      ),
    ],
  );
}

final class _CreateLocationDialog extends StatefulWidget {
  const _CreateLocationDialog({
    required this.unitId,
    required this.unitName,
    required this.onCreate,
  });

  final String unitId;
  final String unitName;
  final ActivityLocationCreator onCreate;

  @override
  State<_CreateLocationDialog> createState() => _CreateLocationDialogState();
}

final class _CreateLocationDialogState extends State<_CreateLocationDialog> {
  final _name = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Informe o nome do local.');
      return;
    }
    setState(() => _saving = true);
    final option = await widget.onCreate(
      ActivityLocationDraft(unitId: widget.unitId, name: _name.text.trim()),
    );
    if (mounted) Navigator.of(context).pop(option);
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    dialogKey: const Key('activity-create-location-dialog'),
    title: 'Cadastrar novo local',
    closeTooltip: 'Fechar cadastro de local',
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('O local será criado dentro de ${widget.unitName}.'),
        const SizedBox(height: CoeloSpacing.space3),
        CoeloFormTextField(
          fieldKey: const Key('activity-location-name'),
          controller: _name,
          labelText: 'Nome do local',
          hintText: 'Ex.: Laboratório de informática',
          prefixIcon: Icons.meeting_room_outlined,
          errorText: _error,
        ),
      ],
    ),
    secondaryAction: OutlinedButton(
      onPressed: _saving ? null : Navigator.of(context).pop,
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(
      key: const Key('activity-location-submit'),
      onPressed: _saving ? null : _submit,
      child: const Text('Cadastrar local'),
    ),
  );
}

final class _ProfessionalPickerDialog extends StatefulWidget {
  const _ProfessionalPickerDialog({required this.controller, required this.groupId});

  final ActivityFormController controller;
  final String groupId;

  @override
  State<_ProfessionalPickerDialog> createState() => _ProfessionalPickerDialogState();
}

final class _ProfessionalPickerDialogState extends State<_ProfessionalPickerDialog> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final items = widget.controller.options.professionals
        .where((item) => item.name.toLowerCase().contains(query))
        .toList(growable: false);
    return CoeloAdminDialogShell(
      dialogKey: const Key('activity-professional-dialog'),
      title: 'Convidar profissional',
      closeTooltip: 'Fechar convite',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CoeloSearchField(
            controller: _search,
            hintText: 'Buscar profissional',
            semanticLabel: 'Buscar profissional para a atividade',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          for (final professional in items)
            Padding(
              padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
              child: _SelectableCard(
                key: Key('activity-professional-${professional.id}'),
                label: professional.name,
                supportingText: professional.role,
                selected: widget.controller.assignments.any(
                  (item) =>
                      item.groupId == widget.groupId && item.professionalId == professional.id,
                ),
                onPressed: () {
                  setState(
                    () => widget.controller.toggleProfessional(widget.groupId, professional.id),
                  );
                },
              ),
            ),
        ],
      ),
      primaryAction: FilledButton(
        onPressed: Navigator.of(context).pop,
        child: const Text('Concluir convite'),
      ),
    );
  }
}

final class _ProfessionalPermissionCard extends StatelessWidget {
  const _ProfessionalPermissionCard({required this.controller, required this.assignment});

  final ActivityFormController controller;
  final ActivityProfessionalAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final professional = controller.options.professionals.firstWhere(
      (item) => item.id == assignment.professionalId,
    );
    Widget permission(String label, bool value, ValueChanged<bool> onChanged) =>
        CoeloAdminToggleField(label: label, value: value, onChanged: onChanged);
    return Container(
      key: Key('activity-assignment-${assignment.groupId}-${assignment.professionalId}'),
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(professional.name, style: Theme.of(context).textTheme.titleSmall),
          Text(professional.role, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: CoeloSpacing.space3),
          Wrap(
            spacing: CoeloSpacing.space4,
            runSpacing: CoeloSpacing.space2,
            children: [
              permission('Happens', assignment.permissions.happens, (value) {
                controller.setPermission(
                  assignment.groupId,
                  assignment.professionalId,
                  happens: value,
                );
              }),
              permission('Now', assignment.permissions.now, (value) {
                controller.setPermission(assignment.groupId, assignment.professionalId, now: value);
              }),
              permission('Moments', assignment.permissions.moments, (value) {
                controller.setPermission(
                  assignment.groupId,
                  assignment.professionalId,
                  moments: value,
                );
              }),
              permission('Chat', assignment.permissions.chat, (value) {
                controller.setPermission(
                  assignment.groupId,
                  assignment.professionalId,
                  chat: value,
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

final class _ActivityAvatar extends StatelessWidget {
  const _ActivityAvatar({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) => Container(
    width: 104,
    height: 104,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Theme.of(context).colorScheme.surfaceContainer,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: bytes == null
        ? Icon(Icons.local_activity_outlined, color: Theme.of(context).colorScheme.primary)
        : Image.memory(bytes!, fit: BoxFit.cover),
  );
}

final class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: CoeloSpacing.space1),
      Text(
        description,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

final class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final width = compact
          ? constraints.maxWidth
          : (constraints.maxWidth - CoeloSpacing.space3) / 2;
      return Wrap(
        spacing: CoeloSpacing.space3,
        runSpacing: CoeloSpacing.space4,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );
}

final class _SelectionSection extends StatelessWidget {
  const _SelectionSection({
    required this.title,
    required this.description,
    required this.children,
    this.error,
  });

  final String title;
  final String description;
  final List<Widget> children;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: CoeloSpacing.space1),
      Text(description),
      if (error != null) ...[
        const SizedBox(height: CoeloSpacing.space1),
        Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
      const SizedBox(height: CoeloSpacing.space3),
      _ResponsiveGrid(children: children),
    ],
  );
}

final class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.label,
    required this.supportingText,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final String label;
  final String supportingText;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CoeloAdminInteractiveCard(
    semanticLabel: '$label, ${selected ? 'selecionado' : 'não selecionado'}',
    onPressed: onPressed,
    minHeight: 88,
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: CoeloSpacing.space1),
                Text(supportingText, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    ),
  );
}

final class _SummarySurface extends StatelessWidget {
  const _SummarySurface({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(CoeloSpacing.space4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: CoeloSpacing.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              Text(value),
            ],
          ),
        ),
      ],
    ),
  );
}
