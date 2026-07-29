import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../domain/activity_directory.dart';

final class ActivityFormController extends ChangeNotifier {
  ActivityFormController.create(this.options)
    : isEditing = false,
      detail = null,
      name = TextEditingController(),
      description = TextEditingController() {
    _listen();
    _baseline = _signature;
  }

  ActivityFormController.edit(this.options, ActivityDetail source)
    : isEditing = true,
      detail = source,
      name = TextEditingController(text: source.item.name),
      description = TextEditingController(text: source.item.description ?? '') {
    _listen();
    _baseline = _signature;
  }

  final ActivityFormOptions options;
  final ActivityDetail? detail;
  final bool isEditing;
  final TextEditingController name;
  final TextEditingController description;

  String? selectedInstitutionId;
  String? selectedUnitId;
  String? nameError;
  String? institutionError;
  String? unitError;
  bool isSubmitting = false;
  late String _baseline;

  List<ActivityFormUnitOption> get units => selectedInstitutionId == null
      ? const []
      : options.unitsFor(selectedInstitutionId!);

  bool get isDirty => _signature != _baseline;

  String get _signature => [
    name.text.trim(),
    description.text.trim(),
    selectedInstitutionId ?? '',
    selectedUnitId ?? '',
  ].join('|');

  void _listen() {
    name.addListener(_changed);
    description.addListener(_changed);
  }

  void _changed() => notifyListeners();

  void selectInstitution(String institutionId) {
    selectedInstitutionId = institutionId;
    if (!units.any((unit) => unit.id == selectedUnitId)) {
      selectedUnitId = null;
    }
    institutionError = null;
    unitError = null;
    notifyListeners();
  }

  void selectUnit(String unitId) {
    selectedUnitId = unitId;
    unitError = null;
    notifyListeners();
  }

  bool validate() {
    nameError = name.text.trim().isEmpty ? 'Informe o nome da atividade.' : null;
    institutionError =
        !isEditing && selectedInstitutionId == null ? 'Selecione a instituição.' : null;
    unitError = !isEditing && selectedUnitId == null ? 'Selecione a unidade inicial.' : null;
    notifyListeners();
    return nameError == null && institutionError == null && unitError == null;
  }

  void setSubmitting(bool value) {
    if (isSubmitting == value) return;
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
    super.dispose();
  }
}
