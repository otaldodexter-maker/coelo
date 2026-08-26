import 'package:coelo_superadmin/features/access_profiles/data/supabase_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_detail_page.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_directory_page.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_form_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const repository = UnavailableAccessProfileRepository();

  testWidgets('directory reports unavailable without exposing successful profile actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileDirectoryPage(
          repository: repository,
          logout: unavailableSuperadminLogout,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar os perfis'), findsOneWidget);
    expect(find.text('A integração de Perfis e Permissões não está disponível.'), findsOneWidget);
    expect(find.text('Criar perfil'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('form reports unavailable without exposing save success', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileFormPage(
          repository: repository,
          logout: unavailableSuperadminLogout,
          domain: AccessProfileDomain.platform,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível abrir o perfil'), findsOneWidget);
    expect(find.text('Não foi possível carregar o formulário.'), findsOneWidget);
    expect(find.text('Salvar alterações'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail reports unavailable without exposing edit or deletion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        home: AccessProfileDetailPage(
          repository: repository,
          logout: unavailableSuperadminLogout,
          domain: AccessProfileDomain.platform,
          profileId: 'profile-id',
          onBack: () {},
          onEdit: () {},
          onDeleted: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar o perfil'), findsOneWidget);
    expect(find.text('A integração de Perfis e Permissões não está disponível.'), findsOneWidget);
    expect(find.text('Editar perfil'), findsNothing);
    expect(find.text('Excluir e realocar'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
