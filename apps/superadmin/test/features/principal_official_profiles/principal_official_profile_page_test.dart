import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/principal_official_profiles/domain/principal_official_profile.dart';
import 'package:coelo_superadmin/features/principal_official_profiles/presentation/principal_official_profile_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// spec 068 (lote 104): perfil oficial no Principal — cabeçalho, seguir e publicações.
void main() {
  const coelo = PrincipalOfficialProfile(
    id: 'p-coelo',
    handle: 'coelo',
    displayName: 'Coelo',
    personId: 'person-coelo',
    description: 'Novidades, dicas e versões do app.',
    mandatory: true,
    followers: 12,
    following: true,
  );
  const educa = PrincipalOfficialProfile(
    id: 'p-educa',
    handle: 'coelo.educa',
    displayName: 'Coelo Educa',
    personId: 'person-educa',
    description: 'Desenvolvimento infantil.',
    followers: 3,
    following: true,
  );

  Widget app(_Reader reader, {String handle = 'coelo', ValueChanged<String>? onOpenProfile}) =>
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalOfficialProfilePage(
          handle: handle,
          reader: reader,
          onOpenProfile: onOpenProfile,
          onOpenCtaTarget: (_) => true,
        ),
      );

  testWidgets('shows the mandatory profile with its publications and the other profiles', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = _Reader(
      profiles: [coelo, educa],
      items: {
        'coelo': [_notice('n1', 'Versão nova')],
      },
    );
    await tester.pumpWidget(app(reader));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-official-profile-name')), findsOneWidget);
    expect(find.text('@coelo'), findsOneWidget);
    expect(find.text('12 seguidores'), findsOneWidget);
    expect(find.text('Seguindo · perfil obrigatório'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('principal-official-profile-follow')))
          .onPressed,
      isNull,
    );
    expect(find.byKey(const Key('principal-official-profile-item-n1')), findsOneWidget);
    expect(find.text('Versão nova'), findsOneWidget);
    expect(find.byKey(const Key('principal-official-profile-chip-coelo.educa')), findsOneWidget);
    expect(find.byKey(const Key('principal-official-profile-chip-coelo')), findsNothing);
  });

  testWidgets('unfollows and follows again a non-mandatory profile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = _Reader(profiles: [coelo, educa], items: const {});
    await tester.pumpWidget(app(reader, handle: 'coelo.educa'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-official-profile-empty')), findsOneWidget);
    expect(find.text('Seguindo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('principal-official-profile-follow')));
    await tester.pumpAndSettle();
    expect(reader.calls, [('person-educa', false)]);
    expect(find.text('Seguir'), findsOneWidget);
    expect(find.text('2 seguidores'), findsOneWidget);
    expect(find.text('Você deixou de seguir Coelo Educa.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('principal-official-profile-follow')));
    await tester.pumpAndSettle();
    expect(reader.calls.last, ('person-educa', true));
    expect(find.text('Seguindo'), findsOneWidget);
    expect(find.text('3 seguidores'), findsOneWidget);
  });

  testWidgets('opens another profile from the chips and reports unknown handles', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reader = _Reader(profiles: [coelo, educa], items: const {});
    final opened = <String>[];
    await tester.pumpWidget(app(reader, onOpenProfile: opened.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-official-profile-chip-coelo.educa')));
    expect(opened, ['coelo.educa']);

    await tester.pumpWidget(app(reader, handle: 'coelo.escola'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-official-profile-error')), findsOneWidget);
    expect(find.text('Este perfil não existe ou não está ativo.'), findsOneWidget);
  });
}

PlatformNotice _notice(String id, String title) => PlatformNotice(
  type: CommunicationType.forYou,
  id: id,
  title: title,
  message: 'Corpo de $title',
  priority: NoticePriority.routine,
  status: NoticeStatus.active,
  startsAt: DateTime.utc(2026, 9, 19, 12),
  endsAt: null,
  audience: NoticeAudience.everyone,
  audienceLabel: 'Toda a plataforma',
  behavior: NoticeBehavior.dismissible,
  targetDevice: NoticeTargetDevice.all,
  reach: 0,
);

final class _Reader implements PrincipalOfficialProfilesReader {
  _Reader({required this.profiles, required this.items});
  List<PrincipalOfficialProfile> profiles;
  final Map<String, List<PlatformNotice>> items;
  final calls = <(String, bool)>[];

  @override
  Future<List<PrincipalOfficialProfile>> loadOfficialProfiles() async => profiles;

  @override
  Future<PrincipalOfficialProfileDetail> loadOfficialProfile(String handle) async {
    final profile = profiles.where((p) => p.handle == handle).firstOrNull;
    if (profile == null) throw const NoticeNotFoundException();
    return PrincipalOfficialProfileDetail(
      profile: profile,
      profiles: profiles,
      items: items[handle] ?? const [],
    );
  }

  @override
  Future<bool> setOfficialFollowing(String personId, {required bool follow}) async {
    calls.add((personId, follow));
    profiles = [
      for (final p in profiles)
        if (p.personId == personId) p.copyWith(following: follow) else p,
    ];
    return follow;
  }
}
