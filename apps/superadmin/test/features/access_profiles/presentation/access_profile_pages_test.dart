import 'dart:async';

import 'package:coelo_superadmin/features/access_profiles/data/fake_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/data/supabase_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_detail_page.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_directory_page.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_form_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
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

  testWidgets('repository swap loads only B and discards late A', (tester) async {
    final pageKey = GlobalKey();
    final repositoryA = _PageRepository.pending(_profile('a', 'Perfil A'));
    final repositoryB = _PageRepository.pending(_profile('b', 'Perfil B'));

    await tester.pumpWidget(_directory(pageKey, repositoryA));
    await tester.pump();
    expect(repositoryA.calls, 1);

    await tester.pumpWidget(_directory(pageKey, repositoryB));
    await tester.pump();
    expect(repositoryB.calls, 1);

    repositoryB.complete();
    await tester.pumpAndSettle();
    expect(find.text('Perfil B'), findsWidgets);

    repositoryA.complete();
    await tester.pump();
    expect(find.text('Perfil B'), findsWidgets);
    expect(find.text('Perfil A'), findsNothing);
  });

  testWidgets('unauthorized is state-only and cannot issue another query', (tester) async {
    final repository = _UnauthorizedRepository();
    await tester.pumpWidget(_directory(GlobalKey(), repository));
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(find.byKey(const Key('access-profile-unauthorized')), findsOneWidget);
    expect(find.byKey(const Key('access-profile-toolbar')), findsNothing);
    expect(find.byKey(const Key('access-profile-domain-selector')), findsNothing);
    expect(find.byKey(const Key('access-profile-view-cards')), findsNothing);
    expect(find.byKey(const Key('access-profile-view-table')), findsNothing);
    expect(find.byType(CoeloAdminCreateAction), findsNothing);
    expect(find.byType(CoeloAdminInteractiveCard), findsNothing);
    expect(find.byType(CoeloAdminResizableTable<AccessProfile>), findsNothing);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets('missing callbacks hide create and keep cards and rows informational', (
    tester,
  ) async {
    final repository = FakeAccessProfileRepository();
    await tester.pumpWidget(_directory(GlobalKey(), repository));
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminCreateAction), findsNothing);
    final card = tester.widget<CoeloAdminInteractiveCard>(
      find.byType(CoeloAdminInteractiveCard).first,
    );
    expect(card.onPressed, isNull);

    await tester.tap(find.byKey(const Key('access-profile-view-table')));
    await tester.pumpAndSettle();
    final table = tester.widget<CoeloAdminResizableTable<AccessProfile>>(
      find.byKey(const Key('access-profile-table')),
    );
    expect(table.onRowPressed, isNull);
  });

  testWidgets('real create and open callbacks fire exactly once', (tester) async {
    var createCalls = 0;
    var openCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileDirectoryPage(
          repository: FakeAccessProfileRepository(),
          logout: unavailableSuperadminLogout,
          onCreate: (_) => createCalls += 1,
          onOpen: (_, _) => openCalls += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.widget<CoeloAdminCreateAction>(find.byType(CoeloAdminCreateAction)).onPressed!();
    tester
        .widget<CoeloAdminInteractiveCard>(find.byType(CoeloAdminInteractiveCard).first)
        .onPressed!();

    expect(createCalls, 1);
    expect(openCalls, 1);
  });

  testWidgets('cards and table remain stable across the responsive matrix', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in const [375.0, 768.0, 1024.0, 1440.0]) {
      for (final scale in const [1.0, 2.0]) {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        await tester.pumpWidget(
          MaterialApp(
            theme: CoeloTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: AccessProfileDirectoryPage(
              repository: FakeAccessProfileRepository(),
              logout: unavailableSuperadminLogout,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('access-profile-card-grid')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: width.toString());

        await tester.tap(find.byKey(const Key('access-profile-view-table')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('access-profile-table')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: width.toString());

        await tester.tap(find.byKey(const Key('access-profile-view-cards')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('access-profile-card-grid')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: width.toString());
      }
    }
  });
}

Widget _directory(Key key, AccessProfileRepository repository) => MaterialApp(
  theme: CoeloTheme.light,
  home: AccessProfileDirectoryPage(
    key: key,
    repository: repository,
    logout: unavailableSuperadminLogout,
  ),
);

final class _PageRepository implements AccessProfileRepository {
  _PageRepository.pending(this.profile);

  final AccessProfile profile;
  final _completer = Completer<AccessProfilePage>();
  int calls = 0;

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete(
        AccessProfilePage(items: [profile], totalCount: 1, page: 0, pageSize: 11),
      );
    }
  }

  @override
  bool get isDemo => false;

  @override
  Future<AccessProfilePage> fetchProfiles(AccessProfileQuery query) {
    calls += 1;
    return _completer.future;
  }

  @override
  Future<List<PrincipalCapability>> fetchPrincipalCapabilities() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _UnauthorizedRepository implements AccessProfileRepository {
  int calls = 0;

  @override
  bool get isDemo => false;

  @override
  Future<AccessProfilePage> fetchProfiles(AccessProfileQuery query) async {
    calls += 1;
    throw const AccessProfileUnauthorizedException();
  }

  @override
  Future<List<PrincipalCapability>> fetchPrincipalCapabilities() async {
    calls += 1;
    throw const AccessProfileUnauthorizedException();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AccessProfile _profile(String id, String name) => AccessProfile(
  id: id,
  domain: AccessProfileDomain.platform,
  code: id,
  name: name,
  description: 'Descrição',
  status: AccessProfileStatus.active,
  maxScope: AccessProfileScope.platform,
  version: 1,
  membershipCount: 0,
);
