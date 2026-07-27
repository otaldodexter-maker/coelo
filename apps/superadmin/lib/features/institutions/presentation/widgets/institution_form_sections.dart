import 'dart:ui' as ui;
import 'dart:convert';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../domain/institution_directory_item.dart';
import '../../domain/institution_record.dart';
import '../view_models/institution_form_controller.dart';
import 'institution_form_dialogs.dart';
import 'institution_logo_picker.dart';

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
          _field(
            controller,
            InstitutionFormField.postalCode,
            'CEP',
            suffixIcon: IconButton(
              tooltip: 'Buscar CEP',
              onPressed: () => _lookupPostalCode(context),
              icon: const Icon(Icons.travel_explore_rounded),
            ),
          ),
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

  Future<void> _lookupPostalCode(BuildContext context) async {
    final postalCode = controller
        .text(InstitutionFormField.postalCode)
        .replaceAll(RegExp(r'\D'), '');
    if (postalCode.length != 8) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe um CEP com 8 números.')));
      return;
    }
    try {
      final response = await http.get(Uri.https('viacep.com.br', '/ws/$postalCode/json/'));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || data['erro'] == true) {
        throw const FormatException();
      }
      controller
        ..setText(InstitutionFormField.country, 'Brasil')
        ..setText(InstitutionFormField.state, data['uf'] as String? ?? '')
        ..setText(InstitutionFormField.city, data['localidade'] as String? ?? '')
        ..setText(InstitutionFormField.district, data['bairro'] as String? ?? '')
        ..setText(InstitutionFormField.street, data['logradouro'] as String? ?? '');
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Não foi possível buscar este CEP.')));
      }
    }
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
          DecoratedBox(
            key: const Key('institution-owner-invitation-notice'),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(CoeloRadius.md),
              border: Border.all(color: colors.primary.withValues(alpha: 0.24)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              child: Text(
                'O convite e a ativação de acesso do responsável serão configurados em uma etapa futura.',
                style: TextStyle(color: colors.onPrimaryContainer),
              ),
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
    final confirmed = await showInstitutionSubscriptionDialog(
      context,
      title: 'Trocar para o plano ${value.label}?',
      message: 'A nova seleção será aplicada localmente ao salvar as alterações.',
    );
    if (!confirmed) {
      return;
    }
    controller.setPlan(value);
  }

  Future<void> _changeSubscription(
    BuildContext context,
    InstitutionSubscriptionStatus value,
  ) async {
    if (!controller.isEditing) {
      controller.setSubscriptionStatus(value);
      return;
    }
    final confirmed = await showInstitutionSubscriptionDialog(
      context,
      title:
          '${_subscriptionActionLabel(value, current: controller.subscriptionStatus)} assinatura?',
      message: 'Esta ação atualiza somente o protótipo local até o salvamento.',
    );
    if (!confirmed) {
      return;
    }
    controller.setSubscriptionStatus(value);
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
      description: 'Defina como a instituição será reconhecida no Coelo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LogoPicker(controller: controller, accent: accent),
          const SizedBox(height: CoeloSpacing.space5),
          _FieldGrid(
            children: [
              _field(
                controller,
                InstitutionFormField.brandDisplayName,
                'Nome de exibição',
                hint: 'Como a instituição aparece no Coelo',
              ),
              _field(
                controller,
                InstitutionFormField.slug,
                '@ da instituição',
                hint: 'instituicao',
              ),
              _ColorField(
                controller: controller,
                field: InstitutionFormField.accentColor,
                label: 'Cor principal',
              ),
              _ColorField(
                controller: controller,
                field: InstitutionFormField.secondaryColor,
                label: 'Cor secundária',
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space4),
          Container(
            key: const Key('institution-brand-preview'),
            width: double.infinity,
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            decoration: BoxDecoration(
              color: colors.surface,
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
                        backgroundImage: controller.logoBytes == null
                            ? null
                            : MemoryImage(controller.logoBytes!),
                        child: controller.logoBytes == null
                            ? Text(_initials(controller.text(InstitutionFormField.publicName)))
                            : null,
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

final class _LogoPicker extends StatelessWidget {
  const _LogoPicker({required this.controller, required this.accent});

  static const maxBytes = 2 * 1024 * 1024;
  final InstitutionFormController controller;
  final Color accent;

  Future<void> _pick(BuildContext context) async {
    final file = await pickInstitutionLogo();
    if (file == null || !context.mounted) {
      return;
    }
    if (file.bytes.lengthInBytes > maxBytes) {
      controller.setLogoError('A imagem deve ter no máximo 2 MB.');
      return;
    }
    try {
      final codec = await ui.instantiateImageCodec(file.bytes);
      final frame = await codec.getNextFrame();
      final square = frame.image.width == frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (!square) {
        controller.setLogoError('Escolha uma imagem quadrada para o recorte circular.');
        return;
      }
      controller.setLogo(bytes: file.bytes, fileName: file.name);
    } on Exception {
      controller.setLogoError('Não foi possível ler essa imagem.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Wrap(
        spacing: CoeloSpacing.space4,
        runSpacing: CoeloSpacing.space3,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          CircleAvatar(
            radius: CoeloSize.touchMin,
            backgroundColor: accent.withValues(alpha: 0.16),
            backgroundImage: controller.logoBytes == null
                ? null
                : MemoryImage(controller.logoBytes!),
            child: controller.logoBytes == null
                ? Icon(Icons.apartment_rounded, color: colors.primary, size: CoeloSize.iconLg)
                : null,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Foto de perfil', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: CoeloSpacing.spaceHalf),
                Text(
                  controller.logoFileName ?? 'Imagem quadrada em PNG, JPG ou WebP, com até 2 MB.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (controller.logoError != null) ...[
                  const SizedBox(height: CoeloSpacing.space1),
                  Text(
                    controller.logoError!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.error),
                  ),
                ],
                const SizedBox(height: CoeloSpacing.space2),
                Wrap(
                  spacing: CoeloSpacing.space2,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('institution-logo-picker'),
                      onPressed: () => _pick(context),
                      icon: const Icon(Icons.upload_rounded),
                      label: Text(controller.hasSimulatedLogo ? 'Trocar foto' : 'Escolher foto'),
                    ),
                    if (controller.hasSimulatedLogo)
                      TextButton(onPressed: controller.removeLogo, child: const Text('Remover')),
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

final class _ColorField extends StatelessWidget {
  const _ColorField({required this.controller, required this.field, required this.label});

  final InstitutionFormController controller;
  final InstitutionFormField field;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(
      controller.text(field),
      fallback: Theme.of(context).colorScheme.primary,
    );
    return CoeloFormTextField(
      controller: controller.controllerOf(field),
      fieldKey: Key('institution-field-${field.name}'),
      labelText: label,
      hintText: '#D63C00',
      prefixIcon: Icons.palette_outlined,
      errorText: controller.errorFor(field),
      onChanged: (value) => controller.setText(field, value, userInitiated: true),
      suffixIcon: IconButton(
        key: Key('institution-color-picker-${field.name}'),
        tooltip: 'Selecionar $label',
        onPressed: () async {
          final selected = await showDialog<Color>(
            context: context,
            builder: (context) => _ColorPickerDialog(initialColor: color, title: label),
          );
          if (selected != null) {
            controller.setText(
              field,
              '#${selected.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
            );
          }
        },
        icon: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: const SizedBox.square(dimension: CoeloSize.iconMd),
        ),
      ),
    );
  }
}

final class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initialColor, required this.title});

  final Color initialColor;
  final String title;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

final class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor color;
  late final TextEditingController hexController;

  @override
  void initState() {
    super.initState();
    color = HSVColor.fromColor(widget.initialColor);
    hexController = TextEditingController(text: _colorHex(color.toColor()));
  }

  @override
  void dispose() {
    hexController.dispose();
    super.dispose();
  }

  void _select(Offset position, Size size) {
    setState(() {
      color = color
          .withSaturation((position.dx / size.width).clamp(0, 1))
          .withValue((1 - position.dy / size.height).clamp(0, 1));
      hexController.text = _colorHex(color.toColor());
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = color.toColor();
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: Text(widget.title),
      content: SizedBox(
        width: 620,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final picker = _ColorVisualPicker(
              color: color,
              onSelect: _select,
              onHueChanged: (hue) => setState(() {
                color = color.withHue(hue);
                hexController.text = _colorHex(color.toColor());
              }),
            );
            final values = _ColorValues(
              color: color,
              original: widget.initialColor,
              hexController: hexController,
              onHexChanged: (value) {
                final parsed = _hexColor(value, fallback: color.toColor());
                if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
                  setState(() => color = HSVColor.fromColor(parsed));
                }
              },
            );
            return compact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      picker,
                      const SizedBox(height: CoeloSpacing.space4),
                      values,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: picker),
                      const SizedBox(width: CoeloSpacing.space5),
                      SizedBox(width: 180, child: values),
                    ],
                  );
          },
        ),
      ),
      actions: [
        OutlinedButton(onPressed: Navigator.of(context).pop, child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(selected),
          child: const Text('Usar cor'),
        ),
      ],
    );
  }
}

