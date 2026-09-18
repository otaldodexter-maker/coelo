from pathlib import Path

root = Path(__file__).resolve().parents[6]
tests = root / 'apps/superadmin/test/features/access_profiles/presentation'
source = (tests / 'access_profile_form_receipt_test.dart').read_text(encoding='utf-8')
source = "import 'dart:io';\nimport 'dart:ui' as ui;\nimport 'package:flutter/rendering.dart';\nimport 'package:flutter/services.dart';\n" + source
golden = (tests / 'access_profile_golden_test.dart').read_text(encoding='utf-8')
source += '\n' + golden[golden.index('Future<void> _loadGoldenFonts()'):]
source = source.replace('void main() {', 'void main() {\n  setUpAll(_loadGoldenFonts);', 1)
source = source.replace('  theme: CoeloTheme.light,', "  builder: (context, child) => RepaintBoundary(key: const Key('receipt-capture'), child: child!),\n  theme: CoeloTheme.light,")
source = source.replace('        expect(deliveries, 2);', '''        expect(deliveries, 2);
        ScaffoldMessenger.of(tester.element(find.byType(AccessProfileFormPage))).clearSnackBars();
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('receipt-capture')));
          final picture = await boundary.toImage();
          final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
          await File('../../docs/reviews/etapa-2-operacao/noturna/acessos-pessoas/models-form-receipt/confirmed-create.png').writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });''')
(tests / 'access_profile_form_receipt_capture_test.dart').write_text(source, encoding='utf-8')
