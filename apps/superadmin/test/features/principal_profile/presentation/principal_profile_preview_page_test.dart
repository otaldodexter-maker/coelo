import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_domain/profile_about.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_preview_page.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';

void main() {
  testWidgets('embedded web preview omits its own application header', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfilePreviewPage(embedded: true, onOpenAgenda: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const Key('principal-profile-logo')), findsNothing);
    expect(find.byKey(const Key('principal-profile-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports 200 percent text at 375x900 light', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: PrincipalProfilePreviewPage(onOpenAgenda: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final key in const [
      Key('principal-profile-tab-acontece'),
      Key('principal-profile-tab-momentos'),
      Key('principal-profile-tab-circulares'),
      Key('principal-profile-tab-sobre'),
    ]) {
      expect(find.byKey(key), findsOneWidget);
      expect(tester.getSize(find.byKey(key)).height, greaterThanOrEqualTo(CoeloSize.touchMin));
    }
    expect(find.byKey(const Key('principal-profile-open-agenda')), findsOneWidget);
  });

  testWidgets('supports 200 percent text at 1440x900 dark', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: PrincipalProfilePreviewPage(onOpenAgenda: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('principal-profile-tab-acontece')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-tab-momentos')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-tab-circulares')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-tab-sobre')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-open-agenda')), findsOneWidget);
  });

  testWidgets('renders the approved profile anatomy and opens agenda', (tester) async {
    var agendaOpened = false;
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfilePreviewPage(onOpenAgenda: () => agendaOpened = true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-logo')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-bug')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-notifications')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-context-avatar')), findsOneWidget);
    expect(find.text('Colégio Horizonte'), findsOneWidget);
    expect(find.text('Instituição de Ensino'), findsOneWidget);
    expect(find.text('Acompanhar'), findsOneWidget);
    expect(find.text('Mensagem'), findsOneWidget);
    expect(find.text('Destaques'), findsOneWidget);
    expect(find.text('Vínculos'), findsOneWidget);
    expect(find.text('Acontece'), findsOneWidget);
    expect(find.text('Momentos'), findsOneWidget);
    expect(find.text('Sobre'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('principal-profile-open-agenda')));
    await tester.tap(find.byKey(const Key('principal-profile-open-agenda')));
    await tester.pump();
    expect(agendaOpened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changes tabs without losing the profile context', (tester) async {
    var mapOpened = false;
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfilePreviewPage(
          onOpenAgenda: () {},
          onOpenAboutMap: () => mapOpened = true,
          aboutPage: ProfileAboutPage(
            subject: const ProfileAboutSubjectRef(
              type: ProfileAboutSubjectType.institution,
              institutionId: 'institution',
            ),
            version: 1,
            fields: const [
              ProfileAboutField(
                key: ProfileAboutFieldKey.preciseLocation,
                value: '-23.5505,-46.6333',
              ),
            ],
            sections: const [
              ProfileAboutSection(
                id: 'history',
                type: ProfileAboutSectionType.text,
                title: 'Uma história feita em comunidade',
                body: 'Conteúdo editorial autorizado.',
                position: 0,
                state: ProfileAboutSectionState.published,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('principal-profile-tab-sobre')));
    await tester.tap(find.byKey(const Key('principal-profile-tab-sobre')));
    await tester.pump();

    expect(find.text('Uma história feita em comunidade'), findsOneWidget);
    await tester.ensureVisible(find.text('Ver no mapa'));
    await tester.tap(find.text('Ver no mapa'));
    expect(mapOpened, isTrue);
    expect(find.text('Colégio Horizonte'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps Sobre and renders authorized Circulares in its own tab', (tester) async {
    var openedCircular = '';
    var mapOpened = false;
    await tester.binding.setSurfaceSize(const Size(768, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfilePreviewPage(
          onOpenAgenda: () {},
          circularRepository: _CircularRepository(),
          circularScope: const CircularScope(institutionId: 'institution-1'),
          onOpenCircular: (id) => openedCircular = id,
          onOpenAboutMap: () => mapOpened = true,
          aboutPage: ProfileAboutPage(
            subject: const ProfileAboutSubjectRef(
              type: ProfileAboutSubjectType.institution,
              institutionId: 'institution-1',
            ),
            version: 1,
            fields: const [
              ProfileAboutField(
                key: ProfileAboutFieldKey.preciseLocation,
                value: '-23.5505,-46.6333',
              ),
            ],
            sections: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acontece'), findsOneWidget);
    expect(find.text('Momentos'), findsOneWidget);
    expect(find.text('Circulares'), findsOneWidget);
    expect(find.text('Sobre'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('principal-profile-tab-circulares')));
    await tester.tap(find.byKey(const Key('principal-profile-tab-circulares')));
    await tester.pumpAndSettle();
    expect(find.text('Circular autorizada'), findsOneWidget);
    await tester.tap(find.text('Circular autorizada'));
    expect(openedCircular, 'circular-1');

    await tester.tap(find.byKey(const Key('principal-profile-tab-sobre')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver no mapa'));
    await tester.tap(find.text('Ver no mapa'));
    expect(mapOpened, isTrue);
  });

  testWidgets('opens Acontece and Momentos through the profile tabs', (tester) async {
    var happensOpened = false;
    var momentsOpened = false;
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfilePreviewPage(
          onOpenAgenda: () {},
          onOpenHappens: () => happensOpened = true,
          onOpenMoments: () => momentsOpened = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('principal-profile-tab-momentos')));
    await tester.tap(find.byKey(const Key('principal-profile-tab-momentos')));
    await tester.pump();
    expect(momentsOpened, isTrue);

    await tester.tap(find.byKey(const Key('principal-profile-tab-acontece')));
    await tester.pump();
    expect(happensOpened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delegates header and profile actions when integrations are provided', (
    tester,
  ) async {
    final invoked = <String>[];
    await tester.binding.setSurfaceSize(const Size(768, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfilePreviewPage(
          onOpenAgenda: () {},
          onReportBug: () => invoked.add('bug'),
          onOpenNotifications: () => invoked.add('notifications'),
          onOpenContext: () => invoked.add('context'),
          onMessage: () => invoked.add('message'),
          onOpenBio: () => invoked.add('bio'),
          onOpenLinks: () => invoked.add('links'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final key in const [
      Key('principal-profile-bug'),
      Key('principal-profile-notifications'),
      Key('principal-profile-context-avatar'),
    ]) {
      await tester.tap(find.byKey(key));
    }
    await tester.tap(find.text('Mensagem'));
    await tester.tap(find.text('Ver mais'));
    await tester.ensureVisible(find.text('Ver todos'));
    await tester.tap(find.text('Ver todos'));
    await tester.pump();

    expect(invoked, ['bug', 'notifications', 'context', 'message', 'bio', 'links']);
    expect(find.byType(SnackBar), findsNothing);
  });
}

final class _CircularRepository implements CircularRepository {
  @override
  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  }) async => PrincipalCursorPage(
    items: [
      CircularSummary(
        id: 'circular-1',
        title: 'Circular autorizada',
        excerpt: 'Conteúdo do contexto autenticado.',
        authorName: 'Colégio Horizonte',
        contextLabel: 'Instituição',
        publishedAt: DateTime.utc(2026, 8, 21),
        attachmentCount: 0,
        questionCount: 0,
        responseState: CircularResponseState.unanswered,
      ),
    ],
    nextCursor: null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
