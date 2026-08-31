import 'dart:io';

import 'package:coelo_superadmin/features/circulars/presentation/circular_directory_page.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('directory matches the approved responsive matrix', (tester) async {
    for (final brightness in Brightness.values) {
      for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
        await _pump(tester, Size(width, 900), brightness: brightness);
        await expectLater(
          find.byKey(const Key('circular-directory-golden-root')),
          matchesGoldenFile('goldens/circular_directory_${brightness.name}_${width.toInt()}.png'),
        );
      }
    }
  });

  testWidgets('directory remains usable at 200 percent text', (tester) async {
    for (final width in [375.0, 1440.0]) {
      await _pump(tester, Size(width, 1100), textScaler: const TextScaler.linear(2));
      await expectLater(
        find.byKey(const Key('circular-directory-golden-root')),
        matchesGoldenFile('goldens/circular_directory_text_200_${width.toInt()}.png'),
      );
    }
  });
}

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CoeloTheme.light,
      darkTheme: CoeloTheme.dark,
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationStyle: AnimationStyle.noAnimation,
      builder: (context, child) => RepaintBoundary(
        key: const Key('circular-directory-golden-root'),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: textScaler),
          child: child!,
        ),
      ),
      home: Scaffold(
        body: CircularDirectoryPage(items: _items, onCreate: () {}, onOpen: (_) {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _items = [
  CircularDirectoryItem(
    id: 'published',
    title: 'Renovação de matrícula',
    excerpt: 'Confirme a renovação para o próximo ano.',
    authorName: 'Ana Souza',
    contextLabel: 'Ensino Fundamental',
    status: CircularStatus.published,
    effectiveAt: DateTime.utc(2026, 8, 21),
    attachmentCount: 2,
    questionCount: 1,
    responseCount: 84,
  ),
  CircularDirectoryItem(
    id: 'scheduled',
    title: 'Reunião de responsáveis',
    excerpt: 'Agenda e orientações para o encontro.',
    authorName: 'Bruno Lima',
    contextLabel: 'Educação Infantil',
    status: CircularStatus.scheduled,
    effectiveAt: DateTime.utc(2026, 9, 2),
    attachmentCount: 1,
    questionCount: 0,
    responseCount: 0,
  ),
  CircularDirectoryItem(
    id: 'draft',
    title: 'Circular em elaboração',
    excerpt: 'Conteúdo ainda não publicado.',
    authorName: 'Carla Melo',
    contextLabel: 'Ensino Médio',
    status: CircularStatus.draft,
    effectiveAt: DateTime.utc(2026, 8, 30),
    attachmentCount: 0,
    questionCount: 2,
    responseCount: 0,
  ),
  CircularDirectoryItem(
    id: 'closed',
    title: 'Pesquisa de transporte',
    excerpt: 'Consulta encerrada com as famílias.',
    authorName: 'Diego Alves',
    contextLabel: 'Ensino Fundamental',
    status: CircularStatus.closed,
    effectiveAt: DateTime.utc(2026, 8, 10),
    attachmentCount: 0,
    questionCount: 3,
    responseCount: 126,
  ),
];

Future<void> _loadGoldenFonts() async {
  final nunitoSans = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
  await nunitoSans.load();
  final flutterArtifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final materialIcons = File(
    '${flutterArtifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await loader.load();
}
