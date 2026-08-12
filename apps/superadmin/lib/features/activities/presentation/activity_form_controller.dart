import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../domain/activity_directory.dart';
import 'activity_form_draft.dart';

enum ActivityFormStep { identity, structure, links, professionals }

typedef ActivityScopedOptionsLoader = Future<ActivityFormOptions> Function(String institutionId);
typedef ActivityTemplateOptionsLoader =
    Future<ActivityTemplateOptions> Function(String? institutionId);
typedef ActivityProfessionalSearcher =
    Future<List<ActivityFormProfessionalOption>> Function(String institutionId, String query);

final class ActivityFormController extends ChangeNotifier {
  ActivityFormController.create(
    this.options, {
    String? initialInstitutionId,
    String? initialUnitId,
    String? initialTemplateId,
    this.loadScopedOptions,
    this.loadTemplateOptions,
    String? initialCatalogError,
    this.professionalSearcher,
  }) : isEditing = false,
       detail = null,
       name = TextEditingController(),
       handleStem = TextEditingController(),
       description = TextEditingController(),
       initials = TextEditingController(),
       otherActivity = TextEditingController(),
       selectedInstitutionId = initialInstitutionId,
       _requestedTemplateId = initialTemplateId,
       catalogOptionsError = initialCatalogError {
    if (initialUnitId != null && units.any((unit) => unit.id == initialUnitId)) {
      selectedUnitIds.add(initialUnitId);
    }
    final initialTemplate = options.templates
        .where((template) => template.id == initialTemplateId)
        .firstOrNull;
    if (initialTemplate != null) {
      template = initialTemplate;
      name.text = initialTemplate.name;
      description.text = initialTemplate.description;
      governance = initialTemplate.governance;
      taxonomy = options.taxonomy
          .where((item) => item.id == initialTemplate.taxonomyId)
          .firstOrNull;
      subtype = taxonomy?.subtypes
          .where((item) => item.id == initialTemplate.subtypeId)
          .firstOrNull;
    }
    _listen();
    _baseline = _signature;
  }

  ActivityFormController.edit(
    this.options,
    ActivityDetail source, {
    ActivityFormDraft? initialDraft,
    this.professionalSearcher,
  }) : isEditing = true,
       loadScopedOptions = null,
       loadTemplateOptions = null,
       detail = source,
       name = TextEditingController(text: initialDraft?.name ?? source.item.name),
       handleStem = TextEditingController(text: initialDraft?.handleStem ?? source.item.handleStem),
       description = TextEditingController(
         text: initialDraft?.description ?? source.item.description ?? '',
       ),
       initials = TextEditingController(text: initialDraft?.identityInitials ?? ''),
       otherActivity = TextEditingController(),
       selectedInstitutionId = initialDraft?.institutionId ?? source.item.institutionId,
       _requestedTemplateId = null,
       catalogOptionsError = null,
       governance = initialDraft?.governance ?? source.item.governance {
    _hydrateEdit(source, initialDraft);
    _listen();
    _baseline = _signature;
  }

  ActivityFormOptions options;
  final ActivityScopedOptionsLoader? loadScopedOptions;
  final ActivityTemplateOptionsLoader? loadTemplateOptions;
  final ActivityProfessionalSearcher? professionalSearcher;
  final ActivityDetail? detail;
  final bool isEditing;
  final TextEditingController name;
  final TextEditingController handleStem;
  final TextEditingController description;
  final TextEditingController initials;
  final TextEditingController otherActivity;

