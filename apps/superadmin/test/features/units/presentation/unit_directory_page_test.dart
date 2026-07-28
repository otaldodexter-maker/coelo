import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/units/data/fake_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/domain/unit_directory.dart' as domain;
import 'package:coelo_superadmin/features/units/presentation/unit_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the unit card contract and switches to the canonical table', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();
    final repository = FakeUnitDirectoryRepository(institutions);
    final firstItem = (await repository.fetchPage(domain.UnitDirectoryQuery())).items.first;
    String? editedId;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitDirectoryPage(
          repository: repository,
          logout: () async => const LogoutResult.success(),
          onEdit: (id) => editedId = id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unidades'), findsWidgets);
    expect(find.text('Gerencie as unidades da plataforma.'), findsOneWidget);
    expect(find.text('Instituição'), findsWidgets);
    expect(find.text('Tipo'), findsWidgets);
    expect(find.text('Plano'), findsWidgets);
    expect(find.text('Grupos'), findsWidgets);
    expect(find.text('Atividades'), findsWidgets);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);

    final firstCard = find.byKey(Key('unit-card-${firstItem.id}'));
    await tester.tap(firstCard);
    expect(editedId, firstItem.id);

    await tester.tap(find.byKey(const Key('unit-view-table')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unit-directory-table')), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Município'), findsOneWidget);
    expect(find.text('UF'), findsOneWidget);
  });

  testWidgets('has no overflow at 375 pixels with text at 200 percent', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: UnitDirectoryPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
