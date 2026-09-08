import 'package:coelo_api/children.dart';
import 'package:coelo_superadmin/features/children/presentation/child_directory_controller.dart';
import 'package:coelo_superadmin/features/children/presentation/child_directory_panel.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _institutionA = '10000000-0000-0000-0000-000000000001';
const _contextA = '20000000-0000-0000-0000-000000000001';

ChildDirectoryPage _page({ChildDirectoryCursor? cursor}) => ChildDirectoryPage(
  items: const [
    ChildDirectoryItem(
      contextId: _contextA,
      personId: '30000000-0000-0000-0000-000000000001',
      personName: 'Sintética Um',
      institutionId: _institutionA,
      institutionName: 'Instituição Sintética',
    ),
  ],
  nextCursor: cursor,
);

Future<ChildDirectoryPage> _read(ChildDirectoryRequest request) async =>
    _page(cursor: const ChildDirectoryCursor(name: 'Sintética Um', contextId: _contextA));

Future<ChildDirectoryPage> _readLast(ChildDirectoryRequest request) async => _page();

void main() {
  Widget host({required ChildDirectoryRead read, bool sessionAvailable = true}) => MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(
      body: ChildDirectoryPanel(
        read: read,
        sessionAvailable: sessionAvailable,
        institutionId: _institutionA,
      ),
    ),
  );

  testWidgets('the students list meets tap size, labelling and contrast', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(read: _read));
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('the list announces its heading and its read-only nature', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(read: _readLast));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Alunos'), findsWidgets);
    expect(find.textContaining('somente leitura'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the denied state keeps readable contrast and offers no false action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(read: _readLast, sessionAvailable: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('child-directory-denied')), findsOneWidget);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    // The forward control exists but must be disabled, never a dead end that
    // looks live.
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('child-directory-next'))).enabled,
      isFalse,
    );
    handle.dispose();
  });

  testWidgets('a disabled next page is not announced as an available action', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(read: _readLast));
    await tester.pumpAndSettle();

    final next = find.byKey(const Key('child-directory-next'));
    expect(tester.widget<FilledButton>(next).enabled, isFalse);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
