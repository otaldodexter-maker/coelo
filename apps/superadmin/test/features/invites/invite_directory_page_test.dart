import 'package:coelo_superadmin/features/invites/data/fake_invite_repository.dart';
import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses only the canonical resizable table', (tester) async {
    await _pumpDirectory(tester, size: const Size(375, 800));

    expect(find.text('Convites'), findsOneWidget);
    expect(find.text('Novo convite'), findsOneWidget);
    expect(find.byKey(const Key('invite-table')), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is CoeloAdminResizableTable<PlatformInvite>),
      findsOneWidget,
    );
    expect(find.byType(CoeloAdminInteractiveCard), findsNothing);
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('searches only masked recipient and existing context text', (tester) async {
    await _pumpDirectory(tester);

    await tester.enterText(find.byType(TextField).first, 'o***@aurora.test');
    await tester.pump();

    expect(find.text('o***@aurora.test'), findsWidgets);
    expect(find.text('Turma Girassol'), findsNothing);
    expect(find.text('owner@aurora.test'), findsNothing);
  });

  testWidgets('applies a status filter and clears all filters', (tester) async {
    await _pumpDirectory(tester);

    final statusFilter = tester.widget<CoeloAdminMultiSelectFilter<InviteStatus>>(
      find.byType(CoeloAdminMultiSelectFilter<InviteStatus>),
    );
    statusFilter.onChanged({InviteStatus.pending});
    await tester.pumpAndSettle();

    expect(find.text('o***@aurora.test'), findsWidgets);
    expect(find.text('Turma Girassol'), findsNothing);
    expect(find.byKey(const Key('invite-clear-filters')), findsOneWidget);

    await tester.tap(find.byKey(const Key('invite-clear-filters')));
    await tester.pumpAndSettle();

    expect(find.text('Turma Girassol'), findsOneWidget);
    expect(find.byKey(const Key('invite-clear-filters')), findsNothing);
  });

  testWidgets('offers flyout actions allowed by each invitation state', (tester) async {
    String? openedInvite;
    await _pumpDirectory(tester, onOpen: (id) => openedInvite = id);

    final flyouts = tester
        .widgetList<Widget>(find.byWidgetPredicate((widget) => widget is CoeloAdminFlyout))
        .toList(growable: false);
    final dynamic pendingFlyout = flyouts.first;
    expect(pendingFlyout.items.map((dynamic item) => item.label), [
      'Ver detalhes',
      'Copiar link',
      'Reenviar convite',
      'Revogar convite',
    ]);
    expect(pendingFlyout.items.last.startsGroup, isTrue);
    expect(pendingFlyout.items.last.tone, CoeloAdminFlyoutTone.negative);

    final dynamic acceptedFlyout = flyouts[1];
    expect(acceptedFlyout.items.map((dynamic item) => item.label), ['Ver detalhes', 'Copiar link']);

    await tester.tap(find.byKey(const Key('invite-actions-invite-1')));
    await tester.pumpAndSettle();
    expect(find.text('Revogar convite'), findsOneWidget);

    await tester.tap(find.text('Ver detalhes'));
    await tester.pumpAndSettle();
    expect(openedInvite, 'invite-1');
    expect(find.text('Revogar convite'), findsNothing);

    await tester.tap(find.byKey(const Key('invite-actions-invite-2')));
    await tester.pumpAndSettle();
    expect(find.text('Ver detalhes'), findsOneWidget);
    expect(find.text('Reenviar convite'), findsNothing);
    expect(find.text('Revogar convite'), findsNothing);

    await tester.tap(find.text('Ver detalhes'));
    await tester.pump();
    expect(openedInvite, 'invite-2');
  });
}

Future<void> _pumpDirectory(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
  ValueChanged<String>? onOpen,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: InviteDirectoryPage(
          repository: FakeInviteRepository(now: () => DateTime(2026, 8, 4, 12)),
          onOpen: onOpen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
