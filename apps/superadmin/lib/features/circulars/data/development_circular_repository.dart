import 'package:flutter/foundation.dart';

import '../../principal_circulars/domain/circular.dart';
import '../../principal_circulars/domain/circular_repository.dart';
import '../presentation/circular_directory_page.dart';

/// Mutable, deterministic data used exclusively by the `/dev` Circular routes.
final class DevelopmentCircularRepository extends ChangeNotifier implements CircularRepository {
  DevelopmentCircularRepository({DateTime Function()? now}) : _now = now ?? DateTime.now {
    for (final seed in _seeds) {
      _records[seed.item.id] = _DevelopmentCircularRecord(
        item: seed.item,
        draft: seed.draft,
        version: seed.draft.expectedVersion,
      );
    }
  }

  final DateTime Function() _now;
  final Map<String, _DevelopmentCircularRecord> _records = {};
  var _sequence = 1;

  List<CircularDirectoryItem> get items {
    final result = _records.values.map((record) => record.item).toList(growable: false);
    return result..sort((a, b) => b.effectiveAt.compareTo(a.effectiveAt));
  }

  CircularDraft? draftFor(String circularId) => _records[circularId]?.draft;

  @override
  Future<CircularDraft?> loadDraft(CircularScope scope) async => _records.values
      .where((record) => record.item.status == CircularStatus.draft)
      .map((record) => record.draft)
      .firstOrNull;

  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) async {
    final issues = draft.validate();
    if (issues.isNotEmpty) throw CircularInvalid(issues.first.code.name);

    final existing = draft.id.isEmpty ? null : _records[draft.id];
    if (draft.id.isNotEmpty && existing == null) throw const CircularNotAvailable();
    if (existing != null && draft.expectedVersion != existing.version) {
      throw const CircularVersionConflict();
    }

    final id = existing?.item.id ?? 'circular-dev-${_sequence++}';
    final version = (existing?.version ?? 0) + 1;
    final saved = _copyDraft(draft, id: id, status: CircularStatus.draft, version: version);
    final body = _body(saved);
    final item = CircularDirectoryItem(
      id: id,
      title: saved.title.trim(),
      excerpt: body.trim().isEmpty ? 'Circular em elaboração.' : body.trim(),
      authorName: existing?.item.authorName ?? 'Equipe Coelo',
      contextLabel: existing?.item.contextLabel ?? 'Toda a comunidade',
      status: CircularStatus.draft,
      effectiveAt: existing?.item.effectiveAt ?? _now().toUtc(),
      attachmentCount: _attachments(saved),
      questionCount: _questions(saved),
      responseCount: existing?.item.responseCount ?? 0,
    );
    _records[id] = _DevelopmentCircularRecord(item: item, draft: saved, version: version);
    notifyListeners();
    return CircularSaveResult(
      id: id,
      revisionId: '$id-revision-$version',
      version: version,
      status: CircularStatus.draft,
    );
  }

  @override
  Future<CircularSaveResult> publish({
    required String requestId,
    required String circularId,
    required int expectedVersion,
    DateTime? publishAt,
  }) async {
    final record = _records[circularId];
    if (record == null) throw const CircularNotAvailable();
    if (record.version != expectedVersion) throw const CircularVersionConflict();
    final now = _now().toUtc();
    final effectiveAt = publishAt?.toUtc() ?? now;
    final status = effectiveAt.isAfter(now) ? CircularStatus.scheduled : CircularStatus.published;
    final version = record.version + 1;
    final draft = _copyDraft(record.draft, status: status, version: version);
    final item = _copyItem(record.item, status: status, effectiveAt: effectiveAt);
    _records[circularId] = _DevelopmentCircularRecord(item: item, draft: draft, version: version);
    notifyListeners();
    return CircularSaveResult(
      id: circularId,
      revisionId: '$circularId-revision-$version',
      version: version,
      status: status,
    );
  }

  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) async {
    final record = _records[circularId];
    if (record == null) throw const CircularNotAvailable();
    return CircularDetail(
      id: circularId,
      revisionId: '$circularId-revision-${record.version}',
      title: record.item.title,
      authorName: record.item.authorName,
      contextLabel: record.item.contextLabel,
      publishedAt: record.item.effectiveAt,
      blocks: record.draft.blocks,
      status: record.item.status,
      responseState: CircularResponseState.unanswered,
    );
  }

  @override
  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  }) async {
    final visible = items
        .where((item) => item.status == CircularStatus.published)
        .take(limit)
        .map(
          (item) => CircularSummary(
            id: item.id,
            title: item.title,
            excerpt: item.excerpt,
            authorName: item.authorName,
            contextLabel: item.contextLabel,
            publishedAt: item.effectiveAt,
            attachmentCount: item.attachmentCount,
            questionCount: item.questionCount,
            responseState: CircularResponseState.unanswered,
          ),
        )
        .toList(growable: false);
    return PrincipalCursorPage(items: visible, nextCursor: null);
  }

  @override
  Future<CircularSaveResult> closeResponses({
    required String requestId,
    required String circularId,
    required int expectedVersion,
  }) async {
    final record = _records[circularId];
    if (record == null) throw const CircularNotAvailable();
    if (record.version != expectedVersion) throw const CircularVersionConflict();
    final version = record.version + 1;
    _records[circularId] = _DevelopmentCircularRecord(
      item: _copyItem(record.item, status: CircularStatus.closed),
      draft: _copyDraft(record.draft, status: CircularStatus.closed, version: version),
      version: version,
    );
    notifyListeners();
    return CircularSaveResult(
      id: circularId,
      revisionId: '$circularId-revision-$version',
      version: version,
      status: CircularStatus.closed,
    );
  }
}

