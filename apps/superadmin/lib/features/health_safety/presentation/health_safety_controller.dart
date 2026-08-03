import 'package:flutter/foundation.dart';

import '../data/demo_health_safety_repository.dart';
import '../domain/health_safety.dart';

enum HealthSafetyLoadState { loading, ready, empty, noResults, error, unauthorized, minimized }

enum HealthSafetyDirectoryDisplay { cards, table }

final class HealthSafetyController extends ChangeNotifier {
  HealthSafetyController(this.repository, {HealthSafetyActor? actor})
    : _actor =
          actor ??
          HealthSafetyActor(
            id: 'owner-demo',
            profile: DemoHealthSafetyProfile.owner,
            authorizedChildIds: const {'child-demo-a', 'child-demo-b'},
          );

  final DemoHealthSafetyRepository repository;
  final HealthSafetyActor _actor;
  HealthSafetyDirectoryQuery _query = const HealthSafetyDirectoryQuery(pageSize: 11);
  HealthSafetyDirectoryPage? _page;
  HealthSafetyChild? _detail;
  HealthSafetyLoadState _state = HealthSafetyLoadState.loading;
  HealthSafetyDirectoryDisplay _display = HealthSafetyDirectoryDisplay.cards;
  Object? _error;

  DemoHealthSafetyProfile get profile => _actor.profile;
  HealthSafetyDirectoryQuery get query => _query;
  HealthSafetyDirectoryPage? get page => _page;
  List<HealthSafetyChildSummary> get items => _page?.items ?? const [];
  HealthSafetyChild? get detail => _detail;
  HealthSafetyLoadState get state => _state;
  HealthSafetyDirectoryDisplay get display => _display;
  Object? get error => _error;
  bool get canReadSensitive => _actor.can(HealthSafetyCapability.sensitiveRead);
  bool get canEdit => _actor.can(HealthSafetyCapability.recordCreateEdit);
  bool get isReadOnly => !canEdit;
  int get totalPages {
    final total = _page?.totalCount ?? 0;
    return total == 0 ? 1 : (total / _query.pageSize).ceil();
  }

  HealthSafetyActor get actor => _actor;
  Set<String> get availableUnitIds => _query.institutionIds.isEmpty
      ? const {}
      : _unitInstitution.entries
            .where((entry) => _query.institutionIds.contains(entry.value))
            .map((entry) => entry.key)
            .toSet();
  Set<String> get availableGroupIds => _query.unitIds.isEmpty
      ? const {}
      : _groupUnit.entries
            .where((entry) => _query.unitIds.contains(entry.value))
            .map((entry) => entry.key)
            .toSet();

