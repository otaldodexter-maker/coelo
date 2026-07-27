import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../domain/institution_directory_item.dart';
import '../../domain/institution_record.dart';
import '../view_models/institution_form_controller.dart';
import 'institution_form_dialogs.dart';

final class InstitutionFormSection extends StatelessWidget {
  const InstitutionFormSection({required this.controller, super.key});

  final InstitutionFormController controller;

  @override
  Widget build(BuildContext context) {
    return switch (controller.currentStep) {
      InstitutionFormStep.profile => _ProfileSection(controller: controller),
      InstitutionFormStep.location => _LocationSection(controller: controller),
      InstitutionFormStep.owner => _OwnerSection(controller: controller),
      InstitutionFormStep.plan => _PlanSection(controller: controller),
      InstitutionFormStep.branding => _BrandingSection(controller: controller),
      InstitutionFormStep.review => _ReviewSection(controller: controller),
    };
  }
}

final class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.controller});
  final InstitutionFormController controller;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Perfil da instituição',
      description: 'Identifique a instituição e defina como ela funcionará no Coelo.',
      child: _FieldGrid(
        children: [
          _field(controller, InstitutionFormField.publicName, 'Nome público'),
          _field(controller, InstitutionFormField.tradeName, 'Nome fantasia'),
          _field(controller, InstitutionFormField.legalName, 'Razão social', wide: true),
          _field(controller, InstitutionFormField.typeName, 'Tipo de instituição'),
          _field(controller, InstitutionFormField.documentType, 'Tipo de documento'),
          _field(controller, InstitutionFormField.document, 'CNPJ/documento'),
          _field(controller, InstitutionFormField.slug, 'Slug'),
          _field(controller, InstitutionFormField.primaryDomain, 'Domínio principal'),
          _dropdown<InstitutionStatus>(
            label: 'Status operacional',
            value: controller.status,
            values: InstitutionStatus.values,
            labelOf: (value) => value.label,
            onChanged: controller.setStatus,
          ),
          _field(controller, InstitutionFormField.locale, 'Idioma/locale'),
          _field(controller, InstitutionFormField.timezone, 'Fuso horário'),
        ],
      ),
    );
  }
}

final class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.controller});
  final InstitutionFormController controller;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Localização e contato',
      description: 'Organize o endereço principal e os canais institucionais.',
      child: _FieldGrid(
        children: [
          _field(controller, InstitutionFormField.postalCode, 'CEP'),
          _field(controller, InstitutionFormField.country, 'País'),
          _field(controller, InstitutionFormField.state, 'Estado'),
          _field(controller, InstitutionFormField.city, 'Cidade'),
          _field(controller, InstitutionFormField.district, 'Bairro'),
          _field(controller, InstitutionFormField.street, 'Logradouro', wide: true),
          _field(controller, InstitutionFormField.addressNumber, 'Número'),
          _field(controller, InstitutionFormField.complement, 'Complemento'),
          _field(
            controller,
            InstitutionFormField.contactEmail,
            'E-mail institucional',
            inputType: TextInputType.emailAddress,
            wide: true,
          ),
          _field(controller, InstitutionFormField.contactPhone, 'Telefone'),
          _field(controller, InstitutionFormField.contactMobilePhone, 'Celular institucional'),
        ],
      ),
    );
  }
}

final class _OwnerSection extends StatelessWidget {
  const _OwnerSection({required this.controller});
  final InstitutionFormController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _Section(
      title: 'Responsável inicial',
      description: 'Cadastre a pessoa que será responsável principal (owner).',
      child: Column(
        children: [
          _FieldGrid(
            children: [
              _field(controller, InstitutionFormField.ownerFirstName, 'Nome'),
              _field(controller, InstitutionFormField.ownerLastName, 'Sobrenome'),
              _field(controller, InstitutionFormField.ownerDisplayName, 'Nome de exibição'),
              _field(
                controller,
                InstitutionFormField.ownerEmail,
                'E-mail',
                inputType: TextInputType.emailAddress,
              ),
              _field(controller, InstitutionFormField.ownerMobilePhone, 'Celular'),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Papel',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                child: const Text('Responsável principal / owner'),
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(CoeloRadius.md),
            ),
            child: const Text(
              'O convite e a ativação de acesso do responsável serão configurados em uma etapa futura.',
            ),
          ),
        ],
      ),
    );
  }
}

