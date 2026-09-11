// Ponto de entrada de QA: a MESMA composicao de lib/main.dart, apenas com a
// extensao do Flutter Driver ligada para a sessao de teste em producao
// (ADR 0034, Decisao 10) poder ser dirigida por ferramenta. Nao entra no
// build de producao: vive em test_driver/ e depende de flutter_driver, que e
// dev_dependency.
import 'package:coelo_superadmin/main.dart' as app;
import 'package:flutter_driver/driver_extension.dart';

Future<void> main() async {
  enableFlutterDriverExtension();
  await app.main();
}
