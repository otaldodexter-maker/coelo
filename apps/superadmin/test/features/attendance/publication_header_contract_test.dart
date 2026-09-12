import 'package:coelo_superadmin/shared/presentation/widgets/publication_surface.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact heading reduction preserves default and desktop typography', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [375.0, 1440.0]) {
      for (final scale in [1.0, .75]) {
        await tester.binding.setSurfaceSize(Size(width, 900));
        await tester.pumpWidget(
          MaterialApp(
            theme: CoeloTheme.light,
            home: Scaffold(
              body: PublicationSurface(
                subtitle: 'Lançar chamada',
                compactHeaderScale: scale,
                form: const Text('Conteúdo'),
                tertiaryAction: TextButton(onPressed: () {}, child: const Text('Voltar')),
                continuationActions: [
                  FilledButton(onPressed: () {}, child: const Text('Concluir')),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final factor = width == 375 ? scale : 1;
        expect(
          tester.widget<Text>(find.text('Sua publicação')).style!.fontSize,
          CoeloTheme.light.textTheme.headlineSmall!.fontSize! * factor,
        );
        expect(
          tester.widget<Text>(find.text('Lançar chamada')).style!.fontSize,
          CoeloTheme.light.textTheme.titleMedium!.fontSize! * factor,
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}
