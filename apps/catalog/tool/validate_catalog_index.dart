import 'dart:convert';
import 'dart:io';

const _requiredKeys = <String>{
  'id',
  'name',
  'category',
  'status',
  'ownerPackage',
  'consumers',
  'purpose',
  'useWhen',
  'doNotUseWhen',
  'variants',
  'states',
  'tokens',
  'accessibility',
  'publicFile',
  'tests',
  'example',
  'replacement',
};

const _stringKeys = <String>{
  'id',
  'name',
  'category',
  'status',
  'ownerPackage',
  'purpose',
  'useWhen',
  'doNotUseWhen',
  'accessibility',
  'publicFile',
  'example',
};

const _listKeys = <String>{'consumers', 'variants', 'states', 'tokens', 'tests'};

const _statuses = <String>{'proposed', 'approved', 'implemented', 'deprecated', 'catalog-stale'};

const _consumers = <String>{'shared', 'admin', 'superadmin', 'principal', 'auth', 'astro-planned'};

final class CatalogIndexDiagnostic {
  const CatalogIndexDiagnostic({
    required this.code,
    required this.message,
    required this.line,
    this.field,
    this.id,
    this.path,
  });

  final String code;
  final String message;
  final int line;
  final String? field;
  final String? id;
  final String? path;

  @override
  String toString() {
    final location = line > 0 ? 'linha $line' : 'indice';
    final context = [
      if (id != null) id,
      if (field != null) field,
      if (path != null) path,
    ].join(' / ');
    return '[$code] $location${context.isEmpty ? '' : ' ($context)'}: $message';
  }
}

final class CatalogIndexValidationResult {
  const CatalogIndexValidationResult(this.diagnostics);

  final List<CatalogIndexDiagnostic> diagnostics;

  bool get isValid => diagnostics.isEmpty;
}

CatalogIndexValidationResult validateCatalogIndex({
  required File indexFile,
  required Directory repositoryRoot,
}) {
  final diagnostics = <CatalogIndexDiagnostic>[];
  if (!indexFile.existsSync()) {
    return CatalogIndexValidationResult([
      CatalogIndexDiagnostic(
        code: 'missing-index-file',
        message: 'O arquivo do indice nao existe.',
        line: 0,
        path: indexFile.path,
      ),
    ]);
  }

  final ids = <String>{};
  final lines = const LineSplitter().convert(indexFile.readAsStringSync());
  for (var index = 0; index < lines.length; index++) {
    final lineNumber = index + 1;
    final source = lines[index].trim();
    if (source.isEmpty) {
      continue;
    }

    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      diagnostics.add(
        CatalogIndexDiagnostic(
          code: 'invalid-json',
          message: 'JSON invalido: ${error.message}',
          line: lineNumber,
        ),
      );
      continue;
    }

    if (decoded is! Map<String, Object?>) {
      diagnostics.add(
        CatalogIndexDiagnostic(
          code: 'invalid-entry',
          message: 'Cada linha deve ser um objeto JSON.',
          line: lineNumber,
        ),
      );
      continue;
    }

    final entry = decoded;
    final id = entry['id'] is String ? entry['id']! as String : null;
    for (final key in _requiredKeys) {
      if (!entry.containsKey(key)) {
        diagnostics.add(
          CatalogIndexDiagnostic(
            code: 'missing-key',
            message: 'Chave obrigatoria ausente.',
            line: lineNumber,
            field: key,
            id: id,
          ),
        );
      }
    }

    for (final key in _stringKeys) {
      final value = entry[key];
      if (entry.containsKey(key) && (value is! String || value.trim().isEmpty)) {
        diagnostics.add(
          CatalogIndexDiagnostic(
            code: 'invalid-field-type',
            message: 'O campo deve ser uma string nao vazia.',
            line: lineNumber,
            field: key,
            id: id,
          ),
        );
      }
    }

    for (final key in _listKeys) {
      final value = entry[key];
      if (entry.containsKey(key) &&
          (value is! List<Object?> ||
              value.any((item) => item is! String || item.trim().isEmpty))) {
        diagnostics.add(
          CatalogIndexDiagnostic(
            code: 'invalid-field-type',
            message: 'O campo deve ser uma lista de strings nao vazias.',
            line: lineNumber,
            field: key,
            id: id,
          ),
        );
      }
    }

    final replacement = entry['replacement'];
    if (entry.containsKey('replacement') && replacement != null && replacement is! String) {
      diagnostics.add(
        CatalogIndexDiagnostic(
          code: 'invalid-field-type',
          message: 'O campo deve ser nulo ou uma string nao vazia.',
          line: lineNumber,
          field: 'replacement',
          id: id,
        ),
      );
    }

    if (id != null && id.trim().isNotEmpty && !ids.add(id)) {
      diagnostics.add(
        CatalogIndexDiagnostic(
          code: 'duplicate-id',
          message: 'O id ja foi declarado.',
          line: lineNumber,
          field: 'id',
          id: id,
        ),
      );
    }

    final status = entry['status'];
    if (status is String && !_statuses.contains(status)) {
      diagnostics.add(
        CatalogIndexDiagnostic(
          code: 'invalid-status',
          message: 'Status nao reconhecido.',
          line: lineNumber,
          field: 'status',
          id: id,
        ),
      );
    }

    final consumers = entry['consumers'];
    if (consumers is List<Object?> && consumers.every((item) => item is String)) {
      for (final consumer in consumers.cast<String>()) {
        if (!_consumers.contains(consumer)) {
          diagnostics.add(
            CatalogIndexDiagnostic(
              code: 'invalid-consumer',
              message: 'Consumidor nao reconhecido: $consumer.',
              line: lineNumber,
              field: 'consumers',
              id: id,
            ),
          );
        }
      }
    }

    if (status == 'deprecated' && (replacement is! String || replacement.trim().isEmpty)) {
      diagnostics.add(
        CatalogIndexDiagnostic(
          code: 'missing-replacement',
          message: 'Um componente descontinuado deve indicar seu substituto.',
          line: lineNumber,
          field: 'replacement',
          id: id,
        ),
      );
    }

    final validateExistence =
        status == 'implemented' || status == 'deprecated' || status == 'catalog-stale';
    final publicFile = entry['publicFile'];
    if (publicFile is String) {
      _validatePath(
        path: publicFile,
        field: 'publicFile',
        missingCode: 'missing-public-file',
        line: lineNumber,
        id: id,
        repositoryRoot: repositoryRoot,
        validateExistence: validateExistence,
        diagnostics: diagnostics,
      );
    }

    final tests = entry['tests'];
    if (tests is List<Object?> && tests.every((item) => item is String)) {
      for (final testPath in tests.cast<String>()) {
        _validatePath(
          path: testPath,
          field: 'tests',
          missingCode: 'missing-test-file',
          line: lineNumber,
          id: id,
          repositoryRoot: repositoryRoot,
          validateExistence: validateExistence,
          diagnostics: diagnostics,
        );
      }
    }
  }

  return CatalogIndexValidationResult(List.unmodifiable(diagnostics));
}

