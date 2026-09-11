import 'package:coelo_domain/profile_about.dart';
import 'package:coelo_superadmin/features/profile_about/data/supabase_profile_about_repository.dart';
import 'package:coelo_superadmin/features/profile_about/domain/profile_about_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _institution = ProfileAboutSubjectRef(
  type: ProfileAboutSubjectType.institution,
  institutionId: '11111111-1111-4111-8111-111111111111',
);

void main() {
  group('tokens', () {
    test('usa snake_case compativel com os defaults da RPC', () {
      expect(
        profileAboutVisibilityToken(ProfileAboutVisibility.profileAccess),
        'profile_access',
      );
      expect(profileAboutOriginToken(ProfileAboutOrigin.manual), 'manual');
      expect(
        profileAboutOriginToken(ProfileAboutOrigin.suggestedOfficial),
        'suggested_official',
      );
      expect(profileAboutSectionStateToken(ProfileAboutSectionState.draft), 'draft');
      expect(profileAboutSectionTypeToken(ProfileAboutSectionType.iconList), 'icon_list');
      expect(profileAboutFieldKeyToken(ProfileAboutFieldKey.displayAddress), 'display_address');
      expect(profileAboutSubjectTypeToken(ProfileAboutSubjectType.activity), 'activity');
    });

    test('token de ida e volta cobre todos os valores do dominio', () {
      for (final key in ProfileAboutFieldKey.values) {
        expect(profileAboutFieldKeyFromToken(profileAboutFieldKeyToken(key)), key);
      }
      for (final type in ProfileAboutSectionType.values) {
        expect(profileAboutSectionTypeFromToken(profileAboutSectionTypeToken(type)), type);
      }
      for (final visibility in ProfileAboutVisibility.values) {
        expect(
          profileAboutVisibilityFromToken(profileAboutVisibilityToken(visibility)),
          visibility,
        );
      }
    });

    test('token desconhecido nao explode e cai no default seguro', () {
      expect(profileAboutFieldKeyFromToken('nao_existe'), isNull);
      expect(profileAboutSectionTypeFromToken(null), isNull);
      expect(
        profileAboutVisibilityFromToken('nao_existe'),
        ProfileAboutVisibility.profileAccess,
      );
      expect(profileAboutOriginFromToken(7), ProfileAboutOrigin.manual);
      expect(profileAboutSectionStateFromToken(null), ProfileAboutSectionState.draft);
    });

    test('mapeia a coluna de sujeito de cada tipo', () {
      expect(
        profileAboutSubjectColumn(ProfileAboutSubjectType.institution),
        'institution_subject_id',
      );
      expect(profileAboutSubjectColumn(ProfileAboutSubjectType.unit), 'unit_subject_id');
      expect(profileAboutSubjectColumn(ProfileAboutSubjectType.group), 'group_subject_id');
      expect(profileAboutSubjectColumn(ProfileAboutSubjectType.activity), 'activity_subject_id');
      expect(profileAboutSubjectColumn(ProfileAboutSubjectType.person), 'person_subject_id');
    });
  });

  group('payload de escrita', () {
    test('serializa campos e secoes no formato esperado pela RPC', () {
      final page = ProfileAboutPage(
        subject: _institution,
        version: 4,
        fields: const [
          ProfileAboutField(
            key: ProfileAboutFieldKey.displayName,
            value: 'Escola Coelo',
          ),
          ProfileAboutField.location(
            address: 'Rua A, 100',
            latitude: -23.5,
            longitude: -46.6,
            visibility: ProfileAboutVisibility.linked,
          ),
        ],
        sections: const [
          ProfileAboutSection(
            id: '22222222-2222-4222-8222-222222222222',
            type: ProfileAboutSectionType.iconList,
            title: 'Horarios',
            body: '',
            position: 0,
            items: ['Manha', 'Tarde'],
            state: ProfileAboutSectionState.published,
          ),
        ],
      );

      final payload = buildProfileAboutSavePayload(page);
      final fields = payload['fields']! as List<Object?>;
      final sections = payload['sections']! as List<Object?>;

      expect(payload.containsKey('state'), isFalse);
      expect(fields.first, {
        'key': 'display_name',
        'value': 'Escola Coelo',
        'visibility': 'profile_access',
        'origin': 'manual',
      });
      expect(fields.last, {
        'key': 'precise_location',
        'value': 'Rua A, 100',
        'visibility': 'linked',
        'origin': 'manual',
        'latitude': -23.5,
        'longitude': -46.6,
      });
      expect(sections.single, {
        'id': '22222222-2222-4222-8222-222222222222',
        'type': 'icon_list',
        'title': 'Horarios',
        'body': '',
        'items': ['Manha', 'Tarde'],
        'position': 0,
        'visibility': 'profile_access',
        'state': 'published',
        'origin': 'manual',
      });
    });

    test('atualizacoes oficiais viram array de key/value', () {
      expect(
        buildProfileAboutOfficialUpdates(const {
          ProfileAboutFieldKey.email: 'contato@coelo.me',
          ProfileAboutFieldKey.mobile: '11999999999',
        }),
        [
          {'key': 'email', 'value': 'contato@coelo.me'},
          {'key': 'mobile', 'value': '11999999999'},
        ],
      );
      expect(buildProfileAboutOfficialUpdates(const {}), isEmpty);
    });
  });

  group('retorno da RPC', () {
    test('le page_id, version e destinos oficiais', () {
      final result = parseProfileAboutSaveResult(<String, Object?>{
        'page_id': '33333333-3333-4333-8333-333333333333',
        'version': 5,
        'about': 'saved',
        'official': [
          {'key': 'email', 'status': 'updated'},
          {'key': 'website', 'status': 'failed', 'message': 'official field has no mapping'},
          {'key': 'chave_desconhecida', 'status': 'updated'},
        ],
      });

      expect(result.pageId, '33333333-3333-4333-8333-333333333333');
      expect(result.version, 5);
      expect(result.official.length, 2);
      expect(result.official.first.key, ProfileAboutFieldKey.email);
      expect(result.official.first.status, 'updated');
      expect(result.official.first.message, isNull);
      expect(result.official.last.key, ProfileAboutFieldKey.website);
      expect(result.official.last.status, 'failed');
      expect(result.official.last.message, 'official field has no mapping');
    });

    test('retorno invalido vira FormatException', () {
      expect(() => parseProfileAboutSaveResult(null), throwsFormatException);
      expect(
        () => parseProfileAboutSaveResult(<String, Object?>{'page_id': '', 'version': 1}),
        throwsFormatException,
      );
      expect(
        () => parseProfileAboutSaveResult(<String, Object?>{'page_id': 'x', 'version': 'nao'}),
        throwsFormatException,
      );
    });

    test('official ausente resulta em lista vazia', () {
      final result = parseProfileAboutSaveResult(<String, Object?>{
        'page_id': '33333333-3333-4333-8333-333333333333',
        'version': 1,
      });
      expect(result.official, isEmpty);
    });
  });

  group('leitura das tabelas', () {
    test('monta a pagina, ordena secoes e ignora linhas desconhecidas', () {
      final page = parseProfileAboutPage(
        subject: _institution,
        pageRow: const {'id': 'page', 'version': 9, 'state': 'published'},
        fieldRows: const [
          {
            'field_key': 'display_name',
            'value': 'Escola Coelo',
            'visibility': 'profile_access',
            'origin': 'copied_official',
            'source_label': 'Cadastro oficial',
          },
          {
            'field_key': 'precise_location',
            'value': 'Rua A, 100',
            'latitude': '-23.5',
            'longitude': -46.6,
            'visibility': 'team',
            'origin': 'manual',
          },
          {'field_key': 'campo_novo_no_banco', 'value': 'x'},
        ],
        sectionRows: const [
          {
            'id': 'b',
            'section_type': 'text',
            'title': 'Segunda',
            'body': 'corpo',
            'items': <Object?>[],
            'position': 2,
            'visibility': 'linked',
            'state': 'published',
            'origin': 'manual',
            'revision': 3,
          },
          {
            'id': 'a',
            'section_type': 'icon_list',
            'title': null,
            'body': null,
            'items': ['um', 2],
            'position': 1,
            'visibility': 'profile_access',
            'state': 'draft',
            'origin': 'manual',
          },
          {'id': 'c', 'section_type': 'tipo_novo', 'position': 3},
        ],
      );

      expect(page.version, 9);
      expect(page.fields.length, 2);
      expect(page.fields.first.origin, ProfileAboutOrigin.copiedOfficial);
      expect(page.fields.first.sourceLabel, 'Cadastro oficial');
      expect(page.fields.last.latitude, -23.5);
      expect(page.fields.last.longitude, -46.6);
      expect(page.fields.last.visibility, ProfileAboutVisibility.team);
      expect(page.sections.map((section) => section.id), ['a', 'b']);
      expect(page.sections.first.title, '');
      expect(page.sections.first.items, ['um']);
      expect(page.sections.last.revision, 3);
      expect(page.sections.last.state, ProfileAboutSectionState.published);
    });

    test('preview aplica o filtro de audiencia do dominio', () {
      final page = parseProfileAboutPage(
        subject: _institution,
        pageRow: const {'id': 'page', 'version': 2},
        fieldRows: const [
          {'field_key': 'display_name', 'value': 'Publico', 'visibility': 'profile_access'},
          {'field_key': 'phone', 'value': 'Somente equipe', 'visibility': 'team'},
        ],
        sectionRows: const [],
      );

      final preview = page.project(ProfileAboutAudience.profileAccess);
      expect(preview.fields.map((field) => field.key), [ProfileAboutFieldKey.displayName]);
      expect(page.fields.length, 2);
    });

    test('version invalido vira FormatException', () {
      expect(
        () => parseProfileAboutPage(
          subject: _institution,
          pageRow: const {'id': 'page'},
          fieldRows: const [],
          sectionRows: const [],
        ),
        throwsFormatException,
      );
    });
  });

  group('mapeamento de erros', () {
    test('privilegio insuficiente vira Unauthorized', () {
      expect(
        mapProfileAboutFailure('42501', 'permission denied'),
        isA<ProfileAboutUnauthorizedException>(),
      );
      expect(
        mapProfileAboutFailure('PGRST301', 'jwt expired'),
        isA<ProfileAboutUnauthorizedException>(),
      );
      expect(
        mapProfileAboutFailure(null, 'profiles.about.publish required'),
        isA<ProfileAboutUnauthorizedException>(),
      );
    });

    test('conflito de versao e reuso de request_id viram Conflict', () {
      expect(
        mapProfileAboutFailure('40001', 'profile about version conflict'),
        isA<ProfileAboutConflictException>(),
      );
      expect(
        mapProfileAboutFailure('23505', 'request_id reused with different payload'),
        isA<ProfileAboutConflictException>(),
      );
      expect(
        mapProfileAboutFailure('P0001', 'profile about version conflict'),
        isA<ProfileAboutConflictException>(),
      );
    });

    test('demais falhas viram Unavailable', () {
      expect(
        mapProfileAboutFailure('23514', 'check_violation'),
        isA<ProfileAboutUnavailableException>(),
      );
      expect(mapProfileAboutFailure(null, 'network'), isA<ProfileAboutUnavailableException>());
      expect(
        mapProfileAboutFailure('P0001', 'algo generico'),
        isA<ProfileAboutUnavailableException>(),
      );
    });
  });

  group('leitura autorizada por RPC', () {
    test('le a pagina, os campos e as secoes do retorno de get_profile_about', () {
      final page = parseProfileAboutReadResponse(
        subject: _institution,
        response: <String, Object?>{
          'page': <String, Object?>{
            'id': '22222222-2222-4222-8222-222222222222',
            'version': 7,
            'state': 'published',
          },
          'fields': [
            <String, Object?>{
              'field_key': 'display_name',
              'value': 'Escola Coelo',
              'visibility': 'profile_access',
              'origin': 'manual',
            },
          ],
          'sections': [
            <String, Object?>{
              'id': '33333333-3333-4333-8333-333333333333',
              'section_type': 'icon_list',
              'title': 'Estrutura',
              'body': '',
              'items': ['Biblioteca'],
              'position': 0,
              'visibility': 'profile_access',
              'state': 'published',
              'origin': 'manual',
              'revision': 3,
            },
          ],
        },
      );

      expect(page, isNotNull);
      expect(page!.version, 7);
      expect(page.fields.single.key, ProfileAboutFieldKey.displayName);
      expect(page.fields.single.value, 'Escola Coelo');
      expect(page.sections.single.type, ProfileAboutSectionType.iconList);
      expect(page.sections.single.items, ['Biblioteca']);
      expect(page.sections.single.revision, 3);
    });

    test('pagina nula e ausencia de conteudo, nao falha nem negacao', () {
      expect(
        parseProfileAboutReadResponse(
          subject: _institution,
          response: <String, Object?>{'page': null, 'fields': [], 'sections': []},
        ),
        isNull,
      );
    });

    test('resposta nula da RPC (sujeito sem pagina Sobre) e ausencia de conteudo', () {
      // Medido na rota real do Perfil (R05, 11/09): get_profile_about devolve
      // null, nao um envelope, para a instituicao sintetica sem Sobre.
      expect(parseProfileAboutReadResponse(subject: _institution, response: null), isNull);
    });

    test('retorno que nao e objeto vira FormatException, que o load traduz em Unavailable', () {
      expect(
        () => parseProfileAboutReadResponse(subject: _institution, response: 'nao e json'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseProfileAboutReadResponse(
          subject: _institution,
          response: <String, Object?>{'page': 'nao e objeto'},
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('somente ausencia da funcao autoriza o fallback para a leitura por tabela', () {
      // 42883 e undefined_function; PGRST202 e o cache de schema do PostgREST.
      expect(isMissingProfileAboutReadFunction('42883', 'function does not exist'), isTrue);
      expect(
        isMissingProfileAboutReadFunction('PGRST202', 'Could not find the function'),
        isTrue,
      );
      expect(
        isMissingProfileAboutReadFunction(
          null,
          'Could not find the function public.get_profile_about',
        ),
        isTrue,
      );
    });

    test('negacao nunca e confundida com ausencia da funcao', () {
      // Assercao de seguranca do fallback: se uma negacao passasse por aqui,
      // um grant revogado viraria select direto na tabela.
      expect(isMissingProfileAboutReadFunction('42501', 'insufficient_privilege'), isFalse);
      expect(isMissingProfileAboutReadFunction('PGRST301', 'jwt expired'), isFalse);
      expect(isMissingProfileAboutReadFunction('403', 'forbidden'), isFalse);
      expect(isMissingProfileAboutReadFunction('40001', 'version conflict'), isFalse);
      expect(isMissingProfileAboutReadFunction(null, 'network'), isFalse);
    });
  });
}
