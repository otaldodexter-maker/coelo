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
    final metricLabels = [
      for (final label in const ['Publicações', 'Momentos', 'Circulares'])
        find.byKey(Key('principal-profile-metric-$label')),
    ];
    for (final label in metricLabels) {
      expect(label, findsOneWidget);
      expect(tester.widget<Text>(label).overflow, isNot(TextOverflow.ellipsis));
    }
    for (var index = 1; index < metricLabels.length; index++) {
      expect(
        tester.getTopLeft(metricLabels[index]).dy,
        greaterThan(tester.getTopLeft(metricLabels[index - 1]).dy),
      );
    }
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
    expect(find.byKey(const Key('principal-profile-bug')), findsNothing);
    expect(find.byKey(const Key('principal-profile-notifications')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-context-avatar')), findsOneWidget);
    expect(find.byKey(const Key('principal-global-dock')), findsOneWidget);
    expect(find.text('Colégio Horizonte'), findsOneWidget);
    expect(find.text('Instituição de Ensino'), findsOneWidget);
    expect(find.text('Acompanhar'), findsNothing);
    expect(find.text('Mensagem'), findsOneWidget);
    expect(find.text('Destaques'), findsOneWidget);
    expect(find.text('Vínculos'), findsOneWidget);
    expect(find.text('Acontece'), findsOneWidget);
    expect(find.text('Momentos'), findsWidgets);
    expect(find.text('Sobre'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('principal-profile-open-agenda')));
    await tester.tap(find.byKey(const Key('principal-profile-open-agenda')));
    await tester.pump();
    expect(agendaOpened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the institutional profile free of public follow signals', (tester) async {
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfilePreviewPage(onOpenAgenda: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Seguidores'), findsNothing);
    expect(find.text('Seguindo'), findsNothing);
    expect(find.byKey(const Key('principal-profile-follow')), findsNothing);
    expect(find.text('Mensagem'), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-tab-acontece')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-tab-momentos')), findsOneWidget);
    expect(find.byKey(const Key('principal-profile-tab-circulares')), findsOneWidget);
  });

  testWidgets('keeps the complete crest visible and renders editorial fixtures', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfilePreviewPage(onOpenAgenda: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final crest = tester.widget<Image>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.endsWith('institution-crest.png'),
      ),
    );
    expect(crest.fit, BoxFit.contain);
    expect(find.textContaining('Aula prática sobre civilizações antigas!'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsWidgets);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsWidgets);

    await tester.ensureVisible(find.byKey(const Key('principal-profile-tab-momentos')));
    await tester.tap(find.byKey(const Key('principal-profile-tab-momentos')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Música que inspira'), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsWidgets);
  });

  testWidgets('keeps tabs horizontally reachable at 200 percent', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 1100));
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

    expect(find.byKey(const Key('principal-profile-tabs-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows compact auxiliary context on desktop', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfilePreviewPage(onOpenAgenda: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-profile-context-aside')), findsOneWidget);
    expect(find.text('Contexto atual'), findsOneWidget);
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
    expect(find.text('Momentos'), findsWidgets);
    expect(find.byKey(const Key('principal-profile-tab-circulares')), findsOneWidget);
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

  testWidgets('delegates global and profile actions when integrations are provided', (
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
          onOpenMenu: () => invoked.add('menu'),
          onOpenNotifications: () => invoked.add('notifications'),
          onOpenHome: () => invoked.add('home'),
          onOpenForYou: () => invoked.add('for-you'),
          onPublishNow: () => invoked.add('publish-now'),
          onOpenMoments: () => invoked.add('moments'),
          onOpenSearch: () => invoked.add('search'),
          onOpenMessages: () => invoked.add('messages'),
          onOpenContext: () => invoked.add('profile'),
          onMessage: () => invoked.add('message'),
          onOpenBio: () => invoked.add('bio'),
          onOpenLinks: () => invoked.add('links'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final tooltip in [
      'Abrir menu',
      'Notificações',
      'Home',
      'Para você',
      'Publicar no Agora',
      'Momentos',
      'Pesquisar',
      'Mensagens',
      'Abrir perfil',
    ]) {
      await tester.tap(find.byTooltip(tooltip));
    }
    await tester.tap(find.text('Mensagem'));
    await tester.tap(find.text('Ver mais'));
    await tester.ensureVisible(find.text('Ver todos'));
    await tester.tap(find.text('Ver todos'));
    await tester.pump();

    expect(
      invoked,
      containsAll([
        'menu',
        'notifications',
        'home',
        'for-you',
        'publish-now',
        'moments',
        'search',
        'messages',
        'profile',
        'message',
        'bio',
        'links',
      ]),
    );
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
