export 'health_medication_plan_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import 'health_care_responsive_surface.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/health_care.dart';

typedef HealthCareFormSave = Future<void> Function();

enum _HealthCareProfileFormStep { child, allergies, guidance, review }

final class HealthCareProfileFormPage extends StatefulWidget {
  const HealthCareProfileFormPage({
    required this.logout,
    required this.onCancel,
    required this.onSaved,
    this.childId,
    super.key,
  });

  final LogoutAction logout;
  final VoidCallback onCancel;
  final HealthCareFormSave onSaved;
  final String? childId;

  @override
  State<HealthCareProfileFormPage> createState() => _HealthCareProfileFormPageState();
}

final class _HealthCareProfileFormPageState extends State<HealthCareProfileFormPage> {
  var _currentStep = _HealthCareProfileFormStep.child;
  late String _childId = widget.childId ?? 'child-demo-a';
  var _allergyType = HealthCareAllergyType.food;
  var _allergyStatus = HealthCareAllergyStatus.active;
  var _severity = HealthCareEpisodeSeverity.moderate;
  var _careItems = <String>{};
  var _saving = false;
  final _lastEpisode = TextEditingController();
  final _reaction = TextEditingController();
  final _guidance = TextEditingController();
  final _notes = TextEditingController();
  final _signs = TextEditingController();
  final _adaptations = TextEditingController();

