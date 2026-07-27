import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/validate_catalog_index.dart';

void main() {
  late Directory repositoryRoot;
  late File indexFile;

  setUp(() {
    repositoryRoot = Directory.systemTemp.createTempSync('coelo_catalog_index_test_');
    indexFile = File('${repositoryRoot.path}${Platform.pathSeparator}index.jsonl');
  });

  tearDown(() {
    if (repositoryRoot.existsSync()) {
      repositoryRoot.deleteSync(recursive: true);
    }
  });

  test('reports malformed JSON with its line number', () {
    indexFile.writeAsStringSync('{invalid json}\n');

    final result = validateCatalogIndex(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(result.diagnostics, contains(_diagnostic('invalid-json', line: 1)));
  });

  test('reports duplicate ids', () {
    final entry = _validEntry();
    _writeEntries(indexFile, [entry, entry]);

    final result = validateCatalogIndex(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(result.diagnostics, contains(_diagnostic('duplicate-id', line: 2)));
  });

  test('reports every missing required key', () {
    for (final key in _requiredKeys) {
      final entry = _validEntry()..remove(key);
      _writeEntries(indexFile, [entry]);

      final result = validateCatalogIndex(indexFile: indexFile, repositoryRoot: repositoryRoot);

      expect(result.diagnostics, contains(_diagnostic('missing-key', line: 1, field: key)));
    }
  });

  test('reports invalid field types', () {
    final entry = _validEntry()..['states'] = 'enabled';
    _writeEntries(indexFile, [entry]);

    final result = validateCatalogIndex(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(
      result.diagnostics,
      contains(_diagnostic('invalid-field-type', line: 1, field: 'states')),
    );
  });

  test('reports invalid status and consumer values', () {
    final entry = _validEntry()
      ..['status'] = 'ready'
      ..['consumers'] = ['superadmin', 'website'];
    _writeEntries(indexFile, [entry]);

    final result = validateCatalogIndex(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(result.diagnostics, contains(_diagnostic('invalid-status', line: 1, field: 'status')));
    expect(
      result.diagnostics,
      contains(_diagnostic('invalid-consumer', line: 1, field: 'consumers')),
    );
  });

  test('reports an implemented entry whose public file does not exist', () {
    final entry = _validEntry()..['publicFile'] = 'packages/missing/lib/missing.dart';
    _writeEntries(indexFile, [entry]);

    final result = validateCatalogIndex(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(result.diagnostics, contains(_diagnostic('missing-public-file', line: 1)));
  });

  test('reports an implemented entry whose test file does not exist', () {
    File('${repositoryRoot.path}${Platform.pathSeparator}existing.dart').writeAsStringSync('');
    final entry = _validEntry()..['tests'] = ['missing_test.dart'];
    _writeEntries(indexFile, [entry]);

    final result = validateCatalogIndex(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(result.diagnostics, contains(_diagnostic('missing-test-file', line: 1, field: 'tests')));
  });

  test('rejects absolute, Windows, and parent-relative paths', () {
    for (final path in ['/absolute.dart', r'C:\absolute.dart', '../outside.dart']) {
      final entry = _validEntry()..['publicFile'] = path;
      _writeEntries(indexFile, [entry]);

      final result = validateCatalogIndex(indexFile: indexFile, repositoryRoot: repositoryRoot);

      expect(
        result.diagnostics,
        contains(_diagnostic('invalid-relative-path', line: 1, field: 'publicFile')),
      );
    }
  });

  test('allows an approved entry to point at its planned public file', () {
    final entry = _validEntry()
      ..['status'] = 'approved'
      ..['publicFile'] = 'packages/planned/lib/planned.dart';
    _writeEntries(indexFile, [entry]);

    final result = validateCatalogIndex(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(result.diagnostics, isEmpty);
  });

  test('reports a deprecated entry without a replacement', () {
    final entry = _validEntry()
      ..['status'] = 'deprecated'
      ..['replacement'] = null;
    _writeEntries(indexFile, [entry]);

    final result = validateCatalogIndex(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(result.diagnostics, contains(_diagnostic('missing-replacement', line: 1)));
  });

  test('accepts a structurally valid implemented entry with existing files', () {
    File('${repositoryRoot.path}${Platform.pathSeparator}existing.dart').writeAsStringSync('');
    File('${repositoryRoot.path}${Platform.pathSeparator}existing_test.dart').writeAsStringSync('');
    _writeEntries(indexFile, [_validEntry()]);

    final result = validateCatalogIndex(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(result.isValid, isTrue);
    expect(result.diagnostics, isEmpty);
  });
}

const _requiredKeys = <String>[
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
];

Matcher _diagnostic(String code, {required int line, String? field}) => predicate(
  (Object? value) =>
      value is CatalogIndexDiagnostic &&
      value.code == code &&
      value.line == line &&
      (field == null || value.field == field),
  '$code on line $line${field == null ? '' : ' for $field'}',
);

void _writeEntries(File indexFile, List<Map<String, Object?>> entries) {
  indexFile.writeAsStringSync('${entries.map(jsonEncode).join('\n')}\n');
}

Map<String, Object?> _validEntry() => {
  'id': 'core.search-field',
  'name': 'CoeloSearchField',
  'category': 'component',
  'status': 'implemented',
  'ownerPackage': 'coelo_ui_core',
  'consumers': ['superadmin'],
  'purpose': 'Busca textual administrativa.',
  'useWhen': 'Busca simples por texto.',
  'doNotUseWhen': 'Selecao de opcoes.',
  'variants': <String>[],
  'states': ['enabled', 'focused', 'disabled'],
  'tokens': ['spacing.2', 'radius.full', 'color.outline'],
  'accessibility': 'Rotulo semantico; foco por teclado.',
  'publicFile': 'existing.dart',
  'tests': ['existing_test.dart'],
  'example': "CoeloSearchField(controller: c, onChanged: search, semanticLabel: 'Buscar')",
  'replacement': null,
};
