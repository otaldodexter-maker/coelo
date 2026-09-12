import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// A familia Publicacao (publication_surface.dart) embute o
// SuperadminFormActionFooter; quem compoe PublicationSurface adota o rodape
// canonico por composicao (Agenda desde 0322e511d, R06). Os publicadores do
// Principal usam o rodape da propria familia (PrincipalPublicationActionFooter,
// referencias aprovadas pelo Owner em 11/09/2026).
bool _usesCanonicalFooter(String source) =>
    source.contains('SuperadminFormActionFooter') ||
    source.contains('PublicationSurface(') ||
    source.contains('PrincipalPublicationActionFooter(');

void main() {
  test('all current administrative creation and edit surfaces use the canonical footer', () {
    const consumers = <String>[
      'lib/features/access_profiles/presentation/access_profile_form_page.dart',
      'lib/features/activities/presentation/activity_form_page.dart',
      'lib/features/agenda/presentation/agenda_event_form_page.dart',
      'lib/features/assessments/assessment_pages.dart',
      'lib/features/attendance/attendance_pages.dart',
      'lib/features/daily_routine/daily_routine_form_sections.dart',
      'lib/features/forms/presentation/editor/forms_editor_page.dart',
      'lib/features/groups/presentation/group_form_page.dart',
      'lib/features/health_care/presentation/health_care_form_pages.dart',
      'lib/features/health_care/presentation/health_medication_plan_form_page.dart',
      'lib/features/imports/presentation/import_wizard_page.dart',
      'lib/features/institutions/presentation/screens/institution_form_page.dart',
      'lib/features/invites/presentation/invite_form_page.dart',
      'lib/features/meal_plans/presentation/meal_plan_wizard_page.dart',
      'lib/features/notices/presentation/notice_form_page.dart',
      'lib/features/people/presentation/person_form_page.dart',
      'lib/features/plans/presentation/plan_form_page.dart',
      'lib/features/platform_users/presentation/platform_user_form_page.dart',
      'lib/features/principal_happens_publication/presentation/principal_happens_publication_page.dart',
      'lib/features/principal_moments_publication/presentation/principal_moments_publication_components.dart',
      'lib/features/principal_now_publication/presentation/principal_now_publication_page.dart',
      'lib/features/safety/presentation/safety_pages.dart',
      'lib/features/units/presentation/unit_form_page.dart',
    ];

    for (final path in consumers) {
      expect(_usesCanonicalFooter(File(path).readAsStringSync()), isTrue, reason: path);
    }
  });

  test('form-like pages without a footer remain semantic non-form wrappers', () {
    final candidates =
        Directory('lib/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .where((file) {
              final source = file.readAsStringSync();
              return RegExp(r'class .*?(Form|Wizard|Editor|Create|Edit).*Page').hasMatch(source) &&
                  !_usesCanonicalFooter(source);
            })
            .map((file) => file.path.replaceAll(r'\', '/'))
            .toList()
          ..sort();

    expect(candidates, <String>[
      'lib/features/daily_routine/daily_routine_pages.dart',
      // Classe de dados (FormsAuthoringInstitutionPage), nao e tela.
      'lib/features/forms/data/forms_authoring_api.dart',
      'lib/features/forms/presentation/directory/forms_directory_page.dart',
      // Paginas de operacao de Formularios (Media/Operations casam com "Form").
      'lib/features/forms/presentation/operations/forms_media_page.dart',
      'lib/features/forms/presentation/operations/forms_operations_page.dart',
      'lib/features/forms/presentation/overview/forms_overview_page.dart',
      'lib/features/forms/presentation/response/form_response_page.dart',
      'lib/features/forms/presentation/response/forms_test_page.dart',
      'lib/features/people/presentation/person_edit_route_page.dart',
      // Familia Principal: composicao propria, fora do rodape administrativo.
      'lib/features/principal_profile/presentation/principal_profile_edit_page.dart',
    ]);
  });
}