  ActivityFormStep currentStep = ActivityFormStep.identity;
  ActivityTaxonomyOption? taxonomy;
  ActivityTaxonomySubtypeOption? subtype;
  ActivityTemplateOption? template;
  ActivityGovernance governance = ActivityGovernance.optional;
  String? selectedInstitutionId;
  final Set<String> selectedUnitIds = {};
  String? selectedLocationId;
  final Set<String> selectedGroupIds = {};
  final List<ActivityProfessionalAssignment> assignments = [];
  final List<ActivityFormLocationOption> _sessionLocations = [];
  Uint8List? imageBytes;
  String? imageName;
  String identityColor = '#D63C00';
  ActivityIdentityIcon identityIcon = ActivityIdentityIcon.activity;
  ActivityIdentityStorageRef? identityStorageRef;
  final Map<String, ActivityParticipation> groupParticipation = {};
  final Map<String, bool> studentSelection = {};
  String? nameError;
  String? handleStemError;
  String? institutionError;
  String? unitsError;
  String? groupsError;
  bool scopedOptionsLoading = false;
  String? scopedOptionsError;
  bool catalogOptionsLoading = false;
  String? catalogOptionsError;
  bool isSubmitting = false;
  int _scopedRequestSequence = 0;
  int _professionalRequestSequence = 0;
  int _catalogRequestSequence = 0;
  final String? _requestedTemplateId;
  late String _baseline;

  bool get institutionLocked => isEditing;
  bool get governanceLocked => isEditing && governance == ActivityGovernance.fixed;
  bool get isDirty => _signature != _baseline;
  bool get isFirstStep => currentStep == ActivityFormStep.identity;
  bool get isLastStep => currentStep == ActivityFormStep.professionals;
  bool get canSaveDraft => _draftValid(setErrors: false);
  bool get canComplete => _completionValid(setErrors: false);
  bool get hasIdentityImage => imageBytes != null || identityStorageRef != null;
  bool get scopedOptionsAvailable =>
      selectedInstitutionId != null && !scopedOptionsLoading && scopedOptionsError == null;

  Future<void> retryScopedOptions() async {
    final institutionId = selectedInstitutionId;
    if (institutionId == null || institutionId.isEmpty) return;
    await selectInstitution(institutionId, preserveSelection: true);
  }

