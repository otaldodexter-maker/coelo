import 'package:flutter/material.dart';
import 'dart:typed_data';

import '../../domain/institution_directory_item.dart';
import '../../domain/institution_record.dart';

enum InstitutionFormStep {
  branding('Identidade visual'),
  profile('Perfil da instituição'),
  location('Localização e contato'),
  legalRepresentatives('Representantes legais'),
  administrators('Administradores'),
  plan('Plano'),
  review('Revisão');

  const InstitutionFormStep(this.label);
  final String label;
}

enum InstitutionFormStepStatus { current, complete, incomplete, error }

enum InstitutionAdministratorLevel {
  adminMaster('Admin Master'),
  authorizedAdministrator('Administrador autorizado'),
  coordinator('Coordenador');

  const InstitutionAdministratorLevel(this.label);
  final String label;
}

enum InstitutionInvitationStatus {
  notSent('Não enviado'),
  sent('Enviado'),
  accepted('Aceito'),
  expired('Expirado');

  const InstitutionInvitationStatus(this.label);
  final String label;
}

final class InstitutionPersonDraft {
  const InstitutionPersonDraft({
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.email,
    required this.mobilePhone,
  });

  final String firstName;
  final String lastName;
  final String displayName;
  final String email;
  final String mobilePhone;

  InstitutionPersonDraft copyWith({
    String? firstName,
    String? lastName,
    String? displayName,
    String? email,
    String? mobilePhone,
  }) => InstitutionPersonDraft(
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    displayName: displayName ?? this.displayName,
    email: email ?? this.email,
    mobilePhone: mobilePhone ?? this.mobilePhone,
  );
}

final class InstitutionLegalRepresentative {
  const InstitutionLegalRepresentative({required this.id, required this.person});

  final String id;
  final InstitutionPersonDraft person;
}

final class InstitutionInvitationHistoryEntry {
  const InstitutionInvitationHistoryEntry({required this.status, required this.occurredAt});

  final InstitutionInvitationStatus status;
  final DateTime occurredAt;
}

final class InstitutionAdministratorDraft {
  const InstitutionAdministratorDraft({
    required this.id,
    required this.person,
    required this.level,
    required this.invitationStatus,
    required this.invitationHistory,
    this.sourceRepresentativeId,
  });

  final String id;
  final InstitutionPersonDraft person;
  final InstitutionAdministratorLevel level;
  final InstitutionInvitationStatus invitationStatus;
  final List<InstitutionInvitationHistoryEntry> invitationHistory;
  final String? sourceRepresentativeId;

