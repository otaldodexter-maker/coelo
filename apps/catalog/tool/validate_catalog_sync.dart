import 'dart:convert';
import 'dart:io';

import 'package:coelo_catalog/catalog/catalog_sync_status.dart';

import 'validate_package_boundaries.dart';

CatalogSyncReport validateCatalogSync({
  required File indexFile,
  required File registryFile,
  required File previousReportFile,
  required Directory repositoryRoot,
}) {
  final diagnostics = <CatalogSyncDiagnostic>[];
  final entries = _readIndex(indexFile, diagnostics);
  final registryVariants = _readRegistryVariants(registryFile, diagnostics);
  final publicDeclarations = {
    for (final declaration in discoverPublicWidgetDeclarations(repositoryRoot: repositoryRoot))
      _declarationKey(declaration.ownerPackage, declaration.name): declaration,
  };

  final boundaryResult = validatePackageBoundaries(
    indexFile: indexFile,
    repositoryRoot: repositoryRoot,
  );
  for (final diagnostic in boundaryResult.diagnostics) {
    if (diagnostic.code == 'missing-index-entry') {
      diagnostics.add(
        CatalogSyncDiagnostic(
          code: diagnostic.code,
          message: diagnostic.message,
          id: diagnostic.name,
          path: diagnostic.path,
        ),
      );
    }
  }

  final safePublicFiles = <String, File>{};
  for (final entry in entries.values) {
    final publicFile = _resolveSafePublicFile(
      repositoryRoot: repositoryRoot,
      entry: entry,
      diagnostics: diagnostics,
    );
    if (publicFile != null) {
      safePublicFiles[entry.id] = publicFile;
    }
    if (_requiresImplementation(entry.status) && publicFile != null && !publicFile.existsSync()) {
      diagnostics.add(
        CatalogSyncDiagnostic(
          code: 'missing-public-file',
          message: 'O arquivo público referenciado não existe.',
          id: entry.id,
          path: entry.publicFile,
        ),
      );
    }
  }

  final expectedRegistryIds = entries.values
      .where((entry) => _requiresImplementation(entry.status))
      .map((entry) => entry.id)
      .toSet();
  for (final id in expectedRegistryIds) {
    final entry = entries[id]!;
    final registeredVariants = registryVariants[entry.id];
    if (registeredVariants == null) {
      diagnostics.add(
        CatalogSyncDiagnostic(
          code: 'missing-registry-entry',
          message: 'O componente implementado está ausente do registry.',
          id: entry.id,
          path: registryFile.path,
        ),
      );
    } else if (!_sameStrings(registeredVariants, entry.variants)) {
      diagnostics.add(
        CatalogSyncDiagnostic(
          code: 'registry-index-variants-mismatch',
          message: 'As variantes do registry e do índice são diferentes.',
          id: entry.id,
          path: registryFile.path,
        ),
      );
    }
  }
  for (final id in registryVariants.keys.where((id) => !expectedRegistryIds.contains(id))) {
    diagnostics.add(
      CatalogSyncDiagnostic(
        code: 'orphan-registry-entry',
        message: 'O registry contém componente sem implementação ativa no índice.',
        id: id,
        path: registryFile.path,
      ),
    );
  }

  _validateReplacements(entries, diagnostics);

  final previous = _readPreviousReport(previousReportFile, diagnostics);
  final fingerprints = <String, CatalogSyncFingerprint>{};
  for (final entry in entries.values) {
    final publicFile = safePublicFiles[entry.id];
    final declaration = publicDeclarations[_declarationKey(entry.ownerPackage, entry.name)];
    File? sourceFile;
    if (publicFile != null && declaration != null) {
      sourceFile = _containedFile(repositoryRoot, declaration.file);
      if (sourceFile == null) {
        diagnostics.add(
          CatalogSyncDiagnostic(
            code: 'invalid-public-declaration-path',
            message: 'A declaração exportada está fora da raiz do repositório.',
            id: entry.id,
            path: declaration.file.path,
          ),
        );
      }
    } else if (publicFile != null && _requiresImplementation(entry.status)) {
      diagnostics.add(
        CatalogSyncDiagnostic(
          code: 'public-widget-not-exported',
          message: 'O widget público não foi localizado nos exports do pacote.',
          id: entry.id,
          path: entry.publicFile,
        ),
      );
    }
    final current = CatalogSyncFingerprint(
      source: catalogSyncFingerprint(
        sourceFile != null && sourceFile.existsSync()
            ? sourceFile.readAsBytesSync()
            : const <int>[],
      ),
      example: catalogSyncFingerprint(utf8.encode(entry.example)),
    );
    final prior = previous?.fingerprints[entry.id];
    if (prior == null) {
      fingerprints[entry.id] = current;
      continue;
    }
    final sourceChanged = prior.source != current.source;
    final exampleChanged = prior.example != current.example;
    if (sourceChanged != exampleChanged) {
      diagnostics.add(
        CatalogSyncDiagnostic(
          code: 'source-example-fingerprint-mismatch',
          message: sourceChanged
              ? 'A fonte mudou sem atualização do exemplo.'
              : 'O exemplo mudou sem atualização correspondente da fonte.',
          id: entry.id,
          path: entry.publicFile,
        ),
      );
      fingerprints[entry.id] = prior;
    } else {
      fingerprints[entry.id] = current;
    }
  }

  return CatalogSyncReport(
    status: diagnostics.isEmpty ? CatalogSyncStatus.synchronized : CatalogSyncStatus.catalogStale,
    diagnostics: List.unmodifiable(diagnostics),
    fingerprints: Map.unmodifiable(fingerprints),
  );
}

