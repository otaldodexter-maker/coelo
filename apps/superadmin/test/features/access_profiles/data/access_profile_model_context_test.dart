import 'dart:async';

import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/access_profiles/data/access_profile_model_repository_adapter.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile_model.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final changed in [false, true]) {
    test('model template preserves authorization continuity: changed=$changed', () async {
      final session = SuperadminSession()..authorize(_institution, sessionId: 'nominal');
      addTearDown(session.dispose);
      final source = _Source(session);
      final adapter = AccessProfileModelRepositoryAdapter(
        source,
        authorizationRevision: () => session.authorizationInvalidationRevision,
      );
      final result = adapter.fetchTemplate(AccessProfileDomain.institution);
      final expectation = changed
          ? expectLater(result, throwsA(isA<AccessProfileUnauthorizedException>()))
          : null;
      await source.catalogStarted.future;
      session.authorize(changed ? _platform : _institution, sessionId: 'nominal');
      source.catalogGate.complete();
      if (changed) {
        await expectation;
      } else {
        expect((await result).domain, AccessProfileDomain.institution);
      }
    });
  }

  for (final changed in [false, true]) {
    for (final heldPage in [1, 2]) {
      test(
        'paged model read preserves authorization continuity: changed=$changed, page=$heldPage',
        () async {
          final session = SuperadminSession()..authorize(_institution, sessionId: 'nominal');
          addTearDown(session.dispose);
          final source = _PagedSource(session, heldPage);
          final adapter = AccessProfileModelRepositoryAdapter(
            source,
            authorizationRevision: () => session.authorizationInvalidationRevision,
          );
          final result = adapter.fetchProfiles(
            const AccessProfileQuery(domain: AccessProfileDomain.platform, page: 1, pageSize: 1),
          );
          final expectation = changed
              ? expectLater(result, throwsA(isA<AccessProfileUnauthorizedException>()))
              : null;
          await source.started.future;
          session.authorize(changed ? _platform : _institution, sessionId: 'nominal');
          source.gate.complete();
          if (changed) {
            await expectation;
            expect(source.calls, heldPage);
          } else {
            expect((await result).items.single.id, 'page-model');
            expect(source.calls, 2);
          }
        },
      );
    }
  }

  test('model captured before context change cannot join a catalog requested afterwards', () async {
    final session = SuperadminSession()..authorize(_institution, sessionId: 'nominal');
    addTearDown(session.dispose);
    final source = _Source(session, holdModel: true);
    final adapter = AccessProfileModelRepositoryAdapter(
      source,
      authorizationRevision: () => session.authorizationInvalidationRevision,
    );
    final result = adapter.fetchDetail(AccessProfileDomain.institution, 'model');
    final expectation = expectLater(result, throwsA(isA<AccessProfileUnauthorizedException>()));
    await source.modelStarted.future;
    session.authorize(_platform, sessionId: 'nominal');
    source.modelGate.complete();
    source.catalogGate.complete();
    await expectation;
    expect(source.catalogStarted.isCompleted, isFalse);
  });

  test('equivalent context preserves a permitted composed read', () async {
    final session = SuperadminSession()..authorize(_institution, sessionId: 'nominal');
    addTearDown(session.dispose);
    final source = _Source(session);
    final adapter = AccessProfileModelRepositoryAdapter(
      source,
      authorizationRevision: () => session.authorizationInvalidationRevision,
    );
    final revision = session.authorizationInvalidationRevision;
    final result = adapter.fetchDetail(AccessProfileDomain.institution, 'model');
    await source.catalogStarted.future;
    session.authorize(_institution, sessionId: 'nominal');
    expect(session.authorizationInvalidationRevision, revision);
    source.catalogGate.complete();
    expect((await result).name, 'Modelo institucional anterior');
  });

  test('model detail cannot combine responses across authorization contexts', () async {
    final session = SuperadminSession()..authorize(_institution, sessionId: 'nominal');
    addTearDown(session.dispose);
    final source = _Source(session);
    final adapter = AccessProfileModelRepositoryAdapter(
      source,
      authorizationRevision: () => session.authorizationInvalidationRevision,
    );
    final revision = session.authorizationInvalidationRevision;
    final result = adapter.fetchDetail(AccessProfileDomain.institution, 'model');
    await source.catalogStarted.future;
    session.authorize(_platform, sessionId: 'nominal');
    expect(session.authorizationInvalidationRevision, greaterThan(revision));
    source.catalogGate.complete();
    await expectLater(result, throwsA(isA<AccessProfileUnauthorizedException>()));
  });
}

final class _PagedSource implements AccessProfileModelRepository {
  _PagedSource(this.session, this.heldPage);
  final SuperadminSession session;
  final int heldPage;
  final started = Completer<void>();
  final gate = Completer<void>();
  int calls = 0;

  @override
  Future<AccessProfileModelPage> fetchModels(AccessProfileModelQuery query) async {
    if (!session.authContext!.permissionCodes.contains('platform.role_models.read')) {
      throw const AccessProfileUnauthorizedException();
    }
    calls++;
    const model = AccessProfileModel(
      id: 'page-model',
      domain: AccessProfileDomain.platform,
      code: 'page-model',
      name: 'Modelo página',
      description: 'Sintético',
      status: AccessProfileStatus.active,
      maxScopeKind: 'platform',
      version: 1,
      isSystem: false,
      capabilities: [],
    );
    final response = AccessProfileModelPage(
      items: const [model],
      nextId: calls == 1 ? model.id : null,
      nextName: calls == 1 ? model.name : null,
    );
    if (calls == heldPage) {
      started.complete();
      await gate.future;
    }
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _institution = SuperadminAuthContext(
  platformRoleCode: 'owner',
  scopeKind: SuperadminAuthScopeKind.platform,
  permissionCodes: {'platform.read', 'institution.role_models.read', 'platform.role_models.read'},
  aal: 'aal1',
);
const _platform = SuperadminAuthContext(
  platformRoleCode: 'owner',
  scopeKind: SuperadminAuthScopeKind.platform,
  permissionCodes: {'platform.read', 'platform.role_models.read'},
  aal: 'aal1',
);

final class _Source implements AccessProfileModelRepository {
  _Source(this.session, {this.holdModel = false});
  final SuperadminSession session;
  final bool holdModel;
  final modelStarted = Completer<void>();
  final modelGate = Completer<void>();
  final catalogStarted = Completer<void>();
  final catalogGate = Completer<void>();

  @override
  Future<AccessProfileModel> fetchModel(String modelId) async {
    if (!session.authContext!.permissionCodes.contains('institution.role_models.read')) {
      throw const AccessProfileUnauthorizedException();
    }
    const model = AccessProfileModel(
      id: 'model',
      domain: AccessProfileDomain.institution,
      code: 'model',
      name: 'Modelo institucional anterior',
      description: 'Sintético',
      status: AccessProfileStatus.active,
      maxScopeKind: 'institution',
      version: 1,
      isSystem: false,
      capabilities: [],
    );
    modelStarted.complete();
    if (holdModel) await modelGate.future;
    return model;
  }

  @override
  Future<List<AccessPermissionCatalogItem>> fetchPermissionCatalog() async {
    if (!session.authContext!.permissionCodes.contains('platform.role_models.read')) {
      throw const AccessProfileUnauthorizedException();
    }
    catalogStarted.complete();
    await catalogGate.future;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
