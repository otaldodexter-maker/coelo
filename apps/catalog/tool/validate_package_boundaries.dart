import 'dart:convert';
import 'dart:io';

final class PackageBoundaryDiagnostic {
  const PackageBoundaryDiagnostic({
    required this.code,
    required this.message,
    required this.path,
    this.name,
    this.ownerPackage,
    this.importUri,
  });

  final String code;
  final String message;
  final String path;
  final String? name;
  final String? ownerPackage;
  final String? importUri;

  @override
  String toString() {
    final context = [
      if (name != null) name,
      if (ownerPackage != null) ownerPackage,
      if (importUri != null) importUri,
    ].join(' / ');
    return '[$code] $path${context.isEmpty ? '' : ' ($context)'}: $message';
  }
}

final class PackageBoundaryValidationResult {
  const PackageBoundaryValidationResult(this.diagnostics);

  final List<PackageBoundaryDiagnostic> diagnostics;

  bool get isValid => diagnostics.isEmpty;
}

PackageBoundaryValidationResult validatePackageBoundaries({
  required File indexFile,
  required Directory repositoryRoot,
}) {
  final diagnostics = <PackageBoundaryDiagnostic>[];
  final indexedOwners = _readIndexedOwners(indexFile, diagnostics);
  for (final widget in discoverPublicWidgetDeclarations(repositoryRoot: repositoryRoot)) {
    final owners = indexedOwners[widget.name];
    if (owners == null) {
      diagnostics.add(
        PackageBoundaryDiagnostic(
          code: 'missing-index-entry',
          message: 'Componente publico exportado ausente no indice.',
          path: _relativePath(repositoryRoot, widget.file),
          name: widget.name,
          ownerPackage: widget.ownerPackage,
        ),
      );
    } else if (owners.length == 1 && owners.single != widget.ownerPackage) {
      diagnostics.add(
        PackageBoundaryDiagnostic(
          code: 'owner-mismatch',
          message: 'O pacote proprietario no indice nao corresponde ao export.',
          path: _relativePath(repositoryRoot, widget.file),
          name: widget.name,
          ownerPackage: widget.ownerPackage,
        ),
      );
    }
  }

  _validateImportBoundaries(repositoryRoot, diagnostics);
  return PackageBoundaryValidationResult(List.unmodifiable(diagnostics));
}

List<PublicWidgetDeclaration> discoverPublicWidgetDeclarations({
  required Directory repositoryRoot,
}) {
  const packages = <_UiPackage>[
    _UiPackage(owner: 'coelo_ui_core', barrel: 'packages/coelo_ui_core/lib/coelo_ui_core.dart'),
    _UiPackage(owner: 'coelo_ui_admin', barrel: 'packages/coelo_ui_admin/lib/coelo_ui_admin.dart'),
    _UiPackage(
      owner: 'coelo_ui_principal',
      barrel: 'packages/coelo_ui_principal/lib/coelo_ui_principal.dart',
    ),
  ];
  final declarations = <PublicWidgetDeclaration>[];
  for (final package in packages) {
    final barrel = _fileAt(repositoryRoot, package.barrel);
    if (!barrel.existsSync()) {
      continue;
    }
    final widgets = _exportedWidgets(
      file: barrel,
      repositoryRoot: repositoryRoot,
      ownerPackage: package.owner,
      visiting: <String>{},
    );
    declarations.addAll(widgets.values);
  }
  return List.unmodifiable(declarations);
}

Map<String, List<String>> _readIndexedOwners(
  File indexFile,
  List<PackageBoundaryDiagnostic> diagnostics,
) {
  if (!indexFile.existsSync()) {
    diagnostics.add(
      PackageBoundaryDiagnostic(
        code: 'missing-index-file',
        message: 'O arquivo do indice nao existe.',
        path: indexFile.path,
      ),
    );
    return const {};
  }

  final owners = <String, List<String>>{};
  final lines = const LineSplitter().convert(indexFile.readAsStringSync());
  for (var index = 0; index < lines.length; index++) {
    final source = lines[index].trim();
    if (source.isEmpty) {
      continue;
    }
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('A entrada deve ser um objeto JSON.');
      }
      final name = decoded['name'];
      final owner = decoded['ownerPackage'] ?? decoded['owner'];
      if (name is! String || name.trim().isEmpty || owner is! String || owner.trim().isEmpty) {
        throw const FormatException('Os campos name e ownerPackage sao obrigatorios.');
      }
      final registeredOwners = owners.putIfAbsent(name, () => <String>[]);
      if (registeredOwners.isNotEmpty) {
        final duplicateOwner = registeredOwners.contains(owner);
        diagnostics.add(
          PackageBoundaryDiagnostic(
            code: duplicateOwner ? 'duplicate-index-name' : 'ambiguous-index-owner',
            message: duplicateOwner
                ? 'O nome aparece mais de uma vez no indice.'
                : 'O nome aparece com mais de um pacote proprietario.',
            path: indexFile.path,
            name: name,
            ownerPackage: owner,
          ),
        );
      }
      registeredOwners.add(owner);
    } on FormatException catch (error) {
      diagnostics.add(
        PackageBoundaryDiagnostic(
          code: 'invalid-index-entry',
          message: 'Linha ${index + 1}: ${error.message}',
          path: indexFile.path,
        ),
      );
    }
  }
  return owners;
}

