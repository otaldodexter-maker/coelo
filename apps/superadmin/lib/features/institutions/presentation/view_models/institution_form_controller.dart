import 'package:flutter/material.dart';
import 'package:characters/characters.dart' as characters;
import 'dart:typed_data';

import '../../domain/institution_directory_item.dart';
import '../../domain/institution_people.dart';
import '../../domain/institution_record.dart';

export '../../domain/institution_people.dart';

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
  secondarySurfaceColor,
}

final class InstitutionFormController extends ChangeNotifier {
  InstitutionFormController({InstitutionRecord? record, Set<String> reservedHandles = const {}})
    : original = record,
      _reservedHandles = reservedHandles.map(_normalizeHandle).toSet(),
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
    if (record != null && record.legalRepresentatives.isNotEmpty) {
      _legalRepresentatives.addAll(record.legalRepresentatives);
    } else {
      final legacyRepresentative = _legacyRepresentative(record);
      if (legacyRepresentative != null) {
        _legalRepresentatives.add(legacyRepresentative);
      }
    }
    if (record != null) {
      _administrators.addAll(record.administrators);
    }
    for (final id in [
      for (final representative in _legalRepresentatives) representative.id,
      for (final administrator in _administrators) administrator.id,
    ]) {
      final suffix = int.tryParse(RegExp(r'(\d+)$').firstMatch(id)?.group(1) ?? '') ?? 0;
      if (suffix > _personSequence) {
        _personSequence = suffix;
      }
    }
    _initialSignature = _signature;
  }

  final InstitutionRecord? original;
  final Set<String> _reservedHandles;
  final Map<InstitutionFormField, TextEditingController> _controllers = {};
  final Set<InstitutionFormStep> _attemptedSteps = {};
  final List<InstitutionLegalRepresentative> _legalRepresentatives = [];
  final List<InstitutionAdministratorDraft> _administrators = [];
  late String _initialSignature;
  bool _slugManuallyEdited = false;
  var _personSequence = 0;
  String? peopleRuleMessage;
  String? administratorNeedingEmailId;

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
          _legalRepresentatives.isEmpty
      ? 'Adicione pelo menos um representante legal para concluir o cadastro.'
      : null;
  String? get administratorsError =>
      _attemptedSteps.contains(InstitutionFormStep.administrators) && _administrators.isEmpty
      ? 'Adicione pelo menos um administrador para concluir o cadastro.'
      : null;

  TextEditingController controllerOf(InstitutionFormField field) => _controllers[field]!;
  String text(InstitutionFormField field) => controllerOf(field).text.trim();
  int get profileBioLength =>
      characters.Characters(controllerOf(InstitutionFormField.profileBio).text).length;

  void insertProfileBioEmoji(String emoji) {
    final controller = controllerOf(InstitutionFormField.profileBio);
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : controller.text.length;
    final end = selection.isValid ? selection.end : controller.text.length;
    final candidate = controller.text.replaceRange(start, end, emoji);
    final clipped = characters.Characters(candidate).take(220).toString();
    final desiredOffset = (start + emoji.length).clamp(0, clipped.length);
    controller.value = TextEditingValue(
      text: clipped,
      selection: TextSelection.collapsed(offset: desiredOffset),
    );
    notifyListeners();
  }

  void setText(InstitutionFormField field, String value, {bool userInitiated = false}) {
    if (field == InstitutionFormField.profileBio && characters.Characters(value).length > 220) {
      value = characters.Characters(value).take(220).toString();
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
    peopleRuleMessage = null;
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

  bool removeLegalRepresentative(String id) {
    if (_legalRepresentatives.length <= 1) {
      peopleRuleMessage = 'Adicione outro representante legal antes de remover o último registro.';
      notifyListeners();
      return false;
    }
    _legalRepresentatives.removeWhere((item) => item.id == id);
    for (var index = 0; index < _administrators.length; index++) {
      if (_administrators[index].sourceRepresentativeId == id) {
        _administrators[index] = _administrators[index].copyWith(clearSourceRepresentativeId: true);
      }
    }
    peopleRuleMessage = null;
    notifyListeners();
    return true;
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
          person: representative.person.copyWith(),
          handle: _nextAdministratorHandle(representative.person.displayName),
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
    Uint8List? avatarBytes,
    String? avatarFileName,
  }) {
    peopleRuleMessage = null;
    _administrators.add(
      InstitutionAdministratorDraft(
        id: _nextPersonId('administrator'),
        person: person.copyWith(),
        handle: _nextAdministratorHandle(person.displayName),
        level: level,
        invitationStatus: InstitutionInvitationStatus.notSent,
        invitationHistory: const [],
        avatarBytes: avatarBytes,
        avatarFileName: avatarFileName,
      ),
    );
    notifyListeners();
  }

  void updateAdministrator(
    String id, {
    required InstitutionPersonDraft person,
    required InstitutionAdministratorLevel level,
    bool sendInvitationAfterSave = false,
  }) {
    final index = _administrators.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _administrators[index] = _administrators[index].copyWith(person: person, level: level);
    if (sendInvitationAfterSave &&
        person.email.trim().isNotEmpty &&
        personError(person, InstitutionPersonField.email) == null) {
      administratorNeedingEmailId = null;
      _transitionAdministratorInvitation(id, InstitutionInvitationStatus.sent);
      return;
    }
    notifyListeners();
  }

  bool removeAdministrator(String id) {
    if (_administrators.length <= 1) {
      peopleRuleMessage = 'Adicione outro administrador antes de remover o último registro.';
      notifyListeners();
      return false;
    }
    _administrators.removeWhere((item) => item.id == id);
    peopleRuleMessage = null;
    notifyListeners();
    return true;
  }

  bool sendAdministratorInvitation(String id) {
    final administrator = _administrators.where((item) => item.id == id).firstOrNull;
    if (administrator == null) return false;
    if (administrator.person.email.trim().isEmpty ||
        personError(administrator.person, InstitutionPersonField.email) != null) {
      administratorNeedingEmailId = id;
      notifyListeners();
      return false;
    }
    administratorNeedingEmailId = null;
    _transitionAdministratorInvitation(id, InstitutionInvitationStatus.sent);
    return true;
  }

  void cancelAdministratorEmailRequest() {
    administratorNeedingEmailId = null;
    notifyListeners();
  }

  void setAdministratorAvatar(String id, {required Uint8List bytes, required String fileName}) {
    final index = _administrators.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _administrators[index] = _administrators[index].copyWith(
      avatarBytes: bytes,
      avatarFileName: fileName,
    );
    notifyListeners();
  }

  void removeAdministratorAvatar(String id) {
    final index = _administrators.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _administrators[index] = _administrators[index].copyWith(clearAvatar: true);
    notifyListeners();
  }

  bool syncRepresentativeToAdministrator(String administratorId) {
    final adminIndex = _administrators.indexWhere((item) => item.id == administratorId);
    if (adminIndex < 0) return false;
    final representativeId = _administrators[adminIndex].sourceRepresentativeId;
    final representative = _legalRepresentatives
        .where((item) => item.id == representativeId)
        .firstOrNull;
    if (representative == null) return false;
    _administrators[adminIndex] = _administrators[adminIndex].copyWith(
      person: representative.person.copyWith(),
    );
    notifyListeners();
    return true;
  }

  bool syncAdministratorToRepresentative(String administratorId) {
    final administrator = _administrators.where((item) => item.id == administratorId).firstOrNull;
    if (administrator == null || administrator.sourceRepresentativeId == null) {
      return false;
    }
    final representativeIndex = _legalRepresentatives.indexWhere(
      (item) => item.id == administrator.sourceRepresentativeId,
    );
    if (representativeIndex < 0) return false;
    _legalRepresentatives[representativeIndex] = _legalRepresentatives[representativeIndex]
        .copyWith(person: administrator.person.copyWith());
    notifyListeners();
    return true;
  }

  void setAdministratorInvitationStatus(String id, InstitutionInvitationStatus status) {
    final index = _administrators.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final administrator = _administrators[index];
    if (administrator.invitationStatus != InstitutionInvitationStatus.sent ||
        !{
          InstitutionInvitationStatus.accepted,
          InstitutionInvitationStatus.expired,
        }.contains(status)) {
      return;
    }
    _transitionAdministratorInvitation(id, status);
  }

  void _transitionAdministratorInvitation(String id, InstitutionInvitationStatus status) {
    final index = _administrators.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final administrator = _administrators[index];
    final history = [
      ...administrator.invitationHistory,
      InstitutionInvitationHistoryEntry(status: status, occurredAt: DateTime.now()),
    ];
    _administrators[index] = administrator.copyWith(
      invitationStatus: status,
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

  bool validateEditSave() {
    _attemptedSteps.add(currentStep);
    if (!_isStepValid(currentStep)) {
      notifyListeners();
      return false;
    }
    const requiredPeopleSteps = [
      InstitutionFormStep.legalRepresentatives,
      InstitutionFormStep.administrators,
    ];
    _attemptedSteps.addAll(requiredPeopleSteps);
    for (final step in requiredPeopleSteps) {
      if (!_isStepValid(step)) {
        currentStep = step;
        notifyListeners();
        return false;
      }
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
    if (field == InstitutionFormField.slug && value.isNotEmpty) {
      final handle = _normalizeHandle('@$value');
      final administratorHandles = {
        for (final administrator in _administrators) _normalizeHandle(administrator.handle),
      };
      if (_reservedHandles.contains(handle) || administratorHandles.contains(handle)) {
        return 'Este @ já está em uso.';
      }
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

  String? personError(InstitutionPersonDraft person, InstitutionPersonField field) {
    final value = switch (field) {
      InstitutionPersonField.firstName => person.firstName,
      InstitutionPersonField.lastName => person.lastName,
      InstitutionPersonField.displayName => person.displayName,
      InstitutionPersonField.email => person.email,
      InstitutionPersonField.mobilePhone => person.mobilePhone,
      InstitutionPersonField.cpf => person.cpf,
    }.trim();
    if ({
          InstitutionPersonField.firstName,
          InstitutionPersonField.lastName,
          InstitutionPersonField.displayName,
        }.contains(field) &&
        value.isEmpty) {
      return 'Preencha este campo.';
    }
    if (field == InstitutionPersonField.email &&
        value.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      return 'Informe um e-mail válido, como nome@dominio.com.';
    }
    if (field == InstitutionPersonField.mobilePhone &&
        value.isNotEmpty &&
        value.replaceAll(RegExp(r'\D'), '').length < 10) {
      return 'Informe um telefone válido com DDD.';
    }
    if (field == InstitutionPersonField.cpf && value.isNotEmpty && !_isValidCpf(value)) {
      return 'Informe um CPF válido.';
    }
    return null;
  }

  bool isPersonValid(InstitutionPersonDraft person) =>
      InstitutionPersonField.values.every((field) => personError(person, field) == null);

  String formatCpf(String value) {
    final digits = characters.Characters(value.replaceAll(RegExp(r'\D'), '')).take(11).toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index == 3 || index == 6) buffer.write('.');
      if (index == 9) buffer.write('-');
      buffer.write(digits[index]);
    }
    return buffer.toString();
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
      ownerFirstName: primaryRepresentative?.firstName ?? '',
      ownerLastName: primaryRepresentative?.lastName ?? '',
      ownerDisplayName: primaryRepresentative?.displayName ?? '',
      ownerEmail: primaryRepresentative?.email ?? '',
      ownerMobilePhone: primaryRepresentative?.mobilePhone ?? '',
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
      secondarySurfaceColor: text(InstitutionFormField.secondarySurfaceColor),
      profileBio: text(InstitutionFormField.profileBio),
      profileLinks: [
        for (final pair in _linkFieldPairs)
          if (text(pair.$1).isNotEmpty || text(pair.$2).isNotEmpty)
            InstitutionProfileLink(label: text(pair.$1), url: text(pair.$2)),
      ],
      legalRepresentatives: List.unmodifiable(_legalRepresentatives),
      administrators: List.unmodifiable(_administrators),
      units: units,
    );
  }

  bool _isStepValid(InstitutionFormStep step) {
    if (step == InstitutionFormStep.review) {
      return _stepsBeforeReview.every(_isStepValid);
    }
    if (step == InstitutionFormStep.legalRepresentatives) {
      return _legalRepresentatives.isNotEmpty &&
          _legalRepresentatives.every((item) => isPersonValid(item.person));
    }
    if (step == InstitutionFormStep.administrators) {
      return _administrators.isNotEmpty &&
          _administrators.every((item) => isPersonValid(item.person));
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
          '${administrator.invitationHistory.length}:${administrator.handle}:'
          '${administrator.sourceRepresentativeId ?? ''}:${administrator.avatarFileName ?? ''}:'
          '${administrator.avatarBytes?.hashCode ?? ''}',
  ].join('|');

  String _nextPersonId(String prefix) => '$prefix-${++_personSequence}';

  String _nextAdministratorHandle(String displayName) {
    final base = _slugify(displayName).isEmpty ? 'administrador' : _slugify(displayName);
    final used = {
      ..._reservedHandles,
      if (text(InstitutionFormField.slug).isNotEmpty)
        _normalizeHandle('@${text(InstitutionFormField.slug)}'),
      for (final administrator in _administrators) _normalizeHandle(administrator.handle),
    };
    var suffix = 1;
    var candidate = '@$base';
    while (used.contains(_normalizeHandle(candidate))) {
      suffix++;
      candidate = '@$base-$suffix';
    }
    return candidate;
  }

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
  InstitutionFormField.secondarySurfaceColor,
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
  InstitutionFormField.surfaceColor ||
  InstitutionFormField.secondarySurfaceColor => InstitutionFormStep.branding,
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
  InstitutionFormField.secondarySurfaceColor: record?.secondarySurfaceColor ?? '#F4F5F5',
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
      cpf: '',
    ),
  );
}

String _personSignature(InstitutionPersonDraft person) => [
  person.firstName,
  person.lastName,
  person.displayName,
  person.email,
  person.mobilePhone,
  person.cpf,
].join(':');

String _normalizeHandle(String value) =>
    value.trim().toLowerCase().replaceFirst(RegExp(r'^@?'), '@');

bool _isValidCpf(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(digits)) {
    return false;
  }
  int verifier(int length) {
    var sum = 0;
    for (var index = 0; index < length; index++) {
      sum += int.parse(digits[index]) * (length + 1 - index);
    }
    final remainder = (sum * 10) % 11;
    return remainder == 10 ? 0 : remainder;
  }

  return verifier(9) == int.parse(digits[9]) && verifier(10) == int.parse(digits[10]);
}

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
