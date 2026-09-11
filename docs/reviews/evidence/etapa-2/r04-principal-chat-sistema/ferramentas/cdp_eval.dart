// Avalia expressoes JS na pagina via CDP (somente leitura/diagnostico).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
Future<void> main(List<String> args) async {
  final ws = await WebSocket.connect(args[0]);
  var id = 0;
  final pending = <int, Completer<Map<String, Object?>>>{};
  ws.listen((d) { final m = jsonDecode(d as String) as Map<String, Object?>; final i = m['id']; if (i is int) pending.remove(i)?.complete(m); });
  for (final expr in args.skip(1)) {
    final c = Completer<Map<String, Object?>>(); pending[++id] = c;
    ws.add(jsonEncode({'id': id, 'method': 'Runtime.evaluate', 'params': {'expression': expr, 'returnByValue': true, 'awaitPromise': true}}));
    final r = await c.future.timeout(const Duration(seconds: 30));
    final res = (r['result'] as Map?)?['result'] as Map?;
    stdout.writeln('$expr => ${res?['value'] ?? res?['description'] ?? r}');
  }
  await ws.close();
}
