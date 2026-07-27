import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders its label, icon, and approved presentation colors', (tester) async {
    const background = Color(0xFF123456);
    const foreground = Color(0xFFFEDCBA);

    await tester.pumpWidget(
      const _TestApp(
        child: CoeloStatusChip(
          label: 'Ativa',
          backgroundColor: background,
          foregroundColor: foreground,
          icon: Icons.check_circle_outline,
        ),
      ),
    );

    expect(find.text('Ativa'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    final chip = tester.widget<Chip>(find.byType(Chip));
    expect(chip.backgroundColor, background);
    expect(chip.labelStyle!.color, foreground);
    expect(chip.side!.color, foreground.withValues(alpha: 0.28));
  });

  testWidgets('does not render an icon when none is provided', (tester) async {
    await tester.pumpWidget(
      const _TestApp(
        child: CoeloStatusChip(
          label: 'Pendente',
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
        ),
      ),
    );

    expect(find.byType(Icon), findsNothing);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(body: Center(child: child)),
    );
  }
}
