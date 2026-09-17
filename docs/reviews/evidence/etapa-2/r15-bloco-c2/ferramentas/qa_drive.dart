// Dirige o build web de QA (test_driver/qa_main.dart) pela extensao do Flutter
// Driver exposta em window.$flutterDriver, via CDP Runtime.evaluate. Dart puro.
// Uso:
//   qa_drive.dart <ws> login <arquivo .env com QA_EMAIL/QA_PASSWORD>   (nunca imprime a credencial)
//   qa_drive.dart <ws> tapkey <key> | taptext <texto> | tapsem <label>
//   qa_drive.dart <ws> typekey <key> <texto...>   (tap na key + enter_text)
//   qa_drive.dart <ws> text <key>                  (get_text do widget com a key)
//   qa_drive.dart <ws> waitkey <key> [ms] | waittext <texto> [ms] | absentkey <key> [ms]
//   qa_drive.dart <ws> scrollkey <key>             (scrollIntoView)
//   qa_drive.dart <ws> goto <url> | url | shot <png> | sleep <ms> | eval <js>
import 'dart:async';
import 'dart:convert';
import 'dart:io';

late WebSocket _ws;
var _id = 0;
final _pending = <int, Completer<Map<String, Object?>>>{};

Future<Map<String, Object?>> cdp(String m, [Map<String, Object?> p = const {}]) {
  final c = Completer<Map<String, Object?>>();
  _pending[++_id] = c;
  _ws.add(jsonEncode({'id': _id, 'method': m, 'params': p}));
  return c.future.timeout(const Duration(seconds: 90));
}

Future<Object?> ev(String expr) async {
  final r = await cdp('Runtime.evaluate', {
    'expression': expr,
    'returnByValue': true,
    'awaitPromise': true,
  });
  final res = r['result'] as Map<String, Object?>?;
  if (res?['exceptionDetails'] != null) {
    throw StateError('JS: ${jsonEncode(res!['exceptionDetails'])}');
  }
  return (res?['result'] as Map<String, Object?>?)?['value'];
}

Future<Map<String, Object?>> driver(Map<String, Object?> command) async {
  // A extensao web grava a resposta em window.$flutterDriverResult de forma
  // assincrona; $flutterDriver(msg) em si nao devolve nada.
  final payload = jsonEncode(jsonEncode(command));
  await ev('(function(){ window.\$flutterDriverResult = null; window.\$flutterDriver($payload); return true; })()');
  Object? raw;
  final deadline = DateTime.now().add(const Duration(seconds: 25));
  while (raw == null && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    raw = await ev('window.\$flutterDriverResult');
  }
  if (raw == null) throw StateError('driver sem resposta em ${command['command']}');
  final decoded = jsonDecode(raw as String) as Map<String, Object?>;
  if (decoded['isError'] == true) {
    throw StateError('driver falhou em ${command['command']}: ${decoded['response']}');
  }
  return (decoded['response'] as Map<String, Object?>?) ?? const {};
}

Map<String, Object?> key(String value) => {
  'finderType': 'ByValueKey',
  'keyValueString': value,
  'keyValueType': 'String',
};
Map<String, Object?> text(String value) => {'finderType': 'ByText', 'text': value};
Map<String, Object?> sem(String value) => {'finderType': 'BySemanticsLabel', 'label': value};

Future<void> waitDriver() async {
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(deadline)) {
    final ready = await ev('typeof window.\$flutterDriver === "function"');
    if (ready == true) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw StateError('driver web nao ficou disponivel');
}

Future<void> main(List<String> args) async {
  _ws = await WebSocket.connect(args[0]);
  _ws.listen((data) {
    final m = jsonDecode(data as String) as Map<String, Object?>;
    if (m['id'] is int) _pending.remove(m['id'])?.complete(m);
  });
  await cdp('Runtime.enable');
  await cdp('Page.enable');
  if (args[1] == 'run') {
    // Roteiro: uma linha por comando (mesma sintaxe da CLI); '#' comenta.
    // Argumentos com espaco entre aspas simples. Erro para o roteiro.
    // Frame sync desligado: com animacoes continuas (badge do chat) o tap
    // nunca "assenta" e a extensao nao responde.
    await driver({'command': 'set_frame_sync', 'enabled': 'false'});
    for (final rawLine in File(args[2]).readAsLinesSync()) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = RegExp(r"'([^']*)'|(\S+)")
          .allMatches(line)
          .map((m) => m.group(1) ?? m.group(2)!)
          .toList();
      stdout.writeln('>> $line');
      try {
        await runCommand(parts);
      } on StateError catch (error) {
        // Resposta perdida (o comando em geral executou): segue o roteiro e
        // deixa a captura seguinte provar o estado.
        if (!error.message.contains('sem resposta')) rethrow;
        stdout.writeln('!! ${error.message} (continuando)');
      }
    }
    await _ws.close();
    return;
  }
  await runCommand(args.sublist(1));
  await _ws.close();
}

