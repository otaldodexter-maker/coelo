import 'package:coelo_superadmin/features/invites/data/fake_invite_repository.dart';
import 'package:coelo_superadmin/features/invites/presentation/invite_directory_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows creation inside invitation directory', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: InviteDirectoryPage(repository: FakeInviteRepository())),
      ),
    );
    expect(find.text('Convites'), findsOneWidget);
    expect(find.text('Novo convite'), findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(375, 800));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
