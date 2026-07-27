import 'package:coelo_catalog/catalog/catalog_foundations.dart';
import 'package:coelo_catalog/catalog/catalog_registry.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('registers and renders every approved chat component', (tester) async {
    final registry = buildCatalogRegistry();
    const ids = [
      'core.chat-avatar',
      'core.conversation-tile',
      'core.conversation-header',
      'core.message-bubble',
      'core.chat-composer',
      'admin.context-picker',
    ];

    expect(registry.keys, containsAll(ids));
    for (final id in ids) {
      await tester.pumpWidget(_app(Builder(builder: registry[id]!.builder)));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: id);
    }
  });

  testWidgets('renders administrative and Principal chat foundations responsively', (tester) async {
    final foundations = buildCatalogFoundationRegistry();
    const ids = [
      'pattern.chat-admin',
      'pattern.chat-principal-mobile',
      'pattern.chat-principal-web',
      'pattern.chat-states',
    ];
    expect(foundations.keys, containsAll(ids));

    for (final id in ids) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(id.contains('mobile') ? 375 : 1024, 760);
      await tester.pumpWidget(_app(Builder(builder: foundations[id]!.builder)));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: id);
    }
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('keeps Coelo pinned and opens Now separately from profile', (tester) async {
    final foundation = buildCatalogFoundationRegistry()['pattern.chat-principal-mobile']!;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app(Builder(builder: foundation.builder)));
    expect(find.text('Coelo'), findsOne);

    await tester.tap(find.byKey(const Key('catalog-chat-avatar-now')));
    await tester.pumpAndSettle();
    expect(find.text('Preview de Now'), findsOne);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Turma Girassol').first);
    await tester.pumpAndSettle();
    expect(find.text('Vínculos autorizados'), findsOne);
  });

  testWidgets('uses the real context picker in the administrative foundation', (tester) async {
    final foundation = buildCatalogFoundationRegistry()['pattern.chat-admin']!;
    await tester.pumpWidget(_app(Builder(builder: foundation.builder)));

    await tester.tap(find.byTooltip('Nova conversa'));
    await tester.pump();
    expect(find.byType(CoeloAdminContextPicker), findsOne);
  });

  testWidgets('does not offer voice or video calls in chat compositions', (tester) async {
    final foundations = buildCatalogFoundationRegistry();
    for (final id in ['pattern.chat-admin', 'pattern.chat-principal-mobile']) {
      await tester.pumpWidget(_app(Builder(builder: foundations[id]!.builder)));
      await tester.pump();
      expect(find.byIcon(Icons.call_outlined), findsNothing, reason: id);
      expect(find.byIcon(Icons.videocam_outlined), findsNothing, reason: id);
    }
  });

  testWidgets('catalog composer enables audio and media simulations', (tester) async {
    final foundation = buildCatalogFoundationRegistry()['pattern.chat-admin']!;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app(Builder(builder: foundation.builder)));
    await tester.tap(find.byTooltip('Gravar áudio'));
    await tester.pump();

    expect(find.text('Gravando áudio…'), findsOne);
    expect(find.byTooltip('Áudio · Em breve'), findsNothing);
    expect(find.byTooltip('Mídia · Em breve'), findsNothing);
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(body: child),
  );
}
