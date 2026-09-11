import 'package:flutter_driver/driver_extension.dart';

import 'main.dart' as production;

/// Ponto de entrada da rota normal dirigida (Etapa 2, regua do MVP): liga a
/// extensao do Flutter Driver e roda exatamente o `main()` de producao, com a
/// mesma composicao. Uso: `flutter run -t lib/main_driver.dart ...`. Nunca e o
/// alvo de build publicado.
Future<void> main() async {
  enableFlutterDriverExtension();
  await production.main();
}
