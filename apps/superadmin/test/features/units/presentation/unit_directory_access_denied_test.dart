import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/units/data/fake_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/domain/unit_directory.dart' as domain;
import 'package:coelo_superadmin/features/units/presentation/unit_directory_page.dart';
import 'package:coelo_superadmin/features/units/presentation/widgets/unit_directory_toolbar.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows only the denied state when the unit directory is unauthorized', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: UnitDirectoryPage(
          repository: _UnauthorizedUnitDirectoryRepository(
            FakeUnitDirectoryRepository(FakeInstitutionDirectoryRepository()),
          ),
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );

    void expectNoDirectoryControls() {
      expect(find.byType(UnitDirectoryToolbar), findsNothing);
      expect(find.byKey(const Key('unit-filter-toolbar')), findsNothing);
      expect(find.byKey(const Key('unit-status-tabs')), findsNothing);
      expect(find.byType(CoeloAdminFileActions), findsNothing);
      expect(find.byKey(const Key('coelo-admin-files-action')), findsNothing);
      expect(find.byKey(const Key('unit-files-import')), findsNothing);
      expect(find.byKey(const Key('unit-files-export-csv')), findsNothing);
      expect(find.byKey(const Key('unit-files-export-xlsx')), findsNothing);
      expect(find.byType(CoeloAdminCreateAction), findsNothing);
      expect(find.byKey(const Key('create-unit-card')), findsNothing);
      expect(find.byKey(const Key('create-unit-banner')), findsNothing);
      expect(find.byKey(const Key('unit-card-grid')), findsNothing);
      expect(find.byKey(const Key('unit-directory-table')), findsNothing);
      expect(find.byKey(const Key('unit-directory-pagination-footer')), findsNothing);
    }

    await tester.pumpAndSettle();

    const deniedMessage = 'Você não tem permissão para ver as unidades.';
    final denied = find.text(deniedMessage);
    expect(denied, findsOneWidget);
    expect(find.bySemanticsLabel(deniedMessage), findsOneWidget);
    expect(tester.getRect(denied).left, greaterThanOrEqualTo(0));
    expect(tester.getRect(denied).right, lessThanOrEqualTo(375));
    expect(tester.getRect(denied).top, greaterThanOrEqualTo(0));
    expect(tester.getRect(denied).bottom, lessThanOrEqualTo(900));
    expect(denied.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    expectNoDirectoryControls();
  });
}

final class _UnauthorizedUnitDirectoryRepository implements domain.UnitDirectoryRepository {
  const _UnauthorizedUnitDirectoryRepository(this._delegate);

  final domain.UnitDirectoryRepository _delegate;

  @override
  List<domain.UnitRecord> get records => _delegate.records;

  @override
  String createId(String institutionId, String slug) => _delegate.createId(institutionId, slug);

  @override
  domain.UnitRecord? findById(String id) => _delegate.findById(id);

  @override
  Future<domain.UnitDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) => throw const domain.UnitDirectoryUnauthorizedException();

  @override
  Future<domain.UnitDirectoryPage> fetchPage(domain.UnitDirectoryQuery query) =>
      throw const domain.UnitDirectoryUnauthorizedException();

  @override
  Future<domain.UnitFormData> loadForm({String? unitId}) => _delegate.loadForm(unitId: unitId);

  @override
  Future<void> upsert(domain.UnitRecord record) => _delegate.upsert(record);
}