  InstitutionAdministratorDraft copyWith({
    InstitutionPersonDraft? person,
    InstitutionAdministratorLevel? level,
    InstitutionInvitationStatus? invitationStatus,
    List<InstitutionInvitationHistoryEntry>? invitationHistory,
  }) => InstitutionAdministratorDraft(
    id: id,
    person: person ?? this.person,
    level: level ?? this.level,
    invitationStatus: invitationStatus ?? this.invitationStatus,
    invitationHistory: invitationHistory ?? this.invitationHistory,
    sourceRepresentativeId: sourceRepresentativeId,
  );
}

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
  whatsappNumber,
  websiteUrl,
  ownerFirstName,
  ownerLastName,
  ownerDisplayName,
  ownerEmail,
  ownerMobilePhone,
  subscriptionJustification,
  brandDisplayName,
  profileBio,
  link1Label,
  link1Url,
  link2Label,
  link2Url,
  link3Label,
  link3Url,
  accentColor,
  secondaryColor,
  tertiaryColor,
  textColor,
  secondaryTextColor,
  tertiaryTextColor,
  surfaceColor,
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
    final legacyRepresentative = _legacyRepresentative(record);
    if (legacyRepresentative != null) {
      _legalRepresentatives.add(legacyRepresentative);
    }
    _initialSignature = _signature;
  }

  final InstitutionRecord? original;
  final Map<InstitutionFormField, TextEditingController> _controllers = {};
  final Set<InstitutionFormStep> _attemptedSteps = {};
  final List<InstitutionLegalRepresentative> _legalRepresentatives = [];
  final List<InstitutionAdministratorDraft> _administrators = [];
  late String _initialSignature;
  bool _slugManuallyEdited = false;
  var _personSequence = 0;

  InstitutionFormStep currentStep = InstitutionFormStep.branding;
  InstitutionStatus status;
  InstitutionPlan plan;
  InstitutionSubscriptionStatus subscriptionStatus;
  DateTime subscriptionStart;
  DateTime? trialEnd;
  bool hasSimulatedLogo;
  bool hasSimulatedCover;
  bool isSaving = false;
  Uint8List? logoBytes;
  String? logoFileName;
  String? logoError;
  Uint8List? coverBytes;
  String? coverFileName;
  String? coverError;

  bool get isEditing => original != null;
  bool get isDirty => _signature != _initialSignature;
  List<InstitutionLegalRepresentative> get legalRepresentatives =>
      List.unmodifiable(_legalRepresentatives);
  List<InstitutionAdministratorDraft> get administrators => List.unmodifiable(_administrators);
  Set<String> get recommendedAdministratorRepresentativeIds => {
    for (final representative in _legalRepresentatives)
      if (!_administrators.any(
        (administrator) => administrator.sourceRepresentativeId == representative.id,
      ))
        representative.id,
  };
  String? get legalRepresentativesError =>
      _attemptedSteps.contains(InstitutionFormStep.legalRepresentatives) &&
          !isEditing &&
          _legalRepresentatives.isEmpty
      ? 'Adicione pelo menos um representante legal para concluir o cadastro.'
      : null;

  TextEditingController controllerOf(InstitutionFormField field) => _controllers[field]!;
  String text(InstitutionFormField field) => controllerOf(field).text.trim();

  void setText(InstitutionFormField field, String value, {bool userInitiated = false}) {
    if (field == InstitutionFormField.profileBio && value.length > 220) {
      value = value.substring(0, 220);
    }
    if (field == InstitutionFormField.postalCode && userInitiated) {
      value = value.replaceAll(RegExp(r'\D'), '');
      if (value.length > 8) {
        value = value.substring(0, 8);
      }
    }
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
    if (value == InstitutionSubscriptionStatus.trial &&
        subscriptionStatus != InstitutionSubscriptionStatus.trial) {
      final now = DateTime.now();
      subscriptionStart = DateTime(now.year, now.month, now.day);
      trialEnd = subscriptionStart.add(const Duration(days: 30));
    }
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

  void setLogo({required Uint8List bytes, required String fileName}) {
    logoBytes = bytes;
    logoFileName = fileName;
    logoError = null;
    hasSimulatedLogo = true;
    notifyListeners();
  }

  void setLogoError(String value) {
    logoError = value;
    notifyListeners();
  }

  void removeLogo() {
    logoBytes = null;
    logoFileName = null;
    logoError = null;
    hasSimulatedLogo = false;
    notifyListeners();
  }

  void setSimulatedCover(bool value) {
    hasSimulatedCover = value;
    notifyListeners();
  }

  void setCover({required Uint8List bytes, required String fileName}) {
    coverBytes = bytes;
    coverFileName = fileName;
    coverError = null;
    hasSimulatedCover = true;
    notifyListeners();
  }

  void setCoverError(String value) {
    coverError = value;
    notifyListeners();
  }

  void removeCover() {
    coverBytes = null;
    coverFileName = null;
    coverError = null;
    hasSimulatedCover = false;
    notifyListeners();
  }

  void setSaving(bool value) {
    isSaving = value;
    notifyListeners();
  }

  void addLegalRepresentative(InstitutionPersonDraft person) {
    _legalRepresentatives.add(
      InstitutionLegalRepresentative(id: _nextPersonId('representative'), person: person),
    );
    notifyListeners();
  }

  void updateLegalRepresentative(String id, InstitutionPersonDraft person) {
    final index = _legalRepresentatives.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _legalRepresentatives[index] = InstitutionLegalRepresentative(id: id, person: person);
    notifyListeners();
  }

  void removeLegalRepresentative(String id) {
    _legalRepresentatives.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void confirmRepresentativeAdministrators(Set<String> representativeIds) {
    for (final representative in _legalRepresentatives.where(
      (item) => representativeIds.contains(item.id),
    )) {
      if (_administrators.any((item) => item.sourceRepresentativeId == representative.id)) {
        continue;
      }
      _administrators.add(
        InstitutionAdministratorDraft(
          id: _nextPersonId('administrator'),
          person: representative.person,
          level: InstitutionAdministratorLevel.adminMaster,
          invitationStatus: InstitutionInvitationStatus.notSent,
          invitationHistory: const [],
          sourceRepresentativeId: representative.id,
        ),
      );
    }
    notifyListeners();
  }

  void addAdministrator(
    InstitutionPersonDraft person, {
    required InstitutionAdministratorLevel level,
  }) {
    _administrators.add(
      InstitutionAdministratorDraft(
        id: _nextPersonId('administrator'),
        person: person,
        level: level,
        invitationStatus: InstitutionInvitationStatus.notSent,
        invitationHistory: const [],
      ),
    );
    notifyListeners();
  }

  void updateAdministrator(
    String id, {
    required InstitutionPersonDraft person,
    required InstitutionAdministratorLevel level,
  }) {
    final index = _administrators.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _administrators[index] = _administrators[index].copyWith(person: person, level: level);
    notifyListeners();
  }

  void removeAdministrator(String id) {
    _administrators.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void sendAdministratorInvitation(String id) {
    final index = _administrators.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final administrator = _administrators[index];
    final history = [
      ...administrator.invitationHistory,
      InstitutionInvitationHistoryEntry(
        status: InstitutionInvitationStatus.sent,
        occurredAt: DateTime.now(),
      ),
    ];
    _administrators[index] = administrator.copyWith(
      invitationStatus: InstitutionInvitationStatus.sent,
      invitationHistory: history,
    );
    notifyListeners();
  }

  void markSaved() {
    _initialSignature = _signature;
    notifyListeners();
  }

  bool validateCurrentStep() {
    _attemptedSteps.add(currentStep);
    final valid = _isStepValid(currentStep);
    notifyListeners();
    return valid;
  }

  bool validateAll() {
    _attemptedSteps.addAll(_stepsBeforeReview);
    final invalid = _stepsBeforeReview.where((step) => !_isStepValid(step));
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
    if (field == InstitutionFormField.postalCode && !RegExp(r'^\d{8}$').hasMatch(value)) {
      return 'Informe um CEP com exatamente 8 dígitos.';
    }
    if ({InstitutionFormField.contactEmail, InstitutionFormField.ownerEmail}.contains(field) &&
        value.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      return 'Informe um e-mail válido, como nome@dominio.com.';
    }
    if (_colorFields.contains(field) &&
        value.isNotEmpty &&
        !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
      return 'Use uma cor hexadecimal no formato #RRGGBB.';
    }
    if (_urlFields.contains(field) && value.isNotEmpty && !_isWebUrl(value)) {
      return 'Informe uma URL completa iniciada por http:// ou https://.';
    }
    final pairedField = _pairedLinkField[field];
    if (pairedField != null && value.isEmpty && text(pairedField).isNotEmpty) {
      return field.name.endsWith('Label')
          ? 'Informe um rótulo para este link.'
          : 'Informe a URL deste link.';
    }
    if (field == InstitutionFormField.contactPhone &&
        value.isEmpty &&
        text(InstitutionFormField.whatsappNumber).isEmpty) {
      return 'Informe pelo menos um telefone ou WhatsApp institucional.';
    }
    return null;
  }

  String? get trialEndError {
    if (!_attemptedSteps.contains(InstitutionFormStep.plan) ||
        subscriptionStatus != InstitutionSubscriptionStatus.trial) {
      return null;
    }
    final end = trialEnd;
    if (end == null) {
      return 'Selecione quando o período de teste termina.';
    }
    if (end.isBefore(subscriptionStart)) {
      return 'A data final não pode ser anterior à data de início.';
    }
    return null;
  }

  InstitutionRecord toRecord({required String id}) {
    final primaryRepresentative = _legalRepresentatives.firstOrNull?.person;
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
      whatsappNumber: text(InstitutionFormField.whatsappNumber),
      websiteUrl: text(InstitutionFormField.websiteUrl),
      ownerFirstName: primaryRepresentative?.firstName ?? text(InstitutionFormField.ownerFirstName),
      ownerLastName: primaryRepresentative?.lastName ?? text(InstitutionFormField.ownerLastName),
      ownerDisplayName:
          primaryRepresentative?.displayName ?? text(InstitutionFormField.ownerDisplayName),
      ownerEmail: primaryRepresentative?.email ?? text(InstitutionFormField.ownerEmail),
      ownerMobilePhone:
          primaryRepresentative?.mobilePhone ?? text(InstitutionFormField.ownerMobilePhone),
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
      tertiaryColor: text(InstitutionFormField.tertiaryColor),
      textColor: text(InstitutionFormField.textColor),
      secondaryTextColor: text(InstitutionFormField.secondaryTextColor),
      tertiaryTextColor: text(InstitutionFormField.tertiaryTextColor),
      surfaceColor: text(InstitutionFormField.surfaceColor),
      profileBio: text(InstitutionFormField.profileBio),
      profileLinks: [
        for (final pair in _linkFieldPairs)
          if (text(pair.$1).isNotEmpty || text(pair.$2).isNotEmpty)
            InstitutionProfileLink(label: text(pair.$1), url: text(pair.$2)),
      ],
      units: units,
    );
  }

  bool _isStepValid(InstitutionFormStep step) {
    if (step == InstitutionFormStep.review) {
      return _stepsBeforeReview.every(_isStepValid);
    }
    if (step == InstitutionFormStep.legalRepresentatives) {
      return isEditing || _legalRepresentatives.isNotEmpty;
    }
    if (step == InstitutionFormStep.plan &&
        subscriptionStatus == InstitutionSubscriptionStatus.trial &&
        (trialEnd == null || trialEnd!.isBefore(subscriptionStart))) {
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

  String get _signature => [
    for (final field in InstitutionFormField.values) text(field),
    status.name,
    plan.name,
    subscriptionStatus.name,
    subscriptionStart.toIso8601String(),
    trialEnd?.toIso8601String() ?? '',
    '$hasSimulatedLogo',
    logoFileName ?? '',
    '$hasSimulatedCover',
    coverFileName ?? '',
    for (final representative in _legalRepresentatives)
      '${representative.id}:${_personSignature(representative.person)}',
    for (final administrator in _administrators)
      '${administrator.id}:${_personSignature(administrator.person)}:'
          '${administrator.level.name}:${administrator.invitationStatus.name}:'
          '${administrator.invitationHistory.length}',
  ].join('|');

  String _nextPersonId(String prefix) => '$prefix-${++_personSequence}';

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
};

const _colorFields = {
  InstitutionFormField.accentColor,
  InstitutionFormField.secondaryColor,
  InstitutionFormField.tertiaryColor,
  InstitutionFormField.textColor,
  InstitutionFormField.secondaryTextColor,
  InstitutionFormField.tertiaryTextColor,
  InstitutionFormField.surfaceColor,
};

const _urlFields = {
  InstitutionFormField.websiteUrl,
  InstitutionFormField.link1Url,
  InstitutionFormField.link2Url,
  InstitutionFormField.link3Url,
};

const _linkFieldPairs = [
  (InstitutionFormField.link1Label, InstitutionFormField.link1Url),
  (InstitutionFormField.link2Label, InstitutionFormField.link2Url),
  (InstitutionFormField.link3Label, InstitutionFormField.link3Url),
];

const _pairedLinkField = {
  InstitutionFormField.link1Label: InstitutionFormField.link1Url,
  InstitutionFormField.link1Url: InstitutionFormField.link1Label,
  InstitutionFormField.link2Label: InstitutionFormField.link2Url,
  InstitutionFormField.link2Url: InstitutionFormField.link2Label,
  InstitutionFormField.link3Label: InstitutionFormField.link3Url,
  InstitutionFormField.link3Url: InstitutionFormField.link3Label,
};

InstitutionFormStep _stepFor(InstitutionFormField field) => switch (field) {
  InstitutionFormField.publicName ||
  InstitutionFormField.tradeName ||
  InstitutionFormField.legalName ||
  InstitutionFormField.typeName ||
  InstitutionFormField.documentType ||
  InstitutionFormField.document ||
  InstitutionFormField.primaryDomain ||
  InstitutionFormField.locale ||
  InstitutionFormField.timezone ||
  InstitutionFormField.profileBio ||
  InstitutionFormField.link1Label ||
  InstitutionFormField.link1Url ||
  InstitutionFormField.link2Label ||
  InstitutionFormField.link2Url ||
  InstitutionFormField.link3Label ||
  InstitutionFormField.link3Url => InstitutionFormStep.profile,
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
  InstitutionFormField.contactMobilePhone ||
  InstitutionFormField.whatsappNumber ||
  InstitutionFormField.websiteUrl => InstitutionFormStep.location,
  InstitutionFormField.ownerFirstName ||
  InstitutionFormField.ownerLastName ||
  InstitutionFormField.ownerDisplayName ||
  InstitutionFormField.ownerEmail ||
  InstitutionFormField.ownerMobilePhone => InstitutionFormStep.legalRepresentatives,
  InstitutionFormField.subscriptionJustification => InstitutionFormStep.plan,
  InstitutionFormField.brandDisplayName ||
  InstitutionFormField.slug ||
  InstitutionFormField.accentColor ||
  InstitutionFormField.secondaryColor ||
  InstitutionFormField.tertiaryColor ||
  InstitutionFormField.textColor ||
  InstitutionFormField.secondaryTextColor ||
  InstitutionFormField.tertiaryTextColor ||
  InstitutionFormField.surfaceColor => InstitutionFormStep.branding,
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
  InstitutionFormField.postalCode: record?.postalCode.replaceAll(RegExp(r'\D'), '') ?? '',
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
  InstitutionFormField.whatsappNumber: record?.whatsappNumber ?? '',
  InstitutionFormField.websiteUrl: record?.websiteUrl ?? '',
  InstitutionFormField.ownerFirstName: record?.ownerFirstName ?? '',
  InstitutionFormField.ownerLastName: record?.ownerLastName ?? '',
  InstitutionFormField.ownerDisplayName: record?.ownerDisplayName ?? '',
  InstitutionFormField.ownerEmail: record?.ownerEmail ?? '',
  InstitutionFormField.ownerMobilePhone: record?.ownerMobilePhone ?? '',
  InstitutionFormField.subscriptionJustification: record?.subscriptionJustification ?? '',
  InstitutionFormField.brandDisplayName: record?.brandDisplayName ?? '',
  InstitutionFormField.profileBio: record?.profileBio ?? '',
  InstitutionFormField.link1Label: record?.profileLinks.elementAtOrNull(0)?.label ?? '',
  InstitutionFormField.link1Url: record?.profileLinks.elementAtOrNull(0)?.url ?? '',
  InstitutionFormField.link2Label: record?.profileLinks.elementAtOrNull(1)?.label ?? '',
  InstitutionFormField.link2Url: record?.profileLinks.elementAtOrNull(1)?.url ?? '',
  InstitutionFormField.link3Label: record?.profileLinks.elementAtOrNull(2)?.label ?? '',
  InstitutionFormField.link3Url: record?.profileLinks.elementAtOrNull(2)?.url ?? '',
  InstitutionFormField.accentColor: record?.accentColor ?? '#D63C00',
  InstitutionFormField.secondaryColor: record?.secondaryColor ?? '#3F4549',
  InstitutionFormField.tertiaryColor: record?.tertiaryColor ?? '#D63C00',
  InstitutionFormField.textColor: record?.textColor ?? '#3F4549',
  InstitutionFormField.secondaryTextColor: record?.secondaryTextColor ?? '#3F4549',
  InstitutionFormField.tertiaryTextColor: record?.tertiaryTextColor ?? '#3F4549',
  InstitutionFormField.surfaceColor: record?.surfaceColor ?? '#FFFFFF',
};

bool _isWebUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
}

List<InstitutionFormStep> get _stepsBeforeReview => InstitutionFormStep.values
    .where((step) => step != InstitutionFormStep.review)
    .toList(growable: false);

InstitutionLegalRepresentative? _legacyRepresentative(InstitutionRecord? record) {
  if (record == null ||
      [
        record.ownerFirstName,
        record.ownerLastName,
        record.ownerDisplayName,
        record.ownerEmail,
        record.ownerMobilePhone,
      ].every((value) => value.trim().isEmpty)) {
    return null;
  }
  return InstitutionLegalRepresentative(
    id: 'representative-legacy',
    person: InstitutionPersonDraft(
      firstName: record.ownerFirstName,
      lastName: record.ownerLastName,
      displayName: record.ownerDisplayName,
      email: record.ownerEmail,
      mobilePhone: record.ownerMobilePhone,
    ),
  );
}

String _personSignature(InstitutionPersonDraft person) => [
  person.firstName,
  person.lastName,
  person.displayName,
  person.email,
  person.mobilePhone,
].join(':');

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
