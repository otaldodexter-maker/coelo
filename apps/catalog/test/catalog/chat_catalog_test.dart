import 'package:coelo_catalog/catalog/catalog_foundations.dart';
import 'package:coelo_catalog/catalog/catalog_registry.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
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
      'admin.chat-context-summary',
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

  testWidgets('adapts the administrative chat at 375 768 1024 and 1440', (tester) async {
    final foundation = buildCatalogFoundationRegistry()['pattern.chat-admin']!;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    tester.view.physicalSize = const Size(375, 760);
    await tester.pumpWidget(_app(Builder(builder: foundation.builder)));
    expect(find.byKey(const Key('catalog-admin-chat-rail')), findsNothing);
    expect(find.text('Turma Girassol'), findsOne);
    await tester.tap(find.text('Turma Girassol'));
    await tester.pump();
    expect(find.byType(CoeloChatComposer), findsOne);
    await tester.tap(find.byTooltip('Ver contexto'));
    await tester.pump();
    expect(find.byType(CoeloAdminChatContextSummary), findsOne);
    expect(find.text('Dados simulados'), findsOne);
    await tester.tap(find.byTooltip('Voltar para a conversa'));
    await tester.pump();

    tester.view.physicalSize = const Size(768, 760);
    await tester.pumpWidget(_app(Builder(builder: foundation.builder)));
    expect(find.byKey(const Key('catalog-admin-chat-rail')), findsOne);
    expect(find.byType(CoeloChatComposer), findsOne);
    await tester.tap(find.byTooltip('Ver contexto'));
    await tester.pump();
    expect(find.byType(CoeloAdminChatContextSummary), findsOne);
    await tester.tap(find.byTooltip('Voltar para a conversa'));
    await tester.pump();

    tester.view.physicalSize = const Size(1024, 760);
    await tester.pumpWidget(_app(Builder(builder: foundation.builder)));
    expect(find.byTooltip('Recolher conversas'), findsOne);
    expect(find.byTooltip('Mostrar detalhes do contexto'), findsOne);

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(_app(Builder(builder: foundation.builder)));
    expect(find.byTooltip('Recolher conversas'), findsOne);
    expect(find.byTooltip('Recolher painel contextual'), findsOne);
    await tester.tap(find.byTooltip('Recolher conversas'));
    await tester.pump();
    expect(find.byKey(const Key('catalog-admin-chat-rail')), findsOne);
    expect(find.byType(CoeloChatComposer), findsOne);
  });

  testWidgets('opens the administrative launcher within 460 by 600', (tester) async {
    final foundation = buildCatalogFoundationRegistry()['pattern.chat-admin']!;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app(Builder(builder: foundation.builder)));
    await tester.tap(find.byKey(const Key('catalog-admin-chat-launcher')));
    await tester.pump();

    final size = tester.getSize(find.byKey(const Key('catalog-admin-chat-launcher-preview')));
    expect(size.width, lessThanOrEqualTo(460));
    expect(size.height, lessThanOrEqualTo(600));
    expect(find.byTooltip('Fechar conversas'), findsOne);
  });

  testWidgets('golden administrative chat mobile light', (tester) async {
    final foundation = buildCatalogFoundationRegistry()['pattern.chat-admin']!;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app(Builder(builder: foundation.builder)));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/chat_admin_mobile_light.png'),
    );
  });

  testWidgets('golden administrative chat desktop dark', (tester) async {
    final foundation = buildCatalogFoundationRegistry()['pattern.chat-admin']!;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app(Builder(builder: foundation.builder), theme: CoeloTheme.dark));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/chat_admin_desktop_dark.png'),
    );
  });
}

Widget _app(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? CoeloTheme.light,
    home: Scaffold(body: child),
  );
}