  @override
  void dispose() {
    _lastEpisode.dispose();
    _reaction.dispose();
    _guidance.dispose();
    _notes.dispose();
    _signs.dispose();
    _adaptations.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<SuperadminFormStep> get _steps => [
    for (final step in _HealthCareProfileFormStep.values)
      SuperadminFormStep(
        label: switch (step) {
          _HealthCareProfileFormStep.child => 'Criança',
          _HealthCareProfileFormStep.allergies => 'Alergias e restrições',
          _HealthCareProfileFormStep.guidance => 'Orientações de cuidado',
          _HealthCareProfileFormStep.review => 'Revisão',
        },
        status: step == _currentStep
            ? SuperadminFormStepStatus.current
            : step.index < _currentStep.index
            ? SuperadminFormStepStatus.complete
            : SuperadminFormStepStatus.incomplete,
      ),
  ];

  void _selectStep(int index) =>
      setState(() => _currentStep = _HealthCareProfileFormStep.values[index]);

  void _previousStep() {
    if (_currentStep.index == 0) return;
    _selectStep(_currentStep.index - 1);
  }

  void _continue() {
    if (_currentStep.index == _HealthCareProfileFormStep.values.length - 1) return;
    _selectStep(_currentStep.index + 1);
  }

  @override
  Widget build(BuildContext context) => _HealthCareFormFrame(
    logout: widget.logout,
    currentDestination: 'health-care-profiles',
    title: widget.childId == null ? 'Criar perfil de cuidado' : 'Editar perfil de cuidado',
    subtitle: 'Registre apenas informações permanentes de saúde e cuidado da criança.',
    onCancel: widget.onCancel,
    onSave: _saving ? null : _save,
    saveLabel: widget.childId == null ? 'Criar perfil' : 'Salvar alterações',
    saving: _saving,
    currentStep: _currentStep.index,
    steps: _steps,
    onStepSelected: _selectStep,
    onPrevious: _currentStep.index == 0 ? null : _previousStep,
    onContinue: _continue,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_currentStep == _HealthCareProfileFormStep.child)
          _FormSection(
            title: 'Criança',
            description: widget.childId == null
                ? 'Selecione a criança que receberá o perfil.'
                : 'A identidade permanece bloqueada durante a edição.',
            child: widget.childId == null
                ? CoeloAdminSingleSelectField<String>(
                    label: 'Criança',
                    value: _childId,
                    options: const ['child-demo-a', 'child-demo-b'],
                    optionLabel: _childLabel,
                    onChanged: (value) => setState(() => _childId = value),
                    prefixIcon: Icons.child_care_rounded,
                  )
                : _LockedIdentity(label: 'Criança', value: _childLabel(_childId)),
          ),
        if (_currentStep == _HealthCareProfileFormStep.allergies)
          _FormSection(
            title: 'Alergias e restrições',
            description:
                'A gravidade descreve somente o episódio registrado e não prevê reações futuras.',
            child: Column(
              children: [
                _ResponsiveFields(
                  children: [
                    CoeloAdminSingleSelectField<HealthCareAllergyType>(
                      label: 'Tipo',
                      value: _allergyType,
                      options: HealthCareAllergyType.values,
                      optionLabel: _allergyTypeLabel,
                      onChanged: (value) => setState(() => _allergyType = value),
                      prefixIcon: Icons.health_and_safety_outlined,
                    ),
                    CoeloAdminSingleSelectField<HealthCareAllergyStatus>(
                      label: 'Status',
                      value: _allergyStatus,
                      options: HealthCareAllergyStatus.values,
                      optionLabel: _allergyStatusLabel,
                      onChanged: (value) => setState(() => _allergyStatus = value),
                      prefixIcon: Icons.flag_outlined,
                    ),
                    CoeloFormTextField(
                      controller: _lastEpisode,
                      labelText: 'Último episódio registrado',
                      prefixIcon: Icons.event_outlined,
                    ),
                    CoeloAdminSingleSelectField<HealthCareEpisodeSeverity>(
                      label: 'Gravidade do episódio',
                      value: _severity,
                      options: HealthCareEpisodeSeverity.values,
                      optionLabel: _severityLabel,
                      onChanged: (value) => setState(() => _severity = value),
                      prefixIcon: Icons.monitor_heart_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: CoeloSpacing.space4),
                _ResponsiveFields(
                  children: [
                    CoeloFormTextField(
                      controller: _reaction,
                      labelText: 'Reação observada',
                      prefixIcon: Icons.visibility_outlined,
                      maxLines: 3,
                    ),
                    CoeloFormTextField(
                      controller: _guidance,
                      labelText: 'Orientação de cuidado',
                      prefixIcon: Icons.assignment_outlined,
                      maxLines: 3,
                    ),
                  ],
                ),
                const SizedBox(height: CoeloSpacing.space4),
                CoeloFormTextField(
                  controller: _notes,
                  labelText: 'Observações',
                  prefixIcon: Icons.notes_rounded,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        if (_currentStep == _HealthCareProfileFormStep.guidance)
          _FormSection(
            title: 'Perfil de cuidado',
            description:
                'Use características e orientações objetivas, sem classificação por semáforo.',
            child: Column(
              children: [
                CoeloAdminMultiSelectField<String>(
                  label: 'Caracter\u00edsticas de cuidado',
                  options: healthCareProfileCatalog
                      .expand((group) => group.items)
                      .map((item) => item.id)
                      .toList(growable: false),
                  selectedValues: _careItems,
                  optionLabel: _careItemLabel,
                  onChanged: (values) => setState(() => _careItems = values),
                  searchable: true,
                  searchHintText: 'Buscar característica',
                ),
                const SizedBox(height: CoeloSpacing.space4),
                _ResponsiveFields(
                  children: [
                    CoeloFormTextField(
                      controller: _signs,
                      labelText: 'Sinais importantes',
                      prefixIcon: Icons.sign_language_outlined,
                      maxLines: 3,
                    ),
                    CoeloFormTextField(
                      controller: _adaptations,
                      labelText: 'Adaptações e orientações',
                      prefixIcon: Icons.accessibility_new_rounded,
                      maxLines: 3,
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (_currentStep == _HealthCareProfileFormStep.review)
          Column(
            children: [
              _ReviewSection(
                title: 'Criança',
                onEdit: () => _selectStep(_HealthCareProfileFormStep.child.index),
                rows: [('Criança', _childLabel(_childId))],
              ),
              const SizedBox(height: CoeloSpacing.space4),
              _ReviewSection(
                title: 'Alergias e restrições',
                onEdit: () => _selectStep(_HealthCareProfileFormStep.allergies.index),
                rows: [
                  ('Tipo', _allergyTypeLabel(_allergyType)),
                  ('Status', _allergyStatusLabel(_allergyStatus)),
                  ('Gravidade do episódio', _severityLabel(_severity)),
                  ('Último episódio registrado', _lastEpisode.text),
                  ('Reação observada', _reaction.text),
                  ('Orientação de cuidado', _guidance.text),
                  ('Observações', _notes.text),
                ],
              ),
              const SizedBox(height: CoeloSpacing.space4),
              _ReviewSection(
                title: 'Orientações de cuidado',
                onEdit: () => _selectStep(_HealthCareProfileFormStep.guidance.index),
                rows: [
                  (
                    'Características de cuidado',
                    _careItems.isEmpty ? '' : _careItems.map(_careItemLabel).join(', '),
                  ),
                  ('Sinais importantes', _signs.text),
                  ('Adaptações e orientações', _adaptations.text),
                ],
              ),
            ],
          ),
      ],
    ),
  );
}

final class _HealthCareFormFrame extends StatefulWidget {
  const _HealthCareFormFrame({
    required this.logout,
    required this.currentDestination,
    required this.title,
    required this.subtitle,
    required this.onCancel,
    required this.onSave,
    required this.saveLabel,
    required this.saving,
    required this.currentStep,
    required this.steps,
    required this.onStepSelected,
    required this.onPrevious,
    required this.onContinue,
    required this.child,
  });

  final LogoutAction logout;
  final String currentDestination;
  final String title;
  final String subtitle;
  final VoidCallback onCancel;
  final VoidCallback? onSave;
  final String saveLabel;
  final bool saving;
  final int currentStep;
  final List<SuperadminFormStep> steps;
  final ValueChanged<int> onStepSelected;
  final VoidCallback? onPrevious;
  final VoidCallback onContinue;
  final Widget child;

  @override
  State<_HealthCareFormFrame> createState() => _HealthCareFormFrameState();
}

final class _HealthCareFormFrameState extends State<_HealthCareFormFrame> {
  double _footerHeight = 0;

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    currentDestination: widget.currentDestination,
    title: widget.title,
    subtitle: widget.subtitle,
    chatLauncherBottomInset: _footerHeight == 0 ? 0 : _footerHeight + CoeloSpacing.space4,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
            ? CoeloSpacing.space10
            : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
            ? CoeloSpacing.space6
            : CoeloSpacing.space4;
        return Padding(
          padding: EdgeInsets.fromLTRB(inset, inset, inset, CoeloSpacing.space4),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: const Key('health-care-form-scroll'),
                  padding: const EdgeInsets.only(bottom: CoeloSpacing.space6),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: LayoutBuilder(
                        builder: (context, contentConstraints) {
                          final navigation = SuperadminFormStepNavigation(
                            steps: widget.steps,
                            currentIndex: widget.currentStep,
                            onStepSelected: widget.onStepSelected,
                          );
                          if (contentConstraints.maxWidth >= CoeloBreakpoints.medium.minWidth) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                navigation,
                                const SizedBox(width: CoeloSpacing.space6),
                                Expanded(child: widget.child),
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              navigation,
                              const SizedBox(height: CoeloSpacing.space4),
                              widget.child,
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              SuperadminFormActionFooter(
                onHeightChanged: (height) {
                  if ((_footerHeight - height).abs() < .5) return;
                  setState(() => _footerHeight = height);
                },
                tertiaryAction: TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancelar'),
                ),
                continuationActions: [
                  if (widget.onPrevious != null)
                    OutlinedButton(onPressed: widget.onPrevious, child: const Text('Anterior')),
                  if (widget.currentStep < widget.steps.length - 1)
                    FilledButton(onPressed: widget.onContinue, child: const Text('Continuar'))
                  else
                    FilledButton(
                      onPressed: widget.onSave,
                      child: widget.saving
                          ? const SizedBox.square(
                              dimension: CoeloSize.iconSm,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.saveLabel),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  ).withHealthCareResponsiveSurface();
}

final class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.title, required this.rows, required this.onEdit});

  final String title;
  final List<(String, String)> rows;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => _FormSection(
    title: title,
    description: 'Confira as informações antes de salvar.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows) ...[
          Text(row.$1, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: CoeloSpacing.spaceHalf),
          Text(
            row.$2.trim().isEmpty ? 'Não informado' : row.$2,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: CoeloSpacing.space3),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: onEdit, child: const Text('Editar')),
        ),
      ],
    ),
  );
}

final class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.description, required this.child});

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: CoeloSpacing.space1),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: CoeloSpacing.space4),
          child,
        ],
      ),
    );
  }
}

