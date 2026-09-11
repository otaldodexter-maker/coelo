// Script de QA: entra no app em execucao com a credencial sintetica lida do
// AMBIENTE do processo (QA_EMAIL/QA_PASSWORD), sem imprimir nada sensivel.
// Fala direto com o VM Service (ext.flutter.driver) para a credencial nunca
// passar por chat, log ou arquivo versionado. Uso:
//   dart run test_driver/qa_login.dart ws://127.0.0.1:PORT/TOKEN=/ws
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final email = Platform.environment['QA_EMAIL'];
  final password = Platform.environment['QA_PASSWORD'];
  if (args.isEmpty || email == null || password == null) {
    stderr.writeln('uso: qa_login.dart <ws uri> com QA_EMAIL e QA_PASSWORD no ambiente');
    exit(2);
  }
  final socket = await WebSocket.connect(args.first);
  var nextId = 0;
  final pending = <int, Completer<Map<String, Object?>>>{};
  socket.listen((data) {
    final message = jsonDecode(data as String) as Map<String, Object?>;
    stderr.writeln('<- ${message['id']} ${message.containsKey('error') ? message['error'] : 'ok'}');
    final id = message['id'];
    if (id is int && pending.containsKey(id)) {
      pending.remove(id)!.complete(message);
    } else if (id is String && pending.containsKey(int.tryParse(id))) {
      pending.remove(int.parse(id))!.complete(message);
    }
  });
  Future<Map<String, Object?>> call(String method, [Map<String, Object?> params = const {}]) {
    final id = ++nextId;
    final completer = Completer<Map<String, Object?>>();
    pending[id] = completer;
    stderr.writeln('-> $id $method ${params['command'] ?? ''}');
    socket.add(jsonEncode({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params}));
    return completer.future.timeout(const Duration(seconds: 40));
  }

  final vm = await call('getVM');
  final isolates = ((vm['result'] as Map)['isolates'] as List).cast<Map>();
  final isolateId = isolates.first['id'] as String;
  Future<Map<String, Object?>> driver(Map<String, Object?> command) async {
    final response = await call('ext.flutter.driver', {'isolateId': isolateId, ...command});
    final result = response['result'] as Map<String, Object?>?;
    if (result == null || result['isError'] == true) {
      throw StateError('driver falhou em ${command['command']}: ${response['error'] ?? result}');
    }
    return result;
  }

  Map<String, Object?> key(String value) =>
      {'finderType': 'ByValueKey', 'keyValueString': value, 'keyValueType': 'String'};
  await driver({'command': 'waitFor', ...key('superadmin-login-email'), 'timeout': '15000'});
  await driver({'command': 'tap', ...key('superadmin-login-email')});
  await driver({'command': 'enter_text', 'text': email});
  await driver({'command': 'tap', ...key('superadmin-login-password')});
  await driver({'command': 'enter_text', 'text': password});
  await driver({'command': 'tap', 'finderType': 'ByText', 'text': 'Entrar'});
  await driver({
    'command': 'waitForAbsent',
    ...key('superadmin-login-email'),
    'timeout': '30000',
  });
  stdout.writeln('login enviado e tela de login saiu');
  await socket.close();
}
