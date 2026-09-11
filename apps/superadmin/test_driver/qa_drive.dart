// Dirige o app web em execucao pelo Chrome DevTools Protocol (CDP), usando o
// gancho window.$flutterDriver que enableFlutterDriverExtension() registra
// na web. Serve para a sessao de teste em producao (ADR 0034, Decisao 10).
//
// Uso:
//   dart run test_driver/qa_drive.dart <ws da pagina> login
//       le QA_EMAIL/QA_PASSWORD do ambiente e entra; nunca imprime a senha
//   dart run test_driver/qa_drive.dart <ws da pagina> cmd command=tap finderType=ByText text=Entrar
//   dart run test_driver/qa_drive.dart <ws da pagina> goto <url>
//   dart run test_driver/qa_drive.dart <ws da pagina> reload
//   dart run test_driver/qa_drive.dart <ws da pagina> shot <arquivo.png>
//   dart run test_driver/qa_drive.dart <ws da pagina> texts   (todos os Text visiveis)
//   dart run test_driver/qa_drive.dart <ws da pagina> url
import 'dart:async';
import 'dart:convert';
import 'dart:io';

late WebSocket _socket;
var _nextId = 0;
final _pending = <int, Completer<Map<String, Object?>>>{};

Future<Map<String, Object?>> _cdp(String method, [Map<String, Object?> params = const {}]) {
  final id = ++_nextId;
  final completer = Completer<Map<String, Object?>>();
  _pending[id] = completer;
  _socket.add(jsonEncode({'id': id, 'method': method, 'params': params}));
  return completer.future.timeout(const Duration(seconds: 60));
}

Future<Object?> _eval(String expression) async {
  final response = await _cdp('Runtime.evaluate', {
    'expression': expression,
    'returnByValue': true,
    'awaitPromise': true,
  });
  final result = response['result'] as Map<String, Object?>?;
  if (result == null) throw StateError('CDP sem resultado: $response');
  if (result['exceptionDetails'] != null) {
    throw StateError('JS falhou: ${jsonEncode(result['exceptionDetails'])}');
  }
  return (result['result'] as Map<String, Object?>?)?['value'];
}

Future<Map<String, Object?>> driver(Map<String, Object?> command) async {
  final message = jsonEncode(jsonEncode(command));
  await _eval('window.\$flutterDriverResult = null; window.\$flutterDriver($message); true');
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (DateTime.now().isBefore(deadline)) {
    final raw = await _eval('window.\$flutterDriverResult');
    if (raw is String) {
      final result = jsonDecode(raw) as Map<String, Object?>;
      if (result['isError'] == true) {
        throw StateError('driver falhou em ${command['command']}: ${result['response']}');
      }
      return result;
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
  throw TimeoutException('driver sem resposta em ${command['command']}');
}

/// Depois de uma carga completa, o app web em debug leva alguns segundos para
/// subir; espera o gancho do driver voltar a responder e desliga o frame sync
/// de novo, porque a instancia nova nasce com ele ligado.
Future<void> _waitForApp() async {
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(seconds: 2));
    final ready = await _eval('typeof window.\$flutterDriver === "function"');
    if (ready == true) {
      await driver({'command': 'set_frame_sync', 'enabled': 'false'});
      await driver({'command': 'get_health'});
      await Future<void>.delayed(const Duration(seconds: 2));
      return;
    }
  }
  throw TimeoutException('app nao respondeu depois da carga');
}

Map<String, Object?> key(String value) =>
    {'finderType': 'ByValueKey', 'keyValueString': value, 'keyValueType': 'String'};
Map<String, Object?> text(String value) => {'finderType': 'ByText', 'text': value};

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('uso: qa_drive.dart <ws> login|cmd <json>|goto <url>|reload|shot <png>|texts|url');
    exit(2);
  }
  _socket = await WebSocket.connect(args[0]);
  _socket.listen((data) {
    final message = jsonDecode(data as String) as Map<String, Object?>;
    final id = message['id'];
    if (id is int) _pending.remove(id)?.complete(message);
  });
  try {
    switch (args[1]) {
      case 'login':
        final email = Platform.environment['QA_EMAIL'];
        final password = Platform.environment['QA_PASSWORD'];
        if (email == null || password == null) {
          stderr.writeln('QA_EMAIL e QA_PASSWORD precisam estar no ambiente');
          exit(2);
        }
        await driver({'command': 'waitFor', ...key('superadmin-login-email'), 'timeout': '15000'});
        await driver({'command': 'tap', ...key('superadmin-login-email')});
        await driver({'command': 'enter_text', 'text': email});
        await driver({'command': 'tap', ...key('superadmin-login-password')});
        await driver({'command': 'enter_text', 'text': password});
        // Manter sessao aberta: a prova de reload precisa sobreviver a uma
        // carga completa da pagina.
        await driver({'command': 'tap', ...key('superadmin-login-keep-session-hit-target')});
        await driver({'command': 'tap', ...text('Entrar')});
        // A confirmacao e a URL sair de /login: o driver pode ficar preso no
        // meio da transicao de rota se esperar pela ausencia do campo.
        final deadline = DateTime.now().add(const Duration(seconds: 40));
        while (DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(seconds: 1));
          final href = await _eval('location.href') as String? ?? '';
          if (!href.contains('/login')) {
            stdout.writeln('login: sessao aberta em $href');
            return;
          }
        }
        throw TimeoutException('login nao saiu de /login');
      case 'cmd':
        // Pares chave=valor, porque o PowerShell descarta aspas de JSON ao
        // repassar argumentos a executaveis nativos.
        final command = <String, Object?>{
          for (final pair in args.skip(2))
            pair.substring(0, pair.indexOf('=')): pair.substring(pair.indexOf('=') + 1),
        };
        final result = await driver(command);
        stdout.writeln(jsonEncode(result['response']));
      case 'goto':
        await _cdp('Page.navigate', {'url': args[2]});
        await _waitForApp();
        stdout.writeln(await _eval('location.href'));
      case 'reload':
        await _cdp('Page.reload', {'ignoreCache': false});
        await _waitForApp();
        stdout.writeln(await _eval('location.href'));
      case 'url':
        stdout.writeln(await _eval('location.href'));
      case 'shot':
        final response = await _cdp('Page.captureScreenshot', {'format': 'png'});
        final data = (response['result'] as Map)['data'] as String;
        File(args[2]).writeAsBytesSync(base64Decode(data));
        stdout.writeln('screenshot: ${args[2]}');
      case 'texts':
        final result = await driver({
          'command': 'get_diagnostics_tree',
          'diagnosticsType': 'widget',
          'finderType': 'ByType',
          'type': 'MaterialApp',
          'subtreeDepth': '400',
          'includeProperties': 'false',
        });
        final found = <String>[];
        void walk(Object? node) {
          if (node is Map) {
            final description = node['description'];
            if (description is String && description.startsWith('Text(')) {
              found.add(description);
            } else if (description is String && node['widgetRuntimeType'] == 'Text') {
              found.add(description);
            }
            for (final child in (node['children'] as List? ?? const [])) {
              walk(child);
            }
          }
        }
        walk(result['response']);
        stdout.writeln(found.join('\n'));
      default:
        stderr.writeln('comando desconhecido: ${args[1]}');
        exit(2);
    }
  } finally {
    await _socket.close();
  }
}