final class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final twoColumns = constraints.maxWidth >= 700;
      final width = twoColumns
          ? (constraints.maxWidth - CoeloSpacing.space3) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: CoeloSpacing.space3,
        runSpacing: CoeloSpacing.space4,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );
}

final class _LockedIdentity extends StatelessWidget {
  const _LockedIdentity({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      enabled: false,
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    child: Text(value),
  );
}

String _childLabel(String value) => switch (value) {
  'child-demo-a' => 'Criança Demo A',
  'child-demo-b' => 'Criança Demo B',
  _ => value,
};

String _allergyTypeLabel(HealthCareAllergyType value) => switch (value) {
  HealthCareAllergyType.medication => 'Medicamento',
  HealthCareAllergyType.food => 'Alimento',
  HealthCareAllergyType.restriction => 'Restrição',
  HealthCareAllergyType.other => 'Outro',
};

String _allergyStatusLabel(HealthCareAllergyStatus value) => switch (value) {
  HealthCareAllergyStatus.active => 'Ativo',
  HealthCareAllergyStatus.monitoring => 'Em acompanhamento',
  HealthCareAllergyStatus.history => 'Histórico',
};

String _severityLabel(HealthCareEpisodeSeverity value) => switch (value) {
  HealthCareEpisodeSeverity.mild => 'Leve',
  HealthCareEpisodeSeverity.moderate => 'Moderada',
  HealthCareEpisodeSeverity.severe => 'Grave',
};

String _careItemLabel(String id) {
  for (final item in healthCareProfileCatalog.expand((group) => group.items)) {
    if (item.id == id) return item.label;
  }
  return id;
}
