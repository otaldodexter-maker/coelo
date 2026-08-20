import 'package:coelo_superadmin/features/invites/data/fake_invite_repository.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_detail_page.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_directory_page.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in const [375.0, 768.0, 1024.0, 1440.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('renders invitation surfaces at ${width.toInt()}px in ${brightness.name}', (
        tester,
      ) async {
        for (final surface in _surfaces()) {
          await _pumpSurface(tester, surface, size: Size(width, 900), brightness: brightness);
          expect(
            tester.takeException(),
            isNull,
            reason: '${surface.runtimeType} at ${width.toInt()}px in ${brightness.name}',
          );
        }
      });
    }
  }

  testWidgets('supports 200 percent text and reduced motion on compact width', (tester) async {
    for (final surface in _surfaces()) {
      await _pumpSurface(
        tester,
        surface,
        size: const Size(375, 1000),
        textScaler: const TextScaler.linear(2),
      );
      expect(tester.takeException(), isNull, reason: '${surface.runtimeType} at 200 percent text');
    }
  });
}

List<Widget> _surfaces() => [
  InviteDirectoryPage(repository: _repository(), onOpen: (_) {}),
  InviteFormPage(repository: _repository(), onCancel: () {}),
  InviteDetailPage(repository: _repository(), inviteId: 'invite-1'),
];

FakeInviteRepository _repository() => FakeInviteRepository(now: () => DateTime(2026, 8, 4, 12));

Future<void> _pumpSurface(
  WidgetTester tester,
  Widget surface, {
  required Size size,
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      darkTheme: CoeloTheme.dark,
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationStyle: AnimationStyle.noAnimation,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(body: surface),
    ),
  );
  await tester.pumpAndSettle();
}
