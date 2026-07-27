import 'package:flutter/material.dart';

import '../../domain/institution_directory_item.dart';
import '../../domain/institution_record.dart';

enum InstitutionFormStep {
  profile('Perfil da instituição'),
  location('Localização e contato'),
  owner('Responsável inicial'),
  plan('Plano'),
  branding('Identidade visual'),
  review('Revisão');

  const InstitutionFormStep(this.label);
  final String label;
}

enum InstitutionFormStepStatus { current, complete, incomplete, error }

enum InstitutionFormField {
  publicName,
  tradeName,
  legalName,
  typeName,
  documentType,
  document,
  slug,
  primaryDomain,
  locale,
  timezone,
  postalCode,
  country,
  state,
  city,
  district,
  street,
  addressNumber,
  complement,
  contactEmail,
  contactPhone,
  contactMobilePhone,
  ownerFirstName,
  ownerLastName,
  ownerDisplayName,
  ownerEmail,
  ownerMobilePhone,
  subscriptionJustification,
  brandDisplayName,
  accentColor,
  secondaryColor,
}

final class InstitutionFormController extends ChangeNotifier {
  InstitutionFormController({InstitutionRecord? record})
    : original = record,
      status = record?.status ?? InstitutionStatus.draft,
      plan = record?.plan ?? InstitutionPlan.essential,
      subscriptionStatus = record?.subscriptionStatus ?? InstitutionSubscriptionStatus.draft,
      subscriptionStart = record?.subscriptionStart ?? DateTime(2026, 7, 27),
      trialEnd = record?.trialEnd,
      hasSimulatedLogo = record?.hasSimulatedLogo ?? false,
      hasSimulatedCover = record?.hasSimulatedCover ?? false {
    final values = _valuesFrom(record);
    for (final field in InstitutionFormField.values) {
      _controllers[field] = TextEditingController(text: values[field] ?? '');
    }
    _initialSignature = _signature;
  }

  final InstitutionRecord? original;
  final Map<InstitutionFormField, TextEditingController> _controllers = {};
  final Set<InstitutionFormStep> _attemptedSteps = {};
  late final String _initialSignature;
  bool _slugManuallyEdited = false;

  InstitutionFormStep currentStep = InstitutionFormStep.profile;
  InstitutionStatus status;
  InstitutionPlan plan;
  InstitutionSubscriptionStatus subscriptionStatus;
  DateTime subscriptionStart;
  DateTime? trialEnd;
  bool hasSimulatedLogo;
  bool hasSimulatedCover;
  bool isSaving = false;

  bool get isEditing => original != null;
  bool get isDirty => _signature != _initialSignature;

  TextEditingController controllerOf(InstitutionFormField field) => _controllers[field]!;
  String text(InstitutionFormField field) => controllerOf(field).text.trim();