final class _ColorVisualPicker extends StatelessWidget {
  const _ColorVisualPicker({
    required this.color,
    required this.onSelect,
    required this.onHueChanged,
  });

  final HSVColor color;
  final void Function(Offset position, Size size) onSelect;
  final ValueChanged<double> onHueChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              onPanDown: (details) => onSelect(details.localPosition, constraints.biggest),
              onPanUpdate: (details) => onSelect(details.localPosition, constraints.biggest),
              child: CustomPaint(
                key: const Key('institution-color-area'),
                painter: _ColorAreaPainter(hue: color.hue, color: color),
              ),
            ),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        SizedBox(
          height: CoeloSpacing.space6,
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              onTapDown: (details) => onHueChanged(
                (details.localPosition.dx / constraints.maxWidth * 360).clamp(0, 360),
              ),
              onHorizontalDragUpdate: (details) => onHueChanged(
                (details.localPosition.dx / constraints.maxWidth * 360).clamp(0, 360),
              ),
              child: CustomPaint(
                painter: _HueBarPainter(hue: color.hue),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _ColorValues extends StatelessWidget {
  const _ColorValues({
    required this.color,
    required this.original,
    required this.hexController,
    required this.onHexChanged,
  });

  final HSVColor color;
  final Color original;
  final TextEditingController hexController;
  final ValueChanged<String> onHexChanged;

  @override
  Widget build(BuildContext context) {
    final selected = color.toColor();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _ColorPreview(label: 'Nova', color: selected),
            ),
            const SizedBox(width: CoeloSpacing.space2),
            Expanded(
              child: _ColorPreview(label: 'Atual', color: original),
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _ColorValue(label: 'H', value: '${color.hue.round()}°'),
        _ColorValue(label: 'S', value: '${(color.saturation * 100).round()}%'),
        _ColorValue(label: 'V', value: '${(color.value * 100).round()}%'),
        const Divider(height: CoeloSpacing.space5),
        _ColorValue(label: 'R', value: '${(selected.r * 255).round()}'),
        _ColorValue(label: 'G', value: '${(selected.g * 255).round()}'),
        _ColorValue(label: 'B', value: '${(selected.b * 255).round()}'),
        const SizedBox(height: CoeloSpacing.space3),
        TextField(
          key: const Key('institution-color-hex'),
          controller: hexController,
          decoration: const InputDecoration(
            labelText: 'Hexadecimal',
            prefixIcon: Icon(Icons.tag_rounded),
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          onChanged: onHexChanged,
        ),
      ],
    );
  }
}

final class _ColorPreview extends StatelessWidget {
  const _ColorPreview({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        height: CoeloSize.touchMin,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(CoeloRadius.sm),
        ),
      ),
      const SizedBox(height: CoeloSpacing.space1),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

final class _ColorValue extends StatelessWidget {
  const _ColorValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space1),
    child: Row(
      children: [
        SizedBox(width: CoeloSpacing.space6, child: Text(label)),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CoeloSpacing.space2,
              vertical: CoeloSpacing.space1,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(CoeloRadius.xs),
            ),
            child: Text(value),
          ),
        ),
      ],
    ),
  );
}

