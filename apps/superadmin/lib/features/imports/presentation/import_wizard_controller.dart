import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../domain/import_job.dart';
import '../domain/import_repository.dart';

final class ImportWizardController extends ChangeNotifier {
  static const supportedEntities = <ImportEntity>{ImportEntity.units};
  static const catalogEntities = <ImportEntity>[
    ImportEntity.institutions,
    ImportEntity.units,
    ImportEntity.people,
    ImportEntity.groups,
    ImportEntity.activities,
    ImportEntity.medicationPlans,
    ImportEntity.mealPlans,
    ImportEntity.forms,
  ];

  ImportWizardController({
    required this.repository,
    ImportEntity? initialEntity,
    String? initialContext,
    ImportStrategy? initialStrategy,
    this.stepInterval = const Duration(seconds: 2),
  }) : entity = catalogEntities.contains(initialEntity) ? initialEntity! : ImportEntity.units,
       strategy = initialStrategy ?? ImportStrategy.createOnly,
       file = ImportFileFixture.csv,
       context = initialContext ?? (initialEntity?.label ?? 'Unidades');

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
  bool _preparingDraft = false;
  bool _confirming = false;
  Timer? _timer;
  var _disposed = false;
  var _generation = 0;

  Map<String, String> get mapping => job?.mapping ?? const {};
  bool get executionAvailable => supportedEntities.contains(entity);
  bool get canConfirm => executionAvailable && sourceFile != null && !selectingFile && !_confirming;

  Future<ImportJob>? get preparedDraft => _draft;

  Future<bool> _prepareDraft() async {
    if (_preparingDraft) return false;
    final key = '${entity.name}|${strategy.name}|${file.name}|$context';
    if (_draft != null && _draftCacheKey == key) return true;
    _preparingDraft = true;
    sourceFileError = null;
    final generation = _generation;
    final next = repository.createDraft(
      entity: entity,
      strategy: strategy,
      context: context,
      file: file,
    );
    _draft = next;
    _draftCacheKey = key;
    try {
      await next;
      return !_disposed && generation == _generation;
    } on ImportRepositoryUnavailableException {
      if (generation != _generation) return false;
      _draft = null;
      _draftCacheKey = null;
      sourceFileError = 'Importação indisponível neste ambiente.';
      return false;
    } finally {
      _preparingDraft = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _invalidateDraft() {
    _generation++;
    _timer?.cancel();
    _draft = null;
    _draftCacheKey = null;
    _confirming = false;
    job = null;
  }

  void selectEntity(ImportEntity value) {
    if (!catalogEntities.contains(value)) return;
    if (entity == value) return;
    entity = value;
    context = value.label;
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

  Future<void> next() async {
    if (currentStep >= 5 || _preparingDraft) return;
    if (currentStep == 0 && !executionAvailable) return;
    if (currentStep == 1 && sourceFile == null) {
      sourceFileError = 'Selecione um arquivo CSV ou XLSX antes de continuar.';
      notifyListeners();
      return;
    }
    if ((currentStep == 1 || currentStep == 3) && !await _prepareDraft()) return;
    currentStep++;
    notifyListeners();
  }

  void previous() => goToStep(currentStep - 1);

  void goToStep(int step) {
    if (step < 0 || step > currentStep) return;
    currentStep = step;
    notifyListeners();
  }

  void confirm() {
    if (job != null || !canConfirm || _draft == null) return;
    unawaited(_confirm());
  }

  Future<void> _confirm() async {
    _confirming = true;
    notifyListeners();
    final generation = _generation;
    try {
      final draftJob = await _draft!;
      if (_disposed || generation != _generation) return;
      final saved = await repository.save(draftJob, sourceFile: sourceFile);
      if (_disposed || generation != _generation) return;
      job = saved;
      notifyListeners();
      _schedulePoll();
    } on ImportRepositoryUnavailableException {
      if (_disposed || generation != _generation) return;
      sourceFileError = 'Não foi possível processar o arquivo com segurança. Tente novamente.';
      if (!_disposed) notifyListeners();
    } finally {
      if (!_disposed && generation == _generation) {
        _confirming = false;
        notifyListeners();
      }
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
    final generation = _generation;
    try {
      final updated = await repository.update(current);
      if (_disposed || generation != _generation || job?.id != current.id) return;
      job = updated;
    } on ImportRepositoryUnavailableException {
      if (_disposed || generation != _generation || job?.id != current.id) return;
      sourceFileError = 'Não foi possível atualizar o processamento. Tente novamente.';
    }
    if (_disposed) return;
    notifyListeners();
    _schedulePoll();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
