import 'package:flutter/foundation.dart';
import 'assessment.dart';

sealed class AssessmentState {
  const AssessmentState();
}

final class AssessmentInitial extends AssessmentState {
  const AssessmentInitial();
}

final class AssessmentLoading extends AssessmentState {
  const AssessmentLoading();
}

final class AssessmentReady extends AssessmentState {
  const AssessmentReady(this.gradebook);
  final AssessmentGradebook gradebook;
}

final class AssessmentEmpty extends AssessmentState {
  const AssessmentEmpty();
}

final class AssessmentUnauthorized extends AssessmentState {
  const AssessmentUnauthorized();
}

final class AssessmentConflict extends AssessmentState {
  const AssessmentConflict();
}

final class AssessmentOffline extends AssessmentState {
  const AssessmentOffline([this.gradebook]);
  final AssessmentGradebook? gradebook;
}

final class AssessmentFailure extends AssessmentState {
  const AssessmentFailure(this.error);
  final Object error;
}

final class AssessmentController extends ChangeNotifier {
  AssessmentController(this.repository);
  final AssessmentRepository repository;
  AssessmentState _state = const AssessmentInitial();
  int _step = 0, _selectedStudentIndex = 0;
  bool _recoveredDraft = false, _saving = false;
  bool _disposed = false;
  int _loadGeneration = 0, _commandGeneration = 0;
  Future<AssessmentGradebook>? _commandInFlight;
  AssessmentState get state => _state;
  int get step => _step;
  int get selectedStudentIndex => _selectedStudentIndex;
  bool get recoveredDraft => _recoveredDraft;
  bool get saving => _saving;
  AssessmentGradebook? get gradebook => switch (_state) {
    AssessmentReady(:final gradebook) => gradebook,
    AssessmentOffline(:final gradebook) => gradebook,
    _ => null,
  };
  AssessmentStudentEntry? get selectedStudent {
    final book = gradebook;
    return book == null || book.students.isEmpty ? null : book.students[_selectedStudentIndex];
  }

  Future<void> loadGradebook(String id) async {
    final generation = _beginLoad();
    try {
      final value = await repository.fetchGradebook(id);
      if (!_isCurrentLoad(generation)) return;
      if (value == null) {
        _emit(const AssessmentEmpty());
        return;
      }
      _recoveredDraft = value.status == AssessmentGradebookStatus.draft;
      _emit(AssessmentReady(value));
    } on AssessmentUnauthorizedException {
      if (!_isCurrentLoad(generation)) return;
      _emit(const AssessmentUnauthorized());
    } on AssessmentOfflineException {
      if (!_isCurrentLoad(generation)) return;
      _emit(const AssessmentOffline());
    } on Exception catch (error) {
      if (!_isCurrentLoad(generation)) return;
      _emit(AssessmentFailure(error));
    }
  }

  Future<void> start(AssessmentContext context, AssessmentConfiguration configuration) async {
    final generation = _beginLoad();
    try {
      final value = await repository.createOrResumeGradebook(context, configuration);
      if (!_isCurrentLoad(generation)) return;
      _recoveredDraft = value.version > 1;
      _emit(AssessmentReady(value));
    } on AssessmentUnauthorizedException {
      if (!_isCurrentLoad(generation)) return;
      _emit(const AssessmentUnauthorized());
    } on AssessmentOfflineException {
      if (!_isCurrentLoad(generation)) return;
      _emit(const AssessmentOffline());
    } on Exception catch (error) {
      if (!_isCurrentLoad(generation)) return;
      _emit(AssessmentFailure(error));
    }
  }

  void goToStep(int value) {
    if (_disposed) return;
    if (value >= 0 && value < 4) {
      _step = value;
      _notify();
    }
  }

  void nextStep() {
    if (_disposed) return;
    if (_step < 3) {
      _step++;
      _notify();
    }
  }

  void previousStep() {
    if (_disposed) return;
    if (_step > 0) {
      _step--;
      _notify();
    }
  }

