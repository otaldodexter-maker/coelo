// Ponto de entrada de QA: a MESMA composicao de lib/main.dart, apenas com a
// extensao do Flutter Driver ligada para a sessao de teste em producao
// (ADR 0034, Decisao 10) poder ser dirigida por ferramenta. Nao entra no
// build de producao: vive em test_driver/ e depende de flutter_driver, que e
// dev_dependency.
import 'dart:convert';

import 'package:coelo_superadmin/core/qa/superadmin_qa_hooks.dart';
import 'package:coelo_superadmin/features/principal_circulars/application/circular_media_upload_coordinator.dart';
import 'package:coelo_superadmin/main.dart' as app;
import 'package:flutter_driver/driver_extension.dart';

// PNG 1x1 valido: a Edge Function circular-media confere assinatura e bytes.
const _qaPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

Future<void> main() async {
  // A automacao pelo navegador usa o teclado real. O mock intercepta esse
  // canal e deixa os controllers vazios. Runners que usam Driver.enterText
  // devem compilar com --dart-define=COELO_QA_TEXT_ENTRY_EMULATION=true.
  enableFlutterDriverExtension(
    enableTextEntryEmulation: const bool.fromEnvironment(
      'COELO_QA_TEXT_ENTRY_EMULATION',
    ),
  );
  // A prova pela interface usa o seletor normal. Runners antigos podem
  // optar pelo arquivo sintetico; essa substituicao nao prova o seletor.
  if (const bool.fromEnvironment('COELO_QA_SYNTHETIC_CIRCULAR_FILE')) {
    SuperadminQaHooks.circularFilePicker = () async => [
      CircularSelectedFile(
        uploadRequestId: CircularMediaLimits.newRequestId(),
        name: 'qa-pixel.png',
        mimeType: 'image/png',
        bytes: base64Decode(_qaPngBase64),
      ),
    ];
  }
  await app.main();
}
