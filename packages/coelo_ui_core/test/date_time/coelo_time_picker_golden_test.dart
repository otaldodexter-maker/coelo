import 'dart:io';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('time picker open light at 375', (tester) async {
    await _match(
      tester,
      size: const Size(375, 720),
      brightness: Brightness.light,
      path: 'goldens/date_time/coelo_time_picker_open_light_375.png',
    );
  });

  testWidgets('time picker open dark at 1440', (tester) async {
    await _match(
      tester,
      size: const Size(1440, 800),
      brightness: Brightness.dark,
      path: 'goldens/date_time/coelo_time_picker_open_dark_1440.png',
    );
  });
}

Future<void> _match(
  WidgetTester tester, {
  required Size size,
  required Brightness brightness,
  required String path,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_GoldenApp(brightness: brightness));
  await tester.tap(find.text('11:30'));
  await tester.pumpAndSettle();
  expectLater(find.byKey(const Key('coelo-time-picker-golden-root')), matchesGoldenFile(path));
}

final class _GoldenApp extends StatelessWidget {
  const _GoldenApp({required this.brightness});

  final Brightness brightness;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.light ? CoeloTheme.light : CoeloTheme.dark,
    themeAnimationStyle: AnimationStyle.noAnimation,
    builder: (context, child) => RepaintBoundary(
      key: const Key('coelo-time-picker-golden-root'),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    ),
    home: Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: const _MealFields(),
          ),
        ),
      ),
    ),
  );
}

final class _MealFields extends StatefulWidget {
  const _MealFields();

  @override
  State<_MealFields> createState() => _MealFieldsState();
}

final class _MealFieldsState extends State<_MealFields> {
  final _name = TextEditingController(text: 'Almoço');
  final _details = TextEditingController(text: 'Arroz, feijão, legumes assados e frango.');

  @override
  void dispose() {
    _name.dispose();
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Refeição', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloFormTextField(
        controller: _name,
        labelText: 'Nome da refeição ou prato',
        prefixIcon: Icons.ramen_dining_outlined,
      ),
      const SizedBox(height: CoeloSpacing.space3),
      CoeloTimeField(value: const TimeOfDay(hour: 11, minute: 30), onChanged: (_) {}),
      const SizedBox(height: CoeloSpacing.space3),
      CoeloFormTextField(
        controller: _details,
        labelText: 'Detalhes do prato',
        prefixIcon: Icons.description_outlined,
        maxLines: 3,
      ),
    ],
  );
}

Future<void> _loadGoldenFonts() async {
  final nunitoBytes = File(
    '../../assets/brand/fonts/nunito-sans/NunitoSans-VariableFont_YTLC,opsz,wdth,wght.ttf',
  ).readAsBytesSync();
  final nunitoSans = FontLoader('Nunito Sans')
    ..addFont(Future.value(ByteData.sublistView(nunitoBytes)));
  await nunitoSans.load();

  final flutterArtifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final materialIcons = File(
    '${flutterArtifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  final materialIconsLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await materialIconsLoader.load();
}