final class _PlanSection extends StatelessWidget {
  const _PlanSection({required this.controller});
  final InstitutionFormController controller;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Plano',
      description: 'Selecione a oferta e acompanhe o estado da assinatura.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth;
              final width = twoColumns
                  ? (constraints.maxWidth - CoeloSpacing.space3) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: CoeloSpacing.space3,
                runSpacing: CoeloSpacing.space3,
                children: [
                  for (final plan in InstitutionPlan.values)
                    SizedBox(
                      width: width,
                      child: _PlanCard(
                        plan: plan,
                        selected: controller.plan == plan,
                        onPressed: () => _selectPlan(context, plan),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: CoeloSpacing.space5),
          Wrap(
            spacing: CoeloSpacing.space2,
            runSpacing: CoeloSpacing.space2,
            children: [
              for (final action in _subscriptionActions(controller.subscriptionStatus))
                OutlinedButton(
                  key: Key('institution-subscription-${action.name}'),
                  onPressed: () => _changeSubscription(context, action),
                  child: Text(
                    _subscriptionActionLabel(action, current: controller.subscriptionStatus),
                  ),
                ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space4),
          _FieldGrid(
            children: [
              _dropdown<InstitutionSubscriptionStatus>(
                label: 'Status da assinatura',
                value: controller.subscriptionStatus,
                values: InstitutionSubscriptionStatus.values,
                labelOf: (value) => value.label,
                onChanged: (value) => _changeSubscription(context, value),
              ),
              _DateControl(
                label: 'Data de início',
                value: controller.subscriptionStart,
                onChanged: controller.setSubscriptionStart,
              ),
              if (controller.subscriptionStatus == InstitutionSubscriptionStatus.trial)
                _DateControl(
                  label: 'Término do período de teste',
                  value: controller.trialEnd,
                  onChanged: controller.setTrialEnd,
                  errorText: controller.trialEndError,
                ),
              _field(
                controller,
                InstitutionFormField.subscriptionJustification,
                'Justificativa',
                wide: true,
                maxLines: 3,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectPlan(BuildContext context, InstitutionPlan value) async {
    if (!controller.isEditing || value == controller.plan) {
      controller.setPlan(value);
      return;
    }
    final justification = await showInstitutionSubscriptionDialog(
      context,
      title: 'Trocar para o plano ${value.label}?',
      message: 'A nova seleção será aplicada localmente ao salvar as alterações.',
      requiresJustification: true,
    );
    if (justification == null) {
      return;
    }
    controller
      ..setPlan(value)
      ..setText(InstitutionFormField.subscriptionJustification, justification);
  }

  Future<void> _changeSubscription(
    BuildContext context,
    InstitutionSubscriptionStatus value,
  ) async {
    if (!controller.isEditing) {
      controller.setSubscriptionStatus(value);
      return;
    }
    final sensitive = {
      InstitutionSubscriptionStatus.paused,
      InstitutionSubscriptionStatus.suspended,
      InstitutionSubscriptionStatus.canceled,
    }.contains(value);
    final justification = await showInstitutionSubscriptionDialog(
      context,
      title:
          '${_subscriptionActionLabel(value, current: controller.subscriptionStatus)} assinatura?',
      message: 'Esta ação atualiza somente o protótipo local até o salvamento.',
      requiresJustification: sensitive,
    );
    if (justification == null) {
      return;
    }
    controller
      ..setSubscriptionStatus(value)
      ..setText(InstitutionFormField.subscriptionJustification, justification);
  }
}

final class _BrandingSection extends StatelessWidget {
  const _BrandingSection({required this.controller});
  final InstitutionFormController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = _hexColor(
      controller.text(InstitutionFormField.accentColor),
      fallback: colors.primary,
    );
    final secondary = _hexColor(
      controller.text(InstitutionFormField.secondaryColor),
      fallback: colors.secondary,
    );
    return _Section(
      title: 'Identidade visual',
      description: 'Personalize uma prévia simples. Todos os campos são opcionais.',
      child: Column(
        children: [
          _FieldGrid(
            children: [
              _field(controller, InstitutionFormField.brandDisplayName, 'Nome de exibição'),
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  title: const Text('Logo simulada'),
                  value: controller.hasSimulatedLogo,
                  onChanged: controller.setSimulatedLogo,
                ),
              ),
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  title: const Text('Capa simulada'),
                  value: controller.hasSimulatedCover,
                  onChanged: controller.setSimulatedCover,
                ),
              ),
              _field(controller, InstitutionFormField.accentColor, 'Cor de destaque'),
              _field(controller, InstitutionFormField.secondaryColor, 'Cor secundária'),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space4),
          Container(
            key: const Key('institution-brand-preview'),
            width: double.infinity,
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(CoeloRadius.lg),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (controller.hasSimulatedCover) ...[
                  Container(
                    height: CoeloSize.touchMin,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(CoeloRadius.md),
                    ),
                  ),
                  const SizedBox(height: CoeloSpacing.space3),
                ],
                Row(
                  children: [
                    if (controller.hasSimulatedLogo)
                      CircleAvatar(
                        backgroundColor: accent.withValues(alpha: 0.18),
                        foregroundColor: colors.onSurface,
                        child: Text(_initials(controller.text(InstitutionFormField.publicName))),
                      ),
                    if (controller.hasSimulatedLogo) const SizedBox(width: CoeloSpacing.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.text(InstitutionFormField.brandDisplayName).isEmpty
                                ? controller.text(InstitutionFormField.publicName)
                                : controller.text(InstitutionFormField.brandDisplayName),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Text('Prévia institucional do Coelo'),
                        ],
                      ),
                    ),
                    _ColorSwatch(color: accent, label: 'Destaque'),
                    const SizedBox(width: CoeloSpacing.space2),
                    _ColorSwatch(color: secondary, label: 'Secundária'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cor $label',
      child: Tooltip(
        message: label,
        child: Container(
          width: CoeloSize.touchMin,
          height: CoeloSize.touchMin,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(CoeloRadius.md),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      ),
    );
  }
}

final class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.controller});
  final InstitutionFormController controller;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Revisão',
      description: 'Confira os dados antes de concluir. Você pode editar qualquer grupo.',
      child: Column(
        children: [
          _ReviewCard(
            editKey: const Key('institution-review-edit-profile'),
            title: 'Perfil',
            summary: controller.text(InstitutionFormField.publicName),
            onEdit: () => controller.selectStep(InstitutionFormStep.profile),
          ),
          _ReviewCard(
            editKey: const Key('institution-review-edit-location'),
            title: 'Localização e contato',
            summary:
                '${controller.text(InstitutionFormField.city)} / ${controller.text(InstitutionFormField.state)}',
            onEdit: () => controller.selectStep(InstitutionFormStep.location),
          ),
          _ReviewCard(
            editKey: const Key('institution-review-edit-owner'),
            title: 'Responsável',
            summary:
                '${controller.text(InstitutionFormField.ownerFirstName)} ${controller.text(InstitutionFormField.ownerLastName)}',
            onEdit: () => controller.selectStep(InstitutionFormStep.owner),
          ),
          _ReviewCard(
            editKey: const Key('institution-review-edit-plan'),
            title: 'Plano',
            summary: '${controller.plan.label} · ${controller.subscriptionStatus.label}',
            onEdit: () => controller.selectStep(InstitutionFormStep.plan),
          ),
          _ReviewCard(
            editKey: const Key('institution-review-edit-branding'),
            title: 'Identidade visual',
            summary: controller.text(InstitutionFormField.brandDisplayName).isEmpty
                ? 'Padrão Coelo'
                : controller.text(InstitutionFormField.brandDisplayName),
            onEdit: () => controller.selectStep(InstitutionFormStep.branding),
          ),
        ],
      ),
    );
  }
}

final class _Section extends StatelessWidget {
  const _Section({required this.title, required this.description, required this.child});
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey(title),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: CoeloSpacing.space1),
        Text(description, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: CoeloSpacing.space5),
        child,
      ],
    );
  }
}

