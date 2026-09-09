import 'dart:io';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_superadmin/features/people/presentation/person_form_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/people/fake_person_directory_repository.dart';

void main() {
  testWidgets('optional legal name does not prevent continuing or saving a person', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakePersonDirectoryRepository(seed: const []);
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('person-form-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Campo obrigatório'), findsNWidgets(3));
    for (final entry in const {
      'person-first-name-field': 'Nome',
      'person-last-name-field': 'Sintético',
      'person-display-name-field': 'Nome Sintético',
    }.entries) {
      await tester.enterText(find.byKey(Key(entry.key)), entry.value);
    }
    await tester.tap(find.byKey(const Key('person-form-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Informe os campos obrigatórios.'), findsNothing);
    await tester.tap(find.byKey(const Key('person-form-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('person-form-save')));
    await tester.pumpAndSettle();
    expect(repository.people, hasLength(1));
    expect(repository.people.single.displayName, 'Nome Sintético');
  });

  testWidgets('person identity step includes the compact address map state', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('coelo-address-map-unavailable')), findsOneWidget);
  });

  testWidgets('form keeps a local address section out of the persisted identity contract', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SuperadminFormFrame), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SuperadminFormFrame),
        matching: find.byType(AnimatedSwitcher),
      ),
      findsNothing,
    );
    expect(find.text('Endereço local'), findsOneWidget);
    expect(find.byKey(const Key('person-address-postal-code')), findsOneWidget);
    expect(find.byKey(const Key('person-address-street')), findsOneWidget);
    expect(find.byKey(const Key('person-address-city')), findsOneWidget);
    expect(find.textContaining('demonstrativ'), findsNothing);
  });

  testWidgets('the relationship search says it is not connected, and invents nobody', (
    tester,
  ) async {
    // This section used to answer with four invented people carrying
    // masked-looking documents, e-mail and phone numbers, compiled into the
    // production form. Selecting one reached nothing, so anyone who "linked"
    // someone lost that work silently. The two tests that stood here asserted
    // that behaviour and therefore protected it.
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

    // The shape the design approved stays visible, so the capability reads as
    // planned rather than forgotten.
    expect(find.text('Buscar adulto existente'), findsOneWidget);
    expect(find.text('Buscar criança existente'), findsOneWidget);
    expect(find.byKey(const Key('person-adult-link-search')), findsOneWidget);
    expect(find.byKey(const Key('person-child-link-search')), findsOneWidget);

    // And it says plainly that it cannot answer.
    final notice = find.byKey(const Key('person-relationship-search-unavailable'));
    expect(notice, findsOneWidget);
    expect(tester.getSemantics(notice).flagsCollection.isLiveRegion, isTrue);
    expect(find.textContaining('ainda não está ligada ao servidor'), findsOneWidget);

    // A box that cannot answer must not invite an answer.
    for (final key in const ['person-adult-link-search', 'person-child-link-search']) {
      expect(tester.widget<CoeloSearchField>(find.byKey(Key(key))).enabled, isFalse, reason: key);
    }
  });

  testWidgets('no invented person survives anywhere in the production form', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Vínculos contextuais').first);
    await tester.pump(const Duration(seconds: 1));
    for (final invented in const [
      'Ana Souza',
      'Caio Lima',
      'Lia Coelo',
      'Noah Coelo',
      '@ana.coelo',
      'Turma Girassol',
    ]) {
      expect(find.textContaining(invented), findsNothing, reason: invented);
    }
  });

  test('the source carries no relationship fixture to render', () {
    // The existing production-boundary guard scans for _Demo, "demonstrativ"
    // and "não será persistido"; none of those words appeared in the fixtures
    // it was meant to catch, so it passed while they shipped. This names them.
    final source = File(
      'lib/features/people/presentation/person_form_page.dart',
    ).readAsStringSync();
    for (final forbidden in const [
      '_LinkCandidate',
      '_adultLinkCandidates',
      '_childLinkCandidates',
      'Ana Souza',
      'Lia Coelo',
    ]) {
      expect(source.contains(forbidden), isFalse, reason: forbidden);
    }
  });

  testWidgets('relationship search uses the direct form canvas without a redundant surface', (
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
    await tester.tap(find.byKey(const Key('person-form-continue')));
    await tester.pump(const Duration(seconds: 1));

    final section = find.byKey(const Key('person-relationship-search-section'));
    expect(section, findsOneWidget);
    expect(tester.widget(section), isA<Column>());
  });

  testWidgets('membership cards have tokenized separation', (tester) async {
    final original = FakePersonDirectoryRepository.samplePeople.firstWhere(
      (item) => item.type == PersonType.adult && item.isEditable,
    );
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(original: original));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Vínculos contextuais').first);
    await tester.pump(const Duration(seconds: 1));

    final first = find.byKey(const Key('person-membership-card-membership-0-a'));
    final second = find.byKey(const Key('person-membership-card-membership-0-b'));
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(tester.getTopLeft(second).dy - tester.getBottomLeft(first).dy, CoeloSpacing.space3);
  });

  testWidgets('revoke membership is semantically negative at rest hover and focus', (tester) async {
    final original = FakePersonDirectoryRepository.samplePeople.firstWhere(
      (item) => item.type == PersonType.adult && item.isEditable,
    );
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(original: original));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Vínculos contextuais').first);
    await tester.pump(const Duration(seconds: 1));

    final button = tester.widget<TextButton>(
      find.ancestor(of: find.text('Revogar vínculo').first, matching: find.byType(TextButton)),
    );
    final colors = Theme.of(tester.element(find.byType(PersonFormPage))).colorScheme;
    expect(button.style?.foregroundColor?.resolve({}), colors.error);
    expect(button.style?.backgroundColor?.resolve({WidgetState.hovered}), colors.errorContainer);
    expect(button.style?.backgroundColor?.resolve({WidgetState.focused}), colors.errorContainer);
  });

  testWidgets('revoke child context is semantically negative at rest hover and focus', (
    tester,
  ) async {
    final child = FakePersonDirectoryRepository.samplePeople.firstWhere(
      (item) => item.type == PersonType.child,
    );
    final original = child.copyWith(
      childContexts: const [
        PersonChildContext(
          id: 'child-context-test',
          institutionId: 'institution-0',
          institutionName: 'Instituição 1',
          unitId: 'unit-0',
          unitName: 'Unidade 1',
          groupId: 'group-0',
          groupName: 'Turma 1',
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(original: original));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Vínculos contextuais').first);
    await tester.pump(const Duration(seconds: 1));

    final button = tester.widget<TextButton>(
      find.ancestor(of: find.text('Revogar contexto').first, matching: find.byType(TextButton)),
    );
    final colors = Theme.of(tester.element(find.byType(PersonFormPage))).colorScheme;
    expect(button.style?.foregroundColor?.resolve({}), colors.error);
    expect(button.style?.backgroundColor?.resolve({WidgetState.hovered}), colors.errorContainer);
    expect(button.style?.backgroundColor?.resolve({WidgetState.focused}), colors.errorContainer);
  });

  testWidgets('keeps the canonical footer after the compact scroll region', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    final scroll = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('person-form-scroll')),
    );
    expect((scroll.padding! as EdgeInsets).bottom, CoeloSpacing.space6);
    expect(
      tester.getTopLeft(find.byType(SuperadminFormActionFooter)).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byKey(const Key('person-form-scroll'))).dy),
    );
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
    final continueButton = find.byKey(const Key('person-form-continue'));
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
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
