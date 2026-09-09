import 'package:coelo_superadmin/features/access_profiles/data/access_profile_model_repository_adapter.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile_model.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_form_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Principal model scope menu cannot select institution or unit', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileFormPage(
          repository: AccessProfileModelRepositoryAdapter(_ModelSource()),
          logout: unavailableSuperadminLogout,
          domain: AccessProfileDomain.principal,
          entityLabel: 'modelo de perfil',
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scope = find.byType(CoeloAdminSingleSelectField<AccessProfileScope>);
    await tester.ensureVisible(scope);
    await tester.tap(scope);
    await tester.pumpAndSettle();
    expect(find.text('Turma'), findsWidgets);
    expect(find.text('Instituição'), findsNothing);
    expect(find.text('Unidade'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

final class _ModelSource implements AccessProfileModelRepository {
  @override
  Future<List<AccessPermissionCatalogItem>> fetchPermissionCatalog() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
