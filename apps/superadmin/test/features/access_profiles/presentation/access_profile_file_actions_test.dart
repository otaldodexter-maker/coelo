import 'package:coelo_superadmin/features/access_profiles/data/fake_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_directory_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _deferred = {
  'access-profile-files-import': 'Importar',
  'access-profile-files-export-csv': 'Exportar CSV',
  'access-profile-files-export-xlsx': 'Exportar XLSX',
};

void main() {
  testWidgets('deferred profile file actions stay visible and announce unavailability', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileDirectoryPage(
          repository: FakeAccessProfileRepository(),
          logout: unavailableSuperadminLogout,
          onCreate: (_) {},
          onOpen: (_, _) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    final actions = tester
        .widgetList<CoeloAdminFileActions>(find.byType(CoeloAdminFileActions))
        .expand((widget) => widget.actions)
        .toList();

    for (final entry in _deferred.entries) {
      final action = actions.where((item) => item.key == Key(entry.key)).toList();
      expect(action, hasLength(1), reason: '${entry.value} must stay on the screen, not disappear');
      expect(
        action.single.onPressed,
        isNull,
        reason: '${entry.value} is deferred: the shared control then announces it as indisponível',
      );
      expect(action.single.label, entry.value);
    }
  });
}
