import 'package:flutter/foundation.dart';

enum ImportEntity {
  institutions,
  units,
  people,
  groups,
  activities,
  medicationPlans,
  mealPlans,
  forms,
  internalUsers,
}

enum ImportStrategy { createOnly, createAndUpdate }

enum ImportFileFixture { csv, xlsx }

enum ImportCreationPreset {
  institutions,
  units,
  groups,
  activities,
  newInstitution,
  newFamily,
  fileByStep,
}

enum ImportJobStatus { draft, inProgress, completed, rejected, error }

extension ImportJobStatusState on ImportJobStatus {
  bool get isTerminal =>
      this == ImportJobStatus.completed ||
      this == ImportJobStatus.rejected ||
      this == ImportJobStatus.error;
}

extension ImportCreationPresetLabels on ImportCreationPreset {
  String get label => switch (this) {
    ImportCreationPreset.institutions => 'Instituições',
    ImportCreationPreset.units => 'Unidades',
    ImportCreationPreset.groups => 'Turmas',
    ImportCreationPreset.activities => 'Atividades',
    ImportCreationPreset.newInstitution => 'Nova instituição',
    ImportCreationPreset.newFamily => 'Nova família',
    ImportCreationPreset.fileByStep => 'Upload por arquivo por etapa',
  };

  ImportEntity get defaultEntity => switch (this) {
    ImportCreationPreset.institutions ||
    ImportCreationPreset.newInstitution => ImportEntity.institutions,
    ImportCreationPreset.units || ImportCreationPreset.fileByStep => ImportEntity.units,
    ImportCreationPreset.groups => ImportEntity.groups,
    ImportCreationPreset.activities => ImportEntity.activities,
    ImportCreationPreset.newFamily => ImportEntity.groups,
  };

  String get defaultContext => switch (this) {
    ImportCreationPreset.institutions => 'Instituições',
    ImportCreationPreset.units => 'Unidades',
    ImportCreationPreset.groups => 'Turmas',
    ImportCreationPreset.activities => 'Atividades',
    ImportCreationPreset.newInstitution => 'Nova instituição',
    ImportCreationPreset.newFamily => 'Nova família',
    ImportCreationPreset.fileByStep => 'Importação por etapa',
  };
}

extension ImportEntityLabels on ImportEntity {
  String get label => switch (this) {
    ImportEntity.institutions => 'Instituições',
    ImportEntity.units => 'Unidades',
    ImportEntity.groups => 'Grupos e turmas',
    ImportEntity.activities => 'Atividades',
    ImportEntity.people => 'Pessoas',
    ImportEntity.medicationPlans => 'Planos de medicação',
    ImportEntity.mealPlans => 'Cardápios',
    ImportEntity.forms => 'Formulários',
    ImportEntity.internalUsers => 'Usuários internos',
  };

  String get matchingKey => switch (this) {
    ImportEntity.institutions => 'Código da instituição',
    ImportEntity.units => 'Código da unidade',
    ImportEntity.groups => 'Código da turma',
    ImportEntity.activities => '@ da atividade',
    ImportEntity.people => 'Documento interno',
    ImportEntity.medicationPlans => 'Identificador do plano',
    ImportEntity.mealPlans => 'Data e contexto',
    ImportEntity.forms => 'Identificador do formulário',
    ImportEntity.internalUsers => 'ID do usuário',
  };
}

extension ImportStrategyLabels on ImportStrategy {
  String get label => this == ImportStrategy.createOnly ? 'Criar apenas' : 'Criar e atualizar';
}

extension ImportFileFixtureLabels on ImportFileFixture {
  String get fileName =>
      this == ImportFileFixture.csv ? 'modelo-importacao.csv' : 'modelo-importacao.xlsx';
}

@immutable
final class ImportSourceFile {
  const ImportSourceFile({required this.name, required this.bytes, required this.mimeType});

  final String name;
  final Uint8List bytes;
  final String mimeType;
}

@immutable
final class ImportPreviewRow {
  const ImportPreviewRow({required this.row, required this.values});
  final int row;
  final Map<String, String> values;
}

@immutable
final class ImportConflict {
  const ImportConflict({required this.row, required this.field, required this.reason});
  final int row;
  final String field;
  final String reason;
}

@immutable
final class ImportResult {
  const ImportResult({this.created = 0, this.updated = 0, this.ignored = 0, this.rejected = 0});
  final int created;
  final int updated;
  final int ignored;
  final int rejected;
}

@immutable
final class ImportJob {
  const ImportJob({
    required this.id,
    required this.entity,
    required this.context,
    required this.file,
    required this.strategy,
    required this.mapping,
    required this.previewRows,
    required this.conflicts,
    required this.result,
    required this.status,
    required this.progress,
    required this.actor,
    required this.createdAt,
    this.sourceFileName,
  });

  final String id;
  final ImportEntity entity;
  final String context;
  final ImportFileFixture file;
  final ImportStrategy strategy;
  final Map<String, String> mapping;
  final List<ImportPreviewRow> previewRows;
  final List<ImportConflict> conflicts;
  final ImportResult result;
  final ImportJobStatus status;
  final int progress;
  final String actor;
  final DateTime createdAt;
  final String? sourceFileName;

  String get displayFileName =>
      sourceFileName?.trim().isNotEmpty == true ? sourceFileName!.trim() : file.fileName;

  ImportJob copyWith({
    ImportJobStatus? status,
    int? progress,
    ImportResult? result,
    String? sourceFileName,
  }) => ImportJob(
    id: id,
    entity: entity,
    context: context,
    file: file,
    strategy: strategy,
    mapping: mapping,
    previewRows: previewRows,
    conflicts: conflicts,
    result: result ?? this.result,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    actor: actor,
    createdAt: createdAt,
    sourceFileName: sourceFileName ?? this.sourceFileName,
  );
}