String catalogSyncFingerprint(List<int> bytes) {
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

int runCatalogSyncCommand(List<String> arguments, {void Function(String message)? writeOutput}) {
  final output = writeOutput ?? stdout.writeln;
  if (arguments.length != 4) {
    output(
      'Uso: dart tool/validate_catalog_sync.dart '
      '<indice.jsonl> <registry.dart> <relatorio.json> <raiz-repositorio>',
    );
    return 0;
  }

  final reportFile = File(arguments[2]);
  CatalogSyncReport report;
  try {
    report = validateCatalogSync(
      indexFile: File(arguments[0]),
      registryFile: File(arguments[1]),
      previousReportFile: reportFile,
      repositoryRoot: Directory(arguments[3]),
    );
  } on Object catch (error) {
    report = CatalogSyncReport(
      status: CatalogSyncStatus.catalogStale,
      diagnostics: [
        CatalogSyncDiagnostic(
          code: 'sync-validation-failed',
          message: 'A validação não pôde ser concluída: $error',
        ),
      ],
      fingerprints: const {},
    );
  }

  try {
    reportFile.parent.createSync(recursive: true);
    reportFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report.toJson()));
  } on Object catch (error) {
    output('Não foi possível gravar o relatório: $error');
  }
  for (final diagnostic in report.diagnostics) {
    output(
      '[${diagnostic.code}]'
      '${diagnostic.id == null ? '' : ' ${diagnostic.id}'}: '
      '${diagnostic.message}',
    );
  }
  output(
    report.isStale
        ? 'Catálogo desatualizado: ${report.diagnostics.length} diagnóstico(s).'
        : 'Catálogo sincronizado: zero diagnóstico.',
  );
  return 0;
}

Map<String, _IndexEntry> _readIndex(File indexFile, List<CatalogSyncDiagnostic> diagnostics) {
  if (!indexFile.existsSync()) {
    diagnostics.add(
      CatalogSyncDiagnostic(
        code: 'missing-index-file',
        message: 'O índice compacto não existe.',
        path: indexFile.path,
      ),
    );
    return const {};
  }
  final entries = <String, _IndexEntry>{};
  final lines = const LineSplitter().convert(indexFile.readAsStringSync());
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index].trim();
    if (line.isEmpty) {
      continue;
    }
    try {
      final json = jsonDecode(line) as Map<String, Object?>;
      final entry = _IndexEntry.fromJson(json);
      entries[entry.id] = entry;
    } on Object catch (error) {
      diagnostics.add(
        CatalogSyncDiagnostic(
          code: 'invalid-index-entry',
          message: 'Linha ${index + 1} inválida: $error',
          path: indexFile.path,
        ),
      );
    }
  }
  return entries;
}

