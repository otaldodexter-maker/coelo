import 'package:coelo_superadmin/app/shell/superadmin_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('stacks from the bottom and softly removes the oldest fourth notice', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SuperadminNoticeHost(child: _NoticeHarness())),
      ),
    );

    for (final id in [1, 2, 3]) {
      await tester.tap(find.byKey(Key('notice-$id')));
      await tester.pumpAndSettle();
    }

    expect(
      tester.getTopLeft(find.text('Primeira')).dy,
      lessThan(tester.getTopLeft(find.text('Segunda')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Segunda')).dy,
      lessThan(tester.getTopLeft(find.text('Terceira')).dy),
    );

    await tester.tap(find.byKey(const Key('notice-4')));
    await tester.pump();
    expect(find.text('Primeira'), findsOneWidget);
    expect(find.text('Quarta'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 140));
    final exitingOpacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('Primeira'), matching: find.byType(Opacity)),
    );
    expect(exitingOpacity.opacity, greaterThan(0));
    expect(exitingOpacity.opacity, lessThan(1));

    await tester.pumpAndSettle();
    expect(find.text('Primeira'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Segunda')).dy,
      lessThan(tester.getTopLeft(find.text('Terceira')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Terceira')).dy,
      lessThan(tester.getTopLeft(find.text('Quarta')).dy),
    );
  });
}

class _NoticeHarness extends StatelessWidget {
  const _NoticeHarness();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final entry in const [(1, 'Primeira'), (2, 'Segunda'), (3, 'Terceira'), (4, 'Quarta')])
          TextButton(
            key: Key('notice-${entry.$1}'),
            onPressed: () => showSuperadminNotice(context, entry.$2),
            child: Text('${entry.$1}'),
          ),
      ],
    );
  }
}
