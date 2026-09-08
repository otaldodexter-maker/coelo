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
        final client = (await tester.runAsync(
          () async => _client(operation, denied ? 'SAI_PERMISSION_DENIED' : null, commands),
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
        expect(successes, denied ? 0 : 1);
        if (denied) {
          expect(find.text(const AccessProfileUnauthorizedException().message), findsOneWidget);
          expect(find.textContaining('Untrusted backend detail'), findsNothing);
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
    var detailReads = 0;
    final client = (await tester.runAsync(
      () async =>
          _client('update', 'SAI_CONCURRENT_CHANGE', commands, onDetail: () => detailReads++),
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
    expect(tester.takeException(), isNull);
  });
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
      await tester.enterText(
        find.widgetWithText(CoeloFormTextField, 'Descrição'),
        'Descrição nominal',
      );
    }
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
      error = failure == null ? null : {'code': failure, 'message': 'Untrusted backend detail'};
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
      data = _model;
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