Map<String, List<String>> _readRegistryVariants(
  File registryFile,
  List<CatalogSyncDiagnostic> diagnostics,
) {
  if (!registryFile.existsSync()) {
    diagnostics.add(
      CatalogSyncDiagnostic(
        code: 'missing-registry-file',
        message: 'O registry do catálogo não existe.',
        path: registryFile.path,
      ),
    );
    return const {};
  }
  final source = maskDartCommentsPreservingStrings(registryFile.readAsStringSync());
  final declarations = RegExp(
    r"const\s+catalogRegistryManifestJson\s*=\s*r'''([\s\S]*?)'''\s*;",
  ).allMatches(source).toList();
  if (declarations.length != 1) {
    diagnostics.add(
      CatalogSyncDiagnostic(
        code: 'invalid-registry-manifest',
        message: declarations.isEmpty
            ? 'O manifesto JSON do registry não foi encontrado.'
            : 'O manifesto JSON do registry deve possuir uma única declaração.',
        path: registryFile.path,
      ),
    );
    return const {};
  }
  try {
    final decoded = jsonDecode(declarations.single.group(1)!);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('O manifesto deve ser um objeto JSON.');
    }
    final result = <String, List<String>>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (entry.key.trim().isEmpty ||
          value is! List<Object?> ||
          !value.every((item) => item is String)) {
        throw FormatException(
          'A entrada ${entry.key} deve conter uma lista de variantes textuais.',
        );
      }
      result[entry.key] = List<String>.unmodifiable(value.cast<String>());
    }
    return result;
  } on Object catch (error) {
    diagnostics.add(
      CatalogSyncDiagnostic(
        code: 'invalid-registry-manifest',
        message: 'O manifesto JSON do registry é inválido: $error',
        path: registryFile.path,
      ),
    );
    return const {};
  }
}

CatalogSyncReport? _readPreviousReport(File reportFile, List<CatalogSyncDiagnostic> diagnostics) {
  if (!reportFile.existsSync()) {
    return null;
  }
  try {
    return CatalogSyncReport.fromJson(
      jsonDecode(reportFile.readAsStringSync()) as Map<String, Object?>,
    );
  } on Object {
    diagnostics.add(
      CatalogSyncDiagnostic(
        code: 'invalid-previous-report',
        message: 'O relatório anterior é inválido.',
        path: reportFile.path,
      ),
    );
    return null;
  }
}

bool _requiresImplementation(String status) =>
    status == 'implemented' || status == 'catalog-stale' || status == 'deprecated';

bool _sameStrings(List<String> left, List<String> right) {
  final normalizedLeft = [...left]..sort();
  final normalizedRight = [...right]..sort();
  if (normalizedLeft.length != normalizedRight.length) {
    return false;
  }
  for (var index = 0; index < normalizedLeft.length; index++) {
    if (normalizedLeft[index] != normalizedRight[index]) {
      return false;
    }
  }
  return true;
}