final class _DevelopmentCircularRecord {
  const _DevelopmentCircularRecord({
    required this.item,
    required this.draft,
    required this.version,
  });

  final CircularDirectoryItem item;
  final CircularDraft draft;
  final int version;
}

CircularDraft _copyDraft(
  CircularDraft source, {
  String? id,
  CircularStatus? status,
  int? version,
}) => CircularDraft(
  id: id ?? source.id,
  title: source.title,
  blocks: source.blocks,
  status: status ?? source.status,
  responsePolicy: source.responsePolicy,
  audiences: source.audiences,
  responsesCloseAt: source.responsesCloseAt,
  expectedVersion: version ?? source.expectedVersion,
);

CircularDirectoryItem _copyItem(
  CircularDirectoryItem source, {
  CircularStatus? status,
  DateTime? effectiveAt,
}) => CircularDirectoryItem(
  id: source.id,
  title: source.title,
  excerpt: source.excerpt,
  authorName: source.authorName,
  contextLabel: source.contextLabel,
  status: status ?? source.status,
  effectiveAt: effectiveAt ?? source.effectiveAt,
  attachmentCount: source.attachmentCount,
  questionCount: source.questionCount,
  responseCount: source.responseCount,
);

int _attachments(CircularDraft draft) =>
    draft.blocks.whereType<CircularMediaBlock>().expand((block) => block.assetIds).length;

int _questions(CircularDraft draft) => draft.blocks.whereType<CircularQuestionBlock>().length;

String _body(CircularDraft draft) =>
    draft.blocks.whereType<CircularTextBlock>().firstOrNull?.text ?? '';

CircularDraft _draft(
  String id,
  String title,
  String body,
  CircularStatus status, {
  List<String> assets = const [],
  int questions = 0,
}) => CircularDraft(
  id: id,
  title: title,
  status: status,
  expectedVersion: 1,
  audiences: const {CircularAudienceKind.families},
  blocks: [
    CircularTextBlock(id: '$id-text', text: body),
    if (assets.isNotEmpty) CircularMediaBlock(id: '$id-media', assetIds: assets),
    for (var index = 0; index < questions; index++)
      CircularQuestionBlock(
        id: '$id-question-$index',
        prompt: index == 0 ? 'Você confirma a leitura desta circular?' : 'Deseja receber contato?',
        kind: CircularQuestionKind.singleChoice,
        required: index == 0,
        options: [
          CircularQuestionOption(id: '$id-question-$index-yes', label: 'Sim'),
          CircularQuestionOption(id: '$id-question-$index-no', label: 'Não'),
        ],
      ),
  ],
);

