import 'dart:io';

/// Le as listas de valores permitidos (`check (<coluna> in (...))`) de dentro da
/// definicao de UMA tabela do pacote de banco.
///
/// O escopo por tabela e obrigatorio e foi aprendido errando: nomes como
/// `status`, `origin` e `context_kind` se repetem em dezenas de tabelas, e a
/// uniao indiscriminada acusou a Agenda de nao mapear valores de convites,
/// importacoes e auditoria. Varredura fora de escopo nao mede contrato nenhum.
Map<String, Set<String>> databaseCheckConstraints(Directory package, String table) {
  final constraints = <String, Set<String>>{};
  final pattern = RegExp(
    r"check\s*\(\s*([a-z_]+)\s+in\s*\(([^)]*)\)\s*\)",
    caseSensitive: false,
  );
  final header = RegExp(
    'create\\s+table\\s+(?:if\\s+not\\s+exists\\s+)?(?:[a-z_]+\\.)?$table\\s*\\(',
    caseSensitive: false,
  );
  final alter = RegExp(
    'alter\\s+table\\s+(?:[a-z_]+\\.)?$table[^;]*;',
    caseSensitive: false,
  );
  for (final file in package.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.sql')) continue;
    if (file.path.replaceAll(r'\', '/').contains('/tests/')) continue;
    final text = file.readAsStringSync();
    final scoped = StringBuffer();
    for (final start in header.allMatches(text)) {
      var depth = 0;
      for (var index = start.end - 1; index < text.length; index++) {
        if (text[index] == '(') depth++;
        if (text[index] == ')') {
          depth--;
          if (depth == 0) {
            scoped.write(text.substring(start.end, index));
            break;
          }
        }
      }
    }
    for (final constraint in alter.allMatches(text)) {
      scoped.write(constraint.group(0));
    }
    for (final match in pattern.allMatches(scoped.toString())) {
      final values = RegExp("'([^']*)'")
          .allMatches(match.group(2)!)
          .map((entry) => entry.group(1)!)
          .toSet();
      constraints.putIfAbsent(match.group(1)!, () => <String>{}).addAll(values);
    }
  }
  return constraints;
}

/// Raiz do repositorio, a partir do diretorio corrente do teste.
Directory repositoryRootForContracts() {
  var directory = Directory.current;
  for (var level = 0; level < 6; level++) {
    if (Directory('${directory.path}/packages/coelo_database').existsSync()) return directory;
    directory = directory.parent;
  }
  throw StateError(
    'packages/coelo_database nao encontrado a partir de ${Directory.current.path}',
  );
}
