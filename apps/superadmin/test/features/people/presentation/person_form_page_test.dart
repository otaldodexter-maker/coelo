import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/people/data/fake_person_directory_repository.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_superadmin/features/people/presentation/person_form_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('form keeps a local address section out of the persisted identity contract', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Endereço local'), findsOneWidget);
    expect(find.byKey(const Key('person-address-postal-code')), findsOneWidget);
    expect(find.byKey(const Key('person-address-street')), findsOneWidget);
    expect(find.byKey(const Key('person-address-city')), findsOneWidget);
    expect(find.textContaining('não será persistido'), findsOneWidget);
  });

  testWidgets('relationship demo searches adults masked and children without contact data', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 1));
    for (final entry in const {
      'person-first-name-field': 'Ana',
      'person-last-name-field': 'Lima',
      'person-display-name-field': 'Ana Lima',
      'person-legal-name-field': 'Ana Lima',
    }.entries) {
      await tester.enterText(find.byKey(Key(entry.key)), entry.value);
    }
    await tester.tap(find.text('Vínculos contextuais').first);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Buscar adulto existente'), findsOneWidget);
    expect(find.textContaining('dados mascarados'), findsOneWidget);
    expect(find.text('Buscar criança existente'), findsOneWidget);
    expect(find.textContaining('nome, identificador ou contexto'), findsOneWidget);
    expect(find.textContaining('E-mail obrigatório'), findsNothing);
    expect(find.textContaining('Celular obrigatório'), findsNothing);

    await tester.enterText(find.byKey(const Key('person-adult-link-search')), '@ana.coelo');
    await tester.pump();
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.textContaining('***.456.***-**'), findsOneWidget);
    await tester.tap(find.byKey(const Key('person-adult-link-result-adult-ana')));
    await tester.pump();
    expect(find.text('Vínculo selecionado: Ana Souza'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('person-child-link-search')), 'Girassol');
    await tester.pump();
    expect(find.text('Lia Coelo'), findsOneWidget);
    expect(find.textContaining('Turma Girassol'), findsOneWidget);
  });

  testWidgets('uses measured glass footer and reserves scroll content', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    final scroll = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('person-form-scroll')),
    );
    expect((scroll.padding! as EdgeInsets).bottom, greaterThan(CoeloSpacing.space6));
  });

  testWidgets('create form has three responsive steps and no sensitive fields', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Identidade'), findsWidgets);
    expect(find.text('Etapa 1 de 3'), findsOneWidget);
    expect(find.text('CPF'), findsNothing);
    expect(find.text('Nascimento'), findsNothing);
    expect(find.text('Foto'), findsNothing);
    expect(find.text('Auth'), findsNothing);

    await tester.enterText(find.byKey(const Key('person-first-name-field')), 'Ana');
    await tester.enterText(find.byKey(const Key('person-last-name-field')), 'Lima');
    await tester.enterText(find.byKey(const Key('person-display-name-field')), 'Ana Lima');
    await tester.enterText(find.byKey(const Key('person-legal-name-field')), 'Ana Lima');
    await tester.tap(find.byKey(const Key('person-form-continue')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Vínculos contextuais', skipOffstage: false), findsWidgets);
  });

  testWidgets('requires identity fields before advancing', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byKey(const Key('person-form-continue')));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Informe os campos obrigatórios.'), findsOneWidget);
    expect(find.byKey(const Key('person-first-name-field')), findsOneWidget);
  });

  testWidgets('uses shared step navigation laterally from medium width', (tester) async {
    final original = FakePersonDirectoryRepository.samplePeople.firstWhere(
      (item) => item.isEditable,
    );
    await tester.binding.setSurfaceSize(const Size(768, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(original: original));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.byKey(const Key('superadmin-form-steps-scroll')), findsOneWidget);
    final navigationX = tester.getTopLeft(find.byType(SuperadminFormStepNavigation)).dx;
    final contentX = tester.getTopLeft(find.text('Informe somente os dados globais aprovados.')).dx;
    expect(navigationX, lessThan(contentX));

    await tester.binding.setSurfaceSize(const Size(1024, 900));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-form-step-summary')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the shared compact step summary at 375', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.byKey(const Key('superadmin-form-step-summary')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('person-form-navigation')),
        matching: find.byType(MenuAnchor),
      ),
      findsNothing,
    );
  });

  testWidgets('separates relationships from progressive institutional access context', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 1));
    for (final entry in const {
      'person-first-name-field': 'Ana',
      'person-last-name-field': 'Lima',
      'person-display-name-field': 'Ana Lima',
      'person-legal-name-field': 'Ana Lima',
    }.entries) {
      await tester.enterText(find.byKey(Key(entry.key)), entry.value);
    }
    await tester.tap(find.byKey(const Key('person-form-continue')));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Relações com outras pessoas'), findsOneWidget);
    expect(find.text('Contexto institucional'), findsOneWidget);
    expect(find.text('Perfil de acesso'), findsOneWidget);
    expect(find.textContaining('acesso contextual do funcionário'), findsOneWidget);

    final unit = tester.widget<CoeloAdminSingleSelectField<PersonFilterOption>>(
      find.byKey(const Key('person-membership-unit')),
    );
    final group = tester.widget<CoeloAdminSingleSelectField<PersonFilterOption>>(
      find.byKey(const Key('person-membership-group')),
    );
    expect(unit.enabled, isFalse);
    expect(group.enabled, isFalse);
  });
  testWidgets('context step requires explicit adult membership selections', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 1));
    for (final entry in const {
      'person-first-name-field': 'Ana',
      'person-last-name-field': 'Lima',
      'person-display-name-field': 'Ana Lima',
      'person-legal-name-field': 'Ana Lima',
    }.entries) {
      await tester.enterText(find.byKey(Key(entry.key)), entry.value);
    }
    await tester.tap(find.byKey(const Key('person-form-continue')));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('person-membership-institution')), findsOneWidget);
    expect(find.byKey(const Key('person-membership-unit')), findsOneWidget);
    expect(find.byKey(const Key('person-membership-group')), findsOneWidget);
    expect(find.byKey(const Key('person-membership-role')), findsOneWidget);
  });

  testWidgets('edit shows auth, platform and guardian summaries as read-only', (tester) async {
    final original = FakePersonDirectoryRepository.samplePeople.firstWhere(
      (item) => item.type == PersonType.child,
    );
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(original: original));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Tipo'), findsWidgets);
    expect(find.text('Status'), findsWidgets);
    expect(find.text('Vínculo Auth'), findsOneWidget);
    expect(find.text('Membership de plataforma'), findsOneWidget);
    expect(find.text('Vínculos de responsável'), findsOneWidget);
    expect(find.byKey(const Key('person-form-navigation')), findsOneWidget);
  });

  testWidgets('desktop edit uses side navigation and one-row footer like Institutions', (
    tester,
  ) async {
    final original = FakePersonDirectoryRepository.samplePeople.firstWhere(
      (item) => item.isEditable,
    );
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(original: original));
    await tester.pump(const Duration(seconds: 1));

    final navigationX = tester.getTopLeft(find.byKey(const Key('person-form-navigation'))).dx;
    final contentX = tester.getTopLeft(find.text('Informe somente os dados globais aprovados.')).dx;
    expect(navigationX, lessThan(contentX));
    expect(
      tester.getCenter(find.text('Continuar')).dy,
      closeTo(tester.getCenter(find.text('Cancelar')).dy, 1),
    );
  });

  testWidgets('service deep-link is read-only and has no save action', (tester) async {
    final service = FakePersonDirectoryRepository.samplePeople.firstWhere(
      (item) => item.type == PersonType.service,
    );
    await tester.pumpWidget(_app(original: service));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Pessoa de serviço — somente leitura'), findsOneWidget);
    expect(find.byKey(const Key('person-form-save')), findsNothing);
    expect(find.byKey(const Key('person-first-name-field')), findsNothing);

    await tester.tap(find.text('Vínculos contextuais').first);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('person-add-membership')), findsNothing);
    expect(find.text('Pessoa de serviço — somente leitura'), findsOneWidget);
  });

  testWidgets('future step navigation validates identity before advancing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Revisão').first);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Informe os campos obrigatórios.'), findsOneWidget);
    expect(find.byKey(const Key('person-first-name-field')), findsOneWidget);
  });

  testWidgets('child contexts never render editable adult memberships', (tester) async {
    final child = FakePersonDirectoryRepository.samplePeople.firstWhere(
      (item) => item.type == PersonType.child,
    );
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(original: child));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Vínculos contextuais').first);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Perfil de acesso'), findsNothing);
    expect(find.text('Revogar vínculo'), findsNothing);
  });

  testWidgets('filter option failure renders a retryable state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(repository: _FilterFailureRepository()));
    await tester.pump(const Duration(seconds: 1));

    for (final entry in const {
      'person-first-name-field': 'Ana',
      'person-last-name-field': 'Lima',
      'person-display-name-field': 'Ana Lima',
      'person-legal-name-field': 'Ana Lima',
    }.entries) {
      await tester.enterText(find.byKey(Key(entry.key)), entry.value);
    }
    await tester.tap(find.text('Vínculos contextuais').first);
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('Não foi possível carregar os vínculos'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}

Widget _app({PersonDirectoryItem? original, PersonDirectoryRepository? repository}) {
  final resolvedRepository = repository ?? FakePersonDirectoryRepository();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => PersonFormPage(
          repository: resolvedRepository,
          logout: () async => const LogoutResult.success(),
          original: original,
        ),
      ),
    ],
  );
  return MaterialApp.router(
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    routerConfig: router,
  );
}

final class _FilterFailureRepository implements PersonDirectoryRepository {
  final _delegate = FakePersonDirectoryRepository();

  @override
  Future<PersonDirectoryItem> createDraft(PersonDraft draft) => _delegate.createDraft(draft);

  @override
  Future<PersonDirectoryItem> fetchDetail(String personId) => _delegate.fetchDetail(personId);

  @override
  Future<PersonDirectoryFilterOptions> fetchFilterOptions() =>
      Future.error(const PersonDirectoryUnavailableException());

  @override
  Future<PersonDirectoryPage> fetchPage(PersonDirectoryQuery query) => _delegate.fetchPage(query);

  @override
  Future<PersonDirectoryItem> updatePerson(PersonUpdate update) => _delegate.updatePerson(update);
}