final _seeds = <({CircularDirectoryItem item, CircularDraft draft})>[
  _seed(
    'renovacao-2027',
    'Renovação de matrícula 2027',
    'Confirme a renovação até 30 de setembro.',
    'Coordenação Pedagógica',
    'Ensino Fundamental',
    CircularStatus.published,
    DateTime.utc(2026, 8, 28),
    84,
    assets: const ['calendario-renovacao.pdf', 'guia-matricula.pdf'],
    questions: 1,
  ),
  _seed(
    'reuniao-infantil',
    'Reunião de responsáveis',
    'Encontro para apresentar os projetos do segundo semestre.',
    'Mariana Costa',
    'Educação Infantil',
    CircularStatus.scheduled,
    DateTime.utc(2026, 9, 8),
    0,
    assets: const ['pauta-reuniao.pdf'],
  ),
  _seed(
    'passeio-museu',
    'Passeio cultural ao Museu da Língua Portuguesa',
    'Orientações, horários e autorização para o passeio pedagógico.',
    'Rafael Nunes',
    'Ensino Fundamental',
    CircularStatus.published,
    DateTime.utc(2026, 8, 25),
    57,
    assets: const ['autorizacao-passeio.pdf'],
    questions: 2,
  ),
  _seed(
    'simulado-enem',
    'Calendário do simulado ENEM',
    'Confira as datas, os horários e os conteúdos previstos.',
    'Carla Mendes',
    'Ensino Médio',
    CircularStatus.published,
    DateTime.utc(2026, 8, 22),
    112,
    assets: const ['calendario-simulado.pdf'],
  ),
  _seed(
    'festa-familia',
    'Encontro da família na escola',
    'Uma manhã de convivência, oficinas e apresentações.',
    'Equipe de Convivência',
    'Toda a comunidade',
    CircularStatus.draft,
    DateTime.utc(2026, 8, 20),
    0,
  ),
  _seed(
    'uniformes-2027',
    'Encomenda de uniformes 2027',
    'Consulte modelos, medidas e prazo para pedidos.',
    'Secretaria Escolar',
    'Toda a comunidade',
    CircularStatus.scheduled,
    DateTime.utc(2026, 9, 12),
    0,
    assets: const ['tabela-medidas.pdf'],
    questions: 1,
  ),
  _seed(
    'avaliacoes-bimestre',
    'Avaliações do terceiro bimestre',
    'Cronograma consolidado por turma e componente curricular.',
    'Coordenação Acadêmica',
    'Ensino Fundamental',
    CircularStatus.published,
    DateTime.utc(2026, 8, 18),
    96,
    assets: const ['cronograma-avaliacoes.pdf'],
  ),
  _seed(
    'projeto-leitura',
    'Projeto de leitura em família',
    'Sugestões de obras e combinados para as próximas semanas.',
    'Biblioteca Coelo',
    'Educação Infantil',
    CircularStatus.published,
    DateTime.utc(2026, 8, 15),
    41,
  ),
  _seed(
    'plantao-duvidas',
    'Plantão de dúvidas',
    'Agenda de atendimento dos professores antes das avaliações.',
    'Coordenação Acadêmica',
    'Ensino Médio',
    CircularStatus.closed,
    DateTime.utc(2026, 8, 12),
    68,
  ),
  _seed(
    'feriado-municipal',
    'Funcionamento no feriado municipal',
    'Não haverá atividades presenciais; confira os canais de atendimento.',
    'Direção Escolar',
    'Toda a comunidade',
    CircularStatus.published,
    DateTime.utc(2026, 8, 10),
    135,
  ),
  _seed(
    'acolhimento-novos',
    'Acolhimento de novas famílias',
    'Conheça os encontros de integração e os principais canais da escola.',
    'Orientação Educacional',
    'Educação Infantil',
    CircularStatus.draft,
    DateTime.utc(2026, 8, 8),
    0,
  ),
  _seed(
    'olimpiada-matematica',
    'Olimpíada de Matemática',
    'Inscrições abertas para estudantes interessados em participar.',
    'Professor André Lima',
    'Ensino Fundamental',
    CircularStatus.closed,
    DateTime.utc(2026, 8, 5),
    73,
    questions: 1,
  ),
  _seed(
    'formatura-terceiro',
    'Preparativos para a formatura',
    'Primeiras orientações para estudantes e responsáveis do terceiro ano.',
    'Comissão de Formatura',
    'Ensino Médio',
    CircularStatus.draft,
    DateTime.utc(2026, 8, 2),
    0,
    questions: 1,
  ),
  _seed(
    'campanha-solidaria',
    'Campanha solidária de inverno',
    'Agradecemos as doações e compartilhamos o resultado da mobilização.',
    'Equipe de Convivência',
    'Toda a comunidade',
    CircularStatus.archived,
    DateTime.utc(2026, 7, 28),
    149,
    assets: const ['prestacao-contas.pdf'],
  ),
];

({CircularDirectoryItem item, CircularDraft draft}) _seed(
  String id,
  String title,
  String body,
  String author,
  String context,
  CircularStatus status,
  DateTime date,
  int responses, {
  List<String> assets = const [],
  int questions = 0,
}) {
  final draft = _draft(id, title, body, status, assets: assets, questions: questions);
  return (
    item: CircularDirectoryItem(
      id: id,
      title: title,
      excerpt: body,
      authorName: author,
      contextLabel: context,
      status: status,
      effectiveAt: date,
      attachmentCount: assets.length,
      questionCount: questions,
      responseCount: responses,
    ),
    draft: draft,
  );
}
