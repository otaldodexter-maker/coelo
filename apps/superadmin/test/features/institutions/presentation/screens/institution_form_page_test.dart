import 'dart:async';
import 'dart:convert';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/data/institution_location_service.dart';
import 'package:coelo_superadmin/features/institutions/presentation/screens/institution_form_page.dart';
import 'package:coelo_superadmin/features/institutions/presentation/widgets/institution_form_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('uses the same empty form for institution creation', (tester) async {
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );

    expect(find.text('Criar instituição'), findsOneWidget);
    expect(find.text('Identidade visual'), findsWidgets);
    expect(find.text('Imagem quadrada em PNG, JPG ou WebP, com até 2 MB.'), findsOneWidget);
    expect(find.byKey(const Key('institution-logo-picker')), findsOneWidget);
    final handle = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const Key('institution-field-slug')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(handle.decoration.labelText, '@ da instituição');
    expect(handle.decoration.prefixIcon, isNotNull);
    final field = tester.widget<TextFormField>(
      find.byKey(const Key('institution-field-brandDisplayName')),
    );
    expect(field.controller!.text, isEmpty);
    final input = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const Key('institution-field-brandDisplayName')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(input.decoration.floatingLabelBehavior, FloatingLabelBehavior.always);
    expect(input.decoration.prefixIcon, isNotNull);
  });

  testWidgets('loads an existing institution into edit mode', (tester) async {
    final repository = FakeInstitutionDirectoryRepository();
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: repository,
          institutionId: 'demo-institution-aurora',
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );

    expect(find.text('Editar instituição'), findsOneWidget);
    final field = tester.widget<TextFormField>(
      find.byKey(const Key('institution-field-brandDisplayName')),
    );
    expect(field.controller!.text, 'Instituto Aurora');
  });

  testWidgets('offers cover, complete palette, bio, and three custom links', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );

    expect(find.byKey(const Key('institution-cover-picker')), findsOneWidget);
    expect(find.text('Cor principal da marca'), findsOneWidget);
    expect(find.text('Cor secundária da marca'), findsOneWidget);
    expect(find.text('Cor terciária da marca'), findsOneWidget);
    expect(find.text('Cor principal do texto'), findsOneWidget);
    expect(find.text('Cor secundária do texto'), findsOneWidget);
    expect(find.text('Cor terciária do texto'), findsOneWidget);
    expect(find.text('Cor de superfície'), findsOneWidget);

    await tester.tap(find.byKey(const Key('institution-form-continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('institution-field-profileBio')), findsOneWidget);
    expect(find.text('0/220'), findsOneWidget);
    for (var index = 1; index <= 3; index++) {
      expect(find.byKey(Key('institution-field-link${index}Label')), findsOneWidget);
      expect(find.byKey(Key('institution-field-link${index}Url')), findsOneWidget);
    }
  });

  testWidgets('separates address from basic contact with the approved fields', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          institutionId: 'demo-institution-aurora',
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Localização e contato'));
    await tester.pumpAndSettle();

    expect(find.text('Endereço'), findsOneWidget);
    expect(find.text('Contato básico'), findsOneWidget);
    expect(find.text('UF'), findsOneWidget);
    expect(find.text('Município'), findsOneWidget);
    expect(find.byKey(const Key('institution-field-whatsappNumber')), findsOneWidget);
    expect(find.byKey(const Key('institution-field-websiteUrl')), findsOneWidget);
  });

  testWidgets('ViaCEP shows loading and fills address without locking manual edits', (
    tester,
  ) async {
    final viaCep = Completer<http.Response>();
    final service = InstitutionLocationService(
      client: MockClient((request) {
        if (request.url.host == 'viacep.com.br') {
          return viaCep.future;
        }
        return Future.value(
          http.Response(
            jsonEncode([
              {'nome': 'São Paulo'},
            ]),
            200,
          ),
        );
      }),
    );
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          institutionId: 'demo-institution-aurora',
          locationService: service,
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.tap(find.text('Localização e contato'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('institution-field-postalCode')), '01310100');
    await tester.tap(find.byTooltip('Buscar CEP'));
    await tester.pump();

    expect(find.byKey(const Key('institution-postal-code-loading')), findsOneWidget);

    viaCep.complete(
      http.Response(
        jsonEncode({
          'logradouro': 'Avenida Paulista',
          'bairro': 'Bela Vista',
          'localidade': 'São Paulo',
          'uf': 'SP',
        }),
        200,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('institution-field-street')))
          .controller!
          .text,
      'Avenida Paulista',
    );
    expect(find.text('São Paulo'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('institution-field-street')),
      'Avenida Paulista, bloco B',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('institution-field-street')))
          .controller!
          .text,
      'Avenida Paulista, bloco B',
    );
  });

  testWidgets('unknown CEP and network failure preserve manually entered address', (tester) async {
    final service = InstitutionLocationService(
      client: MockClient((_) async => http.Response('{"erro": true}', 200)),
    );
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          institutionId: 'demo-institution-aurora',
          locationService: service,
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.tap(find.text('Localização e contato'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('institution-field-street')),
      'Rua digitada manualmente',
    );
    await tester.enterText(find.byKey(const Key('institution-field-postalCode')), '00000000');
    await tester.tap(find.byTooltip('Buscar CEP'));
    await tester.pumpAndSettle();

    expect(find.text('CEP não encontrado.'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('institution-field-street')))
          .controller!
          .text,
      'Rua digitada manualmente',
    );
  });

  testWidgets('edit mode saves locally on the current step and remains there', (tester) async {
    final repository = FakeInstitutionDirectoryRepository();
    var savedCallbackCalls = 0;
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: repository,
          institutionId: 'demo-institution-aurora',
          logout: _logout,
          onCancel: () {},
          onSaved: (_) => savedCallbackCalls++,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('institution-field-brandDisplayName')),
      'Aurora atualizado',
    );
    await tester.tap(find.byKey(const Key('institution-form-save-current')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('institution-field-brandDisplayName')), findsOneWidget);
    expect(repository.findById('demo-institution-aurora')!.brandDisplayName, 'Aurora atualizado');
    expect(savedCallbackCalls, 0);
    await tester.tap(find.byKey(const Key('institution-form-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('institution-confirm-exit-dialog')), findsNothing);
  });

  testWidgets('trial dates are suggested and calendar uses pt-BR Coelo surface', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    for (var step = 0; step < 4; step++) {
      await tester.tap(find.byKey(const Key('institution-form-continue')));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      find.text('Rascunho'),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('institution-form-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Rascunho'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Período de teste'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(const Duration(days: 30));
    expect(find.text(_dateLabel(today)), findsOneWidget);
    expect(find.text(_dateLabel(end)), findsOneWidget);

    await tester.tap(find.byKey(const Key('institution-subscription-start-date')));
    await tester.pumpAndSettle();

    final calendarContext = tester.element(find.byType(CalendarDatePicker));
    final calendarTheme = Theme.of(calendarContext);
    expect(Localizations.localeOf(calendarContext), const Locale('pt', 'BR'));
    expect(calendarTheme.datePickerTheme.backgroundColor, calendarTheme.colorScheme.surface);
    expect(calendarTheme.datePickerTheme.surfaceTintColor, Colors.transparent);
  });

  testWidgets('color picker uses the neutral advanced color surface', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );

    final colorPicker = find.byKey(const Key('institution-color-picker-accentColor'));
    await tester.ensureVisible(colorPicker);
    await tester.tap(colorPicker);
    await tester.pumpAndSettle();

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.backgroundColor, CoeloTheme.light.colorScheme.surface);
    expect(dialog.surfaceTintColor, Colors.transparent);
    expect(find.byKey(const Key('institution-color-area')), findsOneWidget);
    expect(find.byKey(const Key('institution-color-hex')), findsOneWidget);
    expect(find.text('H'), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
    expect(find.text('V'), findsOneWidget);
    expect(find.text('R'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('location offers CEP lookup and owner notice uses the orange information surface', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          institutionId: 'demo-institution-aurora',
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Localização e contato'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Buscar CEP'), findsOneWidget);

    await tester.tap(find.text('Responsável inicial'));
    await tester.pumpAndSettle();
    final notice = tester.widget<DecoratedBox>(
      find.byKey(const Key('institution-owner-invitation-notice')),
    );
    expect(
      (notice.decoration as BoxDecoration).color,
      CoeloTheme.light.colorScheme.primaryContainer,
    );
  });

  testWidgets('plan omits justification and exit actions split the dialog width equally', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          institutionId: 'demo-institution-aurora',
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('institution-field-brandDisplayName')),
      'Instituição alterada',
    );
    await tester.tap(find.text('Plano'));
    await tester.pumpAndSettle();
    expect(find.text('Justificativa'), findsNothing);

    await tester.tap(find.byKey(const Key('institution-form-cancel')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.widgetWithText(OutlinedButton, 'Continuar editando')).width,
      tester.getSize(find.widgetWithText(FilledButton, 'Sair sem salvar')).width,
    );
  });

  testWidgets('invalid branding does not block continuing to profile', (tester) async {
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('institution-form-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Perfil da instituição'), findsWidgets);
    expect(find.byKey(const Key('institution-step-branding-error')), findsOneWidget);
  });

  testWidgets('status uses the administrative continuous single-select menu', (tester) async {
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('institution-form-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Rascunho'),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('institution-form-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Rascunho'));
    await tester.pumpAndSettle();
    expect(find.text('Em implantação'), findsOneWidget);
    expect(find.text('Ativa'), findsOneWidget);
    final selected = tester.widget<MenuItemButton>(find.widgetWithText(MenuItemButton, 'Rascunho'));
    expect(
      selected.style!.backgroundColor!.resolve({}),
      CoeloTheme.light.colorScheme.primaryContainer,
    );
  });

  testWidgets('dirty exit dialog follows the neutral popup and red close contract', (tester) async {
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('institution-field-brandDisplayName')),
      'Instituição em edição',
    );
    await tester.tap(find.byKey(const Key('institution-form-cancel')));
    await tester.pumpAndSettle();

    final dialog = tester.widget<Dialog>(find.byKey(const Key('institution-confirm-exit-dialog')));
    expect(dialog.backgroundColor, CoeloTheme.light.colorScheme.surface);
    final close = tester.widget<IconButton>(find.byKey(const Key('institution-dialog-close')));
    expect(close.style!.foregroundColor!.resolve({}), CoeloTheme.light.colorScheme.error);
    expect(
      close.style!.backgroundColor!.resolve({WidgetState.hovered}),
      CoeloTheme.light.colorScheme.errorContainer,
    );
    final barrier = tester
        .widgetList<ModalBarrier>(find.byType(ModalBarrier))
        .firstWhere((candidate) => candidate.color != null);
    expect(barrier.color, CoeloTheme.light.extension<CoeloOverlayColors>()!.scrim);
  });

  testWidgets('review edit action returns directly to the selected section', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          institutionId: 'demo-institution-aurora',
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('Selecionar etapa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisão').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('institution-review-edit-branding')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('institution-form-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const Key('institution-review-edit-branding')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('institution-field-brandDisplayName')), findsOneWidget);
    expect(find.text('Etapa 1 de 6'), findsOneWidget);
  });

  testWidgets('renders approved breakpoints without overflow', (tester) async {
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        _app(
          InstitutionFormPage(
            repository: FakeInstitutionDirectoryRepository(),
            logout: _logout,
            onCancel: () {},
            onSaved: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'overflow at ${width.toInt()} px');
      if (width == 375) {
        expect(find.text('Etapa 1 de 6'), findsOneWidget);
      }
    }
    addTearDown(tester.view.reset);
  });

  testWidgets('uses lateral step navigation at the 1440 desktop width', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(MediaQuery.sizeOf(tester.element(find.byType(InstitutionFormPage))).width, 1440);
    expect(tester.getSize(find.byType(InstitutionFormNavigation)).width, 248);
  });

  testWidgets('supports 200 percent text on the mobile layout', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Etapa 1 de 6'), findsOneWidget);
  });

  testWidgets('uses the neutral dialog surface in dark mode and Escape keeps editing', (
    tester,
  ) async {
    var canceled = false;
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          logout: _logout,
          onCancel: () => canceled = true,
          onSaved: (_) {},
        ),
        brightness: Brightness.dark,
      ),
    );
    await tester.enterText(
      find.byKey(const Key('institution-field-brandDisplayName')),
      'Instituição em edição',
    );
    await tester.tap(find.byKey(const Key('institution-form-cancel')));
    await tester.pumpAndSettle();

    final dialog = tester.widget<Dialog>(find.byKey(const Key('institution-confirm-exit-dialog')));
    expect(dialog.backgroundColor, CoeloTheme.dark.colorScheme.surface);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('institution-confirm-exit-dialog')), findsNothing);
    expect(canceled, isFalse);
  });
}

Widget _app(
  Widget child, {
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: child,
  );
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

String _dateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
