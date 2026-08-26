import 'dart:convert';
import 'dart:io';

import 'package:coelo_catalog/catalog/catalog_sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/validate_catalog_sync.dart';

void main() {
  late Directory repositoryRoot;
  late File indexFile;
  late File registryFile;
  late File reportFile;

  setUp(() {
    repositoryRoot = Directory.systemTemp.createTempSync('coelo_catalog_sync_test_');
    indexFile = _write(repositoryRoot, 'index.jsonl', '');
    registryFile = _write(
      repositoryRoot,
      'apps/catalog/lib/catalog/catalog_registry.dart',
      _registrySource(const []),
    );
    reportFile = File('${repositoryRoot.path}${Platform.pathSeparator}sync-report.json');
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/coelo_ui_core.dart',
      "export 'src/public_widget.dart';",
    );
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/src/public_widget.dart',
      'final class PublicWidget extends StatelessWidget {}',
    );
    _writeIndex(indexFile, _entry());
  });

  tearDown(() {
    if (repositoryRoot.existsSync()) {
      repositoryRoot.deleteSync(recursive: true);
    }
  });

  test('reports a public widget exported without an index entry', () {
    indexFile.writeAsStringSync('');

    final report = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );

    expect(report.diagnostics, contains(_diagnostic('missing-index-entry')));
    expect(report.status, CatalogSyncStatus.catalogStale);
  });

  test('reports an indexed component whose public file does not exist', () {
    _writeIndex(indexFile, _entry(publicFile: 'packages/coelo_ui_core/lib/missing.dart'));

    final report = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );

    expect(report.diagnostics, contains(_diagnostic('missing-public-file')));
  });

  test('reports source changed while the indexed example stayed stale', () {
    final baseline = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );
    reportFile.writeAsStringSync(jsonEncode(baseline.toJson()));
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/src/public_widget.dart',
      'final class PublicWidget extends StatefulWidget {}',
    );

    final report = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );

    expect(report.diagnostics, contains(_diagnostic('source-example-fingerprint-mismatch')));
  });

  test('clears the fingerprint diagnostic after source and example advance together', () {
    final baseline = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );
    reportFile.writeAsStringSync(jsonEncode(baseline.toJson()));
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/src/public_widget.dart',
      'final class PublicWidget extends StatefulWidget {}',
    );
    _writeIndex(indexFile, _entry(example: 'const PublicWidget(key: key)'));

    final report = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );

    expect(report.diagnostics, isNot(contains(_diagnostic('source-example-fingerprint-mismatch'))));
  });

  test('reports variants implemented in registry but absent from the index', () {
    registryFile.writeAsStringSync(_registrySource(const ['compact']));

    final report = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );

    expect(report.diagnostics, contains(_diagnostic('registry-index-variants-mismatch')));
  });

  test('reports implemented index ids missing from the strict registry manifest', () {
    registryFile.writeAsStringSync(_registrySource(const [], id: 'core.other-widget'));

    final report = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );

    expect(report.diagnostics, contains(_diagnostic('missing-registry-entry')));
    expect(report.diagnostics, contains(_diagnostic('orphan-registry-entry')));
  });

  test('accepts a registered exported public non-widget utility', () {
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/coelo_ui_core.dart',
      "export 'src/public_formatter.dart';",
    );
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/src/public_formatter.dart',
      'final class PublicFormatter { const PublicFormatter(); }',
    );
    _writeIndex(indexFile, _entry(id: 'core.public-formatter', name: 'PublicFormatter'));
    registryFile.writeAsStringSync(_registrySource(const [], id: 'core.public-formatter'));

    final report = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );

    expect(report.diagnostics, isEmpty);
    expect(report.status, CatalogSyncStatus.synchronized);
  });

  test('reports a registered public utility missing from the package exports', () {
    _write(repositoryRoot, 'packages/coelo_ui_core/lib/coelo_ui_core.dart', '');
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/src/public_formatter.dart',
      'final class PublicFormatter { const PublicFormatter(); }',
    );
    _writeIndex(indexFile, _entry(id: 'core.public-formatter', name: 'PublicFormatter'));
    registryFile.writeAsStringSync(_registrySource(const [], id: 'core.public-formatter'));

    final report = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );

    expect(report.diagnostics, contains(_diagnostic('public-widget-not-exported')));
  });

  test('ignores export and class declarations inside multiline strings', () {
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/coelo_ui_core.dart',
      "const fakeExport = '''\nexport 'src/public_formatter.dart';\n''';",
    );
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/src/public_formatter.dart',
      "const fakeDeclaration = '''\nfinal class PublicFormatter {}\n''';",
    );
    _writeIndex(indexFile, _entry(id: 'core.public-formatter', name: 'PublicFormatter'));
    registryFile.writeAsStringSync(_registrySource(const [], id: 'core.public-formatter'));

    final report = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );

    expect(report.diagnostics, contains(_diagnostic('public-widget-not-exported')));
  });
  test('reports an exported public utility source change without an example update', () {
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/coelo_ui_core.dart',
      "export 'src/public_formatter.dart';",
    );
    final sourceFile = _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/src/public_formatter.dart',
      'final class PublicFormatter { const PublicFormatter(); }',
    );
    _writeIndex(indexFile, _entry(id: 'core.public-formatter', name: 'PublicFormatter'));
    registryFile.writeAsStringSync(_registrySource(const [], id: 'core.public-formatter'));
    final baseline = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );
    reportFile.writeAsStringSync(jsonEncode(baseline.toJson()));
    sourceFile.writeAsStringSync(
      'final class PublicFormatter { const PublicFormatter(); String format() => "formatted"; }',
    );

    final report = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );

    expect(report.diagnostics, contains(_diagnostic('source-example-fingerprint-mismatch')));
  });

  test('ignores source newline style changes', () {
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/coelo_ui_core.dart',
      "export 'src/public_formatter.dart';",
    );
    final sourceFile = _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/src/public_formatter.dart',
      'final class PublicFormatter {\r\n  const PublicFormatter();\r\n}\r\n',
    );
    _writeIndex(indexFile, _entry(id: 'core.public-formatter', name: 'PublicFormatter'));
    registryFile.writeAsStringSync(_registrySource(const [], id: 'core.public-formatter'));
    final baseline = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );
    reportFile.writeAsStringSync(jsonEncode(baseline.toJson()));
    sourceFile.writeAsStringSync('final class PublicFormatter {\n  const PublicFormatter();\n}\n');

    final report = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );

    expect(report.diagnostics, isNot(contains(_diagnostic('source-example-fingerprint-mismatch'))));
  });
  test('accepts and fingerprints a private superadmin entry outside the registry', () {
    _write(repositoryRoot, 'packages/coelo_ui_core/lib/coelo_ui_core.dart', '');
    final privateFile = _write(
      repositoryRoot,
      'apps/superadmin/lib/features/example/private_surface.dart',
      'final class PrivateSurface {}',
    );
    _writeIndex(
      indexFile,
      _entry(
        id: 'superadmin.private-surface',
        name: 'PrivateSurface',
        ownerPackage: 'coelo_superadmin',
        publicFile: 'apps/superadmin/lib/features/example/private_surface.dart',
      ),
    );
    registryFile.writeAsStringSync("const catalogRegistryManifestJson = r'''{}''';");

    final report = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );

    expect(report.diagnostics, isEmpty);
    expect(
      report.fingerprints['superadmin.private-surface']?.source,
      catalogSyncFingerprint(privateFile.readAsBytesSync()),
    );
  });

  test('ignores manifest-looking text inside comments', () {
    registryFile.writeAsStringSync('''
// const catalogRegistryManifestJson = r\'\'\'{"comment.fake":[]}\'\'\';
${_registrySource(const [])}
''');

    final report = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );

    expect(report.diagnostics, isEmpty);
  });

  test('reports malformed registry manifest instead of silently omitting entries', () {
    registryFile.writeAsStringSync(
      "const catalogRegistryManifestJson = r'''{\"core.public-widget\":\"compact\"}''';",
    );

    final report = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );

    expect(report.diagnostics, contains(_diagnostic('invalid-registry-manifest')));
    expect(report.diagnostics, contains(_diagnostic('missing-registry-entry')));
  });

  test('reports a deprecated component without an applicable replacement', () {
    _writeIndex(indexFile, _entry(status: 'deprecated'));

    final report = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );

    expect(report.diagnostics, contains(_diagnostic('missing-replacement')));
  });

  test('rejects self, absent, deprecated, and cyclic replacements', () {
    _writeIndexEntries(indexFile, [
      _entry(id: 'self', status: 'deprecated', replacement: 'self'),
      _entry(id: 'missing', status: 'deprecated', replacement: 'not-there'),
      _entry(id: 'deprecated-a', status: 'deprecated', replacement: 'deprecated-b'),
      _entry(id: 'deprecated-b', status: 'deprecated', replacement: 'deprecated-a'),
    ]);
    registryFile.writeAsStringSync(_registrySource(const [], id: 'unused'));

    final report = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: repositoryRoot,
    );

    expect(
      report.diagnostics.where((diagnostic) => diagnostic.code == 'invalid-replacement'),
      hasLength(greaterThanOrEqualTo(4)),
    );
    expect(report.diagnostics, contains(_diagnostic('replacement-cycle')));
  });

  for (final unsafePath in [
    '/absolute/widget.dart',
    '../outside.dart',
    r'packages\coelo_ui_core\lib\widget.dart',
    r'C:\outside.dart',
  ]) {
    test('rejects unsafe public path $unsafePath before reading it', () {
      _writeIndex(indexFile, _entry(publicFile: unsafePath));

      final report = _validate(
        indexFile: indexFile,
        registryFile: registryFile,
        reportFile: reportFile,
        repositoryRoot: repositoryRoot,
      );

      expect(report.diagnostics, contains(_diagnostic('invalid-public-file-path')));
    });
  }

  test('accepts safe paths when the repository root contains dot segments', () {
    Directory('${repositoryRoot.path}${Platform.pathSeparator}nested').createSync();
    final dottedRoot = Directory(
      '${repositoryRoot.path}${Platform.pathSeparator}'
      'nested${Platform.pathSeparator}..',
    );

    final report = _validate(
      indexFile: indexFile,
      registryFile: registryFile,
      reportFile: reportFile,
      repositoryRoot: dottedRoot,
    );

    expect(report.diagnostics, isNot(contains(_diagnostic('invalid-public-file-path'))));
  });

  test('uses a deterministic dependency-free fingerprint', () {
    expect(
      catalogSyncFingerprint(utf8.encode('Coelo')),
      catalogSyncFingerprint(utf8.encode('Coelo')),
    );
    expect(
      catalogSyncFingerprint(utf8.encode('Coelo')),
      isNot(catalogSyncFingerprint(utf8.encode('coelo'))),
    );
  });

  test('command writes the JSON report and always returns zero', () {
    final output = <String>[];

    final result = runCatalogSyncCommand([
      indexFile.path,
      registryFile.path,
      reportFile.path,
      repositoryRoot.path,
    ], writeOutput: output.add);

    expect(result, 0);
    expect(reportFile.existsSync(), isTrue);
    expect(
      CatalogSyncReport.fromJson(
        jsonDecode(reportFile.readAsStringSync()) as Map<String, Object?>,
      ).status,
      CatalogSyncStatus.synchronized,
    );
    expect(output, isNotEmpty);

    final invalidResult = runCatalogSyncCommand(const [], writeOutput: output.add);
    expect(invalidResult, 0);
  });
}

