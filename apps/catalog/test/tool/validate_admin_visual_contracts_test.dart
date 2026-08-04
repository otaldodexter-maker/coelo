import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/validate_admin_visual_contracts.dart';

void main() {
  group('validateAdminVisualContracts', () {
    test('reports every prohibited raw interaction constructor', () {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      fixture.writeFeature('raw.dart', '''
Widget build() => Column(children: [
  PopupMenuButton<String>(itemBuilder: (_) => []),
  PopupMenuItem<String>(value: 'a', child: Text('a')),
  MenuAnchor(builder: (_, controller, child) => child!),
  MenuItemButton(onPressed: () {}, child: Text('a')),
  InkWell(onTap: () {}, child: Text('card')),
  DropdownButton<String>(items: []),
  DropdownButtonFormField<String>(items: []),
  RadioListTile<String>(value: 'a', groupValue: 'a', onChanged: (_) {}),
  CheckboxListTile(value: true, onChanged: (_) {}),
  Builder(builder: (context) => TextButton(
    onPressed: () => showDateRangePicker(
      context: context,
      firstDate: DateTime(2026),
      lastDate: DateTime(2027),
    ),
    child: const Text('Data'),
  )),
]);
''');
      fixture.writeAllowlist(const []);

      final diagnostics = validateAdminVisualContracts(
        root: fixture.root,
        allowlist: fixture.allowlist,
      );

      expect(
        diagnostics.map((diagnostic) => diagnostic.symbol),
        containsAll(<String>[
          'PopupMenuButton',
          'PopupMenuItem',
          'MenuAnchor',
          'MenuItemButton',
          'InkWell',
          'DropdownButton',
          'DropdownButtonFormField',
          'RadioListTile',
          'CheckboxListTile',
          'showDateRangePicker',
        ]),
      );
      expect(diagnostics, hasLength(10));
    });

    test('ignores comments, strings and canonical component imports', () {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      fixture.writeFeature('canonical.dart', r'''
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
// InkWell(onTap: () {});
const description = 'PopupMenuButton('; /* MenuAnchor( */
Widget build() => CoeloAdminInteractiveCard(child: Text(description));
''');
      fixture.writeAllowlist(const []);

      expect(
        validateAdminVisualContracts(root: fixture.root, allowlist: fixture.allowlist),
        isEmpty,
      );
    });

    test('allows exactly the counted legacy baseline and rejects additions', () {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      const path = 'apps/superadmin/lib/features/example/presentation/legacy.dart';
      fixture.writeFeature('legacy.dart', 'InkWell(onTap: () {});');
      fixture.writeAllowlist(<Map<String, Object>>[
        <String, Object>{
          'path': path,
          'symbol': 'InkWell',
          'maxOccurrences': 1,
          'reason': 'Legado existente preservado ate revisao visual dedicada.',
        },
      ]);

      expect(
        validateAdminVisualContracts(root: fixture.root, allowlist: fixture.allowlist),
        isEmpty,
      );

      fixture.writeFeature('legacy.dart', 'InkWell(onTap: () {});\nInkWell(onTap: () {});');
      final diagnostics = validateAdminVisualContracts(
        root: fixture.root,
        allowlist: fixture.allowlist,
      );
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.symbol, 'InkWell');
      expect(diagnostics.single.message, contains('excede a baseline 1'));
    });

    test('rejects allowlist entries with missing files or empty reasons', () {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      fixture.writeAllowlist(<Map<String, Object>>[
        <String, Object>{
          'path': 'apps/superadmin/lib/features/example/presentation/missing.dart',
          'symbol': 'InkWell',
          'maxOccurrences': 1,
          'reason': 'Arquivo legado ainda existente.',
        },
        <String, Object>{
          'path': 'apps/superadmin/lib/features/example/presentation/also_missing.dart',
          'symbol': 'MenuAnchor',
          'maxOccurrences': 1,
          'reason': '   ',
        },
      ]);

      final diagnostics = validateAdminVisualContracts(
        root: fixture.root,
        allowlist: fixture.allowlist,
      );

      expect(diagnostics.where((diagnostic) => diagnostic.symbol == 'allowlist'), hasLength(2));
      expect(
        diagnostics.map((diagnostic) => diagnostic.message).join('\n'),
        allOf(contains('nao existe'), contains('reason vazio')),
      );
    });

    test('current repository is fully represented by the counted baseline', () {
      final catalog = Directory.current.absolute;
      final repository = catalog.parent.parent;

      expect(
        validateAdminVisualContracts(
          root: repository,
          allowlist: File(
            '${catalog.path}${Platform.pathSeparator}assets'
            '${Platform.pathSeparator}admin-visual-contract-allowlist.json',
          ),
        ),
        isEmpty,
      );
    });
  });
}

class _Fixture {
  _Fixture() : root = Directory.systemTemp.createTempSync('admin_visual_gate_');

  final Directory root;

  File get allowlist => File('${root.path}${Platform.pathSeparator}allowlist.json');

  void writeFeature(String name, String source) {
    final file = File(
      '${root.path}${Platform.pathSeparator}apps${Platform.pathSeparator}'
      'superadmin${Platform.pathSeparator}lib${Platform.pathSeparator}'
      'features${Platform.pathSeparator}example${Platform.pathSeparator}'
      'presentation${Platform.pathSeparator}$name',
    );
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(source);
  }

  void writeAllowlist(List<Map<String, Object>> entries) {
    allowlist.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(<String, Object>{'entries': entries}),
    );
  }

  void dispose() => root.deleteSync(recursive: true);
}