  void setText(InstitutionFormField field, String value, {bool userInitiated = false}) {
    if (field == InstitutionFormField.slug && userInitiated) {
      _slugManuallyEdited = true;
    }
    final controller = controllerOf(field);
    if (controller.text != value) {
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    if (field == InstitutionFormField.publicName && !_slugManuallyEdited) {
      final slug = _slugify(value);
      final slugController = controllerOf(InstitutionFormField.slug);
      slugController.value = TextEditingValue(
        text: slug,
        selection: TextSelection.collapsed(offset: slug.length),
      );
    }
    notifyListeners();
  }

  void selectStep(InstitutionFormStep step) {
    currentStep = step;
    notifyListeners();
  }

  void continueFromCurrentStep() {
    _attemptedSteps.add(currentStep);
    final next = currentStep.index + 1;
    if (next < InstitutionFormStep.values.length) {
      currentStep = InstitutionFormStep.values[next];
    }
    notifyListeners();
  }

  void previousStep() {
    final previous = currentStep.index - 1;
    if (previous >= 0) {
      currentStep = InstitutionFormStep.values[previous];
      notifyListeners();
    }
  }

  void setStatus(InstitutionStatus value) {
    status = value;
    notifyListeners();
  }

  void setPlan(InstitutionPlan value) {
    plan = value;
    notifyListeners();
  }

  void setSubscriptionStatus(InstitutionSubscriptionStatus value) {
    subscriptionStatus = value;
    notifyListeners();
  }

  void setSubscriptionStart(DateTime value) {
    subscriptionStart = value;
    notifyListeners();
  }

  void setTrialEnd(DateTime? value) {
    trialEnd = value;
    notifyListeners();
  }

  void setSimulatedLogo(bool value) {
    hasSimulatedLogo = value;
    notifyListeners();
  }

  void setSimulatedCover(bool value) {
    hasSimulatedCover = value;
    notifyListeners();
  }

  void setSaving(bool value) {
    isSaving = value;
    notifyListeners();
  }

  bool validateAll() {
    _attemptedSteps.addAll(InstitutionFormStep.values.take(5));
    final invalid = InstitutionFormStep.values.take(5).where((step) => !_isStepValid(step));
    if (invalid.isNotEmpty) {
      currentStep = invalid.first;
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  InstitutionFormStepStatus statusOf(InstitutionFormStep step) {
    if (step == currentStep) {
      return InstitutionFormStepStatus.current;
    }
    if (_isStepValid(step)) {
      return InstitutionFormStepStatus.complete;
    }
    return _attemptedSteps.contains(step)
        ? InstitutionFormStepStatus.error
        : InstitutionFormStepStatus.incomplete;
  }

  String? errorFor(InstitutionFormField field) {
    final step = _stepFor(field);
    if (!_attemptedSteps.contains(step)) {
      return null;
    }
    final value = text(field);
    if (_requiredFields.contains(field) && value.isEmpty) {
      return 'Preencha este campo para concluir o cadastro.';
    }
    if ({InstitutionFormField.contactEmail, InstitutionFormField.ownerEmail}.contains(field) &&
        value.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      return 'Informe um e-mail válido, como nome@dominio.com.';
    }
    if ({InstitutionFormField.accentColor, InstitutionFormField.secondaryColor}.contains(field) &&
        value.isNotEmpty &&
        !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
      return 'Use uma cor hexadecimal no formato #RRGGBB.';
    }
    if (field == InstitutionFormField.contactMobilePhone &&
        text(InstitutionFormField.contactPhone).isEmpty &&
        value.isEmpty) {
      return 'Informe pelo menos um telefone ou celular institucional.';
    }
    if (field == InstitutionFormField.subscriptionJustification &&
        _requiresJustification &&
        value.isEmpty) {
      return 'Explique o motivo desta alteração de assinatura.';
    }
    return null;
  }

  String? get trialEndError {
    if (!_attemptedSteps.contains(InstitutionFormStep.plan) ||
        subscriptionStatus != InstitutionSubscriptionStatus.trial ||
        trialEnd != null) {
      return null;
    }
    return 'Selecione quando o período de teste termina.';
  }

  InstitutionRecord toRecord({required String id}) {
    final units =
        original?.units ??
        [
          InstitutionUnit(
            id: '$id-unit-01',
            name: 'Unidade principal',
            groups: [InstitutionGroup(id: '$id-unit-01-group-01', name: 'Turma 01')],
          ),
        ];
    return InstitutionRecord(
      id: id,
      publicName: text(InstitutionFormField.publicName),
      tradeName: text(InstitutionFormField.tradeName),
      legalName: text(InstitutionFormField.legalName),
      typeId: 'local-type-${_slugify(text(InstitutionFormField.typeName))}',
      typeName: text(InstitutionFormField.typeName),
      documentType: text(InstitutionFormField.documentType),
      document: text(InstitutionFormField.document),
      slug: text(InstitutionFormField.slug),
      primaryDomain: text(InstitutionFormField.primaryDomain),
      status: status,
      locale: text(InstitutionFormField.locale),
      timezone: text(InstitutionFormField.timezone),
      postalCode: text(InstitutionFormField.postalCode),
      country: text(InstitutionFormField.country),
      state: text(InstitutionFormField.state),
      city: text(InstitutionFormField.city),
      district: text(InstitutionFormField.district),
      street: text(InstitutionFormField.street),
      addressNumber: text(InstitutionFormField.addressNumber),
      complement: text(InstitutionFormField.complement),
      contactEmail: text(InstitutionFormField.contactEmail),
      contactPhone: text(InstitutionFormField.contactPhone),
      contactMobilePhone: text(InstitutionFormField.contactMobilePhone),
      ownerFirstName: text(InstitutionFormField.ownerFirstName),
      ownerLastName: text(InstitutionFormField.ownerLastName),
      ownerDisplayName: text(InstitutionFormField.ownerDisplayName),
      ownerEmail: text(InstitutionFormField.ownerEmail),
      ownerMobilePhone: text(InstitutionFormField.ownerMobilePhone),
      plan: plan,
      subscriptionStatus: subscriptionStatus,
      subscriptionStart: subscriptionStart,
      trialEnd: trialEnd,
      subscriptionJustification: text(InstitutionFormField.subscriptionJustification),
      brandDisplayName: text(InstitutionFormField.brandDisplayName),
      hasSimulatedLogo: hasSimulatedLogo,
      hasSimulatedCover: hasSimulatedCover,
      accentColor: text(InstitutionFormField.accentColor),
      secondaryColor: text(InstitutionFormField.secondaryColor),
      units: units,
    );
  }

  bool _isStepValid(InstitutionFormStep step) {
    if (step == InstitutionFormStep.review) {
      return InstitutionFormStep.values.take(5).every(_isStepValid);
    }
    if (step == InstitutionFormStep.plan &&
        subscriptionStatus == InstitutionSubscriptionStatus.trial &&
        trialEnd == null) {
      return false;
    }
    final fields = InstitutionFormField.values.where((field) => _stepFor(field) == step);
    return fields.every((field) => errorForForced(field) == null);
  }

  String? errorForForced(InstitutionFormField field) {
    final wasAttempted = _attemptedSteps.contains(_stepFor(field));
    _attemptedSteps.add(_stepFor(field));
    final error = errorFor(field);
    if (!wasAttempted) {
      _attemptedSteps.remove(_stepFor(field));
    }
    return error;
  }

  bool get _requiresJustification => {
    InstitutionSubscriptionStatus.paused,
    InstitutionSubscriptionStatus.suspended,
    InstitutionSubscriptionStatus.canceled,
  }.contains(subscriptionStatus);

  String get _signature => [
    for (final field in InstitutionFormField.values) text(field),
    status.name,
    plan.name,
    subscriptionStatus.name,
    subscriptionStart.toIso8601String(),
    trialEnd?.toIso8601String() ?? '',
    '$hasSimulatedLogo',
    '$hasSimulatedCover',
  ].join('|');

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

const _requiredFields = {
  InstitutionFormField.publicName,
  InstitutionFormField.legalName,
  InstitutionFormField.typeName,
  InstitutionFormField.documentType,
  InstitutionFormField.document,
  InstitutionFormField.slug,
  InstitutionFormField.locale,
  InstitutionFormField.timezone,
  InstitutionFormField.postalCode,
  InstitutionFormField.country,
  InstitutionFormField.state,
  InstitutionFormField.city,
  InstitutionFormField.street,
  InstitutionFormField.addressNumber,
  InstitutionFormField.contactEmail,
  InstitutionFormField.ownerFirstName,
  InstitutionFormField.ownerLastName,
  InstitutionFormField.ownerEmail,
  InstitutionFormField.ownerMobilePhone,
};

InstitutionFormStep _stepFor(InstitutionFormField field) => switch (field) {
  InstitutionFormField.publicName ||
  InstitutionFormField.tradeName ||
  InstitutionFormField.legalName ||
  InstitutionFormField.typeName ||
  InstitutionFormField.documentType ||
  InstitutionFormField.document ||
  InstitutionFormField.slug ||
  InstitutionFormField.primaryDomain ||
  InstitutionFormField.locale ||
  InstitutionFormField.timezone => InstitutionFormStep.profile,
  InstitutionFormField.postalCode ||
  InstitutionFormField.country ||
  InstitutionFormField.state ||
  InstitutionFormField.city ||
  InstitutionFormField.district ||
  InstitutionFormField.street ||
  InstitutionFormField.addressNumber ||
  InstitutionFormField.complement ||
  InstitutionFormField.contactEmail ||
  InstitutionFormField.contactPhone ||
  InstitutionFormField.contactMobilePhone => InstitutionFormStep.location,
  InstitutionFormField.ownerFirstName ||
  InstitutionFormField.ownerLastName ||
  InstitutionFormField.ownerDisplayName ||
  InstitutionFormField.ownerEmail ||
  InstitutionFormField.ownerMobilePhone => InstitutionFormStep.owner,
  InstitutionFormField.subscriptionJustification => InstitutionFormStep.plan,
  InstitutionFormField.brandDisplayName ||
  InstitutionFormField.accentColor ||
  InstitutionFormField.secondaryColor => InstitutionFormStep.branding,
};

Map<InstitutionFormField, String> _valuesFrom(InstitutionRecord? record) => {
  InstitutionFormField.publicName: record?.publicName ?? '',
  InstitutionFormField.tradeName: record?.tradeName ?? '',
  InstitutionFormField.legalName: record?.legalName ?? '',
  InstitutionFormField.typeName: record?.typeName ?? '',
  InstitutionFormField.documentType: record?.documentType ?? 'CNPJ',
  InstitutionFormField.document: record?.document ?? '',
  InstitutionFormField.slug: record?.slug ?? '',
  InstitutionFormField.primaryDomain: record?.primaryDomain ?? '',
  InstitutionFormField.locale: record?.locale ?? 'pt-BR',
  InstitutionFormField.timezone: record?.timezone ?? 'America/Sao_Paulo',
  InstitutionFormField.postalCode: record?.postalCode ?? '',
  InstitutionFormField.country: record?.country ?? 'Brasil',
  InstitutionFormField.state: record?.state ?? '',
  InstitutionFormField.city: record?.city ?? '',
  InstitutionFormField.district: record?.district ?? '',
  InstitutionFormField.street: record?.street ?? '',
  InstitutionFormField.addressNumber: record?.addressNumber ?? '',
  InstitutionFormField.complement: record?.complement ?? '',
  InstitutionFormField.contactEmail: record?.contactEmail ?? '',
  InstitutionFormField.contactPhone: record?.contactPhone ?? '',
  InstitutionFormField.contactMobilePhone: record?.contactMobilePhone ?? '',
  InstitutionFormField.ownerFirstName: record?.ownerFirstName ?? '',
  InstitutionFormField.ownerLastName: record?.ownerLastName ?? '',
  InstitutionFormField.ownerDisplayName: record?.ownerDisplayName ?? '',
  InstitutionFormField.ownerEmail: record?.ownerEmail ?? '',
  InstitutionFormField.ownerMobilePhone: record?.ownerMobilePhone ?? '',
  InstitutionFormField.subscriptionJustification: record?.subscriptionJustification ?? '',
  InstitutionFormField.brandDisplayName: record?.brandDisplayName ?? '',
  InstitutionFormField.accentColor: record?.accentColor ?? '#D63C00',
  InstitutionFormField.secondaryColor: record?.secondaryColor ?? '#3F4549',
};

String _slugify(String value) {
  var normalized = value.toLowerCase();
  const replacements = {
    'á': 'a',
    'à': 'a',
    'ã': 'a',
    'â': 'a',
    'é': 'e',
    'ê': 'e',
    'í': 'i',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ç': 'c',
  };
  for (final entry in replacements.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
}
