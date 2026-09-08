import 'dart:async';

import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_duplicate_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('replacement repository loads its source and discards the previous response', (
    tester,
  ) async {
    final first = _Repository('A');
    final second = _Repository('B');
    await tester.pumpWidget(_page(first));
    await tester.pumpWidget(_page(second));
    second.detail.complete(_profile('B'));
    first.detail.complete(_profile('A'));
    await tester.pumpAndSettle();
    expect(second.reads, 1);
    expect(_name(tester), 'Modelo B (cópia)');
    expect(find.textContaining('“Modelo A”'), findsNothing);
  });

  testWidgets('pending duplicate cannot invoke the replacement context callback', (tester) async {
    final first = _Repository('A')..detail.complete(_profile('A'));
    final second = _Repository('B')..detail.complete(_profile('B'));
    var oldCalls = 0;
    var newCalls = 0;
    await tester.pumpWidget(_page(first, onDuplicated: (_) => oldCalls++));
    await tester.pumpAndSettle();
    await _submit(tester);
    await tester.pumpWidget(_page(second, onDuplicated: (_) => newCalls++));
    await tester.pump();
    first.result.complete(_profile('copy-A'));
    await tester.pumpAndSettle();
    expect(oldCalls, 0);
    expect(newCalls, 0);
    expect(_name(tester), 'Modelo B (cópia)');
  });

  testWidgets('repeated activation before a frame sends only one duplication', (tester) async {
    final repository = _Repository('A')..detail.complete(_profile('A'));
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(CoeloFormTextField, 'Motivo da duplicação'),
      'Motivo sintético',
    );
    final submit = tester
        .widget<FilledButton>(find.byKey(const Key('access-profile-duplicate-submit')))
        .onPressed!;
    submit();
    submit();
    final calls = repository.duplicates;
    repository.result.complete(_profile('copy'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
}

String _name(WidgetTester tester) => tester
    .widget<CoeloFormTextField>(find.widgetWithText(CoeloFormTextField, 'Nome do novo modelo'))
    .controller
    .text;

Future<void> _submit(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(CoeloFormTextField, 'Motivo da duplicação'),
    'Motivo sintético',
  );
  await tester.tap(find.byKey(const Key('access-profile-duplicate-submit')));
  await tester.pump();
}

Widget _page(_Repository repository, {ValueChanged<AccessProfile>? onDuplicated}) => MaterialApp(
  theme: CoeloTheme.light,
  home: AccessProfileDuplicatePage(
    repository: repository,
    duplicator: repository,
    logout: unavailableSuperadminLogout,
    domain: AccessProfileDomain.platform,
    sourceProfileId: repository.id,
    onCancel: () {},
    onDuplicated: onDuplicated ?? (_) {},
  ),
);

final class _Repository implements AccessProfileRepository, AccessProfileDuplicator {
  _Repository(this.id);
  final String id;
  final detail = Completer<AccessProfile>();
  final result = Completer<AccessProfile>();
  int reads = 0;
  int duplicates = 0;

  @override
  Future<AccessProfile> fetchDetail(AccessProfileDomain domain, String profileId) {
    reads++;
    return detail.future;
  }

  @override
  Future<AccessProfile> duplicate({
    required String requestId,
    required String sourceProfileId,
    required AccessProfileDomain domain,
    required String name,
    required String reason,
  }) {
    duplicates++;
    return result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AccessProfile _profile(String id) => AccessProfile(
  id: id,
  domain: AccessProfileDomain.platform,
  code: id,
  name: 'Modelo $id',
  description: 'Registro sintético.',
  status: AccessProfileStatus.inactive,
  maxScope: AccessProfileScope.platform,
  version: 1,
  membershipCount: 0,
);
