import 'dart:async';

enum FormAutosaveStatus { idle, saving, saved, failure }

final class FormAutosaveState<T> {
  const FormAutosaveState({required this.status, required this.draft, this.savedValue, this.error});

  final FormAutosaveStatus status;
  final T draft;
  final T? savedValue;
  final Object? error;
}

final class FormAutosaveController<T> {
  FormAutosaveController({
    required T initialValue,
    required Future<T> Function(T draft) save,
    this.debounce = const Duration(milliseconds: 600),
  }) : _save = save,
       _state = FormAutosaveState(status: FormAutosaveStatus.idle, draft: initialValue);

  final Future<T> Function(T draft) _save;
  final Duration debounce;
  final _changes = StreamController<FormAutosaveState<T>>.broadcast(sync: true);
  FormAutosaveState<T> _state;
  Timer? _timer;
  int _revision = 0;
  bool _disposed = false;

  FormAutosaveState<T> get state => _state;
  Stream<FormAutosaveState<T>> get changes => _changes.stream;

  void update(T draft) {
    _ensureActive();
    _revision++;
    _timer?.cancel();
    _emit(FormAutosaveState(status: FormAutosaveStatus.idle, draft: draft));
    _timer = Timer(debounce, () => unawaited(_saveRevision(_revision, draft)));
  }

  Future<void> flush() async {
    _ensureActive();
    _timer?.cancel();
    await _saveRevision(_revision, _state.draft);
  }

  Future<void> _saveRevision(int revision, T draft) async {
    if (_disposed) return;
    _emit(FormAutosaveState(status: FormAutosaveStatus.saving, draft: draft));
    try {
      final saved = await _save(draft);
      if (_disposed || revision != _revision) return;
      _emit(FormAutosaveState(status: FormAutosaveStatus.saved, draft: draft, savedValue: saved));
    } on Object catch (error) {
      if (_disposed || revision != _revision) return;
      _emit(FormAutosaveState(status: FormAutosaveStatus.failure, draft: draft, error: error));
    }
  }

  void _emit(FormAutosaveState<T> value) {
    _state = value;
    _changes.add(value);
  }

  void _ensureActive() {
    if (_disposed) throw StateError('FormAutosaveController is disposed.');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    await _changes.close();
  }
}
