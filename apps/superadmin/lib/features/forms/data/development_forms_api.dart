import 'dart:convert';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';

/// Deterministic, in-memory data source used only by the `/dev` composition.
///
/// It models directory reads and cursor pagination without implying remote
/// persistence, tenant authorization, or a production backend.
final class DevelopmentFormsApi implements FormsApi {
  DevelopmentFormsApi.seeded() : _items = _seedItems();

  static const institutionId = 'institution-coelo-dev';
  static const _cursorPrefix = 'forms-directory-dev-v1:';

  final List<FormDirectoryItem> _items;

  @override
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query) async {
    if (query.limit < 1 || query.limit > 100) {
      throw const FormApiException(
        FormApiFailureKind.validation,
        'O limite local deve estar entre 1 e 100.',
      );
    }

    if (query.institutionId != null && query.institutionId != institutionId) {
      return FormCursorPage(items: const [], nextCursor: null);
    }

    final normalizedSearch = query.search?.trim().toLowerCase();
    final filtered = _items
        .where((item) {
          if (normalizedSearch != null &&
              normalizedSearch.isNotEmpty &&
              ![item.title, item.contextLabel, item.audienceLabel].whereType<String>().any(
                (value) => value.toLowerCase().contains(normalizedSearch),
              )) {
            return false;
          }
          if (query.statuses.isNotEmpty && !query.statuses.contains(item.status)) {
            return false;
          }
          if (query.operationalStatuses.isNotEmpty &&
              !query.operationalStatuses.contains(item.operationalStatus)) {
            return false;
          }
          if (query.kinds.isNotEmpty && !query.kinds.contains(item.kind)) {
            return false;
          }
          if (query.startsOnOrAfter case final start? when item.updatedAt.isBefore(start)) {
            return false;
          }
          if (query.endsOnOrBefore case final end? when item.updatedAt.isAfter(end)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    final offset = _decodeCursor(query.cursor);
    if (offset > filtered.length) {
      throw const FormApiException(
        FormApiFailureKind.validation,
        'O cursor local não pertence a esta consulta.',
      );
    }
    final end = (offset + query.limit).clamp(0, filtered.length);
    return FormCursorPage(
      items: filtered.sublist(offset, end),
      nextCursor: end < filtered.length ? _encodeCursor(end) : null,
    );
  }

  static int _decodeCursor(String? cursor) {
    if (cursor == null) return 0;
    try {
      final decoded = utf8.decode(base64Url.decode(base64Url.normalize(cursor)));
      if (!decoded.startsWith(_cursorPrefix)) throw const FormatException();
      final offset = int.parse(decoded.substring(_cursorPrefix.length));
      if (offset < 0) throw const FormatException();
      return offset;
    } on FormatException {
      throw const FormApiException(FormApiFailureKind.validation, 'Cursor local inválido.');
    }
  }

  static String _encodeCursor(int offset) => base64Url.encode(utf8.encode('$_cursorPrefix$offset'));

  static List<FormDirectoryItem> _seedItems() {
    const titles = [
      'Pesquisa anual das famílias',
      'Enquete rápida sobre transporte',
      'Autorização para passeio cultural',
      'Avaliação da reunião pedagógica',
      'Inscrição nas oficinas de primavera',
      'Pesquisa de alimentação escolar',
      'Consulta sobre atividades extracurriculares',
      'Confirmação da festa da comunidade',
      'Levantamento de acessibilidade',
      'Enquete sobre horários de atendimento',
      'Atualização de contatos responsáveis',
      'Pesquisa de acolhimento das famílias',
      'Autorização para uso de imagem',
      'Avaliação do encontro de responsáveis',
      'Inscrição na semana da leitura',
      'Consulta sobre o calendário letivo',
      'Enquete de satisfação da cantina',
      'Confirmação de participação na mostra',
      'Levantamento de necessidades alimentares',
      'Pesquisa sobre comunicação institucional',
      'Autorização para atividade externa',
      'Avaliação do período de adaptação',
      'Inscrição no encontro esportivo',
      'Consulta sobre apoio pedagógico',
      'Enquete de preferência de oficinas',
      'Confirmação de rematrícula',
      'Levantamento de recursos de inclusão',
      'Pesquisa de convivência escolar',
      'Autorização para visita técnica',
      'Avaliação semestral da instituição',
    ];
    const operationalStatuses = [
      FormOperationalStatus.scheduled,
      FormOperationalStatus.active,
      FormOperationalStatus.draft,
      FormOperationalStatus.closed,
      FormOperationalStatus.archived,
    ];
    const contexts = [
      'Instituição Horizonte',
      'Unidade Centro',
      'Turma Ipê Amarelo',
      'Atividade Período Integral',
      'Unidade Jardim',
    ];
    const audiences = [
      'Todas as famílias',
      'Responsáveis da Unidade Centro',
      'Turma Ipê Amarelo',
      'Perfil Responsável',
      'Pessoas selecionadas',
    ];

    return List.generate(titles.length, (index) {
      final operationalStatus = operationalStatuses[index % operationalStatuses.length];
      final status = switch (operationalStatus) {
        FormOperationalStatus.draft => FormStatus.draft,
        FormOperationalStatus.archived => FormStatus.archived,
        _ => FormStatus.published,
      };
      return FormDirectoryItem(
        id: index == 0
            ? 'form-family-annual-survey'
            : 'form-dev-${(index + 1).toString().padLeft(2, '0')}',
        title: titles[index],
        kind: index % 3 == 1 ? FormKind.quickPoll : FormKind.form,
        status: status,
        operationalStatus: operationalStatus,
        identityMode: index.isEven ? FormIdentityMode.identified : FormIdentityMode.anonymous,
        contextLabel: contexts[index % contexts.length],
        audienceLabel: audiences[index % audiences.length],
        responseCount: status == FormStatus.draft ? 0 : 6 + (index * 3),
        scheduleCount: operationalStatus == FormOperationalStatus.draft ? 0 : 1 + (index % 3),
        createdAt: DateTime(2026, 6, 1).add(Duration(days: index)),
        updatedAt: DateTime(2026, 8, 30).subtract(Duration(days: index)),
        managementVersion: 1 + (index % 4),
      );
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
