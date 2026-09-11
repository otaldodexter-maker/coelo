// Entrada de execução com a extensão do flutter_driver ligada, só para provas
// dirigidas da rota real (Rodada 4). Não é a entrada de produção.
import 'package:flutter_driver/driver_extension.dart';

import 'package:coelo_superadmin/main.dart' as app;

Future<void> main() async {
  enableFlutterDriverExtension();
  await app.main();
}
