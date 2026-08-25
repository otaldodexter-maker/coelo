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
    _emit(const AssessmentLoading());
    try {
      final value = await repository.fetchGradebook(id);
      if (value == null) {
        _emit(const AssessmentEmpty());
        return;
      }
      _recoveredDraft = value.status == AssessmentGradebookStatus.draft;
      _emit(AssessmentReady(value));
    } on AssessmentUnauthorizedException {
      _emit(const AssessmentUnauthorized());
    } on AssessmentOfflineException {
      _emit(const AssessmentOffline());
    } on Exception catch (error) {
      _emit(AssessmentFailure(error));
    }
  }

  Future<void> start(AssessmentContext context, AssessmentConfiguration configuration) async {
    _emit(const AssessmentLoading());
    try {
      final value = await repository.createOrResumeGradebook(context, configuration);
      _recoveredDraft = value.version > 1;
      _emit(AssessmentReady(value));
    } on AssessmentUnauthorizedException {
      _emit(const AssessmentUnauthorized());
    } on AssessmentOfflineException {
      _emit(const AssessmentOffline());
    } on Exception catch (error) {
      _emit(AssessmentFailure(error));
    }
  }

  void goToStep(int value) {
    if (value >= 0 && value < 4) {
      _step = value;
      _notify();
    }
  }

  void nextStep() {
    if (_step < 3) {
      _step++;
      _notify();
    }
  }

  void previousStep() {
    if (_step > 0) {
      _step--;
      _notify();
    }
  }

  void nextStudent() {
    final count = gradebook?.students.length ?? 0;
    if (_selectedStudentIndex < count - 1) {
      _selectedStudentIndex++;
      _notify();
    }
  }

  void previousStudent() {
    if (_selectedStudentIndex > 0) {
      _selectedStudentIndex--;
      _notify();
    }
  }

  void updateStudent(AssessmentStudentEntry value) {
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
  ) async {
    final book = gradebook;
    if (book == null) throw StateError('Diário não carregado.');
    _saving = true;
    _notify();
    try {
      final saved = await operation(book);
      _emit(AssessmentReady(saved));
      return saved;
    } on AssessmentVersionConflictException {
      _emit(const AssessmentConflict());
      rethrow;
    } on AssessmentUnauthorizedException {
      _emit(const AssessmentUnauthorized());
      rethrow;
    } on AssessmentOfflineException {
      _emit(AssessmentOffline(book));
      rethrow;
    } on Exception catch (error) {
      _emit(AssessmentFailure(error));
      rethrow;
    } finally {
      _saving = false;
      _notify();
    }
  }

  void _emit(AssessmentState value) {
    _state = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
