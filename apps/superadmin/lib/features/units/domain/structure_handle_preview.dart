/// Prévia do @ que o servidor gera quando o formulário não informa um
/// (`create_unit_for_superadmin`, lote 211400; gatilho `groups_assign_handle`;
/// `superadmin_activity_create_v2`, lote 100).
/// O servidor é a fonte da verdade: a prévia só aproxima o segmento e o corte,
/// e a tela diz que ele confirma ao salvar.
library;

const _accents = {
  'á': 'a',
  'à': 'a',
  'ã': 'a',
  'â': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'õ': 'o',
  'ô': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
};

/// Letras e números minúsculos, sem acento: um segmento do @.
String structureHandleSegment(String value) {
  var text = value.toLowerCase();
  for (final entry in _accents.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  return text.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// `@nomedaunidade.nomedainstituicao`, até 30 caracteres como no servidor.
String previewUnitHandle({required String name, required String institutionSlug}) {
  final institution = switch (structureHandleSegment(institutionSlug)) {
    '' => 'instituicao',
    final segment => segment.length > 24 ? segment.substring(0, 24) : segment,
  };
  final unit = switch (structureHandleSegment(name)) {
    '' => 'unidade',
    final segment => segment,
  };
  final room = (30 - institution.length - 1).clamp(1, 30);
  return '${unit.length > room ? unit.substring(0, room) : unit}.$institution';
}

/// `@nomedaturma.nomedaunidade` (o @ da unidade já traz a instituição).
String previewGroupHandle({required String name, required String unitHandle}) {
  final group = switch (structureHandleSegment(name)) {
    '' => 'turma',
    final segment => segment,
  };
  final unit = unitHandle.trim().isEmpty ? 'nomedaunidade' : unitHandle.trim();
  return '$group.$unit';
}

/// Stem do @ da atividade como o servidor gera quando o campo fica vazio
/// (`structure_handle_segment` do nome, lote 100): mesmo segmento das
/// unidades e turmas, até 20 caracteres, sem hífen.
String activityHandleStemFromName(String value) {
  final segment = structureHandleSegment(value);
  return segment.length > 20 ? segment.substring(0, 20) : segment;
}

/// Regra do stem no servidor (`set_activity_canonical_handle`, lote 100).
final RegExp activityHandleStemPattern = RegExp(r'^[a-z0-9][a-z0-9_]{0,62}[a-z0-9]$');
const String activityHandleStemRule =
    'Use de 2 a 64 caracteres: letras minúsculas, números e sublinhado.';

/// Stem digitado como `app_private.activity_handle_stem_normalize`: sem o @,
/// minúsculas, só o primeiro segmento, sem acento, só `[a-z0-9_]`.
String activityHandleStemNormalize(String value) {
  var text = value.trim().toLowerCase();
  if (text.startsWith('@')) text = text.substring(1);
  text = text.split('.').first;
  for (final entry in _accents.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  return text.replaceAll(RegExp(r'[^a-z0-9_]'), '');
}

/// `@stem.@dainstituicao` (lote 100; a atividade criada pelo Superadmin nasce
/// no escopo da instituição). Com `handleStem` vazio o stem sai do nome.
String previewActivityHandle({
  required String name,
  required String handleStem,
  required String institutionHandle,
}) {
  final stem = switch (activityHandleStemNormalize(handleStem)) {
    '' => switch (activityHandleStemFromName(name)) {
      '' => 'atividade',
      final segment => segment,
    },
    final typed => typed,
  };
  final institution = institutionHandle.trim().isEmpty
      ? 'nomedainstituicao'
      : institutionHandle.trim();
  return '$stem.$institution';
}
