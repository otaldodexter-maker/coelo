"""Materialize a temporary capture of the tested mobile confirmation state."""
from pathlib import Path

here = Path(__file__).resolve().parent
root = next(p for p in here.parents if (p / 'AGENTS.md').is_file())
tests = root / 'apps/superadmin/test/features/access_profiles/presentation'
source = (tests / 'access_profile_duplicate_context_test.dart').read_text(encoding='utf-8')
source = ("import 'dart:io';\nimport 'dart:ui' as ui;\n"
          "import 'package:flutter/rendering.dart';\nimport 'package:flutter/services.dart';\n" + source)
golden = (tests / 'access_profile_golden_test.dart').read_text(encoding='utf-8')
source += '\n' + golden[golden.index('Future<void> _loadGoldenFonts()'):]
source = source.replace('void main() {', 'void main() {\n  setUpAll(_loadGoldenFonts);', 1)
source = source.replace('  theme: CoeloTheme.light,',
    "  builder: (context, child) => RepaintBoundary(key: const Key('duplicate-capture'), child: child!),\n  theme: CoeloTheme.light,")
source = source.replace("final repository = _Repository('A')..detail.complete(_profile('A'));", """
      await tester.binding.setSurfaceSize(const Size(375, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Repository('A')..detail.complete(_profile('A'));
""")
source = source.replace('expect(completions, 2);', """expect(completions, 2);
      ScaffoldMessenger.of(tester.element(find.byType(AccessProfileDuplicatePage))).clearSnackBars();
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('duplicate-capture')));
        final picture = await boundary.toImage();
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await File('../../docs/reviews/etapa-2-operacao/noturna/acessos-pessoas/models/duplicate-confirmed-375.png').writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });""")
(tests / 'access_profile_duplicate_capture_test.dart').write_text(source, encoding='utf-8')
