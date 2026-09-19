import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/staff_access/data/fake_staff_access_repository.dart';
import 'package:coelo_superadmin/features/staff_access/domain/staff_access.dart';
import 'package:coelo_superadmin/features/staff_access/presentation/staff_access_directory_page.dart';
import 'package:coelo_superadmin/features/staff_access/presentation/staff_access_form_page.dart';
import 'package:coelo_superadmin/features/staff_access/presentation/staff_leave_directory_page.dart';
import 'package:coelo_superadmin/features/staff_access/presentation/staff_leave_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<LogoutResult> _logout() async => const LogoutResult.success();

Widget _app(Widget child) => MaterialApp(theme: CoeloTheme.light, home: child);

void main() {
  group('Acesso de funcionários (diretório)', () {
    testWidgets('lista um card por vínculo com o estado do servidor e abre pelo card', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? opened;
      await tester.pumpWidget(
        _app(
          StaffAccessDirectoryPage(
            repository: FakeStaffAccessRepository(),
            logout: _logout,
            onOpen: (id) => opened = id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ana Ribeiro'), findsOneWidget);
      expect(find.text('Bruno Carvalho'), findsOneWidget);
      expect(find.byKey(const Key('staff-access-state-m-ana')), findsOneWidget);
      // a regra da Ana aparece resumida no card
      expect(find.textContaining('6 janelas'), findsOneWidget);

      await tester.tap(find.byKey(const Key('staff-access-card-m-ana')));
      await tester.pumpAndSettle();
      expect(opened, 'm-ana');
    });

    testWidgets('filtra por estado e mostra "sem resultados" com Limpar filtros', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(StaffAccessDirectoryPage(repository: FakeStaffAccessRepository(), logout: _logout)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('staff-access-search')),
          matching: find.byType(TextField),
        ),
        'zzz-ninguem',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum funcionário encontrado com estes filtros.'), findsOneWidget);
      expect(find.text('Limpar filtros'), findsWidgets);
    });

    testWidgets('tabela mostra as colunas de estado e regra', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(StaffAccessDirectoryPage(repository: FakeStaffAccessRepository(), logout: _logout)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('staff-access-view-table')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('staff-access-table')), findsOneWidget);
      expect(find.byKey(const Key('staff-access-state-chip-schedule')), findsWidgets);
    });

    testWidgets('sem permissão mostra o estado não autorizado', (tester) async {
      final repository = FakeStaffAccessRepository()..unauthorized = true;
      await tester.pumpWidget(_app(StaffAccessDirectoryPage(repository: repository, logout: _logout)));
      await tester.pumpAndSettle();
      expect(find.text('Você não tem permissão para gerir o acesso de funcionários.'), findsOneWidget);
    });
  });

  group('Acesso de funcionários (formulário)', () {
    testWidgets('carrega a regra, adiciona uma janela e salva com a versão esperada', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = FakeStaffAccessRepository();
      StaffAccessItem? saved;
      await tester.pumpWidget(
        _app(
          StaffAccessFormPage(
            repository: repository,
            membershipId: 'm-ana',
            onCancel: () {},
            onSaved: (item) => saved = item,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ana Ribeiro'), findsWidgets);
      expect(find.byKey(const Key('staff-access-restricted-toggle')), findsOneWidget);

      // Horários: seg–sex 08–18 já existem; adiciona uma janela no sábado.
      await tester.tap(find.text('Horários'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('staff-access-window-add-6')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('staff-access-window-add-6')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('staff-access-window-remove-6')), findsOneWidget);

      await tester.tap(find.byKey(const Key('staff-access-form-save')));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(repository.savedRules, hasLength(1));
      final draft = repository.savedRules.single;
      expect(draft.clear, isFalse);
      expect(draft.windows.where((w) => w.weekday == 6), hasLength(1));
      expect(draft.surfaces, {StaffAccessSurface.web, StaffAccessSurface.mobileWeb});
      expect(saved!.rule!.version, 3);
    });

    testWidgets('versão defasada (PT409) mostra o conflito com Recarregar e bloqueia Salvar', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = FakeStaffAccessRepository()..failNextSaveWithConflict = true;
      await tester.pumpWidget(
        _app(StaffAccessFormPage(repository: repository, membershipId: 'm-ana', onCancel: () {})),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('staff-access-form-save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('staff-access-form-conflict')), findsOneWidget);
      expect(find.text('Recarregar'), findsOneWidget);
      final save = tester.widget<FilledButton>(find.byKey(const Key('staff-access-form-save')));
      expect(save.onPressed, isNull);

      await tester.tap(find.byKey(const Key('staff-access-form-reload')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('staff-access-form-conflict')), findsNothing);
    });

    testWidgets('desligar "Restringir" limpa a regra no servidor', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = FakeStaffAccessRepository();
      await tester.pumpWidget(
        _app(
          StaffAccessFormPage(
            repository: repository,
            membershipId: 'm-ana',
            onCancel: () {},
            onSaved: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('staff-access-restricted-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('staff-access-form-save')));
      await tester.pumpAndSettle();
      expect(repository.savedRules.single.clear, isTrue);
    });

    testWidgets('vínculo livre: ligar a restrição exige ao menos uma superfície', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          StaffAccessFormPage(
            repository: FakeStaffAccessRepository(),
            membershipId: 'm-diego',
            onCancel: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('staff-access-restricted-toggle')));
      await tester.pumpAndSettle();
      // a seção Superfícies abre com todas ligadas; desliga as quatro
      for (final surface in StaffAccessSurface.values) {
        await tester.tap(find.byKey(Key('staff-access-surface-${surface.name}')));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const Key('staff-access-surfaces-error')), findsOneWidget);
      final save = tester.widget<FilledButton>(find.byKey(const Key('staff-access-form-save')));
      expect(save.onPressed, isNull);
    });

    testWidgets('compacto (375) não estoura horizontalmente', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          StaffAccessFormPage(
            repository: FakeStaffAccessRepository(),
            membershipId: 'm-ana',
            onCancel: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // no compacto a navegação é um resumo; avança pelo rodapé
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const Key('staff-access-form-continue')));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const Key('staff-access-window-add-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Afastamentos', () {
    testWidgets('diretório lista os afastamentos com abas por período', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      StaffLeave? opened;
      await tester.pumpWidget(
        _app(
          StaffLeaveDirectoryPage(
            repository: FakeStaffAccessRepository(),
            logout: _logout,
            onCreate: () {},
            onOpen: (leave) => opened = leave,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Carla Mendes'), findsOneWidget);
      expect(find.byKey(const Key('staff-leave-period-tabs')), findsOneWidget);
      expect(find.byKey(const Key('create-staff-leave-card')), findsOneWidget);

      await tester.tap(find.byKey(const Key('staff-leave-card-leave-carla-1')));
      await tester.pumpAndSettle();
      expect(opened?.id, 'leave-carla-1');

      await tester.tap(find.text('Encerrados'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum afastamento encontrado com estes filtros.'), findsOneWidget);
    });

    testWidgets('editar afastamento salva com versão e remover pede confirmação', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = FakeStaffAccessRepository();
      final page = await repository.fetchLeaves(const StaffLeaveQuery());
      final leave = page.items.single;
      final results = <StaffLeave?>[];
      await tester.pumpWidget(
        _app(
          StaffLeaveFormPage(
            repository: repository,
            leave: leave,
            onCancel: () {},
            onSaved: results.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Editar afastamento'), findsWidgets);

      await tester.tap(find.byKey(const Key('staff-leave-popup-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('staff-leave-form-save')));
      await tester.pumpAndSettle();
      expect(results.single!.popupEnabled, isFalse);
      expect(results.single!.version, 2);
    });

    testWidgets('remover afastamento chama o servidor com remove', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = FakeStaffAccessRepository();
      final leave = (await repository.fetchLeaves(const StaffLeaveQuery())).items.single;
      final results = <StaffLeave?>[];
      await tester.pumpWidget(
        _app(
          StaffLeaveFormPage(
            repository: repository,
            leave: leave,
            onCancel: () {},
            onSaved: results.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('staff-leave-form-remove')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('staff-leave-remove-confirm')));
      await tester.pumpAndSettle();
      expect(results, [null]);
      expect(repository.savedLeaves.single.remove, isTrue);
    });

    testWidgets('PT409 no afastamento mostra o conflito com Recarregar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = FakeStaffAccessRepository();
      final leave = (await repository.fetchLeaves(const StaffLeaveQuery())).items.single;
      repository.failNextSaveWithConflict = true;
      await tester.pumpWidget(
        _app(StaffLeaveFormPage(repository: repository, leave: leave, onCancel: () {})),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('staff-leave-form-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('staff-leave-form-conflict')), findsOneWidget);
      expect(find.byKey(const Key('staff-leave-form-reload')), findsOneWidget);
    });

    testWidgets('criar exige vínculo e período', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          StaffLeaveFormPage(
            repository: FakeStaffAccessRepository(),
            initialMembershipId: 'm-diego',
            onCancel: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Registrar afastamento'), findsWidgets);
      final save = tester.widget<FilledButton>(find.byKey(const Key('staff-leave-form-save')));
      expect(save.onPressed, isNull, reason: 'sem período o servidor nem é chamado');
    });
  });

  group('popup', () {
    test('texto fixo com horário e vigência; sem popup, mensagem genérica', () {
      expect(
        staffAccessPopupPreview(windows: const [], enabled: false),
        'Este contexto não está disponível agora.',
      );
      final text = staffAccessPopupPreview(
        windows: const [
          StaffAccessWindow(weekday: 1, start: '08:00', end: '18:00'),
          StaffAccessWindow(weekday: 5, start: '22:00', end: '02:00'),
        ],
        validFrom: DateTime(2026, 10, 1),
        validUntil: DateTime(2026, 10, 10),
        enabled: true,
      );
      expect(text, contains('Seg 08:00–18:00'));
      expect(text, contains('Sex 22:00–02:00'));
      expect(text, contains('de 01/10/2026 até 10/10/2026'));
    });
  });
}