File? _resolveSafePublicFile({
  required Directory repositoryRoot,
  required _IndexEntry entry,
  required List<CatalogSyncDiagnostic> diagnostics,
}) {
  final path = entry.publicFile;
  final unsafe =
      path.isEmpty ||
      path.startsWith('/') ||
      path.startsWith(r'\') ||
      path.contains(r'\') ||
      RegExp(r'^[A-Za-z]:').hasMatch(path) ||
      path.split('/').any((segment) => segment.isEmpty || segment == '.' || segment == '..');
  if (unsafe) {
    diagnostics.add(
      CatalogSyncDiagnostic(
        code: 'invalid-public-file-path',
        message: 'O arquivo público deve usar caminho relativo seguro à raiz.',
        id: entry.id,
        path: path,
      ),
    );
    return null;
  }
  final candidate = File.fromUri(repositoryRoot.absolute.uri.resolve(path));
  final contained = _containedFile(repositoryRoot, candidate);
  if (contained == null) {
    diagnostics.add(
      CatalogSyncDiagnostic(
        code: 'invalid-public-file-path',
        message: 'O arquivo público resolve fora da raiz do repositório.',
        id: entry.id,
        path: path,
      ),
    );
  }
  return contained;
}

File? _containedFile(Directory repositoryRoot, File candidate) {
  final normalizedRoot = Directory.fromUri(repositoryRoot.absolute.uri.normalizePath());
  final rootPath = _normalizedPath(normalizedRoot.path);
  final candidatePath = _normalizedPath(File.fromUri(candidate.absolute.uri.normalizePath()).path);
  if (!_isWithin(rootPath, candidatePath)) {
    return null;
  }
  if (!candidate.existsSync()) {
    return File(candidatePath);
  }
  final resolvedRoot = _normalizedPath(normalizedRoot.resolveSymbolicLinksSync());
  final resolvedCandidate = _normalizedPath(candidate.resolveSymbolicLinksSync());
  return _isWithin(resolvedRoot, resolvedCandidate) ? File(resolvedCandidate) : null;
}

String _normalizedPath(String path) {
  final normalized = path.replaceAll(r'\', '/').replaceAll(RegExp(r'/+$'), '');
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}

bool _isWithin(String root, String candidate) =>
    candidate == root || candidate.startsWith('$root/');

String _declarationKey(String ownerPackage, String name) => '$ownerPackage::$name';

void _validateReplacements(
  Map<String, _IndexEntry> entries,
  List<CatalogSyncDiagnostic> diagnostics,
) {
  for (final entry in entries.values.where((entry) => entry.status == 'deprecated')) {
    final replacement = entry.replacement?.trim();
    if (replacement == null || replacement.isEmpty) {
      diagnostics.add(
        CatalogSyncDiagnostic(
          code: 'missing-replacement',
          message: 'O componente descontinuado não possui substituto.',
          id: entry.id,
        ),
      );
      continue;
    }
    final target = entries[replacement];
    if (replacement == entry.id || target == null || target.status == 'deprecated') {
      diagnostics.add(
        CatalogSyncDiagnostic(
          code: 'invalid-replacement',
          message: 'O substituto deve existir, ser diferente e não estar descontinuado.',
          id: entry.id,
        ),
      );
    }
  }

  final reportedCycles = <String>{};
  for (final start in entries.keys) {
    final positions = <String, int>{};
    final path = <String>[];
    String? current = start;
    while (current != null && entries.containsKey(current)) {
      final cycleStart = positions[current];
      if (cycleStart != null) {
        final cycle = path.sublist(cycleStart);
        final signature = ([...cycle]..sort()).join('|');
        if (reportedCycles.add(signature)) {
          diagnostics.add(
            CatalogSyncDiagnostic(
              code: 'replacement-cycle',
              message: 'A cadeia de substituição contém um ciclo.',
              id: cycle.first,
            ),
          );
        }
        break;
      }
      positions[current] = path.length;
      path.add(current);
      current = entries[current]!.replacement?.trim();
    }
  }
}

final class _IndexEntry {
  const _IndexEntry({
    required this.id,
    required this.name,
    required this.ownerPackage,
    required this.status,
    required this.publicFile,
    required this.example,
    required this.variants,
    required this.replacement,
  });

  factory _IndexEntry.fromJson(Map<String, Object?> json) {
    return _IndexEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerPackage: json['ownerPackage'] as String,
      status: json['status'] as String,
      publicFile: json['publicFile'] as String,
      example: json['example'] as String,
      variants: List<String>.from(json['variants'] as List<Object?>),
      replacement: json['replacement'] as String?,
    );
  }

  final String id;
  final String name;
  final String ownerPackage;
  final String status;
  final String publicFile;
  final String example;
  final List<String> variants;
  final String? replacement;
}

void main(List<String> arguments) {
  exitCode = runCatalogSyncCommand(arguments);
}
