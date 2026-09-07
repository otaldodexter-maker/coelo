import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/platform_users/data/fake_platform_user_repository.dart';
import 'package:coelo_superadmin/features/platform_users/domain/platform_user.dart';
import 'package:coelo_superadmin/features/platform_users/presentation/platform_user_detail_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('remote denial never renders a previously cached identity', (tester) async {
    final repository = _RemoteRepository()
      ..error = const PlatformUserRuleException('unauthorized', 'private detail');
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.textContaining(repository.cached.fullName), findsNothing);
    expect(find.text('private detail'), findsNothing);
  });

  testWidgets('missing read capability does not query remote detail', (tester) async {
    final repository = _RemoteRepository();
    await tester.pumpWidget(_page(repository, capability: PlatformUserCapability.unauthorized));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    expect(find.text('Acesso não autorizado'), findsOneWidget);
  });

  testWidgets('remote not found does not fall back to cached identity', (tester) async {
    final repository = _RemoteRepository()..missing = true;
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    expect(find.text('Usuário interno não encontrado'), findsOneWidget);
    expect(find.textContaining(repository.cached.fullName), findsNothing);
  });

  testWidgets('transient failure offers retry and reauthorizes detail', (tester) async {
    final repository = _RemoteRepository()..error = StateError('private detail');
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar o usuário interno'), findsOneWidget);
    expect(find.textContaining(repository.cached.fullName), findsNothing);
    repository.error = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(find.textContaining(repository.cached.fullName), findsWidgets);
    expect(find.text('Último Owner ativo protegido'), findsNothing);
  });

  testWidgets('late detail A cannot replace detail B after repository change', (tester) async {
    final pending = Completer<PlatformUserRecord?>();
    final first = _RemoteRepository()..pending = pending;
    final second = _RemoteRepository(name: 'Contexto B');
    await tester.pumpWidget(_page(first));
    await tester.pump();
    await tester.pumpWidget(_page(second));
    await tester.pumpAndSettle();
    expect(find.textContaining(second.cached.fullName), findsWidgets);
    pending.complete(first.cached);
    await tester.pumpAndSettle();
    expect(find.textContaining(second.cached.fullName), findsWidgets);
    expect(find.textContaining(first.cached.fullName), findsNothing);
  });

  testWidgets('back action returns to the directory callback', (tester) async {
    final repository = _RemoteRepository();
    var backCalls = 0;
    await tester.pumpWidget(_page(repository, onBack: () => backCalls++));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Voltar'));
    expect(backCalls, 1);
  });

  testWidgets('authorization revision clears the detail before rendering denial', (tester) async {
    final repository = _RemoteRepository();
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    expect(find.textContaining(repository.cached.fullName), findsWidgets);

    await tester.pumpWidget(_page(repository, capability: PlatformUserCapability.unauthorized));
    await tester.pump();
    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.textContaining(repository.cached.fullName), findsNothing);
    expect(repository.calls, 1);
  });
}

Widget _page(
  _RemoteRepository repository, {
  PlatformUserCapability capability = PlatformUserCapability.auditor,
  VoidCallback? onBack,
}) => MaterialApp(
  theme: CoeloTheme.light,
  home: PlatformUserDetailPage(
    key: const ValueKey('detail'),
    repository: repository,
    internalUserId: repository.cached.id,
    capability: capability,
    logout: unavailableSuperadminLogout,
    onBack: onBack,
  ),
);

final class _RemoteRepository implements PlatformUserRepository, PlatformUserRemoteLoader {
  _RemoteRepository({String name = 'Contexto A'}) {
    final source = FakePlatformUserRepository().records.first;
    cached = source.copyWith(
      identity: source.identity.copyWith(firstName: name, lastName: 'Exclusivo', displayName: ''),
    );
  }
  late final PlatformUserRecord cached;
  int calls = 0;
  Object? error;
  bool missing = false;
  Completer<PlatformUserRecord?>? pending;

  @override
  bool get isDemo => false;
  @override
  List<PlatformUserRecord> get records => [cached];
  @override
  List<PlatformAccessProfile> get profiles => [cached.profile];
  @override
  PlatformUserRecord? findById(String id) => cached;
  @override
  Future<PlatformUserRecord?> fetchById(String id) async {
    calls++;
    if (error case final failure?) throw failure;
    if (pending case final result?) return result.future;
    return missing ? null : cached;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
