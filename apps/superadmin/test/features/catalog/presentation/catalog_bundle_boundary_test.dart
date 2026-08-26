import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps catalog implementation and Principal UI out of the Superadmin bundle', () {
    final violations = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) {
        continue;
      }
      final source = file.readAsStringSync();
      if (source.contains('apps/catalog') ||
          source.contains('coelo_catalog') ||
          source.contains('coelo_ui_principal') ||
          source.contains('catalog_registry.dart')) {
        violations.add(file.path);
      }
    }

    final pubspec = File('pubspec.yaml').readAsStringSync();
    if (pubspec.contains(RegExp(r'^\s*coelo_catalog\s*:', multiLine: true))) {
      violations.add('pubspec.yaml');
    }

    expect(violations, isEmpty);
  });

  test('keeps the web iframe and external-link security policy explicit', () {
    final source = File(
      'lib/features/catalog/presentation/catalog_platform_host_web.dart',
    ).readAsStringSync();

    expect(source, contains("..title = 'Catálogo Coelo'"));
    expect(source, contains("..referrerPolicy = 'no-referrer'"));
    expect(source, contains("const ['allow-same-origin', 'allow-scripts']"));
    expect(source, isNot(contains('allow-top-navigation')));
    expect(source, contains("html.window.open(uri.toString(), '_blank', 'noopener,noreferrer')"));
  });
}
