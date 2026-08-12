import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../domain/import_job.dart';
import '../domain/import_repository.dart';

final class ImportWizardController extends ChangeNotifier {
  ImportWizardController({
    required this.repository,
    ImportEntity? initialEntity,
    String? initialContext,
    ImportStrategy? initialStrategy,
    this.stepInterval = const Duration(seconds: 2),
  }) : entity = initialEntity ?? ImportEntity.units,
       strategy = initialStrategy ?? ImportStrategy.createOnly,
       file = ImportFileFixture.csv,
       context = initialContext ?? 'Unidades';

  final ImportRepository repository;
  final Duration stepInterval;
  ImportEntity entity;
  ImportStrategy strategy;
  ImportFileFixture file;
  String context;
  int currentStep = 0;
  ImportJob? job;
  ImportSourceFile? sourceFile;
  String? sourceFileError;
  bool selectingFile = false;
  Future<ImportJob>? _draft;
  String? _draftCacheKey;
  Timer? _timer;
  var _disposed = false;

  Map<String, String> get mapping => job?.mapping ?? const {};
  bool get canConfirm => entity == ImportEntity.units && sourceFile != null && !selectingFile;

  Future<ImportJob> get draft {
    final key = '${entity.name}|${strategy.name}|${file.name}|$context';
    if (_draft != null && _draftCacheKey == key) return _draft!;
    final next = repository.createDraft(
      entity: entity,
      strategy: strategy,
      context: context,
      file: file,
    );
    _draft = next;
    _draftCacheKey = key;
    return next;
  }

  void _invalidateDraft() {
    _timer?.cancel();
    _draft = null;
    _draftCacheKey = null;
    job = null;
  }

  void selectEntity(ImportEntity value) {
    if (entity == value) return;
    entity = value;
    _invalidateDraft();
    notifyListeners();
  }

  void selectFile(ImportFileFixture value) {
    if (file == value) return;
    file = value;
    _invalidateDraft();
    notifyListeners();
  }

  Future<void> pickSourceFile() async {
    if (selectingFile) return;
    selectingFile = true;
    sourceFileError = null;
    notifyListeners();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx'],
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final selected = result.files.single;
      final bytes = selected.bytes;
      final extension = selected.extension?.toLowerCase();
      if (bytes == null || bytes.isEmpty) {
        sourceFileError = 'Não foi possível ler o arquivo selecionado.';
        return;
      }
      if (bytes.length > 5 * 1024 * 1024) {
        sourceFileError = 'O arquivo deve ter no máximo 5 MB.';
        return;
      }
      if (extension != 'csv' && extension != 'xlsx') {
        sourceFileError = 'Use um arquivo CSV ou XLSX.';
        return;
      }
      file = extension == 'xlsx' ? ImportFileFixture.xlsx : ImportFileFixture.csv;
      _invalidateDraft();
      sourceFile = ImportSourceFile(
        name: selected.name,
        bytes: bytes,
        mimeType: extension == 'xlsx'
            ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            : 'text/csv',
      );
    } on Object {
      sourceFileError = 'Não foi possível abrir o seletor de arquivos.';
    } finally {
      selectingFile = false;
      if (!_disposed) notifyListeners();
    }
  }

  void selectStrategy(ImportStrategy value) {
    if (strategy == value) return;
    strategy = value;
    _invalidateDraft();
    notifyListeners();
  }

  void setContext(String value) {
    if (context == value) return;
    context = value;
    _invalidateDraft();
    notifyListeners();
  }

  void next() {
    if (currentStep < 5) {
      currentStep++;
      notifyListeners();
    }
  }

  void previous() => goToStep(currentStep - 1);

  void goToStep(int step) {
    if (step < 0 || step > currentStep) return;
    currentStep = step;
    notifyListeners();
  }

  void confirm() {
    if (job != null || !canConfirm) return;
    unawaited(_confirm());
  }

  Future<void> _confirm() async {
    try {
      final draftJob = await draft;
      if (_disposed) return;
      job = await repository.save(draftJob, sourceFile: sourceFile);
      if (_disposed) return;
      notifyListeners();
      _schedulePoll();
    } on ImportRepositoryUnavailableException {
      sourceFileError = 'Não foi possível processar o arquivo com segurança. Tente novamente.';
      if (!_disposed) notifyListeners();
    }
  }

  void _schedulePoll() {
    _timer?.cancel();
    if (_disposed || job == null || job!.status.isTerminal) return;
    _timer = Timer(stepInterval, () => unawaited(_poll()));
  }

  Future<void> _poll() async {
    final current = job;
    if (_disposed || current == null) return;
    try {
      job = await repository.update(current);
    } on ImportRepositoryUnavailableException {
      sourceFileError = 'Não foi possível atualizar o processamento. Tente novamente.';
    }
    if (_disposed) return;
    notifyListeners();
    _schedulePoll();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
