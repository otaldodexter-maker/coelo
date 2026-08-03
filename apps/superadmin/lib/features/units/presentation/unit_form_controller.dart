import 'package:flutter/widgets.dart';

enum UnitFormStep {
  branding('Identidade'),
  profile('Hierarquia'),
  location('Localização'),
  plan('Plano'),
  review('Revisão');

  const UnitFormStep(this.label);

  final String label;
}

enum UnitFormStepStatus { current, complete, error, incomplete }

enum UnitFormLoadStatus { ready, loading, missing, unauthorized, failure }

/// State that belongs to the Unit form composition, without becoming a public
/// UI package contract.
final class UnitFormController extends ChangeNotifier {
  UnitFormController({required this.isEditing});

  final bool isEditing;

  UnitFormStep _currentStep = UnitFormStep.branding;
  bool _isDirty = false;
  bool _isSaving = false;
  UnitFormLoadStatus _loadStatus = UnitFormLoadStatus.ready;
  String? _saveError;
  final Set<UnitFormStep> _errorSteps = {};

  UnitFormStep get currentStep => _currentStep;
  bool get isDirty => _isDirty;
  bool get isSaving => _isSaving;
  UnitFormLoadStatus get loadStatus => _loadStatus;
  String? get saveError => _saveError;

  UnitFormStepStatus statusOf(UnitFormStep step) {
    if (_errorSteps.contains(step)) {
      return UnitFormStepStatus.error;
    }
    if (step == _currentStep) {
      return UnitFormStepStatus.current;
    }
    if (isEditing) {
      return UnitFormStepStatus.complete;
    }
    return step.index < _currentStep.index
        ? UnitFormStepStatus.complete
        : UnitFormStepStatus.incomplete;
  }

  void selectStep(UnitFormStep step) {
    if (_currentStep == step) {
      return;
    }
    _currentStep = step;
    notifyListeners();
  }

  void nextStep() {
    final next = _currentStep.index + 1;
    if (next < UnitFormStep.values.length) {
      selectStep(UnitFormStep.values[next]);
    }
  }

  void previousStep() {
    final previous = _currentStep.index - 1;
    if (previous >= 0) {
      selectStep(UnitFormStep.values[previous]);
    }
  }

  void markDirty() {
    if (_isDirty) {
      return;
    }
    _isDirty = true;
    notifyListeners();
  }

  void setSaving(bool value) {
    if (_isSaving == value) {
      return;
    }
    _isSaving = value;
    notifyListeners();
  }

  void markSaved() {
    _isDirty = false;
    notifyListeners();
  }

  bool validateCurrentStep(GlobalKey<FormState> formKey) {
    if (_currentStep != UnitFormStep.profile && _currentStep != UnitFormStep.location) {
      return true;
    }
    final valid = formKey.currentState?.validate() ?? false;
    _setStepError(_currentStep, !valid);
    return valid;
  }

  bool validateForSave({
    required GlobalKey<FormState> profileFormKey,
    required GlobalKey<FormState> locationFormKey,
  }) {
    final profileValid = profileFormKey.currentState?.validate() ?? false;
    final locationValid = locationFormKey.currentState?.validate() ?? false;
    _setStepError(UnitFormStep.profile, !profileValid);
    _setStepError(UnitFormStep.location, !locationValid);
    if (!profileValid) {
      selectStep(UnitFormStep.profile);
    } else if (!locationValid) {
      selectStep(UnitFormStep.location);
    }
    return profileValid && locationValid;
  }

  void setLoadStatus(UnitFormLoadStatus value) {
    if (_loadStatus == value) {
      return;
    }
    _loadStatus = value;
    notifyListeners();
  }

  void setSaveError(String? value) {
    if (_saveError == value) {
      return;
    }
    _saveError = value;
    notifyListeners();
  }

  void _setStepError(UnitFormStep step, bool hasError) {
    final changed = hasError ? _errorSteps.add(step) : _errorSteps.remove(step);
    if (changed) notifyListeners();
  }
}
