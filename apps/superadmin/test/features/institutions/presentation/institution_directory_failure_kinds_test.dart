import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_page.dart'
    as domain;
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_query.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/presentation/screens/institution_directory_page.dart';
import 'package:coelo_superadmin/features/institutions/presentation/view_models/institution_directory_view_model.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The directory distinguishes several reasons a read can fail and writes a
/// different sentence for each. Only two of those sentences were ever driven
/// through the repository, so a regression that collapsed the others into the
/// generic message would have shipped green.
///
/// The distinction is not cosmetic. "A busca foi rejeitada" tells the operator
/// to change what they typed; "Não foi possível carregar" tells them to try the
/// same thing again. Swapping them wastes the operator's time in the direction
/// that looks like the product working.
final class _ThrowingRepository implements InstitutionDirectoryRepository {
  _ThrowingRepository(this.failure);

  final Object failure;
  var reads = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<domain.InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query) async {
    reads++;
    throw failure;
  }

  @override
  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) async => InstitutionDirectoryFilterOptions.empty;
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

void main() {
  Widget app(InstitutionDirectoryRepository repository) => MaterialApp(
    theme: CoeloTheme.light,
    home: InstitutionDirectoryPage(repository: repository, logout: _logout),
  );

  Future<_ThrowingRepository> pumpFailing(WidgetTester tester, Object failure) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ThrowingRepository(failure);
    // A fresh tree per case: pumping the same widget type again updates the
    // existing State, which keeps the previous repository and reads nothing.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('a rejected search says the search was rejected, not that loading failed', (
    tester,
  ) async {
    await pumpFailing(tester, const InstitutionDirectoryValidationException('rejeitada'));
    expect(find.text(InstitutionDirectoryViewModel.validationMessage), findsOneWidget);
    expect(find.text(InstitutionDirectoryViewModel.genericErrorMessage), findsNothing);
    expect(find.text(InstitutionDirectoryViewModel.unauthorizedMessage), findsNothing);
  });

  testWidgets('the server message of a rejected search never reaches the screen', (tester) async {
    // The exception carries a server string. Rendering it would leak backend
    // wording into the product and, worse, could carry detail the operator is
    // not entitled to.
    await pumpFailing(
      tester,
      const InstitutionDirectoryValidationException('coluna oculta inválida: tenant_id'),
    );
    expect(find.textContaining('tenant_id'), findsNothing);
    expect(find.textContaining('coluna oculta'), findsNothing);
  });

  testWidgets('a conflict is reported as an ordinary failure, not as a rejected search', (
    tester,
  ) async {
    await pumpFailing(tester, const InstitutionDirectoryConflictException());
    expect(find.text(InstitutionDirectoryViewModel.genericErrorMessage), findsOneWidget);
    expect(find.text(InstitutionDirectoryViewModel.validationMessage), findsNothing);
  });

  testWidgets('an unexpected failure keeps its own generic wording', (tester) async {
    await pumpFailing(tester, const InstitutionDirectoryUnexpectedException('boom'));
    expect(find.text(InstitutionDirectoryViewModel.genericErrorMessage), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('a denial is not a failure and offers no retry', (tester) async {
    await pumpFailing(tester, const InstitutionDirectoryUnauthorizedException());
    expect(find.text(InstitutionDirectoryViewModel.unauthorizedMessage), findsOneWidget);
    // Retrying a denial would only teach the operator that the button lies.
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets('every failure kind offers a retry that genuinely reads again', (tester) async {
    for (final failure in <Object>[
      const InstitutionDirectoryValidationException('rejeitada'),
      const InstitutionDirectoryConflictException(),
      const InstitutionDirectoryUnexpectedException('boom'),
      Exception('offline'),
    ]) {
      final repository = await pumpFailing(tester, failure);
      expect(repository.reads, 1, reason: '$failure');
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(repository.reads, 2, reason: '$failure');
    }
  });
}