Map<String, PublicWidgetDeclaration> _exportedWidgets({
  required File file,
  required Directory repositoryRoot,
  required String ownerPackage,
  required Set<String> visiting,
}) {
  final absolutePath = _normalizedAbsolutePath(file.path);
  if (!file.existsSync() || !visiting.add(absolutePath)) {
    return const {};
  }

  final source = file.readAsStringSync();
  final widgets = <String, PublicWidgetDeclaration>{
    for (final declaration in _widgetDeclarations(source, file, ownerPackage))
      declaration.name: declaration,
  };

  for (final directive in _directives(source, 'export')) {
    if (_isConditionalExport(directive)) {
      continue;
    }
    final exportedFile = _resolveExport(
      directive.uri,
      exportingFile: file,
      repositoryRoot: repositoryRoot,
      ownerPackage: ownerPackage,
    );
    if (exportedFile == null) {
      continue;
    }
    final exported = _exportedWidgets(
      file: exportedFile,
      repositoryRoot: repositoryRoot,
      ownerPackage: ownerPackage,
      visiting: visiting,
    );
    final shown = _allCombinatorNames(directive.tail, 'show');
    final hidden = _allCombinatorNames(directive.tail, 'hide');
    for (final declaration in exported.values) {
      if ((shown.isEmpty || shown.contains(declaration.name)) &&
          !hidden.contains(declaration.name)) {
        widgets[declaration.name] = declaration;
      }
    }
  }

  visiting.remove(absolutePath);
  return widgets;
}

Iterable<PublicWidgetDeclaration> _widgetDeclarations(
  String source,
  File file,
  String ownerPackage,
) sync* {
  final masked = _maskCommentsAndStrings(source);
  final pattern = RegExp(
    r'\bclass\s+([A-Za-z_]\w*)(?:\s*<[^>{;]*>)?\s+extends\s+'
    r'(?:[A-Za-z_]\w*\.)?(StatelessWidget|StatefulWidget)\b',
    multiLine: true,
  );
  for (final match in pattern.allMatches(masked)) {
    final name = match.group(1)!;
    if (!name.startsWith('_')) {
      yield PublicWidgetDeclaration(name: name, file: file, ownerPackage: ownerPackage);
    }
  }
}

File? _resolveExport(
  String exportUri, {
  required File exportingFile,
  required Directory repositoryRoot,
  required String ownerPackage,
}) {
  if (exportUri.startsWith('dart:')) {
    return null;
  }
  if (exportUri.startsWith('package:')) {
    final packagePath = exportUri.substring('package:'.length);
    final separator = packagePath.indexOf('/');
    if (separator < 0 || packagePath.substring(0, separator) != ownerPackage) {
      return null;
    }
    return _fileAt(
      repositoryRoot,
      'packages/$ownerPackage/lib/${packagePath.substring(separator + 1)}',
    );
  }
  if (exportUri.contains(':')) {
    return null;
  }
  return File.fromUri(exportingFile.parent.uri.resolve(exportUri));
}

Set<String> _allCombinatorNames(String source, String combinator) {
  final names = <String>{};
  final pattern = RegExp('\\b$combinator\\s+([A-Za-z_]\\w*(?:\\s*,\\s*[A-Za-z_]\\w*)*)');
  for (final match in pattern.allMatches(source)) {
    names.addAll(
      match.group(1)!.split(',').map((name) => name.trim()).where((name) => name.isNotEmpty),
    );
  }
  return names;
}