String _colorHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

final class _HueBarPainter extends CustomPainter {
  const _HueBarPainter({required this.hue});
  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(CoeloRadius.full)),
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFF0000),
            Color(0xFFFFFF00),
            Color(0xFF00FF00),
            Color(0xFF00FFFF),
            Color(0xFF0000FF),
            Color(0xFFFF00FF),
            Color(0xFFFF0000),
          ],
        ).createShader(rect),
    );
    final x = hue / 360 * size.width;
    canvas.drawCircle(
      Offset(x, size.height / 2),
      size.height / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_HueBarPainter oldDelegate) => oldDelegate.hue != hue;
}

final class _ColorAreaPainter extends CustomPainter {
  const _ColorAreaPainter({required this.hue, required this.color});
  final double hue;
  final HSVColor color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, HSVColor.fromAHSV(1, hue, 1, 1).toColor()],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
    final marker = Offset(color.saturation * size.width, (1 - color.value) * size.height);
    canvas.drawCircle(marker, 7, Paint()..color = Colors.white);
    canvas.drawCircle(
      marker,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(_ColorAreaPainter oldDelegate) =>
      oldDelegate.hue != hue || oldDelegate.color != color;
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
  String? hint,
  String? prefixText,
  Widget? suffixIcon,
}) {
  final fieldWidget = CoeloFormTextField(
    controller: controller.controllerOf(field),
    fieldKey: Key('institution-field-${field.name}'),
    labelText: label,
    hintText: hint,
    prefixText: prefixText,
    prefixIcon: _iconFor(field),
    suffixIcon: suffixIcon,
    keyboardType: inputType,
    maxLines: maxLines,
    errorText: controller.errorFor(field),
    onChanged: (value) => controller.setText(field, value, userInitiated: true),
  );
  return wide ? _WideField(child: fieldWidget) : fieldWidget;
}

