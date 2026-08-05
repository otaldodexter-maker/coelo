import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../domain/activity_directory.dart';
import 'activity_form_draft.dart';

enum ActivityFormStep { identity, structure, links, professionals }

final class ActivityFormController extends ChangeNotifier {
  ActivityFormController.create(this.options, {String? initialInstitutionId, String? initialUnitId})
    : isEditing = false,
      detail = null,
      name = TextEditingController(),
      description = TextEditingController(),
      otherActivity = TextEditingController(),
      selectedInstitutionId = initialInstitutionId {
    if (initialUnitId != null && units.any((unit) => unit.id == initialUnitId)) {
      selectedUnitIds.add(initialUnitId);
    }
    _listen();
    _baseline = _signature;
  }

  ActivityFormController.edit(
    this.options,
    ActivityDetail source, {
    ActivityFormDraft? initialDraft,
  }) : isEditing = true,
       detail = source,
       name = TextEditingController(text: initialDraft?.name ?? source.item.name),
       description = TextEditingController(
         text: initialDraft?.description ?? source.item.description ?? '',
       ),
       otherActivity = TextEditingController(),
       selectedInstitutionId = initialDraft?.institutionId ?? source.item.institutionId,
       governance = initialDraft?.governance ?? source.item.governance {
    _hydrateEdit(source, initialDraft);
    _listen();
    _baseline = _signature;
  }

  final ActivityFormOptions options;
  final ActivityDetail? detail;
  final bool isEditing;
  final TextEditingController name;
  final TextEditingController description;
  final TextEditingController otherActivity;

  ActivityFormStep currentStep = ActivityFormStep.identity;
  ActivityCategory? category;
  String? selectedActivitySuggestion;
  ActivityGovernance governance = ActivityGovernance.optional;
  String? selectedInstitutionId;
  final Set<String> selectedUnitIds = {};
  String? selectedLocationId;
  final Set<String> selectedGroupIds = {};
  final List<ActivityProfessionalAssignment> assignments = [];
  final List<ActivityFormLocationOption> _sessionLocations = [];
  Uint8List? imageBytes;
  String? imageName;
  String? nameError;
  String? institutionError;
  String? unitsError;
  String? groupsError;
  bool isSubmitting = false;
  late String _baseline;

  bool get institutionLocked => isEditing;
  bool get governanceLocked => governance == ActivityGovernance.fixed;
  bool get isDirty => _signature != _baseline;
  bool get isFirstStep => currentStep == ActivityFormStep.identity;
  bool get isLastStep => currentStep == ActivityFormStep.professionals;
  bool get canSaveDraft => _draftValid(setErrors: false);
  bool get canComplete => _completionValid(setErrors: false);

  List<String> get activitySuggestions => category?.suggestions ?? const [];
  String get activityLabel => selectedActivitySuggestion == 'Outro'
      ? otherActivity.text.trim()
      : selectedActivitySuggestion ?? '';

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
    description.text.trim(),
    otherActivity.text.trim(),
    category?.name ?? '',
    selectedActivitySuggestion ?? '',
    governance.name,
    selectedInstitutionId ?? '',
    (selectedUnitIds.toList()..sort()).join(','),
    selectedLocationId ?? '',
    (selectedGroupIds.toList()..sort()).join(','),
    assignments
        .map(
          (item) =>
              '${item.groupId}:${item.professionalId}:'
              '${item.permissions.happens}:${item.permissions.now}:'
              '${item.permissions.moments}:${item.permissions.chat}',
        )
        .toList()
      ..sort(),
    imageName ?? '',
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
      category = initialDraft.category;
      if (category != null && initialDraft.activityLabel.isNotEmpty) {
        if (category!.suggestions.contains(initialDraft.activityLabel)) {
          selectedActivitySuggestion = initialDraft.activityLabel;
        } else {
          selectedActivitySuggestion = 'Outro';
          otherActivity.text = initialDraft.activityLabel;
        }
      }

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
          final key = '${assignment.groupId}:${assignment.professionalId}';
          return selectedGroupIds.contains(assignment.groupId) &&
              options.professionals.any(
                (professional) => professional.id == assignment.professionalId,
              ) &&
              assignmentKeys.add(key);
        }),
      );
      imageBytes = initialDraft.imageBytes;
      imageName = initialDraft.imageName;
      return;
    }

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
      if (match != null) selectedGroupIds.add(match.id);
    }
  }

  void _listen() {
    name.addListener(_changed);
    description.addListener(_changed);
    otherActivity.addListener(_changed);
  }

  void _changed() => notifyListeners();

  void selectCategory(ActivityCategory value) {
    category = value;
    selectedActivitySuggestion = null;
    otherActivity.clear();
    notifyListeners();
  }

  void selectActivitySuggestion(String value) {
    selectedActivitySuggestion = value;
    if (value != 'Outro') otherActivity.clear();
    notifyListeners();
  }

  void selectGovernance(ActivityGovernance value) {
    if (governanceLocked) return;
    governance = value;
    notifyListeners();
  }

  void selectInstitution(String institutionId) {
    if (institutionLocked) return;
    selectedInstitutionId = institutionId;
    selectedUnitIds.clear();
    selectedGroupIds.clear();
    assignments.clear();
    selectedLocationId = null;
    institutionError = null;
    unitsError = null;
    groupsError = null;
    notifyListeners();
  }

  void toggleUnit(String unitId) {
    if (!units.any((unit) => unit.id == unitId)) return;
    if (!selectedUnitIds.add(unitId)) selectedUnitIds.remove(unitId);
    selectedGroupIds.removeWhere((groupId) => !groups.any((group) => group.id == groupId));
    assignments.removeWhere((assignment) => !selectedGroupIds.contains(assignment.groupId));
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

  void addLocation(ActivityFormLocationOption location) {
    _sessionLocations.add(location);
    selectedLocationId = location.id;
    notifyListeners();
  }

  void toggleGroup(String groupId) {
    if (!groups.any((group) => group.id == groupId)) return;
    if (!selectedGroupIds.add(groupId)) {
      selectedGroupIds.remove(groupId);
      assignments.removeWhere((assignment) => assignment.groupId == groupId);
    }
    groupsError = null;
    notifyListeners();
  }

  void toggleProfessional(String groupId, String professionalId) {
    if (!selectedGroupIds.contains(groupId) ||
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
        ActivityProfessionalAssignment(groupId: groupId, professionalId: professionalId),
      );
    }
    notifyListeners();
  }

  void setPermission(
    String groupId,
    String professionalId, {
    bool? happens,
    bool? now,
    bool? moments,
    bool? chat,
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
      ),
    );
    notifyListeners();
  }

  void setImage({required String name, required Uint8List bytes}) {
    imageName = name;
    imageBytes = bytes;
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
    if (setErrors) nameError = validName ? null : 'Informe o nome da atividade.';
    return validName;
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
    description: description.text.trim(),
    category: category,
    activityLabel: activityLabel,
    governance: governance,
    institutionId: selectedInstitutionId!,
    unitIds: Set.unmodifiable(selectedUnitIds),
    locationId: selectedLocationId,
    groupIds: Set.unmodifiable(selectedGroupIds),
    assignments: List.unmodifiable(assignments),
    imageName: imageName,
    imageBytes: imageBytes,
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
    description
      ..removeListener(_changed)
      ..dispose();
    otherActivity
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }
}