Future<void> runCommand(List<String> args) async {
  final cmd = args[0];
  args = ['', ...args];
  switch (cmd) {
    case 'pushroute':
      final path = jsonEncode(args[2]);
      final result = await ev('(function(){history.pushState(null,"",$path);window.dispatchEvent(new PopStateEvent("popstate",{state:null}));return location.pathname;})()');
      stdout.writeln('route $result');
    case 'goto':
      await cdp('Page.navigate', {'url': args[2]});
      await waitDriver();
      await driver({'command': 'set_frame_sync', 'enabled': 'false'});
      stdout.writeln('goto ok');
    case 'url':
      stdout.writeln(await ev('location.href'));
    case 'shot':
      final r = await cdp('Page.captureScreenshot', {'format': 'png'});
      final data = (r['result'] as Map<String, Object?>)['data'] as String;
      File(args[2]).writeAsBytesSync(base64Decode(data));
      stdout.writeln('shot ${args[2]}');
    case 'sleep':
      await Future<void>.delayed(Duration(milliseconds: int.parse(args[2])));
    case 'eval':
      stdout.writeln(jsonEncode(await ev(args.sublist(2).join(' '))));
    case 'login':
      final lines = File(args[2]).readAsLinesSync();
      String? email, password;
      for (final line in lines) {
        final i = line.indexOf('=');
        if (i < 0) continue;
        final k = line.substring(0, i).trim();
        final v = line.substring(i + 1).trim().replaceAll(RegExp(r'^"|"$'), '');
        if (k == 'QA_EMAIL') email = v;
        if (k == 'QA_PASSWORD') password = v;
      }
      if (email == null || password == null) {
        stderr.writeln('arquivo sem QA_EMAIL/QA_PASSWORD');
        exit(2);
      }
      await waitDriver();
      await driver({'command': 'set_frame_sync', 'enabled': 'false'});
      await driver({'command': 'waitFor', ...key('superadmin-login-email'), 'timeout': '30000'});
      await driver({'command': 'tap', ...key('superadmin-login-email')});
      await driver({'command': 'enter_text', 'text': email});
      await driver({'command': 'tap', ...key('superadmin-login-password')});
      await driver({'command': 'enter_text', 'text': password});
      await driver({'command': 'tap', ...text('Entrar')});
      await driver({'command': 'waitForAbsent', ...key('superadmin-login-email'), 'timeout': '40000'});
      stdout.writeln('login ok (${email.replaceAll(RegExp(r'^[^@]*'), '***')})');
    case 'tapkey':
      await driver({'command': 'tap', ...key(args[2]), 'timeout': '15000'});
      stdout.writeln('tap ${args[2]}');
    case 'taptext':
      await driver({'command': 'tap', ...text(args.sublist(2).join(' ')), 'timeout': '15000'});
      stdout.writeln('tap text ok');
    case 'tapsem':
      await driver({'command': 'tap', ...sem(args.sublist(2).join(' ')), 'timeout': '15000'});
      stdout.writeln('tap sem ok');
    case 'typekey':
      await driver({'command': 'tap', ...key(args[2]), 'timeout': '15000'});
      await driver({'command': 'enter_text', 'text': args.sublist(3).join(' ')});
      stdout.writeln('type ${args[2]} ok');
    case 'typesem':
      await driver({'command': 'tap', ...sem(args[2]), 'timeout': '15000'});
      await driver({'command': 'enter_text', 'text': args.sublist(3).join(' ')});
      stdout.writeln('type sem ok');
    case 'taptooltip':
      await driver({'command': 'tap', 'finderType': 'ByTooltipMessage', 'text': args.sublist(2).join(' '), 'timeout': '15000'});
      stdout.writeln('tap tooltip ok');
    case 'texts':
      final r = await driver({'command': 'get_text', ...sem(args.sublist(2).join(' ')), 'timeout': '15000'});
      stdout.writeln(r['text']);
    case 'semantics':
      await driver({'command': 'set_semantics', 'enabled': 'true'});
      stdout.writeln('semantics on');
    case 'enter':
      await driver({'command': 'enter_text', 'text': args.sublist(2).join(' ')});
      stdout.writeln('enter ok');
    case 'clickxy':
      final x = double.parse(args[2]);
      final y = double.parse(args[3]);
      for (final type in ['mouseMoved', 'mousePressed', 'mouseReleased']) {
        await cdp('Input.dispatchMouseEvent', {
          'type': type,
          'x': x,
          'y': y,
          'button': type == 'mouseMoved' ? 'none' : 'left',
          'clickCount': 1,
        });
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
      stdout.writeln('click $x,$y');
    case 'text':
      final r = await driver({'command': 'get_text', ...key(args[2]), 'timeout': '15000'});
      stdout.writeln(r['text']);
    case 'waitkey':
      await driver({'command': 'waitFor', ...key(args[2]), 'timeout': args.length > 3 ? args[3] : '20000'});
      stdout.writeln('wait ${args[2]} ok');
    case 'waittext':
      await driver({'command': 'waitFor', ...text(args[2]), 'timeout': args.length > 3 ? args[3] : '20000'});
      stdout.writeln('wait text ok');
    case 'absentkey':
      await driver({'command': 'waitForAbsent', ...key(args[2]), 'timeout': args.length > 3 ? args[3] : '20000'});
      stdout.writeln('absent ${args[2]} ok');
    case 'scrollkey':
      await driver({'command': 'scrollIntoView', ...key(args[2]), 'alignment': '0.5', 'timeout': '15000'});
      stdout.writeln('scroll ${args[2]} ok');
    default:
      stderr.writeln('comando desconhecido: $cmd');
      exit(2);
  }
}
