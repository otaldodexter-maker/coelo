// Mantem Network.setBlockedURLs ativo por N segundos na pagina (sessao propria).
// Uso: cdp_block <ws> <padrao> <segundos>
import 'dart:async';
import 'dart:convert';
import 'dart:io';
Future<void> main(List<String> args) async {
  final ws = await WebSocket.connect(args[0]);
  var id = 0; final pending = <int, Completer<Map<String, Object?>>>{};
  ws.listen((d) { final m = jsonDecode(d as String) as Map<String, Object?>; if (m['id'] is int) pending.remove(m['id'])?.complete(m); });
  Future<Map<String, Object?>> cdp(String method, [Map<String, Object?> p = const {}]) { final i = ++id; final c = Completer<Map<String, Object?>>(); pending[i] = c; ws.add(jsonEncode({'id': i, 'method': method, 'params': p})); return c.future.timeout(const Duration(seconds: 30)); }
  await cdp('Network.enable');
  await cdp('Network.setBlockedURLs', {'urls': [args[1]]});
  stdout.writeln('bloqueado ${args[1]} por ${args[2]}s');
  await Future<void>.delayed(Duration(seconds: int.parse(args[2])));
  await cdp('Network.setBlockedURLs', {'urls': <String>[]});
  stdout.writeln('desbloqueado');
  await ws.close();
}
