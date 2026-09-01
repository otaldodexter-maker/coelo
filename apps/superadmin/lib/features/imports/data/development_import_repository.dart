import '../domain/import_job.dart';
import '../domain/import_repository.dart';

/// Stateful fixtures used only by `/dev` routes. Production composition must
/// keep using [SupabaseImportRepository].
final class DevelopmentImportRepository implements ImportRepository, ImportExecutionCapabilities {
  DevelopmentImportRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now,
      _jobs = _seededJobs();

  final DateTime Function() _now;
  final List<ImportJob> _jobs;
  var _nextId = 100;

  @override
  Set<ImportEntity> get supportedImportEntities =>
      Set<ImportEntity>.unmodifiable(ImportWizardDevelopmentEntities.values);

  @override
  Future<List<ImportJob>> fetchJobs() async => List<ImportJob>.unmodifiable(_jobs);

  @override
  Future<ImportJobPage> fetchPage(ImportJobQuery query) async {
    final search = query.search?.trim().toLowerCase();
    final filtered = _jobs
        .where((job) {
          if (query.entities.isNotEmpty && !query.entities.contains(job.entity)) return false;
          if (query.file != null && query.file != job.file) return false;
          if (query.status != null && query.status != job.status) return false;
          if (query.createdAfter != null && job.createdAt.isBefore(query.createdAfter!))
            return false;
          if (query.createdBefore != null && job.createdAt.isAfter(query.createdBefore!))
            return false;
          if (search == null || search.isEmpty) return true;
          return '${job.displayFileName} ${job.entity.label} ${job.context} ${job.actor}'
              .toLowerCase()
              .contains(search);
        })
        .toList(growable: false);
    final offset = _offset(query.cursor);
    final requestedEnd = offset + query.pageSize;
    final end = requestedEnd < filtered.length ? requestedEnd : filtered.length;
    final items = offset >= filtered.length ? const <ImportJob>[] : filtered.sublist(offset, end);
    return ImportJobPage(
      items: List<ImportJob>.unmodifiable(items),
      nextCursor: end < filtered.length ? 'dev:$end' : null,
    );
  }

  @override
  Future<ImportJob> createDraft({
    required ImportEntity entity,
    required ImportStrategy strategy,
    String context = 'Coelo',
    ImportFileFixture file = ImportFileFixture.csv,
  }) async {
    if (!supportedImportEntities.contains(entity)) {
      throw const ImportRepositoryUnavailableException();
    }
    final rows = _preview(entity);
    return ImportJob(
      id: 'dev-import-${_nextId++}',
      entity: entity,
      context: context.trim().isEmpty ? entity.label : context.trim(),
      file: file,
      strategy: strategy,
      mapping: _mapping(entity),
      previewRows: rows,
      conflicts: <ImportConflict>[
        ImportConflict(
          row: 6,
          field: entity.matchingKey,
          reason: strategy == ImportStrategy.createOnly
              ? 'Registro já existe e será ignorado.'
              : 'Registro existente será atualizado com histórico.',
        ),
      ],
      result: ImportResult(
        created: strategy == ImportStrategy.createOnly ? 7 : 5,
        updated: strategy == ImportStrategy.createAndUpdate ? 2 : 0,
        ignored: strategy == ImportStrategy.createOnly ? 1 : 0,
      ),
      status: ImportJobStatus.draft,
      progress: 0,
      actor: 'Charles Dias Ferreira',
      createdAt: _now(),
    );
  }

  @override
  Future<ImportJob> save(ImportJob job, {ImportSourceFile? sourceFile}) async {
    if (sourceFile == null || sourceFile.bytes.isEmpty) {
      throw const ImportRepositoryUnavailableException();
    }
    final saved = job.copyWith(
      status: ImportJobStatus.inProgress,
      progress: 20,
      sourceFileName: sourceFile.name,
    );
    _jobs.insert(0, saved);
    return saved;
  }

  @override
  Future<ImportJob> update(ImportJob job) async {
    final updated = job.progress < 65
        ? job.copyWith(status: ImportJobStatus.inProgress, progress: 65)
        : job.copyWith(status: ImportJobStatus.completed, progress: 100);
    final index = _jobs.indexWhere((candidate) => candidate.id == job.id);
    if (index >= 0) _jobs[index] = updated;
    return updated;
  }
}