  void nextStudent() {
    if (_disposed) return;
    final count = gradebook?.students.length ?? 0;
    if (_selectedStudentIndex < count - 1) {
      _selectedStudentIndex++;
      _notify();
    }
  }

  void previousStudent() {
    if (_disposed) return;
    if (_selectedStudentIndex > 0) {
      _selectedStudentIndex--;
      _notify();
    }
  }

  void updateStudent(AssessmentStudentEntry value) {
    if (_disposed) return;
    final book = gradebook;
    if (book == null) return;
    final students = [...book.students];
    final index = students.indexWhere((item) => item.id == value.id);
    if (index < 0) return;
    students[index] = value;
    _emit(AssessmentReady(book.copyWith(students: students)));
  }

  Future<AssessmentGradebook> saveDraft({String? reason}) =>
      _run((book) => repository.saveGradebook(book, reason: reason));
  Future<AssessmentGradebook> submit() => _run(repository.submitGradebook);
  Future<AssessmentGradebook> transition(AssessmentClosingAction action, String reason) {
    if (reason.trim().isEmpty) throw ArgumentError.value(reason, 'reason');
    return _run((book) => repository.transitionGradebook(book, action, reason.trim()));
  }

  Future<AssessmentGradebook> schedulePublication(DateTime publishAt, String reason) {
    if (reason.trim().isEmpty) throw ArgumentError.value(reason, 'reason');
    return _run((book) => repository.schedulePublication(book, publishAt, reason.trim()));
  }

  Future<AssessmentGradebook> _run(
    Future<AssessmentGradebook> Function(AssessmentGradebook) operation,
  ) {
    if (_disposed) throw StateError('Controller descartado.');
    if (_commandInFlight case final current?) return current;
    late final Future<AssessmentGradebook> future;
    future = _execute(operation).whenComplete(() {
      if (identical(_commandInFlight, future)) _commandInFlight = null;
    });
    _commandInFlight = future;
    return future;
  }

  Future<AssessmentGradebook> _execute(
    Future<AssessmentGradebook> Function(AssessmentGradebook) operation,
  ) async {
    final book = gradebook;
    if (book == null) throw StateError('Diário não carregado.');
    final generation = ++_commandGeneration;
    _saving = true;
    _notify();
    try {
      final saved = await operation(book);
      if (!_isCurrentCommand(generation)) return saved;
      _emit(AssessmentReady(saved));
      return saved;
    } on AssessmentVersionConflictException {
      if (!_isCurrentCommand(generation)) rethrow;
      _emit(const AssessmentConflict());
      rethrow;
    } on AssessmentUnauthorizedException {
      if (!_isCurrentCommand(generation)) rethrow;
      _emit(const AssessmentUnauthorized());
      rethrow;
    } on AssessmentOfflineException {
      if (!_isCurrentCommand(generation)) rethrow;
      _emit(AssessmentOffline(book));
      rethrow;
    } on Exception catch (error) {
      if (!_isCurrentCommand(generation)) rethrow;
      _emit(AssessmentFailure(error));
      rethrow;
    } finally {
      if (_isCurrentCommand(generation)) {
        _saving = false;
        _notify();
      }
    }
  }

  int _beginLoad() {
    final generation = ++_loadGeneration;
    _commandGeneration++;
    _commandInFlight = null;
    _clearSensitiveState();
    _emit(const AssessmentLoading());
    return generation;
  }

  bool _isCurrentLoad(int generation) => !_disposed && generation == _loadGeneration;
  bool _isCurrentCommand(int generation) => !_disposed && generation == _commandGeneration;

  void _clearSensitiveState() {
    _state = const AssessmentInitial();
    _step = 0;
    _selectedStudentIndex = 0;
    _recoveredDraft = false;
    _saving = false;
  }

  void _emit(AssessmentState value) {
    if (_disposed) return;
    _state = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    _commandGeneration++;
    _commandInFlight = null;
    _clearSensitiveState();
    super.dispose();
  }
}
