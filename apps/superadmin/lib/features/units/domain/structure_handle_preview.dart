/// Prévia do @ que o servidor gera quando o formulário não informa um
/// (`create_unit_for_superadmin`, lote 211400; gatilho `groups_assign_handle`).
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

/// Stem do @ da atividade como `app_private.activity_slugify`: minúsculas sem
/// acento, blocos de [a-z0-9] separados por hífen.
String activityHandleStemFromName(String value) {
  var text = value.toLowerCase();
  for (final entry in _accents.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  return text.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
}