abstract final class ImportWizardDevelopmentEntities {
  static const values = <ImportEntity>{
    ImportEntity.institutions,
    ImportEntity.units,
    ImportEntity.people,
    ImportEntity.groups,
    ImportEntity.activities,
    ImportEntity.medicationPlans,
    ImportEntity.mealPlans,
    ImportEntity.forms,
  };
}

int _offset(String? cursor) {
  if (cursor == null) return 0;
  final value = cursor.startsWith('dev:') ? int.tryParse(cursor.substring(4)) : null;
  return value == null || value < 0 ? 0 : value;
}

Map<String, String> _mapping(ImportEntity entity) => switch (entity) {
  ImportEntity.institutions => const {
    'codigo_instituicao': 'Código da instituição',
    'nome': 'Nome oficial',
    'cidade': 'Cidade',
    'estado': 'UF',
  },
  ImportEntity.units => const {
    'codigo_unidade': 'Código da unidade',
    'nome': 'Nome da unidade',
    'codigo_instituicao': 'Instituição',
    'cidade': 'Cidade',
  },
  ImportEntity.people => const {
    'identificador': 'Documento interno',
    'nome': 'Nome completo',
    'papel': 'Papel contextual',
    'unidade': 'Unidade',
  },
  ImportEntity.groups => const {
    'codigo_turma': 'Código da turma',
    'nome': 'Nome da turma',
    'unidade': 'Unidade',
    'turno': 'Turno',
  },
  ImportEntity.activities => const {
    'arroba': '@ da atividade',
    'nome': 'Nome da atividade',
    'profissional': 'Profissional',
    'unidade': 'Unidade',
  },
  ImportEntity.medicationPlans => const {
    'identificador': 'Identificador do plano',
    'pessoa': 'Pessoa atendida',
    'medicamento': 'Medicamento',
    'horario': 'Horário',
  },
  ImportEntity.mealPlans => const {
    'data': 'Data',
    'contexto': 'Contexto',
    'refeicao': 'Refeição',
    'descricao': 'Descrição',
  },
  ImportEntity.forms => const {
    'identificador': 'Identificador do formulário',
    'titulo': 'Título',
    'publico': 'Público',
    'vigencia': 'Vigência',
  },
  ImportEntity.internalUsers => const {
    'id_usuario': 'ID do usuário',
    'nome': 'Nome completo',
    'perfil': 'Perfil de acesso',
    'instituicao': 'Instituição',
  },
};

List<ImportPreviewRow> _preview(ImportEntity entity) {
  final samples = switch (entity) {
    ImportEntity.institutions => const [
      ('Instituto Horizonte', 'INST-HORIZONTE'),
      ('Escola Aurora', 'INST-AURORA'),
      ('Colégio Caminhos', 'INST-CAMINHOS'),
    ],
    ImportEntity.units => const [
      ('Unidade Centro', 'UNI-CENTRO'),
      ('Unidade Jardim', 'UNI-JARDIM'),
      ('Unidade Lagoa', 'UNI-LAGOA'),
    ],
    ImportEntity.people => const [
      ('Helena Silva', 'PES-HELENA'),
      ('Paulo Mendes', 'PES-PAULO'),
      ('Carolina Dias', 'PES-CAROLINA'),
    ],
    ImportEntity.groups => const [
      ('Turma Girassol', 'TUR-GIRASSOL'),
      ('Turma Ipê Amarelo', 'TUR-IPE'),
      ('Turma Estrelas', 'TUR-ESTRELAS'),
    ],
    ImportEntity.activities => const [
      ('Terapia ocupacional', '@terapia-ocupacional'),
      ('Ballet', '@ballet'),
      ('Psicomotricidade', '@psicomotricidade'),
    ],
    ImportEntity.medicationPlans => const [
      ('Plano respiratório de Lia', 'MED-LIA-RESP'),
      ('Plano de suporte de Noah', 'MED-NOAH-SUP'),
      ('Plano contínuo de Maya', 'MED-MAYA-CONT'),
    ],
    ImportEntity.mealPlans => const [
      ('Cardápio semanal Centro', '2026-08-24-CENTRO'),
      ('Cardápio sem lactose Jardim', '2026-08-24-JARDIM'),
      ('Cardápio integral Horizonte', '2026-08-24-HORIZONTE'),
    ],
    ImportEntity.forms => const [
      ('Pesquisa anual das famílias', 'FORM-PESQUISA-ANUAL'),
      ('Autorização para passeio', 'FORM-AUT-PASSEIO'),
      ('Avaliação da reunião pedagógica', 'FORM-AVAL-REUNIAO'),
    ],
    ImportEntity.internalUsers => const [
      ('Carolina Mendes', 'USR-CAROLINA'),
      ('Rafael Costa', 'USR-RAFAEL'),
      ('Ana Ribeiro', 'USR-ANA'),
    ],
  };
  return List<ImportPreviewRow>.generate(8, (index) {
    final sample = samples[index % samples.length];
    return ImportPreviewRow(
      row: index + 1,
      values: <String, String>{
        'nome': index < samples.length ? sample.$1 : '${sample.$1} ${index + 1}',
        'codigo': index < samples.length ? sample.$2 : '${sample.$2}-${index + 1}',
      },
    );
  });
}