CatalogSyncReport _validate({
  required File indexFile,
  required File registryFile,
  required File reportFile,
  required Directory repositoryRoot,
}) {
  return validateCatalogSync(
    indexFile: indexFile,
    registryFile: registryFile,
    previousReportFile: reportFile,
    repositoryRoot: repositoryRoot,
  );
}

Map<String, Object?> _entry({
  String id = 'core.public-widget',
  String name = 'PublicWidget',
  String ownerPackage = 'coelo_ui_core',
  String publicFile = 'packages/coelo_ui_core/lib/coelo_ui_core.dart',
  String status = 'implemented',
  String example = 'const PublicWidget()',
  String? replacement,
}) {
  return {
    'id': id,
    'name': name,
    'ownerPackage': ownerPackage,
    'status': status,
    'publicFile': publicFile,
    'example': example,
    'variants': <String>[],
    'replacement': replacement,
  };
}

String _registrySource(List<String> variants, {String id = 'core.public-widget'}) {
  final manifest = jsonEncode({id: variants});
  return '''
const catalogRegistryManifestJson = r\'\'\'$manifest\'\'\';
''';
}

void _writeIndex(File file, Map<String, Object?> entry) {
  file.writeAsStringSync('${jsonEncode(entry)}\n');
}

void _writeIndexEntries(File file, List<Map<String, Object?>> entries) {
  file.writeAsStringSync('${entries.map(jsonEncode).join('\n')}\n');
}

File _write(Directory root, String relativePath, String contents) {
  final file = File(
    '${root.path}${Platform.pathSeparator}'
    '${relativePath.replaceAll('/', Platform.pathSeparator)}',
  );
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
  return file;
}

Matcher _diagnostic(String code) => predicate(
  (Object? value) => value is CatalogSyncDiagnostic && value.code == code,
  'CatalogSyncDiagnostic with code $code',
);