void _validateImportBoundaries(
  Directory repositoryRoot,
  List<PackageBoundaryDiagnostic> diagnostics,
) {
  final scopes = <_ImportScope>[
    const _ImportScope(
      directory: 'packages/coelo_ui_core/lib',
      forbiddenPackages: {
        'coelo_ui_admin',
        'coelo_ui_principal',
        'coelo_ui_superadmin',
        'admin',
        'superadmin',
        'principal',
        'site',
        'catalog',
        'coelo_admin',
        'coelo_superadmin',
        'coelo_principal',
        'coelo_site',
        'coelo_catalog',
      },
      forbiddenPaths: {
        'packages/coelo_ui_admin',
        'packages/coelo_ui_principal',
        'packages/coelo_ui_superadmin',
        'apps',
      },
    ),
    const _ImportScope(
      directory: 'packages/coelo_ui_admin/lib',
      forbiddenPackages: {
        'coelo_ui_principal',
        'coelo_ui_superadmin',
        'admin',
        'superadmin',
        'principal',
        'site',
        'catalog',
        'coelo_admin',
        'coelo_superadmin',
        'coelo_principal',
        'coelo_site',
        'coelo_catalog',
      },
      forbiddenPaths: {'packages/coelo_ui_principal', 'packages/coelo_ui_superadmin', 'apps'},
    ),
    const _ImportScope(
      directory: 'packages/coelo_ui_principal/lib',
      forbiddenPackages: {
        'coelo_ui_admin',
        'coelo_ui_superadmin',
        'admin',
        'superadmin',
        'principal',
        'site',
        'catalog',
        'coelo_admin',
        'coelo_superadmin',
        'coelo_principal',
        'coelo_site',
        'coelo_catalog',
      },
      forbiddenPaths: {'packages/coelo_ui_admin', 'packages/coelo_ui_superadmin', 'apps'},
    ),
    const _ImportScope(
      directory: 'apps/principal/lib',
      forbiddenPackages: {
        'coelo_ui_admin',
        'coelo_ui_superadmin',
        'admin',
        'superadmin',
        'coelo_admin',
        'coelo_superadmin',
      },
      forbiddenPaths: {
        'packages/coelo_ui_admin',
        'packages/coelo_ui_superadmin',
        'apps/admin',
        'apps/superadmin',
      },
    ),
  ];

  for (final scope in scopes) {
    final directory = _directoryAt(repositoryRoot, scope.directory);
    if (!directory.existsSync()) {
      continue;
    }
    for (final entity in directory.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final keyword in const ['import', 'export']) {
        for (final directive in _directives(source, keyword)) {
          if (keyword == 'export' && _isConditionalExport(directive)) {
            diagnostics.add(
              PackageBoundaryDiagnostic(
                code: 'unsupported-export-directive',
                message: 'Export condicional exige analise explicita.',
                path: _relativePath(repositoryRoot, entity),
                importUri: directive.uri,
              ),
            );
          }
          if (!_isForbiddenDependency(repositoryRoot, entity, directive.uri, scope)) {
            continue;
          }
          diagnostics.add(
            PackageBoundaryDiagnostic(
              code: keyword == 'import' ? 'forbidden-import' : 'forbidden-export',
              message:
                  '${keyword == 'import' ? 'Importacao' : 'Exportacao'} '
                  'viola a fronteira entre produtos e pacotes.',
              path: _relativePath(repositoryRoot, entity),
              importUri: directive.uri,
            ),
          );
        }
      }
    }
  }
}

bool _isConditionalExport(_Directive directive) => RegExp(r'\bif\s*\(').hasMatch(directive.tail);

bool _isForbiddenDependency(
  Directory repositoryRoot,
  File importingFile,
  String importUri,
  _ImportScope scope,
) {
  if (importUri.startsWith('package:')) {
    final packageName = importUri.substring('package:'.length).split('/').first;
    return scope.forbiddenPackages.contains(packageName);
  }
  if (importUri.startsWith('dart:') || importUri.contains(':')) {
    return false;
  }

  final importedFile = File.fromUri(importingFile.parent.uri.resolve(importUri));
  final relative = _relativePath(repositoryRoot, importedFile);
  return scope.forbiddenPaths.any((path) => relative == path || relative.startsWith('$path/'));
}

Iterable<_Directive> _directives(String source, String keyword) sync* {
  final commentsOnly = _maskSource(source, maskStrings: false);
  final masked = _maskSource(source, maskStrings: true);
  final pattern = RegExp('^\\s*$keyword\\b', multiLine: true);
  final uriPattern = RegExp(r'''['"]([^'"]+)['"]''');
  for (final match in pattern.allMatches(masked)) {
    final end = commentsOnly.indexOf(';', match.end);
    if (end < 0) {
      continue;
    }
    final directive = commentsOnly.substring(match.start, end);
    final uriMatch = uriPattern.firstMatch(directive);
    if (uriMatch != null) {
      yield _Directive(uri: uriMatch.group(1)!, tail: directive.substring(uriMatch.end));
    }
  }
}

String _maskCommentsAndStrings(String source) => _maskSource(source, maskStrings: true);