final class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space3) / columns;
        return Wrap(
          spacing: CoeloSpacing.space3,
          runSpacing: CoeloSpacing.space4,
          children: [
            for (final child in children)
              SizedBox(
                width: columns > 1 && child is _WideField ? constraints.maxWidth : width,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

final class _WideField extends StatelessWidget {
  const _WideField({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

final class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.selected, required this.onPressed});
  final InstitutionPlan plan;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final resources = switch (plan) {
      InstitutionPlan.essential => 'Comunicação, agenda e rotina',
      InstitutionPlan.professional => 'Essencial + gestão ampliada',
      InstitutionPlan.complete => 'Todos os módulos do Coelo',
      InstitutionPlan.custom => 'Composição personalizada',
    };
    return Semantics(
      button: true,
      selected: selected,
      label: 'Plano ${plan.label}',
      child: OutlinedButton(
        key: Key('institution-plan-${plan.name}'),
        onPressed: onPressed,
        style:
            OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              minimumSize: const Size.fromHeight(104),
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
            ).copyWith(
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) =>
                    selected ||
                        states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused)
                    ? colors.primary
                    : colors.onSurface,
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) =>
                    selected ||
                        states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused)
                    ? colors.primaryContainer
                    : colors.surface,
              ),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: CoeloSpacing.space1),
            Text(resources),
          ],
        ),
      ),
    );
  }
}

