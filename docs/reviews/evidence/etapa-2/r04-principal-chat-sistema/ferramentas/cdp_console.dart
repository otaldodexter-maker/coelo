// Recarrega a pagina e captura console e excecoes por alguns segundos (diagnostico).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
Future<void> main(List<String> args) async {
  final ws = await WebSocket.connect(args[0]);
  var id = 0;
  void send(String m, [Map<String, Object?> p = const {}]) => ws.add(jsonEncode({'id': ++id, 'method': m, 'params': p}));
  ws.listen((d) {
    final m = jsonDecode(d as String) as Map<String, Object?>;
    final method = m['method'];
    if (method == 'Runtime.consoleAPICalled') {
      final p = m['params'] as Map; final argsList = (p['args'] as List).map((a) => (a as Map)['value'] ?? a['description'] ?? '').join(' ');
      stdout.writeln('[console.${p['type']}] ${argsList.toString().substring(0, argsList.toString().length > 400 ? 400 : argsList.toString().length)}');
    } else if (method == 'Runtime.exceptionThrown') {
      final det = ((m['params'] as Map)['exceptionDetails'] as Map);
      stdout.writeln('[exception] ${det['text']} ${(det['exception'] as Map?)?['description']}'.substring(0, 900));
    }
  });
  send('Runtime.enable'); send('Log.enable');
  await Future<void>.delayed(const Duration(milliseconds: 500));
  send('Page.reload', {'ignoreCache': true});
  await Future<void>.delayed(Duration(seconds: int.parse(args.length > 1 ? args[1] : '20')));
  await ws.close();
}