List<ImportJob> _seededJobs() {
  const contexts = <String>[
    'Instituto Horizonte',
    'Unidade Centro',
    'Unidade Jardim',
    'Turma Girassol',
    'Turma Ipê Amarelo',
    'Atendimento ocupacional',
    'Comunidade escolar',
    'Todas as unidades',
  ];
  const actors = <String>['Carolina Mendes', 'Rafael Costa', 'Ana Ribeiro', 'João Nogueira'];
  const statuses = <ImportJobStatus>[
    ImportJobStatus.completed,
    ImportJobStatus.completed,
    ImportJobStatus.inProgress,
    ImportJobStatus.rejected,
    ImportJobStatus.error,
    ImportJobStatus.draft,
  ];
  const entities = <ImportEntity>[
    ImportEntity.institutions,
    ImportEntity.units,
    ImportEntity.people,
    ImportEntity.groups,
    ImportEntity.activities,
    ImportEntity.medicationPlans,
    ImportEntity.mealPlans,
    ImportEntity.forms,
  ];
  return List<ImportJob>.generate(34, (index) {
    final entity = entities[index % entities.length];
    final status = statuses[index % statuses.length];
    final file = index.isEven ? ImportFileFixture.csv : ImportFileFixture.xlsx;
    final total = 18 + (index * 7 % 83);
    final rejected = status == ImportJobStatus.rejected ? 4 + index % 5 : 0;
    return ImportJob(
      id: 'dev-history-${index + 1}',
      entity: entity,
      context: contexts[index % contexts.length],
      file: file,
      strategy: index % 3 == 0 ? ImportStrategy.createAndUpdate : ImportStrategy.createOnly,
      mapping: _mapping(entity),
      previewRows: _preview(entity),
      conflicts: rejected == 0
          ? const <ImportConflict>[]
          : <ImportConflict>[
              ImportConflict(
                row: 3 + index % 6,
                field: entity.matchingKey,
                reason: 'Identificador duplicado no contexto selecionado.',
              ),
            ],
      result: ImportResult(
        created: status == ImportJobStatus.completed ? total - rejected : 0,
        updated: status == ImportJobStatus.completed && index % 3 == 0 ? 6 : 0,
        rejected: rejected,
      ),
      status: status,
      progress: switch (status) {
        ImportJobStatus.draft => 0,
        ImportJobStatus.inProgress => 62,
        _ => 100,
      },
      actor: actors[index % actors.length],
      createdAt: DateTime.utc(2026, 8, 31).subtract(Duration(hours: index * 13)),
      sourceFileName: '${_fileStem(entity)}-${(index + 1).toString().padLeft(2, '0')}.${file.name}',
    );
  });
}

String _fileStem(ImportEntity entity) => switch (entity) {
  ImportEntity.institutions => 'instituicoes-rede-horizonte',
  ImportEntity.units => 'unidades-instituto-horizonte',
  ImportEntity.people => 'pessoas-comunidade-escolar',
  ImportEntity.groups => 'turmas-ano-letivo-2026',
  ImportEntity.activities => 'atividades-extracurriculares',
  ImportEntity.medicationPlans => 'planos-medicacao-vigentes',
  ImportEntity.mealPlans => 'cardapios-agosto-2026',
  ImportEntity.forms => 'formularios-familias-2026',
  ImportEntity.internalUsers => 'usuarios-internos',
};
