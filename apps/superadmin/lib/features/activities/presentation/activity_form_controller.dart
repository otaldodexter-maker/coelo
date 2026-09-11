import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:coelo_domain/profile_about.dart';
import 'package:coelo_domain/locations.dart';
import '../domain/activity_command.dart';

import '../domain/activity_directory.dart';
import '../../units/domain/unit_handle_availability.dart';
import 'activity_form_draft.dart';
import 'activity_pedagogical_configuration_draft.dart';

enum ActivityFormStep { identity, structure, pedagogical, links, about, professionals }

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
    this.handleAvailabilityChecker,
  }) : isEditing = false,
       detail = null,
       expectedManagementVersion = 0,
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
    this.loadTemplateOptions,
    String? initialCatalogError,
    this.handleAvailabilityChecker,
  }) : isEditing = true,
       loadScopedOptions = null,
       detail = source,
       expectedManagementVersion =
           initialDraft?.expectedManagementVersion ?? source.item.managementVersion,
       name = TextEditingController(text: initialDraft?.name ?? source.item.name),
       handleStem = TextEditingController(text: initialDraft?.handleStem ?? source.item.handleStem),
       description = TextEditingController(
         text: initialDraft?.description ?? source.item.description ?? '',
       ),
       initials = TextEditingController(text: initialDraft?.identityInitials ?? ''),
       otherActivity = TextEditingController(),
       selectedInstitutionId = initialDraft?.institutionId ?? source.item.institutionId,
       _requestedTemplateId = null,
       catalogOptionsError = initialCatalogError,
       governance = initialDraft?.governance ?? source.item.governance {
    _hydrateEdit(source, initialDraft);
    _listen();
    _baseline = _signature;
  }

  ActivityFormOptions options;
  final ActivityScopedOptionsLoader? loadScopedOptions;
  final ActivityTemplateOptionsLoader? loadTemplateOptions;
  final ActivityProfessionalSearcher? professionalSearcher;

  /// Regra do @ (ADR 0034 Decisao 16): verificacao de disponibilidade do
  /// stem enquanto digita; opcional, nunca bloqueia o formulario.
  final StructureHandleAvailabilityChecker? handleAvailabilityChecker;
  UnitHandleAvailability? handleAvailability;
  String _handleChecked = '';
  Timer? _handleCheckTimer;
  int _handleCheckSequence = 0;

  /// Texto vivo da legenda do @, ou nulo quando nao ha verificacao valida
  /// para o texto atual.
  String? get handleAvailabilityMessage {
    final result = handleAvailability;
    if (result == null || _handleChecked != handleStem.text.trim()) return null;
    return switch (result.reason) {
      UnitHandleAvailabilityReason.available => '@${result.normalized} está disponível.',
      UnitHandleAvailabilityReason.taken => '@${result.normalized} já está em uso. Escolha outro.',
      UnitHandleAvailabilityReason.invalid => 'Use de 3 a 64 caracteres, letras, números e hífens.',
      UnitHandleAvailabilityReason.empty => null,
      UnitHandleAvailabilityReason.unavailable =>
        'Não foi possível verificar a disponibilidade agora; o servidor confere ao salvar.',
    };
  }

  void _scheduleHandleCheck() {
    final checker = handleAvailabilityChecker;
    if (checker == null) return;
    final value = handleStem.text.trim();
    _handleCheckTimer?.cancel();
    if (value.isEmpty || value == (detail?.item.handleStem ?? '')) {
      if (handleAvailability != null) {
        handleAvailability = null;
        notifyListeners();
      }
      return;
    }
    final sequence = ++_handleCheckSequence;
    _handleCheckTimer = Timer(const Duration(milliseconds: 300), () async {
      final result = await checker('activity', value, excludeId: detail?.item.id);
      if (sequence != _handleCheckSequence) return;
      handleAvailability = result;
      _handleChecked = value;
      notifyListeners();
    });
  }
  final ActivityDetail? detail;
  final bool isEditing;
  final int expectedManagementVersion;
  final TextEditingController name;
  final TextEditingController handleStem;
  final TextEditingController description;
  final TextEditingController initials;
  final TextEditingController otherActivity;

  ActivityFormStep currentStep = ActivityFormStep.identity;
  ProfileAboutPage? aboutPage;
  ActivityPedagogicalConfigurationDraft pedagogicalConfiguration =
      const ActivityPedagogicalConfigurationDraft.disabled();
  bool _aboutDirty = false;

  void setAboutPage(ProfileAboutPage page, {bool markDirty = true}) {
    aboutPage = page;
    if (markDirty) _aboutDirty = true;
    notifyListeners();
  }

  ActivityTaxonomyOption? taxonomy;
  ActivityTaxonomySubtypeOption? subtype;
  ActivityTemplateOption? template;
  ActivityGovernance governance = ActivityGovernance.optional;
  String? selectedInstitutionId;
  final Set<String> selectedUnitIds = {};
  String? selectedLocationId;
  CataloguedLocationSelection? _cataloguedLocationSelection;
  ActivityCreateReservationIntent? _locationReservation;
  CataloguedLocationSelection? get cataloguedLocationSelection => _cataloguedLocationSelection;
  ActivityCreateReservationIntent? get locationReservation => _locationReservation;

  bool _matchesLocationOwner(CataloguedLocationSelection selection) {
    final scope = selection.snapshot.scope;
    return scope.institutionId == selectedInstitutionId &&
        (scope is InstitutionLocationScope ||
            scope is UnitLocationScope && selectedUnitIds.contains(scope.unitId));
  }

  void selectCataloguedLocation(CataloguedLocationSelection? selection) {
    if (isSubmitting) return;
    if (isEditing) throw StateError('Catalogued selection editing is unavailable');
    if (selection != null && !_matchesLocationOwner(selection)) {
      throw ArgumentError('Location owner mismatch');
    }
    _cataloguedLocationSelection = selection;
    _locationReservation = null;
    selectedLocationId = null;
    notifyListeners();
  }

  void setLocationReservation(ActivityCreateReservationIntent? reservation) {
    if (isSubmitting) return;
    if (isEditing || reservation != null && _cataloguedLocationSelection == null) {
      throw StateError('A catalogued create selection is required');
    }
    _locationReservation = reservation;
    notifyListeners();
  }

  void _clearCataloguedLocation() {
    _cataloguedLocationSelection = null;
    _locationReservation = null;
  }

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
  String? pedagogicalError;
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
  bool get isDirty => _aboutDirty || _signature != _baseline;
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

  /// A v2 guarda em taxonomy_id o no escolhido na arvore legada, que pode ser
  /// um subtipo: quando nao ha categoria com esse id, sobe ao pai para a
  /// categoria e o subtipo baterem.
  void _hydrateTaxonomy(String? taxonomyId, String? subtypeId) {
    taxonomy = options.taxonomy.where((item) => item.id == taxonomyId).firstOrNull;
    subtype = taxonomy?.subtypes.where((item) => item.id == subtypeId).firstOrNull;
    if (taxonomy != null) return;
    for (final parent in options.taxonomy) {
      final child = parent.subtypes.where((item) => item.id == taxonomyId).firstOrNull;
      if (child != null) {
        taxonomy = parent;
        subtype = child;
        return;
      }
    }
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
      final source = detail;
      if (taxonomy == null && source != null) {
        _hydrateTaxonomy(source.taxonomyId, source.subtypeId);
      }
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

  String get commandSignature => jsonEncode([
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
    selectedUnitIds.toList()..sort(),
    selectedLocationId ?? '',
    _cataloguedLocationSelection?.snapshot.id,
    _locationReservation?.toJson(),
    selectedGroupIds.toList()..sort(),
    _commandAssignmentSignature,
    imageName ?? '',
    identityHashCode(imageBytes),
    identityStorageRef?.bucket ?? '',
    identityStorageRef?.path ?? '',
    identityColor,
    identityIcon.name,
    (groupParticipation.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        .map((entry) => [entry.key, entry.value.name])
        .toList(growable: false),
    (studentSelection.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        .map((entry) => [entry.key, entry.value])
        .toList(growable: false),
    pedagogicalConfiguration.toJson(),
    identityHashCode(aboutPage),
    expectedManagementVersion,
  ]);

  List<List<Object?>> get _commandAssignmentSignature {
    final signature = assignments
        .map(
          (item) => <Object?>[
            item.groupId,
            item.professionalId,
            item.role.name,
            item.permissions.happens.name,
            item.permissions.now.name,
            item.permissions.moments.name,
            item.permissions.chat.name,
            item.permissions.attendance.name,
          ],
        )
        .toList();
    signature.sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
    return signature;
  }

  String get _signature => '${currentStep.name}|$commandSignature';

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
      pedagogicalConfiguration = initialDraft.pedagogicalConfiguration;
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

    if (source.pedagogicalConfiguration case final configuration?) {
      pedagogicalConfiguration = ActivityPedagogicalConfigurationDraft.fromJson(configuration);
    }
    _hydrateTaxonomy(source.taxonomyId, source.subtypeId);
    template = options.templates.where((item) => item.id == source.templateId).firstOrNull;
    otherActivity.text = source.taxonomyOtherDescription;
    initials.text = source.identity.initials ?? '';
    identityColor = source.identity.color ?? identityColor;
    identityIcon = ActivityIdentityIcon.fromDatabaseKey(source.identity.icon) ?? identityIcon;
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
    handleStem.addListener(_scheduleHandleCheck);
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
    if (selectedInstitutionId != institutionId) _clearCataloguedLocation();
    selectedInstitutionId = institutionId;
    if (!preserveSelection) {
      selectedUnitIds.clear();
      selectedGroupIds.clear();
      groupParticipation.clear();
      studentSelection.clear();
      assignments.clear();
      selectedLocationId = null;
      _clearCataloguedLocation();
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
    final selection = _cataloguedLocationSelection;
    if (selection != null && !_matchesLocationOwner(selection)) _clearCataloguedLocation();
    unitsError = null;
    notifyListeners();
  }

  void selectLocation(String? locationId) {
    _clearCataloguedLocation();
    selectedLocationId = locationId?.isEmpty == true ? null : locationId;
    notifyListeners();
  }

  void addLocations(List<ActivityFormLocationOption> locations) {
    _clearCataloguedLocation();
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

  void setPedagogicalConfiguration(ActivityPedagogicalConfigurationDraft value) {
    pedagogicalConfiguration = value;
    pedagogicalError = null;
    notifyListeners();
  }

  void previousStep() => goToStep(currentStep.index - 1);

  bool continueFromCurrentStep() {
    final valid = switch (currentStep) {
      ActivityFormStep.identity => _identityValid(setErrors: true),
      ActivityFormStep.structure => _draftValid(setErrors: true),
      ActivityFormStep.pedagogical => _pedagogicalValid(setErrors: true),
      ActivityFormStep.links => _completionValid(setErrors: true),
      ActivityFormStep.about => true,
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
    final pedagogicalValid = _pedagogicalValid(setErrors: setErrors);
    final validGroups = selectedGroupIds.isNotEmpty;
    if (setErrors) groupsError = validGroups ? null : 'Selecione ao menos uma turma.';
    return draftValid && pedagogicalValid && validGroups;
  }

  bool _pedagogicalValid({required bool setErrors}) {
    final valid = pedagogicalConfiguration.isValid;
    if (setErrors) {
      pedagogicalError = valid
          ? null
          : 'Revise a configuração pedagógica, as datas, os horários e os pesos.';
    }
    return valid;
  }

  ActivityFormDraft toDraft({String? requestId, String? commandSignature}) => ActivityFormDraft(
    requestId: requestId,
    commandSignature: commandSignature,
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
    locationId: _cataloguedLocationSelection?.snapshot.id ?? selectedLocationId,
    locationSelection: _cataloguedLocationSelection,
    reservation: _locationReservation,
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
    aboutPage: aboutPage,
    pedagogicalConfiguration: pedagogicalConfiguration,
    expectedManagementVersion: expectedManagementVersion,
  );

  void setSubmitting(bool value) {
    isSubmitting = value;
    notifyListeners();
  }

  void markSubmitted() {
    _baseline = _signature;
    _aboutDirty = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _handleCheckTimer?.cancel();
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