void _validatePath({
  required String path,
  required String field,
  required String missingCode,
  required int line,
  required String? id,
  required Directory repositoryRoot,
  required bool validateExistence,
  required List<CatalogIndexDiagnostic> diagnostics,
}) {
  if (!_isSafeRelativePath(path)) {
    diagnostics.add(
      CatalogIndexDiagnostic(
        code: 'invalid-relative-path',
        message: 'Use um caminho relativo a raiz do repositorio com separadores "/".',
        line: line,
        field: field,
        id: id,
        path: path,
      ),
    );
    return;
  }

  if (!validateExistence) {
    return;
  }

  final platformPath = path.replaceAll('/', Platform.pathSeparator);
  final file = File('${repositoryRoot.absolute.path}${Platform.pathSeparator}$platformPath');
  if (!file.existsSync()) {
    diagnostics.add(
      CatalogIndexDiagnostic(
        code: missingCode,
        message: 'O arquivo referenciado nao existe.',
        line: line,
        field: field,
        id: id,
        path: path,
      ),
    );
  }
}

bool _isSafeRelativePath(String path) {
  if (path.isEmpty ||
      path.startsWith('/') ||
      path.contains(r'\') ||
      RegExp(r'^[A-Za-z]:').hasMatch(path)) {
    return false;
  }
  final segments = path.split('/');
  return !segments.contains('..') && !segments.contains('');
}

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln('Uso: dart tool/validate_catalog_index.dart <indice.jsonl> <raiz-repositorio>');
    exitCode = 64;
    return;
  }

  final result = validateCatalogIndex(
    indexFile: File(arguments[0]),
    repositoryRoot: Directory(arguments[1]),
  );
  for (final diagnostic in result.diagnostics) {
    stdout.writeln(diagnostic);
  }
  stdout.writeln(
    result.isValid
        ? 'Indice Coelo UI valido: zero diagnostico.'
        : 'Indice Coelo UI invalido: ${result.diagnostics.length} diagnostico(s).',
  );
  if (!result.isValid) {
    exitCode = 1;
  }
}