IconData _iconFor(InstitutionFormField field) => switch (field) {
  InstitutionFormField.publicName ||
  InstitutionFormField.tradeName ||
  InstitutionFormField.legalName ||
  InstitutionFormField.brandDisplayName => Icons.apartment_rounded,
  InstitutionFormField.typeName || InstitutionFormField.documentType => Icons.category_outlined,
  InstitutionFormField.document => Icons.badge_outlined,
  InstitutionFormField.slug => Icons.alternate_email_rounded,
  InstitutionFormField.primaryDomain => Icons.language_rounded,
  InstitutionFormField.locale => Icons.translate_rounded,
  InstitutionFormField.timezone => Icons.schedule_rounded,
  InstitutionFormField.postalCode => Icons.markunread_mailbox_outlined,
  InstitutionFormField.country => Icons.public_rounded,
  InstitutionFormField.state => Icons.map_outlined,
  InstitutionFormField.city => Icons.location_city_rounded,
  InstitutionFormField.district => Icons.holiday_village_outlined,
  InstitutionFormField.street => Icons.route_outlined,
  InstitutionFormField.addressNumber => Icons.pin_outlined,
  InstitutionFormField.complement => Icons.add_home_work_outlined,
  InstitutionFormField.contactEmail ||
  InstitutionFormField.ownerEmail => Icons.mail_outline_rounded,
  InstitutionFormField.contactPhone ||
  InstitutionFormField.contactMobilePhone ||
  InstitutionFormField.ownerMobilePhone => Icons.phone_outlined,
  InstitutionFormField.ownerFirstName ||
  InstitutionFormField.ownerLastName ||
  InstitutionFormField.ownerDisplayName => Icons.person_outline_rounded,
  InstitutionFormField.subscriptionJustification => Icons.notes_rounded,
  InstitutionFormField.accentColor || InstitutionFormField.secondaryColor => Icons.palette_outlined,
};

Widget _dropdown<T>({
  required String label,
  required T value,
  required List<T> values,
  required String Function(T value) labelOf,
  required ValueChanged<T> onChanged,
}) {
  return CoeloAdminSingleSelectField<T>(
    label: label,
    value: value,
    options: values,
    optionLabel: labelOf,
    onChanged: onChanged,
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
