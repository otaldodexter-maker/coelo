import 'dart:async';

import 'package:coelo_superadmin/features/access_profiles/data/access_profile_model_repository_adapter.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final duplicate in [false, true]) {
    for (final changed in [false, true]) {
      test(
        '${duplicate ? "duplicate" : "save"} late cache preserves context changed=$changed',
        () async {
          var revision = 1;
          final source = _Source();
          final adapter = AccessProfileModelRepositoryAdapter(
            source,
            authorizationRevision: () => revision,
          );
          final initial = await adapter.fetchDetail(AccessProfileDomain.platform, 'target-model');
          Object? lateError;
          final late =
              (duplicate
                      ? adapter.duplicate(
                          requestId: 'request-a',
                          sourceProfileId: 'source-model',
                          domain: AccessProfileDomain.platform,
                          name: 'Cópia A',
                          reason: 'Motivo A',
                        )
                      : adapter.save(
                          requestId: 'request-a',
                          expectedVersion: 1,
                          reason: 'Motivo A',
                          draft: initial,
                        ))
                  .then<void>(
                    (_) {},
                    onError: (Object error) {
                      lateError = error;
                    },
                  );
          await source.started.future;
          AccessProfile draft = initial;
          if (changed) {
            revision++;
            source.current = _model(AccessProfileModelEffect.allow, 3);
            // Context B authoritatively loads the returned ID, including for a copy.
            draft = await adapter.fetchDetail(AccessProfileDomain.platform, 'target-model');
            expect(draft.permissions.single.selected, isTrue);
          }
          source.gate.complete(_model(AccessProfileModelEffect.deny, 2));
          await late;
          await adapter.save(
            requestId: 'request-b',
            expectedVersion: changed ? 3 : 1,
            reason: 'Motivo B',
            draft: draft.copyWith(permissions: const []),
          );

          // Observe the next public command, not the private cache implementation.
          expect(
            source.lastDraft!.capabilities.map((item) => item.effect),
            changed ? isEmpty : [AccessProfileModelEffect.deny],
          );
          expect(source.lastDraft!.expectedVersion, changed ? 3 : 1);
          expect(source.lastDraft!.reason, 'Motivo B');
          expect(source.requests, ['request-a', 'request-b']);
          expect(lateError, changed ? isA<AccessProfileUnauthorizedException>() : isNull);
        },
      );
    }
  }
}

final class _Source implements AccessProfileModelRepository {
  AccessProfileModel current = _model(AccessProfileModelEffect.deny, 1);
  final started = Completer<void>();
  final gate = Completer<AccessProfileModel>();
  final requests = <String>[];
  AccessProfileModelDraft? lastDraft;

  @override
  Future<AccessProfileModel> fetchModel(String modelId) async => current;

  @override
  Future<List<AccessPermissionCatalogItem>> fetchPermissionCatalog() async => const [_catalog];

  @override
  Future<AccessProfileModel> updateModel(String requestId, AccessProfileModelDraft draft) async {
    requests.add(requestId);
    lastDraft = draft;
    if (requestId == 'request-a') {
      started.complete();
      return gate.future;
    }
    return current;
  }

  @override
  Future<AccessProfileModel> duplicateModel(String requestId, AccessProfileModelDraft draft) async {
    requests.add(requestId);
    expect(draft.sourceModelId, 'source-model');
    started.complete();
    return gate.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AccessProfileModel _model(AccessProfileModelEffect effect, int version) => AccessProfileModel(
  id: 'target-model',
  domain: AccessProfileDomain.platform,
  code: 'modelo.nominal',
  name: 'Modelo nominal',
  description: 'Descrição nominal',
  status: AccessProfileStatus.inactive,
  maxScopeKind: 'platform',
  version: version,
  isSystem: false,
  capabilities: [AccessProfileModelCapability(code: 'platform.read', effect: effect)],
);
const _catalog = AccessPermissionCatalogItem(
  applicationCode: 'superadmin',
  moduleCode: 'platform',
  moduleLabel: 'Plataforma',
  screenCode: 'platform',
  screenLabel: 'Plataforma',
  actionCode: 'read',
  actionLabel: 'Ler',
  code: 'platform.read',
  description: '',
  riskLevel: 'normal',
  requiresMfa: false,
);
