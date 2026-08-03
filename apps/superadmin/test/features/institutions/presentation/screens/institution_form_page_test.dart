import 'dart:async';
import 'dart:convert';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/data/institution_location_service.dart';
import 'package:coelo_superadmin/features/institutions/presentation/screens/institution_form_page.dart';
import 'package:coelo_superadmin/features/institutions/presentation/widgets/institution_form_navigation.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('uses the measured shared footer and keeps the launcher above it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
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
    await tester.pump();
    await tester.pump();

    final footer = find.byType(SuperadminFormActionFooter);
    final launcher = find.byKey(const Key('superadmin-chat-launcher-surface'));
    expect(footer, findsOneWidget);
    expect(launcher, findsOneWidget);
    expect(
      tester.getBottomLeft(launcher).dy,
      lessThanOrEqualTo(tester.getTopLeft(footer).dy - CoeloSpacing.space4),
    );
  });

  testWidgets('aligns the rounded notes icon at the bio top-left', (tester) async {
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
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('institution-form-continue')));
    await tester.pump(const Duration(seconds: 1));

    final field = find.byKey(const Key('institution-field-profileBio'));
    final decorator = find.descendant(of: field, matching: find.byType(InputDecorator));
    final icon = find.descendant(of: decorator, matching: find.byIcon(Icons.notes_rounded));
    expect(icon, findsOneWidget);
    expect(tester.getTopLeft(icon).dy, lessThan(tester.getCenter(field).dy));
    expect(find.byKey(const Key('institution-bio-emoji-picker')), findsOneWidget);
    expect(find.text('0/220'), findsOneWidget);
  });

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

  testWidgets('puts preview first, groups the complete palette, and offers emoji bio', (
    tester,
  ) async {
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

    expect(
      tester.getTopLeft(find.byKey(const Key('institution-brand-preview'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('institution-logo-picker'))).dy),
    );
    expect(find.byKey(const Key('institution-cover-picker')), findsOneWidget);
    expect(find.text('Cores de superfície'), findsOneWidget);
    expect(find.text('Cores da marca'), findsOneWidget);
    expect(find.text('Cores de texto'), findsOneWidget);
    expect(find.text('Cor principal da superfície'), findsOneWidget);
    expect(find.text('Cor secundária da superfície'), findsOneWidget);
    expect(find.byKey(const Key('institution-field-secondarySurfaceColor')), findsOneWidget);
    expect(find.text('Cor principal da marca'), findsOneWidget);
    expect(find.text('Cor secundária da marca'), findsOneWidget);
    expect(find.text('Cor terciária da marca'), findsOneWidget);
    final brandColorFields = [
      find.byKey(const Key('institution-field-accentColor')),
      find.byKey(const Key('institution-field-secondaryColor')),
      find.byKey(const Key('institution-field-tertiaryColor')),
    ];
    expect(brandColorFields.map((finder) => tester.getTopLeft(finder).dy).toSet(), hasLength(1));
    expect(find.text('Cor principal do texto'), findsOneWidget);
    expect(find.text('Cor secundária do texto'), findsOneWidget);
    expect(find.text('Cor terciária do texto'), findsOneWidget);
    final textColorFields = [
      find.byKey(const Key('institution-field-textColor')),
      find.byKey(const Key('institution-field-secondaryTextColor')),
      find.byKey(const Key('institution-field-tertiaryTextColor')),
    ];
    expect(textColorFields.map((finder) => tester.getTopLeft(finder).dy).toSet(), hasLength(1));

    await tester.tap(find.byKey(const Key('institution-form-continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('institution-field-profileBio')), findsOneWidget);
    expect(find.text('0/220'), findsOneWidget);
    expect(find.byKey(const Key('institution-bio-emoji-picker')), findsOneWidget);
    expect(find.byKey(const Key('institution-bio-emoji-palette')), findsNothing);
    await tester.enterText(find.byKey(const Key('institution-field-profileBio')), 'Olá mundo');
    final bio = tester.widget<TextFormField>(find.byKey(const Key('institution-field-profileBio')));
    bio.controller!.selection = const TextSelection.collapsed(offset: 4);
    await tester.tap(find.byKey(const Key('institution-bio-emoji-picker')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('institution-bio-emoji-palette')), findsOneWidget);
    await tester.tap(find.byKey(const Key('institution-bio-emoji-0')));
    await tester.pumpAndSettle();
    expect(bio.controller!.text, 'Olá 😊mundo');
    expect(find.text('10/220'), findsOneWidget);
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

  testWidgets('empty creation associates required errors with UF and municipality selects', (
    tester,
  ) async {
    await _useDesktopSurface(tester);
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          locationService: InstitutionLocationService(
            client: MockClient((_) async => http.Response('[]', 200)),
          ),
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );

    for (var step = 0; step < 3; step++) {
      await tester.tap(find.byKey(const Key('institution-form-continue')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('institution-step-location-error')));
    await tester.pumpAndSettle();

    const requiredError = 'Preencha este campo para concluir o cadastro.';
    final stateFinder = find.byKey(const Key('institution-state-select'));
    final municipalityFinder = find.byKey(const Key('institution-municipality-select'));
    expect(
      tester.widget<CoeloAdminSingleSelectField<String>>(stateFinder).errorText,
      requiredError,
    );
    expect(
      tester.widget<CoeloAdminSingleSelectField<String>>(municipalityFinder).errorText,
      requiredError,
    );
    expect(
      tester
          .widgetList<Semantics>(find.descendant(of: stateFinder, matching: find.byType(Semantics)))
          .map((widget) => widget.properties.hint),
      contains(requiredError),
    );
    expect(
      tester
          .widgetList<Semantics>(
            find.descendant(of: municipalityFinder, matching: find.byType(Semantics)),
          )
          .map((widget) => widget.properties.hint),
      contains(requiredError),
    );
  });

  testWidgets('editing CEP clears lookup error and reveals current validation', (tester) async {
    await _useDesktopSurface(tester);
    final service = InstitutionLocationService(
      client: MockClient((_) async => http.Response('{"erro": true}', 200)),
    );
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          locationService: service,
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );

    for (var step = 0; step < 3; step++) {
      await tester.tap(find.byKey(const Key('institution-form-continue')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('institution-step-location-error')));
    await tester.pumpAndSettle();

    final postalCodeField = find.byKey(const Key('institution-field-postalCode'));
    await tester.enterText(postalCodeField, '00000000');
    await tester.tap(find.byTooltip('Buscar CEP'));
    await tester.pumpAndSettle();
    expect(find.text('CEP não encontrado.'), findsOneWidget);

    await tester.enterText(postalCodeField, '123');
    await tester.pump();

    expect(find.text('CEP não encontrado.'), findsNothing);
    expect(find.text('Informe um CEP com exatamente 8 dígitos.'), findsOneWidget);
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

  testWidgets('loads IBGE municipalities on entry when edit mode already has a UF', (tester) async {
    await _useDesktopSurface(tester);
    var ibgeRequests = 0;
    final service = InstitutionLocationService(
      client: MockClient((request) async {
        expect(request.url.path, endsWith('/estados/SP/municipios'));
        ibgeRequests += 1;
        return http.Response(
          jsonEncode([
            {'nome': 'Campinas'},
            {'nome': 'São Paulo'},
          ]),
          200,
        );
      }),
    );
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

    expect(ibgeRequests, 1);
    expect(_municipalitySelect(tester).options, contains('Campinas'));
  });

  testWidgets('IBGE error keeps the municipality coherent and retries the same UF', (tester) async {
    await _useDesktopSurface(tester);
    var ibgeRequests = 0;
    final service = InstitutionLocationService(
      client: MockClient((request) async {
        ibgeRequests += 1;
        if (ibgeRequests == 1) {
          throw http.ClientException('offline', request.url);
        }
        return http.Response(
          jsonEncode([
            {'nome': 'Campinas'},
            {'nome': 'São Paulo'},
          ]),
          200,
        );
      }),
    );
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

    final failedSelect = _municipalitySelect(tester);
    expect(failedSelect.value, isNotEmpty);
    expect(failedSelect.errorText, isNotNull);
    expect(failedSelect.isLoading, isFalse);
    expect(find.byKey(const Key('institution-municipalities-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('institution-municipalities-retry')));
    await tester.pumpAndSettle();

    expect(ibgeRequests, 2);
    expect(_municipalitySelect(tester).options, contains('Campinas'));
    expect(_municipalitySelect(tester).errorText, isNull);
  });

  testWidgets('late IBGE response for a previous UF cannot replace the current list', (
    tester,
  ) async {
    await _useDesktopSurface(tester);
    final spResponse = Completer<http.Response>();
    final service = InstitutionLocationService(
      client: MockClient((request) async {
        if (request.url.host == 'viacep.com.br') {
          return http.Response(
            jsonEncode({
              'logradouro': 'Rua do Catete',
              'bairro': 'Catete',
              'localidade': 'Rio de Janeiro',
              'uf': 'RJ',
            }),
            200,
          );
        }
        if (request.url.path.contains('/estados/SP/')) {
          return spResponse.future;
        }
        return http.Response(
          jsonEncode([
            {'nome': 'Rio de Janeiro'},
          ]),
          200,
        );
      }),
    );
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
    await tester.pump();
    await tester.pump();
    expect(_municipalitySelect(tester).isLoading, isTrue);

    await tester.enterText(find.byKey(const Key('institution-field-postalCode')), '22220000');
    await tester.tap(find.byTooltip('Buscar CEP'));
    await tester.pumpAndSettle();
    expect(_municipalitySelect(tester).options, contains('Rio de Janeiro'));

    spResponse.complete(
      http.Response(
        jsonEncode([
          {'nome': 'Campinas'},
        ]),
        200,
      ),
    );
    await tester.pumpAndSettle();

    expect(_municipalitySelect(tester).options, contains('Rio de Janeiro'));
    expect(_municipalitySelect(tester).options, isNot(contains('Campinas')));
  });

  testWidgets('starting a new UF request clears incompatible municipality options', (tester) async {
    await _useDesktopSurface(tester);
    final rjResponse = Completer<http.Response>();
    final service = InstitutionLocationService(
      client: MockClient((request) async {
        if (request.url.host == 'viacep.com.br') {
          return http.Response(
            jsonEncode({
              'logradouro': 'Rua do Catete',
              'bairro': 'Catete',
              'localidade': 'Rio de Janeiro',
              'uf': 'RJ',
            }),
            200,
          );
        }
        if (request.url.path.contains('/estados/RJ/')) {
          return rjResponse.future;
        }
        return http.Response(
          jsonEncode([
            {'nome': 'Campinas'},
          ]),
          200,
        );
      }),
    );
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
    expect(_municipalitySelect(tester).options, contains('Campinas'));

    await tester.enterText(find.byKey(const Key('institution-field-postalCode')), '22220000');
    await tester.tap(find.byTooltip('Buscar CEP'));
    await tester.pump();

    final loadingSelect = _municipalitySelect(tester);
    expect(loadingSelect.isLoading, isTrue);
    expect(loadingSelect.enabled, isFalse);
    expect(loadingSelect.options, isNot(contains('Campinas')));

    rjResponse.complete(
      http.Response(
        jsonEncode([
          {'nome': 'Rio de Janeiro'},
        ]),
        200,
      ),
    );
    await tester.pumpAndSettle();
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

  testWidgets('actual ViaCEP network error preserves the manual address', (tester) async {
    await _useDesktopSurface(tester);
    final service = InstitutionLocationService(
      client: MockClient((request) async {
        if (request.url.host == 'viacep.com.br') {
          throw http.ClientException('offline', request.url);
        }
        return http.Response('[]', 200);
      }),
    );
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
    await tester.enterText(find.byKey(const Key('institution-field-postalCode')), '01310100');
    await tester.tap(find.byTooltip('Buscar CEP'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível consultar o CEP. Tente novamente.'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('institution-field-street')))
          .controller!
          .text,
      'Rua digitada manualmente',
    );
  });

  testWidgets('CEP field keeps digits only and blocks save when it is incomplete', (tester) async {
    await _useDesktopSurface(tester);
    final repository = FakeInstitutionDirectoryRepository();
    final service = InstitutionLocationService(
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    await tester.pumpWidget(
      _app(
        InstitutionFormPage(
          repository: repository,
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

    final postalCodeField = find.byKey(const Key('institution-field-postalCode'));
    await tester.enterText(postalCodeField, 'ABC 01310-100 XYZ');
    expect(tester.widget<TextFormField>(postalCodeField).controller!.text, '01310100');

    await tester.enterText(postalCodeField, '123');
    await tester.tap(find.byKey(const Key('institution-form-save-current')));
    await tester.pumpAndSettle();

    expect(find.text('Informe um CEP com exatamente 8 dígitos.'), findsOneWidget);
    expect(repository.findById('demo-institution-aurora')!.postalCode, isNot('123'));
  });

  testWidgets('legacy edit cannot save until it has an administrator', (tester) async {
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

    expect(find.text('Administradores'), findsWidgets);
    expect(
      repository.findById('demo-institution-aurora')!.brandDisplayName,
      isNot('Aurora atualizado'),
    );
    await tester.tap(find.byKey(const Key('institution-confirm-representative-administrators')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-form-save-current')));
    await tester.pumpAndSettle();

    expect(repository.findById('demo-institution-aurora')!.brandDisplayName, 'Aurora atualizado');
    expect(repository.findById('demo-institution-aurora')!.administrators, hasLength(1));
    expect(savedCallbackCalls, 0);
    await tester.tap(find.byKey(const Key('institution-form-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('institution-confirm-exit-dialog')), findsNothing);
  });

  testWidgets('edit footer keeps save as the only primary action at both widths', (tester) async {
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

    final save = find.byKey(const Key('institution-form-save-current'));
    final continueAction = find.byKey(const Key('institution-form-continue'));
    expect(tester.widget<Widget>(save), isA<FilledButton>());
    expect(tester.widget<Widget>(continueAction), isA<OutlinedButton>());
    expect(tester.getCenter(save).dx, greaterThan(tester.getCenter(continueAction).dx));

    await tester.binding.setSurfaceSize(const Size(375, 900));
    await tester.pumpAndSettle();

    expect(tester.widget<Widget>(save), isA<FilledButton>());
    expect(tester.widget<Widget>(continueAction), isA<OutlinedButton>());
    expect(tester.getTopLeft(save).dy, lessThan(tester.getTopLeft(continueAction).dy));
  });

  testWidgets('creation footer keeps Continue as its primary action', (tester) async {
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

    final continueAction = find.byKey(const Key('institution-form-continue'));
    expect(tester.widget<Widget>(continueAction), isA<FilledButton>());
    expect(find.byKey(const Key('institution-form-save-current')), findsNothing);
  });

  testWidgets('trial dates are suggested and calendar uses pt-BR Coelo surface', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    tester.view
      ..physicalSize = const Size(1440, 1100)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
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
    for (var step = 0; step < 5; step++) {
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
    await tester.tap(find.byKey(const Key('institution-subscription-status-select')));
    await tester.pumpAndSettle();
    final trialOption = find.widgetWithText(MenuItemButton, 'Período de teste');
    expect(MenuController.maybeOf(tester.element(trialOption))?.isOpen, isTrue);
    final subscriptionTrigger = find.descendant(
      of: find.byKey(const Key('institution-subscription-status-select')),
      matching: find.byType(InputDecorator),
    );
    expect(
      tester.getTopLeft(trialOption).dy,
      greaterThan(tester.getBottomLeft(subscriptionTrigger).dy),
    );
    await tester.tap(trialOption);
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

    final dialog = tester.widget<AlertDialog>(
      find.byKey(const Key('advanced-color-picker-dialog')),
    );
    expect(dialog.backgroundColor, CoeloTheme.light.colorScheme.surface);
    expect(dialog.surfaceTintColor, Colors.transparent);
    expect(find.byKey(const Key('advanced-color-picker-area')), findsOneWidget);
    expect(find.byKey(const Key('advanced-color-picker-hex')), findsOneWidget);
    expect(find.text('H'), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
    expect(find.text('V'), findsOneWidget);
    expect(find.text('R'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(
      tester.getSize(find.widgetWithText(OutlinedButton, 'Cancelar')).width,
      tester.getSize(find.widgetWithText(FilledButton, 'Usar cor')).width,
    );
  });

  testWidgets('location offers CEP lookup and representatives use a neutral surface', (
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

    await tester.tap(find.text('Representantes legais'));
    await tester.pumpAndSettle();
    final representativeCard = tester.widget<Card>(
      find.descendant(
        of: find.byKey(const Key('institution-legal-representative-representative-legacy')),
        matching: find.byType(Card),
      ),
    );
    expect(representativeCard.color, CoeloTheme.light.colorScheme.surface);
  });

  testWidgets('representatives are explicitly confirmed as admin master before inviting', (
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

    await tester.tap(find.text('Representantes legais'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('institution-add-legal-representative')), findsOneWidget);
    expect(find.text('Rafael Coelho'), findsOneWidget);

    await tester.tap(find.text('Administradores'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('institution-confirm-representative-administrators')),
      findsOneWidget,
    );
    expect(find.text('Rafael Coelho'), findsOneWidget);
    expect(find.text('Admin Master'), findsNothing);

    await tester.tap(find.byKey(const Key('institution-confirm-representative-administrators')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Admin Master'), findsOneWidget);
    expect(find.textContaining('Não enviado'), findsOneWidget);
    expect(find.text('@rafael-coelho'), findsOneWidget);
    expect(_byKeyPrefix('institution-sync-representative-to-admin-'), findsOneWidget);
    expect(_byKeyPrefix('institution-sync-admin-to-representative-'), findsOneWidget);
    expect(find.text('Copiar dados do representante'), findsOneWidget);
    expect(find.text('Copiar dados para o representante'), findsOneWidget);
    expect(
      tester.getSize(_byKeyPrefix('institution-invitation-icon-box-')),
      const Size.square(CoeloSize.iconMd),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Enviar convite'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enviado'), findsWidgets);
    expect(find.textContaining('Enviado em '), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Marcar como aceito'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Marcar como expirado'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Marcar como aceito'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aceito'), findsWidgets);
    expect(find.textContaining('Aceito em '), findsOneWidget);

    await tester.tap(find.text('Revisão'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Rafael Coelho — representante legal'), findsOneWidget);
    expect(find.textContaining('Rafael Coelho — Admin Master · Aceito'), findsOneWidget);
  });

  testWidgets('invite without email opens the editor focused and sends after valid save', (
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

    await tester.tap(find.text('Administradores'));
    await tester.pumpAndSettle();
    final addAdministrator = find.byKey(const Key('institution-add-administrator'));
    tester.widget<OutlinedButton>(addAdministrator).onPressed!();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('institution-person-avatar-picker')), findsOneWidget);
    expect(find.text('Adicionar foto'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('institution-person-first-name')), 'Ana');
    await tester.enterText(find.byKey(const Key('institution-person-last-name')), 'Souza');
    await tester.enterText(find.byKey(const Key('institution-person-display-name')), 'Ana Souza');
    await tester.tap(find.byKey(const Key('institution-person-dialog-save')));
    await tester.pumpAndSettle();

    expect(find.text('@ana-souza'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('institution-administrator-avatar-'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Enviar convite'));
    await tester.pumpAndSettle();

    final emailField = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('institution-person-email')),
        matching: find.byType(EditableText),
      ),
    );
    expect(emailField.focusNode.hasFocus, isTrue);
    await tester.tap(find.byKey(const Key('institution-person-dialog-save')));
    await tester.pump();
    expect(find.text('Informe um e-mail para enviar o convite.'), findsOneWidget);
    expect(find.byKey(const Key('institution-person-email')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('institution-person-email')), 'ana@example.com');
    await tester.tap(find.byKey(const Key('institution-person-dialog-save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Enviado'), findsWidgets);
    expect(find.textContaining('Enviado em '), findsOneWidget);
  });

  testWidgets('blocks removing the last person in either required role', (tester) async {
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

    await tester.tap(find.text('Representantes legais'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remover Rafael Coelho'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Adicione outro representante legal'), findsOneWidget);
    expect(find.text('Rafael Coelho'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.text('Representantes legais').last)).clearSnackBars();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Administradores'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-confirm-representative-administrators')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remover Rafael Coelho'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Adicione outro administrador'), findsOneWidget);
    expect(find.text('@rafael-coelho'), findsOneWidget);
  });

  testWidgets('person dialog reveals required errors after submit attempt', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
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

    for (var step = 0; step < 3; step++) {
      await tester.tap(find.byKey(const Key('institution-form-continue')));
      await tester.pumpAndSettle();
    }
    final addRepresentative = find.byKey(const Key('institution-add-legal-representative'));
    await tester.ensureVisible(addRepresentative);
    await tester.pump();
    await tester.tap(addRepresentative);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-person-dialog-save')));
    await tester.pumpAndSettle();

    expect(find.text('Preencha este campo.'), findsNWidgets(3));
    expect(find.text('E-mail (opcional)'), findsOneWidget);
    expect(find.text('Telefone (opcional)'), findsOneWidget);
    expect(find.text('CPF (opcional)'), findsOneWidget);
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Salvar pessoa')).width,
      tester.getSize(find.widgetWithText(OutlinedButton, 'Cancelar')).width,
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
    expect(find.text('Etapa 1 de 7'), findsOneWidget);
  });

  testWidgets('renders approved breakpoints without overflow', (tester) async {
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        _app(
          InstitutionFormPage(
            key: ValueKey(width),
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
        expect(find.text('Etapa 1 de 7'), findsOneWidget);
      }

      for (var step = 0; step < 2; step++) {
        await tester.tap(find.byKey(const Key('institution-form-continue')));
        await tester.pumpAndSettle();
      }
      expect(
        find.byKey(const Key('institution-field-postalCode')),
        findsOneWidget,
        reason: 'location at ${width.toInt()} px',
      );
      expect(tester.takeException(), isNull, reason: 'location overflow at ${width.toInt()} px');

      for (var step = 0; step < 3; step++) {
        await tester.tap(find.byKey(const Key('institution-form-continue')));
        await tester.pumpAndSettle();
      }
      expect(
        find.byKey(const Key('institution-plan-essential')),
        findsOneWidget,
        reason: 'plan at ${width.toInt()} px',
      );
      expect(tester.takeException(), isNull, reason: 'plan overflow at ${width.toInt()} px');
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
    expect(find.text('Etapa 1 de 7'), findsOneWidget);
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

Future<void> _useDesktopSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

CoeloAdminSingleSelectField<String> _municipalitySelect(WidgetTester tester) =>
    tester.widget<CoeloAdminSingleSelectField<String>>(
      find.byKey(const Key('institution-municipality-select')),
    );

String _dateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

Finder _byKeyPrefix(String prefix) => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith(prefix),
);