  Future<void> retryCatalogOptions() async {
    final loader = loadTemplateOptions;
    if (loader == null) return;
    final requestSequence = ++_catalogRequestSequence;
    catalogOptionsLoading = true;
    catalogOptionsError = null;
    notifyListeners();
    try {
      final catalog = await loader(selectedInstitutionId);
      if (requestSequence != _catalogRequestSequence) return;
      options = ActivityFormOptions(
        institutions: catalog.institutions.isEmpty ? options.institutions : catalog.institutions,
        units: options.units,
        locations: options.locations,
        groups: options.groups,
        professionals: options.professionals,
        students: options.students,
        taxonomy: catalog.taxonomy,
        templates: catalog.templates,
      );
      final templateId = template?.id ?? _requestedTemplateId;
      template = catalog.templates.where((item) => item.id == templateId).firstOrNull;
      final selectedTemplate = template;
      if (selectedTemplate != null) {
        taxonomy = catalog.taxonomy
            .where((item) => item.id == selectedTemplate.taxonomyId)
            .firstOrNull;
        subtype = taxonomy?.subtypes
            .where((item) => item.id == selectedTemplate.subtypeId)
            .firstOrNull;
        if (name.text.trim().isEmpty) {
          name.text = selectedTemplate.name;
          governance = selectedTemplate.governance;
        }
        if (description.text.trim().isEmpty) {
          description.text = selectedTemplate.description;
        }
      }
    } on ActivityDirectoryUnauthorizedException {
      rethrow;
    } catch (_) {
      if (requestSequence == _catalogRequestSequence) {
        catalogOptionsError = 'Não foi possível carregar categorias e modelos.';
      }
    } finally {
      if (requestSequence == _catalogRequestSequence) {
        catalogOptionsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<List<ActivityFormProfessionalOption>> searchProfessionals(String query) async {
    final institutionId = selectedInstitutionId;
    final searcher = professionalSearcher;
    if (institutionId == null || searcher == null || query.trim().isEmpty) return const [];
    final requestSequence = ++_professionalRequestSequence;
    final results = await searcher(institutionId, query.trim());
    if (requestSequence != _professionalRequestSequence || selectedInstitutionId != institutionId) {
      return const [];
    }
    return results;
  }

  void acceptProfessionalResults(List<ActivityFormProfessionalOption> results) {
    final byId = <String, ActivityFormProfessionalOption>{
      for (final item in options.professionals) item.id: item,
      for (final item in results) item.id: item,
    };
    options = ActivityFormOptions(
      institutions: options.institutions,
      units: options.units,
      locations: options.locations,
      groups: options.groups,
      professionals: byId.values.toList(growable: false),
      students: options.students,
      taxonomy: options.taxonomy,
      templates: options.templates,
    );
    notifyListeners();
  }

  List<ActivityTaxonomyOption> get taxonomyOptions =>
      _includeUnknown(options.taxonomy, taxonomy, (item) => item.id);

  List<ActivityTaxonomySubtypeOption> get subtypeOptions =>
      _includeUnknown(taxonomy?.subtypes ?? const [], subtype, (item) => item.id);

  List<ActivityTemplateOption> get activityTemplates => _includeUnknown(
    options.templates
        .where(
          (item) =>
              item.taxonomyId == taxonomy?.id &&
              (subtype == null || item.subtypeId == null || item.subtypeId == subtype?.id),
        )
        .toList(growable: false),
    template,
    (item) => item.id,
  );

  String get activityLabel => taxonomy?.isOther == true
      ? otherActivity.text.trim()
      : template?.name ?? subtype?.label ?? taxonomy?.label ?? '';

  List<ActivityFormUnitOption> get units =>
      selectedInstitutionId == null ? const [] : options.unitsFor(selectedInstitutionId!);

  List<ActivityFormLocationOption> get locations => [
    ...options.locations,
    ..._sessionLocations,
  ].where((location) => selectedUnitIds.contains(location.unitId)).toList(growable: false);

  List<ActivityFormGroupOption> get groups => options.groups
      .where((group) => selectedUnitIds.contains(group.unitId))
      .toList(growable: false);

  String get _signature => [
    currentStep.name,
    name.text.trim(),
    handleStem.text.trim(),
    description.text.trim(),
    initials.text.trim(),
    otherActivity.text.trim(),
    taxonomy?.id ?? '',
    subtype?.id ?? '',
    template?.id ?? '',
    governance.name,
    selectedInstitutionId ?? '',
    (selectedUnitIds.toList()..sort()).join(','),
    selectedLocationId ?? '',
    (selectedGroupIds.toList()..sort()).join(','),
    assignments
        .map(
          (item) =>
              '${item.groupId ?? 'activity'}:${item.professionalId}:${item.role.name}:'
              '${item.permissions.happens}:${item.permissions.now}:'
              '${item.permissions.moments}:${item.permissions.chat}:'
              '${item.permissions.attendance}',
        )
        .toList()
      ..sort(),
    imageName ?? '',
    identityStorageRef?.bucket ?? '',
    identityStorageRef?.path ?? '',
    identityColor,
    identityIcon.name,
    (groupParticipation.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        .map((entry) => '${entry.key}:${entry.value.name}')
        .join(','),
    (studentSelection.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        .map((entry) => '${entry.key}:${entry.value}')
        .join(','),
  ].join('|');

  void _hydrateEdit(ActivityDetail source, ActivityFormDraft? initialDraft) {
    final institutionExists = options.institutions.any(
      (institution) => institution.id == selectedInstitutionId,
    );
    if (!institutionExists) selectedInstitutionId = source.item.institutionId;

    final availableUnits = options.unitsFor(selectedInstitutionId!);
    T? unique<T>(Iterable<T> values) {
      final matches = values.toList(growable: false);
      return matches.length == 1 ? matches.single : null;
    }

    String normalized(String value) => value.trim().toLowerCase();

    if (initialDraft != null) {
      taxonomy = initialDraft.taxonomy;
      subtype = initialDraft.subtype;
      template = initialDraft.template;
      otherActivity.text = initialDraft.taxonomyOtherDescription;

      selectedUnitIds.addAll(
        initialDraft.unitIds.where((unitId) => availableUnits.any((unit) => unit.id == unitId)),
      );
      final availableGroups = options.groups.where(
        (group) => selectedUnitIds.contains(group.unitId),
      );
      selectedGroupIds.addAll(
        initialDraft.groupIds.where(
          (groupId) => availableGroups.any((group) => group.id == groupId),
        ),
      );
      if (initialDraft.locationId != null &&
          options.locations.any(
            (location) =>
                location.id == initialDraft.locationId && selectedUnitIds.contains(location.unitId),
          )) {
        selectedLocationId = initialDraft.locationId;
      }
      final assignmentKeys = <String>{};
      assignments.addAll(
        initialDraft.assignments.where((assignment) {
          final key = '${assignment.groupId}:${assignment.professionalId}:${assignment.role.name}';
          final validScope = assignment.role == ActivityAssignmentRole.activityAdmin
              ? assignment.groupId == null
              : selectedGroupIds.contains(assignment.groupId);
          return validScope &&
              options.professionals.any(
                (professional) => professional.id == assignment.professionalId,
              ) &&
              assignmentKeys.add(key);
        }),
      );
      imageBytes = initialDraft.imageBytes;
      imageName = initialDraft.imageName;
      identityColor = initialDraft.identityColor;
      identityIcon = initialDraft.identityIcon;
      identityStorageRef = initialDraft.identityStorageRef;
      groupParticipation.addAll(initialDraft.groupParticipation);
      studentSelection.addEntries(
        initialDraft.studentSelections
            .where((selection) {
              return selectedGroupIds.contains(selection.groupId) &&
                  options.students.any(
                    (student) =>
                        student.groupId == selection.groupId &&
                        student.childGroupLinkId == selection.childGroupLinkId,
                  );
            })
            .map((selection) => MapEntry(selection.childGroupLinkId, selection.belongs)),
      );
      return;
    }

    taxonomy = options.taxonomy.where((item) => item.id == source.taxonomyId).firstOrNull;
    subtype = taxonomy?.subtypes.where((item) => item.id == source.subtypeId).firstOrNull;
    template = options.templates.where((item) => item.id == source.templateId).firstOrNull;
    otherActivity.text = source.taxonomyOtherDescription;
    initials.text = source.identity.initials ?? '';
    identityColor = source.identity.color ?? identityColor;
    identityIcon =
        ActivityIdentityIcon.values
            .where((icon) => icon.name == source.identity.icon)
            .firstOrNull ??
        identityIcon;
    identityStorageRef = source.identity.storageRef;

    for (final linkedUnit in source.units) {
      final exact = unique(availableUnits.where((unit) => unit.id == linkedUnit.id));
      final byName = unique(
        availableUnits.where((unit) => normalized(unit.name) == normalized(linkedUnit.name)),
      );
      final match = exact ?? byName;
      if (match != null) selectedUnitIds.add(match.id);
    }

    final selectedUnits = availableUnits.where((unit) => selectedUnitIds.contains(unit.id));
    for (final linkedGroup in source.groups) {
      final availableGroups = options.groups.where(
        (group) => selectedUnitIds.contains(group.unitId),
      );
      final exact = unique(availableGroups.where((group) => group.id == linkedGroup.id));
      final byNameAndUnit = unique(
        availableGroups.where((group) {
          final unit = unique(selectedUnits.where((unit) => unit.id == group.unitId));
          return unit != null &&
              normalized(unit.name) == normalized(linkedGroup.unitName) &&
              normalized(group.name) == normalized(linkedGroup.name);
        }),
      );
      final match = exact ?? byNameAndUnit;
      if (match != null) {
        selectedGroupIds.add(match.id);
        groupParticipation[match.id] = linkedGroup.participation;
      }
    }
    for (final participant in source.participants) {
      final student = options.students
          .where(
            (item) =>
                item.groupId == participant.groupId &&
                item.childGroupLinkId == participant.childGroupLinkId,
          )
          .firstOrNull;
      if (student != null && selectedGroupIds.contains(student.groupId)) {
        studentSelection[student.childGroupLinkId] = participant.belongs;
      }
    }
    for (final assignment in source.professionalAssignments) {
      final role = switch (assignment.role) {
        ActivityDetailProfessionalRole.instructor => ActivityAssignmentRole.instructor,
        ActivityDetailProfessionalRole.activityAdmin => ActivityAssignmentRole.activityAdmin,
      };
      final validScope = role == ActivityAssignmentRole.activityAdmin
          ? assignment.groupId == null
          : selectedGroupIds.contains(assignment.groupId);
      if (validScope && options.professionals.any((item) => item.id == assignment.membershipId)) {
        assignments.add(
          ActivityProfessionalAssignment(
            groupId: assignment.groupId,
            professionalId: assignment.membershipId,
            role: role,
            permissions: ActivityProfessionalPermissions(
              happens: _accessFromDatabase(assignment.capabilities['happens']),
              now: _accessFromDatabase(assignment.capabilities['now']),
              moments: _accessFromDatabase(assignment.capabilities['moments']),
              chat: _accessFromDatabase(assignment.capabilities['chat']),
              attendance: _accessFromDatabase(assignment.capabilities['attendance']),
            ),
          ),
        );
      }
    }
  }

  void _listen() {
    name.addListener(_changed);
    handleStem.addListener(_changed);
    description.addListener(_changed);
    initials.addListener(_changed);
    otherActivity.addListener(_changed);
  }

  void _changed() => notifyListeners();

  void selectTaxonomy(ActivityTaxonomyOption value) {
    taxonomy = value;
    subtype = null;
    template = null;
    otherActivity.clear();
    notifyListeners();
  }

  void selectSubtype(ActivityTaxonomySubtypeOption? value) {
    subtype = value;
    template = null;
    notifyListeners();
  }

  void selectTemplate(ActivityTemplateOption? value) {
    template = value;
    notifyListeners();
  }

  void selectGovernance(ActivityGovernance value) {
    if (governanceLocked) return;
    governance = value;
    notifyListeners();
  }

  void setIdentityColor(String value) {
    identityColor = value;
    notifyListeners();
  }

  void selectIdentityIcon(ActivityIdentityIcon value) {
    identityIcon = value;
    notifyListeners();
  }

  Future<void> selectInstitution(String institutionId, {bool preserveSelection = false}) async {
    if (institutionLocked) return;
    _professionalRequestSequence++;
    selectedInstitutionId = institutionId;
    if (!preserveSelection) {
      selectedUnitIds.clear();
      selectedGroupIds.clear();
      groupParticipation.clear();
      studentSelection.clear();
      assignments.clear();
      selectedLocationId = null;
    }
    institutionError = null;
    unitsError = null;
    groupsError = null;
    scopedOptionsError = null;
    notifyListeners();
    final loader = loadScopedOptions;
    if (loader == null || institutionId.isEmpty) return;
    scopedOptionsLoading = true;
    final requestSequence = ++_scopedRequestSequence;
    notifyListeners();
    try {
      final scoped = await loader(institutionId);
      if (selectedInstitutionId != institutionId || requestSequence != _scopedRequestSequence) {
        return;
      }
      options = ActivityFormOptions(
        institutions: options.institutions,
        units: scoped.units,
        locations: scoped.locations,
        groups: scoped.groups,
        professionals: scoped.professionals,
        students: scoped.students,
        taxonomy: scoped.taxonomy.isEmpty ? options.taxonomy : scoped.taxonomy,
        templates: scoped.templates.isEmpty ? options.templates : scoped.templates,
      );
    } catch (_) {
      if (selectedInstitutionId == institutionId && requestSequence == _scopedRequestSequence) {
        scopedOptionsError = 'Não foi possível carregar os vínculos desta instituição.';
      }
    } finally {
      if (selectedInstitutionId == institutionId && requestSequence == _scopedRequestSequence) {
        scopedOptionsLoading = false;
      }
      notifyListeners();
    }
  }

  void toggleUnit(String unitId) {
    if (!units.any((unit) => unit.id == unitId)) return;
    if (!selectedUnitIds.add(unitId)) selectedUnitIds.remove(unitId);
    selectedGroupIds.removeWhere((groupId) => !groups.any((group) => group.id == groupId));
    groupParticipation.removeWhere((groupId, _) => !selectedGroupIds.contains(groupId));
    studentSelection.removeWhere((linkId, _) {
      final student = options.students.where((item) => item.childGroupLinkId == linkId).firstOrNull;
      return student == null || !selectedGroupIds.contains(student.groupId);
    });
    assignments.removeWhere(
      (assignment) => assignment.groupId != null && !selectedGroupIds.contains(assignment.groupId),
    );
    if (!locations.any((location) => location.id == selectedLocationId)) {
      selectedLocationId = null;
    }
    unitsError = null;
    notifyListeners();
  }

  void selectLocation(String? locationId) {
    selectedLocationId = locationId?.isEmpty == true ? null : locationId;
    notifyListeners();
  }

  void addLocations(List<ActivityFormLocationOption> locations) {
    _sessionLocations.addAll(locations);
    if (locations.isNotEmpty) selectedLocationId = locations.first.id;
    notifyListeners();
  }

  void toggleGroup(String groupId) {
    if (!groups.any((group) => group.id == groupId)) return;
    if (selectedGroupIds.add(groupId)) {
      groupParticipation[groupId] = ActivityParticipation.all;
      for (final student in options.students.where((item) => item.groupId == groupId)) {
        studentSelection[student.childGroupLinkId] = true;
      }
    } else {
      selectedGroupIds.remove(groupId);
      groupParticipation.remove(groupId);
      studentSelection.removeWhere(
        (linkId, _) => options.students.any(
          (student) => student.childGroupLinkId == linkId && student.groupId == groupId,
        ),
      );
      assignments.removeWhere((assignment) => assignment.groupId == groupId);
    }
    groupsError = null;
    notifyListeners();
  }

  void setGroupParticipation(String groupId, ActivityParticipation value) {
    groupParticipation[groupId] = value;
    notifyListeners();
  }

  void setStudentIncluded(String childGroupLinkId, bool value) {
    if (!options.students.any(
      (student) =>
          student.childGroupLinkId == childGroupLinkId &&
          selectedGroupIds.contains(student.groupId),
    )) {
      return;
    }
    studentSelection[childGroupLinkId] = value;
    notifyListeners();
  }

  void toggleProfessional(
    String? groupId,
    String professionalId, {
    ActivityAssignmentRole role = ActivityAssignmentRole.instructor,
  }) {
    if ((role == ActivityAssignmentRole.instructor &&
            (groupId == null || !selectedGroupIds.contains(groupId))) ||
        !options.professionals.any((professional) => professional.id == professionalId)) {
      return;
    }
    final index = assignments.indexWhere(
      (assignment) => assignment.groupId == groupId && assignment.professionalId == professionalId,
    );
    if (index >= 0) {
      assignments.removeAt(index);
    } else {
      assignments.add(
        ActivityProfessionalAssignment(
          groupId: groupId,
          professionalId: professionalId,
          role: role,
        ),
      );
    }
    notifyListeners();
  }

  void setPermission(
    String? groupId,
    String professionalId, {
    ActivityProfessionalAccess? happens,
    ActivityProfessionalAccess? now,
    ActivityProfessionalAccess? moments,
    ActivityProfessionalAccess? chat,
    ActivityProfessionalAccess? attendance,
  }) {
    final index = assignments.indexWhere(
      (assignment) => assignment.groupId == groupId && assignment.professionalId == professionalId,
    );
    if (index < 0) return;
    final current = assignments[index];
    assignments[index] = current.copyWith(
      permissions: current.permissions.copyWith(
        happens: happens,
        now: now,
        moments: moments,
        chat: chat,
        attendance: attendance,
      ),
    );
    notifyListeners();
  }

  void setImage({required String name, required Uint8List bytes}) {
    imageName = name;
    imageBytes = bytes;
    identityStorageRef = null;
    notifyListeners();
  }

  void goToStep(int index) {
    if (index < 0 || index >= ActivityFormStep.values.length) return;
    currentStep = ActivityFormStep.values[index];
    notifyListeners();
  }

  void previousStep() => goToStep(currentStep.index - 1);

  bool continueFromCurrentStep() {
    final valid = switch (currentStep) {
      ActivityFormStep.identity => _identityValid(setErrors: true),
      ActivityFormStep.structure => _draftValid(setErrors: true),
      ActivityFormStep.links => _completionValid(setErrors: true),
      ActivityFormStep.professionals => _completionValid(setErrors: true),
    };
    if (valid && !isLastStep) goToStep(currentStep.index + 1);
    notifyListeners();
    return valid;
  }

  bool validateDraft() {
    final valid = _draftValid(setErrors: true);
    notifyListeners();
    return valid;
  }

  bool validateCompletion() {
    final valid = _completionValid(setErrors: true);
    notifyListeners();
    return valid;
  }

  bool _identityValid({required bool setErrors}) {
    final validName = name.text.trim().isNotEmpty;
    final handle = handleStem.text.trim();
    final validHandle = handle.isEmpty
        ? name.text.trim().length >= 3
        : RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(handle) &&
              handle.length >= 3 &&
              handle.length <= 64;
    if (setErrors) {
      nameError = validName ? null : 'Informe o nome da atividade.';
      handleStemError = validHandle ? null : 'Use de 3 a 64 caracteres, letras, números e hífens.';
    }
    return validName && validHandle;
  }

  bool _draftValid({required bool setErrors}) {
    final identityValid = _identityValid(setErrors: setErrors);
    final validInstitution = selectedInstitutionId != null;
    final validUnits = selectedUnitIds.isNotEmpty;
    if (setErrors) {
      institutionError = validInstitution ? null : 'Selecione a instituição.';
      unitsError = validUnits ? null : 'Selecione ao menos uma unidade.';
    }
    return identityValid && validInstitution && validUnits;
  }

  bool _completionValid({required bool setErrors}) {
    final draftValid = _draftValid(setErrors: setErrors);
    final validGroups = selectedGroupIds.isNotEmpty;
    if (setErrors) groupsError = validGroups ? null : 'Selecione ao menos uma turma.';
    return draftValid && validGroups;
  }

  ActivityFormDraft toDraft() => ActivityFormDraft(
    name: name.text.trim(),
    handleStem: handleStem.text.trim(),
    description: description.text.trim(),
    taxonomy: taxonomy,
    subtype: subtype,
    template: template,
    taxonomyOtherDescription: otherActivity.text.trim(),
    governance: governance,
    institutionId: selectedInstitutionId!,
    unitIds: Set.unmodifiable(selectedUnitIds),
    locationId: selectedLocationId,
    groupIds: Set.unmodifiable(selectedGroupIds),
    assignments: List.unmodifiable(assignments),
    imageName: imageName,
    imageBytes: imageBytes,
    identityInitials: initials.text.trim(),
    identityColor: identityColor,
    identityIcon: identityIcon,
    identityStorageRef: identityStorageRef,
    groupParticipation: Map.unmodifiable(groupParticipation),
    studentSelections: List.unmodifiable(
      options.students
          .where(
            (student) =>
                selectedGroupIds.contains(student.groupId) &&
                studentSelection.containsKey(student.childGroupLinkId),
          )
          .map(
            (student) => ActivityStudentSelection(
              groupId: student.groupId,
              childGroupLinkId: student.childGroupLinkId,
              belongs: studentSelection[student.childGroupLinkId]!,
            ),
          ),
    ),
  );

  void setSubmitting(bool value) {
    isSubmitting = value;
    notifyListeners();
  }

  void markSubmitted() {
    _baseline = _signature;
    notifyListeners();
  }

  @override
  void dispose() {
    name
      ..removeListener(_changed)
      ..dispose();
    handleStem
      ..removeListener(_changed)
      ..dispose();
    description
      ..removeListener(_changed)
      ..dispose();
    initials
      ..removeListener(_changed)
      ..dispose();
    otherActivity
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }
}

ActivityProfessionalAccess _accessFromDatabase(String? value) => switch (value) {
  'none' => ActivityProfessionalAccess.none,
  'view' => ActivityProfessionalAccess.view,
  'edit' => ActivityProfessionalAccess.edit,
  _ => ActivityProfessionalAccess.both,
};

List<T> _includeUnknown<T>(List<T> known, T? current, String Function(T item) id) {
  if (current == null || known.any((item) => id(item) == id(current))) return known;
  return [current, ...known];
}