  Future<void> load() async {
    _state = HealthSafetyLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      _page = await repository.fetchDirectory(_query, actor: actor);
      _state = profile == DemoHealthSafetyProfile.minimized
          ? HealthSafetyLoadState.minimized
          : (_page!.items.isEmpty
                ? (_hasFilters ? HealthSafetyLoadState.noResults : HealthSafetyLoadState.empty)
                : HealthSafetyLoadState.ready);
    } on Object catch (error) {
      _error = error;
      _state = HealthSafetyLoadState.error;
    }
    notifyListeners();
  }

  Future<void> loadDetail(String childId) async {
    _detail = null;
    if (!canReadSensitive) {
      _state = HealthSafetyLoadState.minimized;
      notifyListeners();
      return;
    }
    _state = HealthSafetyLoadState.loading;
    notifyListeners();
    try {
      _detail = await repository.findChild(childId, actor: actor);
      _state = _detail == null ? HealthSafetyLoadState.empty : HealthSafetyLoadState.ready;
    } on StateError catch (error) {
      _error = error;
      _state = HealthSafetyLoadState.unauthorized;
    } on Object catch (error) {
      _error = error;
      _state = HealthSafetyLoadState.error;
    }
    notifyListeners();
  }

  Future<void> setProfile(DemoHealthSafetyProfile value) async {
    if (value != profile) throw StateError('The authenticated actor profile cannot be changed.');
  }

  void setDisplay(HealthSafetyDirectoryDisplay value) {
    _display = value;
    final size = value == HealthSafetyDirectoryDisplay.cards ? 11 : 8;
    _query = _copy(page: 0, pageSize: size);
    notifyListeners();
    load();
  }

  Future<void> setSearch(String value) => _replace(_copy(search: value, page: 0));
  Future<void> setPersonIds(Set<String> value) => _replace(_copy(personIds: value, page: 0));
  Future<void> setChildIds(Set<String> value) => _replace(_copy(childIds: value, page: 0));
  Future<void> setInstitutionIds(Set<String> value) async {
    final validUnits = value.isEmpty
        ? <String>{}
        : _query.unitIds.where((id) {
            final parent = _unitInstitution[id];
            return parent != null && value.contains(parent);
          }).toSet();
    final validGroups = _query.groupOrActivityIds.where((id) {
      final parent = _groupUnit[id];
      return parent != null && validUnits.contains(parent);
    }).toSet();
    await _replace(
      _copy(institutionIds: value, unitIds: validUnits, groupOrActivityIds: validGroups, page: 0),
    );
  }

  Future<void> setUnitIds(Set<String> value) async {
    final allowed = _query.institutionIds.isEmpty
        ? <String>{}
        : value.where((id) {
            final parent = _unitInstitution[id];
            return parent != null && _query.institutionIds.contains(parent);
          }).toSet();
    final groups = _query.groupOrActivityIds.where((id) {
      final parent = _groupUnit[id];
      return parent != null && allowed.contains(parent);
    }).toSet();
    await _replace(_copy(unitIds: allowed, groupOrActivityIds: groups, page: 0));
  }

  Future<void> setGroupIds(Set<String> value) {
    final allowed = _query.unitIds.isEmpty
        ? <String>{}
        : value.where((id) {
            final parent = _groupUnit[id];
            return parent != null && _query.unitIds.contains(parent);
          }).toSet();
    return _replace(_copy(groupOrActivityIds: allowed, page: 0));
  }

  Future<void> setStatuses(Set<HealthSafetyOperationalStatus> value) =>
      _replace(_copy(operationalStatuses: value, page: 0));
  Future<void> setDoseSituations(Set<HealthMedicationDoseSituation> value) =>
      _replace(_copy(doseSituations: value, page: 0));
  Future<void> setPage(int value) => _replace(_copy(page: value));
  Future<void> setPageSize(int value) => _replace(_copy(page: 0, pageSize: value));

  Future<void> _replace(HealthSafetyDirectoryQuery value) async {
    _query = value;
    await load();
  }

  bool get _hasFilters =>
      _query.search.trim().isNotEmpty ||
      _query.personIds.isNotEmpty ||
      _query.childIds.isNotEmpty ||
      _query.institutionIds.isNotEmpty ||
      _query.unitIds.isNotEmpty ||
      _query.groupOrActivityIds.isNotEmpty ||
      _query.operationalStatuses.isNotEmpty ||
      _query.doseSituations.isNotEmpty;

  HealthSafetyDirectoryQuery _copy({
    String? search,
    Set<String>? personIds,
    Set<String>? childIds,
    Set<String>? institutionIds,
    Set<String>? unitIds,
    Set<String>? groupOrActivityIds,
    Set<HealthSafetyOperationalStatus>? operationalStatuses,
    Set<HealthMedicationDoseSituation>? doseSituations,
    int? page,
    int? pageSize,
  }) => HealthSafetyDirectoryQuery(
    search: search ?? _query.search,
    personIds: personIds ?? _query.personIds,
    childIds: childIds ?? _query.childIds,
    institutionIds: institutionIds ?? _query.institutionIds,
    unitIds: unitIds ?? _query.unitIds,
    groupOrActivityIds: groupOrActivityIds ?? _query.groupOrActivityIds,
    operationalStatuses: operationalStatuses ?? _query.operationalStatuses,
    doseSituations: doseSituations ?? _query.doseSituations,
    page: page ?? _query.page,
    pageSize: pageSize ?? _query.pageSize,
  );

  static const _unitInstitution = {
    'unit-demo-a': 'institution-demo-a',
    'unit-demo-b': 'institution-demo-b',
  };
  static const _groupUnit = {'group-demo-a': 'unit-demo-a', 'group-demo-b': 'unit-demo-b'};

  Future<void> correctMedication(HealthMedicationCorrectionCommand command) async {
    await repository.changeMedicationRelevant(
      childId: command.childId,
      medicationId: command.medicationId,
      name: command.name,
      justification: command.justification,
      actor: actor,
    );
    await loadDetail(command.childId);
  }

  Future<void> createMedication(HealthMedicationCreateCommand command) async {
    await repository.createMedication(
      childId: command.childId,
      name: command.name,
      dose: command.dose,
      doseUnit: command.doseUnit,
      route: command.route,
      startsAt: command.startsAt,
      endsAt: command.endsAt,
      schedules: command.schedules,
      documentName: command.documentName,
      documentType: command.documentType,
      actor: actor,
    );
    await loadDetail(command.childId);
  }

  Future<void> createAllergy(HealthAllergyCreateCommand command) async {
    await repository.createAllergy(
      childId: command.childId,
      label: command.label,
      type: command.type,
      actor: actor,
    );
    await loadDetail(command.childId);
  }

  Future<void> inactivateAllergy(HealthAllergyInactivationCommand command) async {
    await repository.deactivateAllergy(
      childId: command.childId,
      allergyId: command.allergyId,
      justification: command.justification,
      actor: actor,
    );
    await loadDetail(command.childId);
  }

  Future<void> updateCareProfile(HealthCareProfileUpdateCommand command) async {
    await repository.updateCareProfile(
      childId: command.childId,
      items: command.items,
      justification: command.justification,
      actor: actor,
    );
    await loadDetail(command.childId);
  }
}