String maskDartCommentsPreservingStrings(String source) => _maskSource(source, maskStrings: false);

String _maskSource(String source, {required bool maskStrings}) {
  final result = StringBuffer();
  var index = 0;
  while (index < source.length) {
    if (index + 1 < source.length && source[index] == '/' && source[index + 1] == '/') {
      result.write('  ');
      index += 2;
      while (index < source.length && source[index] != '\n') {
        result.write(' ');
        index++;
      }
      continue;
    }
    if (index + 1 < source.length && source[index] == '/' && source[index + 1] == '*') {
      var depth = 1;
      result.write('  ');
      index += 2;
      while (index < source.length && depth > 0) {
        if (index + 1 < source.length && source[index] == '/' && source[index + 1] == '*') {
          depth++;
          result.write('  ');
          index += 2;
        } else if (index + 1 < source.length && source[index] == '*' && source[index + 1] == '/') {
          depth--;
          result.write('  ');
          index += 2;
        } else {
          result.write(source[index] == '\n' ? '\n' : ' ');
          index++;
        }
      }
      continue;
    }

    final quote = source[index];
    if (quote == "'" || quote == '"') {
      final triple =
          index + 2 < source.length && source[index + 1] == quote && source[index + 2] == quote;
      final delimiterLength = triple ? 3 : 1;
      for (var offset = 0; offset < delimiterLength; offset++) {
        result.write(maskStrings ? ' ' : quote);
      }
      index += delimiterLength;
      while (index < source.length) {
        final closes = triple
            ? index + 2 < source.length &&
                  source[index] == quote &&
                  source[index + 1] == quote &&
                  source[index + 2] == quote
            : source[index] == quote;
        if (closes) {
          for (var offset = 0; offset < delimiterLength; offset++) {
            result.write(maskStrings ? ' ' : quote);
          }
          index += delimiterLength;
          break;
        }
        if (!triple && source[index] == '\\' && index + 1 < source.length) {
          result.write(maskStrings ? ' ' : source[index]);
          result.write(maskStrings ? ' ' : source[index + 1]);
          index += 2;
        } else {
          result.write(maskStrings && source[index] != '\n' ? ' ' : source[index]);
          index++;
        }
      }
      continue;
    }

    result.write(source[index]);
    index++;
  }
  return result.toString();
}

File _fileAt(Directory root, String relativePath) =>
    File('${root.absolute.path}${Platform.pathSeparator}${_platformPath(relativePath)}');

Directory _directoryAt(Directory root, String relativePath) =>
    Directory('${root.absolute.path}${Platform.pathSeparator}${_platformPath(relativePath)}');

String _platformPath(String path) => path.replaceAll('/', Platform.pathSeparator);

String _normalizedAbsolutePath(String path) =>
    File.fromUri(File(path).absolute.uri.normalizePath()).path;

String _relativePath(Directory root, File file) {
  final rootPath = _normalizedAbsolutePath(root.path).replaceAll(r'\', '/');
  final filePath = _normalizedAbsolutePath(file.path).replaceAll(r'\', '/');
  final prefix = '$rootPath/';
  if (filePath.toLowerCase().startsWith(prefix.toLowerCase())) {
    return filePath.substring(prefix.length);
  }
  return filePath;
}

final class _UiPackage {
  const _UiPackage({required this.owner, required this.barrel});

  final String owner;
  final String barrel;
}

final class PublicWidgetDeclaration {
  const PublicWidgetDeclaration({
    required this.name,
    required this.file,
    required this.ownerPackage,
  });

  final String name;
  final File file;
  final String ownerPackage;
}

final class _Directive {
  const _Directive({required this.uri, required this.tail});

  final String uri;
  final String tail;
}

final class _ImportScope {
  const _ImportScope({
    required this.directory,
    required this.forbiddenPackages,
    required this.forbiddenPaths,
  });

  final String directory;
  final Set<String> forbiddenPackages;
  final Set<String> forbiddenPaths;
}

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'Uso: dart tool/validate_package_boundaries.dart '
      '<indice.jsonl> <raiz-repositorio>',
    );
    exitCode = 64;
    return;
  }

  final result = validatePackageBoundaries(
    indexFile: File(arguments[0]),
    repositoryRoot: Directory(arguments[1]),
  );
  for (final diagnostic in result.diagnostics) {
    stdout.writeln(diagnostic);
  }
  stdout.writeln(
    result.isValid
        ? 'Fronteiras Coelo UI validas: zero diagnostico.'
        : 'Fronteiras Coelo UI invalidas: '
              '${result.diagnostics.length} diagnostico(s).',
  );
  if (!result.isValid) {
    exitCode = 1;
  }
}
