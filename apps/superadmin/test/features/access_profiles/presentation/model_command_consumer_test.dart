import 'dart:convert';

import 'package:coelo_superadmin/features/access_profiles/data/access_profile_model_repository_adapter.dart';
import 'package:coelo_superadmin/features/access_profiles/data/supabase_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_detail_page.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_duplicate_page.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_form_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final operation in ['create', 'update', 'duplicate', 'delete']) {
    for (final denied in [false, true]) {
      testWidgets('$operation SQL envelope reaches UI denied=$denied', (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final commands = <String>[];
        final payloads = <Map<String, dynamic>>[];
        final client = (await tester.runAsync(
          () async => _client(
            operation,
            denied ? 'SAI_PERMISSION_DENIED' : null,
            commands,
            onCommand: payloads.add,
          ),
        ))!;
        addTearDown(() => tester.runAsync(client.dispose));
        final adapter = AccessProfileModelRepositoryAdapter(
          SupabaseAccessProfileRepository(client),
        );
        var successes = 0;
        AccessProfile? saved;
        void onSuccess(AccessProfile value) {
          successes++;
          saved = value;
        }

        final page = switch (operation) {
          'delete' => AccessProfileDetailPage(
            repository: adapter,
            domain: AccessProfileDomain.platform,
            profileId: _id,
            logout: unavailableSuperadminLogout,
            onBack: () {},
            onEdit: () {},
            onDeleted: () => successes++,
          ),
          'duplicate' => AccessProfileDuplicatePage(
            repository: adapter,
            duplicator: adapter,
            domain: AccessProfileDomain.platform,
            sourceProfileId: _id,
            logout: unavailableSuperadminLogout,
            onCancel: () {},
            onDuplicated: onSuccess,
          ),
          _ => AccessProfileFormPage(
            repository: adapter,
            domain: AccessProfileDomain.platform,
            profileId: operation == 'update' ? _id : null,
            logout: unavailableSuperadminLogout,
            onCancel: () {},
            onSaved: onSuccess,
          ),
        };
        await tester.pumpWidget(MaterialApp(theme: CoeloTheme.light, home: page));
        await tester.pumpAndSettle();
        await _submit(tester, operation);
        await tester.pumpAndSettle();
        expect(commands, [operation]);
        final payload = payloads.single;
        expect(payload['p_request_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
        if (operation == 'create' || operation == 'update') {
          final draft = payload['p_draft'] as Map;
          expect(draft['name'], 'Nome revisado');
          expect(draft['description'], 'Descrição revisada');
          expect(draft['reason'], 'Motivo nominal');
          expect(draft['expected_version'], operation == 'update' ? 3 : null);
        }
        expect(successes, denied ? 0 : 1);
        if (denied) {
          expect(find.text(const AccessProfileUnauthorizedException().message), findsOneWidget);
          expect(find.textContaining('Untrusted backend detail'), findsNothing);
          if (operation == 'create' || operation == 'update') {
            await _checkDraft(tester, operation);
          } else if (operation == 'duplicate') {
            expect(_fieldText(tester, 'Nome do novo modelo'), 'Cópia nominal');
            expect(_fieldText(tester, 'Motivo da duplicação'), 'Motivo nominal');
          }
        } else if (operation != 'delete') {
          expect(saved?.id, _id);
          expect(saved?.version, 4);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('update envelope conflict offers reference reload without save callback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final commands = <String>[];
    final payloads = <Map<String, dynamic>>[];
    var detailReads = 0;
    final client = (await tester.runAsync(
      () async => _client(
        'update',
        'SAI_CONCURRENT_CHANGE',
        commands,
        onDetail: () => detailReads++,
        onCommand: payloads.add,
        resolveConflict: true,
      ),
    ))!;
    addTearDown(() => tester.runAsync(client.dispose));
    final adapter = AccessProfileModelRepositoryAdapter(SupabaseAccessProfileRepository(client));
    var successes = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileFormPage(
          repository: adapter,
          domain: AccessProfileDomain.platform,
          profileId: _id,
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onSaved: (_) => successes++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _submit(tester, 'update');
    // Save stays pending while the user decides in the conflict dialog.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Alterações em conflito'), findsOneWidget);
    expect(successes, 0);
    expect(detailReads, 1);
    await tester.tap(find.text('Recarregar referência'));
    await tester.pumpAndSettle();
    expect(detailReads, 2);
    expect(commands, ['update']);
    expect(successes, 0);
    await _checkDraft(tester, 'update');
    for (var step = 0; step < 3; step++) {
      await tester.tap(find.byKey(const Key('access-profile-continue')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('access-profile-save')));
    await tester.pumpAndSettle();
    expect(successes, 1);
    expect(commands, ['update', 'update']);
    final first = payloads.first['p_draft'] as Map;
    final retried = payloads.last['p_draft'] as Map;
    expect(first['expected_version'], 3);
    expect(retried['expected_version'], 5);
    expect(retried['name'], first['name']);
    expect(retried['description'], first['description']);
    expect(retried['reason'], first['reason']);
    expect(payloads.last['p_request_id'], isNot(payloads.first['p_request_id']));
    expect(tester.takeException(), isNull);
  });
}

String _fieldText(WidgetTester tester, String label) => tester
    .widget<CoeloFormTextField>(find.widgetWithText(CoeloFormTextField, label))
    .controller
    .text;

Future<void> _checkDraft(WidgetTester tester, String operation) async {
  expect(_fieldText(tester, 'Motivo da alteração'), 'Motivo nominal');
  for (var step = 0; step < (operation == 'create' ? 2 : 3); step++) {
    await tester.tap(find.byKey(const Key('access-profile-previous')));
    await tester.pumpAndSettle();
  }
  expect(_fieldText(tester, 'Nome do perfil'), 'Nome revisado');
  expect(_fieldText(tester, 'Código'), 'nominal.model');
  expect(_fieldText(tester, 'Descrição'), 'Descrição revisada');
}

Future<void> _submit(WidgetTester tester, String operation) async {
  if (operation == 'delete') {
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(CoeloFormTextField, 'Motivo da exclusão'),
      'Motivo nominal',
    );
    await tester.pump();
    await tester.tap(find.text('Excluir e realocar'));
  } else if (operation == 'duplicate') {
    await tester.enterText(
      find.widgetWithText(CoeloFormTextField, 'Nome do novo modelo'),
      'Cópia nominal',
    );
    await tester.enterText(
      find.widgetWithText(CoeloFormTextField, 'Motivo da duplicação'),
      'Motivo nominal',
    );
    await tester.ensureVisible(find.byKey(const Key('access-profile-duplicate-submit')));
    await tester.tap(find.byKey(const Key('access-profile-duplicate-submit')));
  } else {
    await tester.enterText(
      find.widgetWithText(CoeloFormTextField, 'Nome do perfil'),
      'Nome revisado',
    );
    if (operation == 'create') {
      await tester.enterText(find.widgetWithText(CoeloFormTextField, 'Código'), 'nominal.model');
    }
    await tester.enterText(
      find.widgetWithText(CoeloFormTextField, 'Descrição'),
      'Descrição revisada',
    );
    for (var step = 0; step < (operation == 'create' ? 2 : 3); step++) {
      await tester.ensureVisible(find.byKey(const Key('access-profile-continue')));
      await tester.tap(find.byKey(const Key('access-profile-continue')));
      await tester.pumpAndSettle();
    }
    await tester.enterText(
      find.widgetWithText(CoeloFormTextField, 'Motivo da alteração'),
      'Motivo nominal',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('access-profile-save')));
    await tester.tap(find.byKey(const Key('access-profile-save')));
  }
}

SupabaseClient _client(
  String operation,
  String? failure,
  List<String> commands, {
  VoidCallback? onDetail,
  ValueChanged<Map<String, dynamic>>? onCommand,
  bool resolveConflict = false,
}) => SupabaseClient(
  'https://model-consumer.invalid',
  'test-publishable-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
  httpClient: MockClient((request) async {
    final rpc = request.url.path.split('/').last;
    Object data;
    Object? error;
    if (rpc == 'superadmin_access_profile_model_$operation') {
      commands.add(operation);
      onCommand?.call(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
      error = failure == null || (resolveConflict && commands.length > 1)
          ? null
          : {'code': failure, 'message': 'Untrusted backend detail'};
      data = operation == 'delete'
          ? {'model_id': _id, 'status': 'inactive', 'version': 4, 'replayed': false}
          : {
              'model': {..._model, 'version': 4},
              'model_id': _id,
              'version': 4,
              'replayed': false,
            };
    } else if (rpc == 'superadmin_access_profile_model_detail') {
      onDetail?.call();
      data = resolveConflict && commands.isNotEmpty
          ? {
              ..._model,
              'name': 'Nome remoto novo',
              'description': 'Descrição remota nova',
              'version': 5,
            }
          : _model;
    } else if (rpc == 'superadmin_access_permission_catalog' ||
        rpc == 'superadmin_access_profile_models_cursor') {
      data = {'items': <Object>[], 'next_cursor': null};
    } else {
      throw StateError('Unexpected RPC $rpc');
    }
    return http.Response(
      jsonEncode({'ok': error == null, 'data': error == null ? data : null, 'error': error}),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }),
);

const _id = '00000000-0000-4000-8000-000000000002';
const _model = {
  'id': _id,
  'domain': 'platform',
  'application_code': 'superadmin',
  'code': 'nominal.model',
  'name': 'Modelo nominal',
  'description': 'Descrição nominal',
  'status': 'inactive',
  'max_scope_kind': 'platform',
  'version': 3,
  'is_system': false,
  'capabilities': <Object>[],
};
