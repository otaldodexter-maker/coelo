import 'package:coelo_superadmin/features/principal_happens_publication/domain/happens_publication.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/presentation/principal_happens_publication_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = <({String name, Size size, ThemeData theme})>[
    (name: 'light_375', size: const Size(375, 1200), theme: CoeloTheme.light),
    (name: 'light_768', size: const Size(768, 1100), theme: CoeloTheme.light),
    (name: 'light_1440', size: const Size(1440, 1000), theme: CoeloTheme.light),
    (name: 'dark_1440', size: const Size(1440, 1000), theme: CoeloTheme.dark),
  ];

  for (final testCase in cases) {
    testWidgets('matches publication composition ${testCase.name}', (tester) async {
      await tester.binding.setSurfaceSize(testCase.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: testCase.theme,
          home: PrincipalHappensPublicationPage(repository: InMemoryHappensPublicationRepository()),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(PrincipalHappensPublicationPage),
        matchesGoldenFile('goldens/principal_happens_publication_${testCase.name}.png'),
      );
    });
  }
}