final class _DateControl extends StatelessWidget {
  const _DateControl({
    required this.label,
    required this.value,
    required this.onChanged,
    this.errorText,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(2026, 7, 27),
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
        child: Text(value == null ? 'Selecionar data' : _date(value!)),
      ),
    );
  }
}

final class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.editKey,
    required this.title,
    required this.summary,
    required this.onEdit,
  });
  final Key editKey;
  final String title;
  final String summary;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: CoeloSpacing.space3),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(summary.isEmpty ? 'Não informado' : summary),
                ],
              ),
            ),
            TextButton(key: editKey, onPressed: onEdit, child: const Text('Editar')),
          ],
        ),
      ),
    );
  }
}

Widget _field(
  InstitutionFormController controller,
  InstitutionFormField field,
  String label, {
  bool wide = false,
  int maxLines = 1,
  TextInputType? inputType,
}) {
  final fieldWidget = TextFormField(
    key: Key('institution-field-${field.name}'),
    controller: controller.controllerOf(field),
    decoration: InputDecoration(
      labelText: label,
      errorText: controller.errorFor(field),
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    keyboardType: inputType,
    maxLines: maxLines,
    onChanged: (value) => controller.setText(field, value, userInitiated: true),
  );
  return wide ? _WideField(child: fieldWidget) : fieldWidget;
}

Widget _dropdown<T>({
  required String label,
  required T value,
  required List<T> values,
  required String Function(T value) labelOf,
  required ValueChanged<T> onChanged,
}) {
  return DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    items: [
      for (final option in values) DropdownMenuItem(value: option, child: Text(labelOf(option))),
    ],
    onChanged: (value) {
      if (value != null) {
        onChanged(value);
      }
    },
  );
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _initials(String value) {
  final words = value.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  if (words.isEmpty) {
    return 'CO';
  }
  return words.take(2).map((word) => word[0]).join().toUpperCase();
}

Color _hexColor(String value, {required Color fallback}) {
  if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
    return fallback;
  }
  return Color(int.parse(value.substring(1), radix: 16) | 0xFF000000);
}

List<InstitutionSubscriptionStatus> _subscriptionActions(InstitutionSubscriptionStatus current) =>
    switch (current) {
      InstitutionSubscriptionStatus.draft || InstitutionSubscriptionStatus.trial => const [
        InstitutionSubscriptionStatus.active,
        InstitutionSubscriptionStatus.canceled,
      ],
      InstitutionSubscriptionStatus.active => const [
        InstitutionSubscriptionStatus.paused,
        InstitutionSubscriptionStatus.suspended,
        InstitutionSubscriptionStatus.canceled,
      ],
      InstitutionSubscriptionStatus.paused || InstitutionSubscriptionStatus.suspended => const [
        InstitutionSubscriptionStatus.active,
        InstitutionSubscriptionStatus.canceled,
      ],
      InstitutionSubscriptionStatus.canceled => const [InstitutionSubscriptionStatus.active],
    };

String _subscriptionActionLabel(
  InstitutionSubscriptionStatus status, {
  required InstitutionSubscriptionStatus current,
}) => switch (status) {
  InstitutionSubscriptionStatus.active
      when current == InstitutionSubscriptionStatus.draft ||
          current == InstitutionSubscriptionStatus.trial =>
    'Ativar',
  InstitutionSubscriptionStatus.active => 'Reativar',
  InstitutionSubscriptionStatus.paused => 'Pausar',
  InstitutionSubscriptionStatus.suspended => 'Suspender',
  InstitutionSubscriptionStatus.canceled => 'Cancelar',
  InstitutionSubscriptionStatus.draft => 'Voltar para rascunho',
  InstitutionSubscriptionStatus.trial => 'Iniciar período de teste',
};
