// Entrypoint de prova na rota normal contra produção: liga a extensão do
// Flutter Driver e sobe o mesmo composition root de `lib/main.dart`.
// Uso: flutter run -d chrome -t test_driver/driver_main.dart --dart-define=...
import 'package:flutter_driver/driver_extension.dart';

import 'package:coelo_superadmin/main.dart' as app;

void main() {
  enableFlutterDriverExtension();
  app.main();
}
