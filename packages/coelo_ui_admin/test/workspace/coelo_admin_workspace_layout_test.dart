import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gives the body all available width when detail is closed', (tester) async {
    await _pumpWorkspace(tester, width: 1400, detailVisible: false);
    expect(tester.getSize(find.byKey(const Key('body'))).width, 1400);
    expect(find.byKey(const Key('detail')), findsNothing);
  });

  testWidgets('uses a 480 pixel detail on wide constraints', (tester) async {
    await _pumpWorkspace(tester, width: 1400, detailVisible: true);
    expect(tester.getSize(find.byKey(const Key('detail'))).width, 480);
    expect(tester.getSize(find.byKey(const Key('body'))).width, 920);
  });

  testWidgets('uses a 360 pixel detail on expanded constraints', (tester) async {
    await _pumpWorkspace(tester, width: 1000, detailVisible: true);
    expect(tester.getSize(find.byKey(const Key('detail'))).width, 360);
    expect(tester.getSize(find.byKey(const Key('body'))).width, 640);
  });

  testWidgets('replaces the body with full-width detail below expanded constraints', (
    tester,
  ) async {
    await _pumpWorkspace(tester, width: 700, detailVisible: true);
    expect(find.byKey(const Key('body')), findsNothing);
    expect(tester.getSize(find.byKey(const Key('detail'))).width, 700);
  });

  testWidgets('preserves horizontal scrolling owned by a narrowed body', (tester) async {
    await _setViewport(tester, 1000);
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 400,
            child: CoeloAdminWorkspaceLayout(
              toolbar: const SizedBox(height: CoeloSize.touchMin),
              body: SingleChildScrollView(
                key: const Key('body-scroll'),
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                child: const SizedBox(width: 900, child: Placeholder()),
              ),
              detail: const SizedBox(key: Key('detail')),
              detailVisible: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scroll = tester.widget<SingleChildScrollView>(find.byKey(const Key('body-scroll')));
    expect(scroll.controller!.position.maxScrollExtent, 260);
  });
}

Future<void> _pumpWorkspace(
  WidgetTester tester, {
  required double width,
  required bool detailVisible,
}) async {
  await _setViewport(tester, width);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 400,
          child: CoeloAdminWorkspaceLayout(
            toolbar: const SizedBox(height: CoeloSize.touchMin),
            body: const SizedBox(key: Key('body')),
            detail: const SizedBox(key: Key('detail')),
            detailVisible: detailVisible,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _setViewport(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 600);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
