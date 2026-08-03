import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/prototype/superadmin_prototype_store.dart';
import '../data/fake_import_repository.dart';
import '../domain/import_job.dart';

final class ImportWizardController extends ChangeNotifier {
  ImportWizardController({
    required this.repository,
    required this.store,
    this.stepInterval = const Duration(milliseconds: 180),
  });

  final FakeImportRepository repository;
  final SuperadminPrototypeStore store;
  final Duration stepInterval;
  ImportEntity entity = ImportEntity.institutions;
  ImportStrategy strategy = ImportStrategy.createOnly;
  ImportFileFixture file = ImportFileFixture.csv;
  String context = 'Coelo';
  int currentStep = 0;
  ImportJob? job;
  Timer? _timer;
  var _disposed = false;

  Map<String, String> get mapping => const {'nome': 'Nome', 'codigo': 'Código'};
  ImportJob get draft =>
      repository.createDraft(entity: entity, strategy: strategy, context: context, file: file);

  void selectEntity(ImportEntity value) {
    entity = value;
    notifyListeners();
  }

  void selectFile(ImportFileFixture value) {
    file = value;
    notifyListeners();
  }

  void selectStrategy(ImportStrategy value) {
    strategy = value;
    notifyListeners();
  }

  void setContext(String value) {
    context = value;
    notifyListeners();
  }

  void next() {
    if (currentStep < 5) {
      currentStep++;
      notifyListeners();
    }
  }

  void previous() {
    if (currentStep > 0) {
      currentStep--;
      notifyListeners();
    }
  }

  void downloadTemplate() {
    store.recordActivity(
      kind: SuperadminActivityKind.export,
      subject: 'Modelo de importação',
      summary: 'Modelo ${file.name.toUpperCase()} preparado para ${entity.label}',
      fileName: file.fileName,
      progress: 100,
    );
  }

  void confirm() {
    if (job != null) return;
    job = repository.save(draft.copyWith(status: ImportJobStatus.inProgress));
    _recordProgress(0);
    _scheduleNext();
    notifyListeners();
  }

  void _scheduleNext() {
    _timer?.cancel();
    _timer = Timer(stepInterval, () {
      if (_disposed || job == null) return;
      final nextProgress = switch (job!.progress) {
        0 => 25,
        25 => 55,
        55 => 80,
        _ => 100,
      };
      _recordProgress(nextProgress);
      if (nextProgress < 100) _scheduleNext();
    });
  }

  void _recordProgress(int progress) {
    final finished = progress == 100;
    job = repository.update(
      job!.copyWith(
        progress: progress,
        status: finished ? ImportJobStatus.completed : ImportJobStatus.inProgress,
      ),
    );
    store.recordActivity(
      kind: SuperadminActivityKind.import,
      subject: entity.label,
      summary: finished ? 'Importação concluída' : 'Importando ${entity.label.toLowerCase()}',
      status: finished ? SuperadminActivityStatus.partial : SuperadminActivityStatus.inProgress,
      fileName: file.fileName,
      progress: progress,
    );
    if (finished) {
      store.recordAuditEvent(
        module: 'Importações',
        action: 'concluída',
        objectType: 'importação',
        objectId: job!.id,
        risk: PrototypeAuditRisk.medium,
        relatedReference: job!.id,
        after: {'strategy': strategy.label, 'result': 'concluída', 'progress': '100'},
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