final class HealthMedicationCreateCommand {
  HealthMedicationCreateCommand({
    required this.childId,
    required this.name,
    required this.dose,
    required this.doseUnit,
    required this.route,
    required this.startsAt,
    required this.endsAt,
    required List<HealthMedicationSchedule> schedules,
    this.documentName,
    this.documentType,
  }) : schedules = List.unmodifiable(schedules);

  final String childId;
  final String name;
  final String dose;
  final String doseUnit;
  final String route;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<HealthMedicationSchedule> schedules;
  final String? documentName;
  final String? documentType;
}

final class HealthAllergyCreateCommand {
  HealthAllergyCreateCommand({required this.childId, required this.label, required this.type}) {
    if (label.trim().isEmpty) throw ArgumentError('Allergy label is required.');
  }

  final String childId;
  final String label;
  final HealthSafetyAllergyType type;
}

final class HealthMedicationCorrectionCommand {
  HealthMedicationCorrectionCommand({
    required this.childId,
    required this.medicationId,
    required this.name,
    required this.justification,
  }) {
    if (name.trim().isEmpty) throw ArgumentError('Medication name is required.');
    if (justification.trim().isEmpty) {
      throw ArgumentError('Owner correction justification is required.');
    }
  }
  final String childId;
  final String medicationId;
  final String name;
  final String justification;
}

final class HealthAllergyInactivationCommand {
  HealthAllergyInactivationCommand({
    required this.childId,
    required this.allergyId,
    required this.justification,
  }) {
    if (justification.trim().isEmpty) {
      throw ArgumentError('Owner allergy justification is required.');
    }
  }
  final String childId;
  final String allergyId;
  final String justification;
}

final class HealthCareProfileUpdateCommand {
  HealthCareProfileUpdateCommand({
    required this.childId,
    required this.items,
    required this.justification,
  }) {
    if (justification.trim().isEmpty) {
      throw ArgumentError('Owner care profile justification is required.');
    }
  }
  final String childId;
  final List<HealthSafetyCareProfileItem> items;
  final String justification;
}
