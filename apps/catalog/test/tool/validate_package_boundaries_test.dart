import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/validate_package_boundaries.dart';

void main() {
  late Directory repositoryRoot;
  late File indexFile;

  setUp(() {
    repositoryRoot = Directory.systemTemp.createTempSync('coelo_package_boundaries_test_');
    indexFile = _write(repositoryRoot, 'index.jsonl', '');
  });

  tearDown(() {
    if (repositoryRoot.existsSync()) {
      repositoryRoot.deleteSync(recursive: true);
    }
  });

  test('accepts indexed widgets exported transitively by core and admin barrels', () {
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/coelo_ui_core.dart',
      "export 'src/components.dart';",
    );
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/src/components.dart',
      "export 'search.dart';",
    );
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/src/search.dart',
      'final class CoeloSearchField extends StatelessWidget {}',
    );
    _write(
      repositoryRoot,
      'packages/coelo_ui_admin/lib/coelo_ui_admin.dart',
      "export 'src/table.dart';",
    );
    _write(
      repositoryRoot,
      'packages/coelo_ui_admin/lib/src/table.dart',
      'final class CoeloAdminTable extends StatefulWidget {}',
    );
    _writeIndex(indexFile, {
      'CoeloSearchField': 'coelo_ui_core',
      'CoeloAdminTable': 'coelo_ui_admin',
    });

    final result = validatePackageBoundaries(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(result.diagnostics, isEmpty);
  });

  test('reports a public exported widget missing from the index', () {
    _coreWidget(repositoryRoot, 'UnregisteredWidget', 'StatelessWidget');

    final result = validatePackageBoundaries(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(
      result.diagnostics,
      contains(_diagnostic('missing-index-entry', name: 'UnregisteredWidget')),
    );
  });

  test('reports an indexed widget owned by the wrong package', () {
    _coreWidget(repositoryRoot, 'OwnedWidget', 'StatelessWidget');
    _writeIndex(indexFile, {'OwnedWidget': 'coelo_ui_admin'});

    final result = validatePackageBoundaries(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(result.diagnostics, contains(_diagnostic('owner-mismatch', name: 'OwnedWidget')));
  });

  test('reports duplicate names even when both entries use the same owner', () {
    final entry = jsonEncode({'name': 'RepeatedWidget', 'ownerPackage': 'coelo_ui_core'});
    indexFile.writeAsStringSync('$entry\n$entry\n');

    final result = validatePackageBoundaries(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(
      result.diagnostics,
      contains(_diagnostic('duplicate-index-name', name: 'RepeatedWidget')),
    );
  });

  test('reports a name registered with two different owners', () {
    indexFile.writeAsStringSync(
      '${jsonEncode({'name': 'SharedWidget', 'ownerPackage': 'coelo_ui_core'})}\n'
      '${jsonEncode({'name': 'SharedWidget', 'ownerPackage': 'coelo_ui_admin'})}\n',
    );

    final result = validatePackageBoundaries(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(
      result.diagnostics,
      contains(_diagnostic('ambiguous-index-owner', name: 'SharedWidget')),
    );
  });

  test('honors show and hide export combinators', () {
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/coelo_ui_core.dart',
      "export 'src/widgets.dart' "
          "show ShownWidget, HiddenByHideWidget "
          "hide HiddenByHideWidget;",
    );
    _write(repositoryRoot, 'packages/coelo_ui_core/lib/src/widgets.dart', '''
class ShownWidget extends StatelessWidget {}
class HiddenByHideWidget extends StatelessWidget {}
class NotShownWidget extends StatefulWidget {}
''');
    _writeIndex(indexFile, {'ShownWidget': 'coelo_ui_core'});

    final result = validatePackageBoundaries(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(result.diagnostics, isEmpty);
  });

  test('aggregates every hide combinator in an export', () {
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/coelo_ui_core.dart',
      "export 'src/widgets.dart' hide FirstHidden hide SecondHidden;",
    );
    _write(repositoryRoot, 'packages/coelo_ui_core/lib/src/widgets.dart', '''
class FirstHidden extends StatelessWidget {}
class SecondHidden extends StatefulWidget {}
''');

    final result = validatePackageBoundaries(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(result.diagnostics, isEmpty);
  });

  test('follows a package self export', () {
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/coelo_ui_core.dart',
      "export 'package:coelo_ui_core/src/self_exported.dart';",
    );
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/src/self_exported.dart',
      'class SelfExportedWidget extends StatelessWidget {}',
    );

    final result = validatePackageBoundaries(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(
      result.diagnostics,
      contains(_diagnostic('missing-index-entry', name: 'SelfExportedWidget')),
    );
  });

  test('reports a conditional export instead of silently scanning one branch', () {
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/coelo_ui_core.dart',
      "export 'src/base.dart' if (dart.library.io) 'src/io.dart';",
    );

    final result = validatePackageBoundaries(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(result.diagnostics, contains(_diagnostic('unsupported-export-directive')));
  });

  test('ignores private, non-widget, unexported, commented, and string declarations', () {
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/coelo_ui_core.dart',
      "export 'src/public.dart';",
    );
    _write(repositoryRoot, 'packages/coelo_ui_core/lib/src/public.dart', r'''
class _PrivateWidget extends StatelessWidget {}
class PublicModel {}
// class CommentWidget extends StatelessWidget {}
/* class BlockCommentWidget extends StatefulWidget {} */
const source = 'class StringWidget extends StatelessWidget {}';
''');
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/src/not_exported.dart',
      'class NotExportedWidget extends StatelessWidget {}',
    );

    final result = validatePackageBoundaries(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(result.diagnostics, isEmpty);
  });

  test('reports forbidden imports from core and admin packages', () {
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/src/core.dart',
      "import 'package:coelo_ui_admin/coelo_ui_admin.dart';",
    );
    _write(
      repositoryRoot,
      'packages/coelo_ui_admin/lib/src/admin.dart',
      "import 'package:superadmin/app.dart';",
    );

    final result = validatePackageBoundaries(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(
      result.diagnostics,
      contains(_diagnostic('forbidden-import', pathContains: 'core.dart')),
    );
    expect(
      result.diagnostics,
      contains(_diagnostic('forbidden-import', pathContains: 'admin.dart')),
    );
  });

  test('recognizes real Coelo app package names as forbidden dependencies', () {
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/src/core.dart',
      "import 'package:coelo_principal/main.dart';",
    );
    _write(
      repositoryRoot,
      'packages/coelo_ui_admin/lib/src/admin.dart',
      "import 'package:coelo_catalog/main.dart';",
    );
    _write(
      repositoryRoot,
      'packages/coelo_ui_principal/lib/src/principal.dart',
      "import 'package:coelo_superadmin/main.dart';",
    );
    _write(
      repositoryRoot,
      'apps/principal/lib/main.dart',
      "import 'package:coelo_admin/main.dart';",
    );

    final result = validatePackageBoundaries(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(
      result.diagnostics.where((diagnostic) => diagnostic.code == 'forbidden-import'),
      hasLength(4),
    );
  });

  test('reports admin and superadmin imports from principal package and app', () {
    _write(
      repositoryRoot,
      'packages/coelo_ui_principal/lib/src/principal.dart',
      "import 'package:coelo_ui_admin/coelo_ui_admin.dart';",
    );
    _write(
      repositoryRoot,
      'apps/principal/lib/main.dart',
      "import 'package:coelo_ui_superadmin/coelo_ui_superadmin.dart';",
    );

    final result = validatePackageBoundaries(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(
      result.diagnostics.where((diagnostic) => diagnostic.code == 'forbidden-import'),
      hasLength(2),
    );
  });

  test('detects relative imports that resolve across a forbidden boundary', () {
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/src/core.dart',
      "import '../../../../apps/superadmin/lib/main.dart';",
    );
    _write(
      repositoryRoot,
      'packages/coelo_ui_admin/lib/src/admin.dart',
      "import '../../../../apps/superadmin/lib/main.dart';",
    );

    final result = validatePackageBoundaries(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(
      result.diagnostics.where((diagnostic) => diagnostic.code == 'forbidden-import'),
      hasLength(2),
    );
  });

  test('blocks relative imports from every app in core, admin, and principal packages', () {
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/src/core.dart',
      "import '../../../../apps/catalog/lib/main.dart';",
    );
    _write(
      repositoryRoot,
      'packages/coelo_ui_admin/lib/src/admin.dart',
      "import '../../../../apps/principal/lib/main.dart';",
    );
    _write(
      repositoryRoot,
      'packages/coelo_ui_principal/lib/src/principal.dart',
      "import '../../../../apps/catalog/lib/main.dart';",
    );

    final result = validatePackageBoundaries(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(
      result.diagnostics.where((diagnostic) => diagnostic.code == 'forbidden-import'),
      hasLength(3),
    );
  });

  test('applies package boundaries to exports', () {
    _write(
      repositoryRoot,
      'packages/coelo_ui_core/lib/src/core.dart',
      "export 'package:coelo_ui_admin/coelo_ui_admin.dart';",
    );
    _write(
      repositoryRoot,
      'packages/coelo_ui_admin/lib/src/admin.dart',
      "export '../../../../apps/catalog/lib/main.dart';",
    );
    _write(
      repositoryRoot,
      'packages/coelo_ui_principal/lib/src/principal.dart',
      "export 'package:coelo_superadmin/main.dart';",
    );

    final result = validatePackageBoundaries(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(
      result.diagnostics.where((diagnostic) => diagnostic.code == 'forbidden-export'),
      hasLength(3),
    );
  });

  test('ignores imports written inside comments and strings', () {
    _write(repositoryRoot, 'packages/coelo_ui_core/lib/src/core.dart', r'''
// import 'package:coelo_ui_admin/coelo_ui_admin.dart';
/* import 'package:superadmin/app.dart'; */
const source = "import 'package:coelo_ui_admin/coelo_ui_admin.dart';";
''');

    final result = validatePackageBoundaries(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(result.diagnostics, isEmpty);
  });

  test('accepts a repository without principal package or app', () {
    final result = validatePackageBoundaries(indexFile: indexFile, repositoryRoot: repositoryRoot);

    expect(result.diagnostics, isEmpty);
  });
}

void _coreWidget(Directory root, String name, String superclass) {
  _write(root, 'packages/coelo_ui_core/lib/coelo_ui_core.dart', "export 'src/widget.dart';");
  _write(root, 'packages/coelo_ui_core/lib/src/widget.dart', 'class $name extends $superclass {}');
}

void _writeIndex(File indexFile, Map<String, String> entries) {
  indexFile.writeAsStringSync(
    '${entries.entries.map((entry) => jsonEncode({'name': entry.key, 'ownerPackage': entry.value})).join('\n')}\n',
  );
}

File _write(Directory root, String relativePath, String source) {
  final file = File(
    '${root.path}${Platform.pathSeparator}'
    '${relativePath.replaceAll('/', Platform.pathSeparator)}',
  );
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(source);
  return file;
}

Matcher _diagnostic(String code, {String? name, String? pathContains}) => predicate(
  (Object? value) =>
      value is PackageBoundaryDiagnostic &&
      value.code == code &&
      (name == null || value.name == name) &&
      (pathContains == null || value.path.contains(pathContains)),
  '$code${name == null ? '' : ' for $name'}',
);
