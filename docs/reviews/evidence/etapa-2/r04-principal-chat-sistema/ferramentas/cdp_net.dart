// Observa as chamadas de rede da pagina (somente leitura): navega para a URL,
// espera e imprime as respostas de /rest/v1/ e /functions/v1/ com status e
// corpo truncado. Nao imprime cabecalhos (tokens ficam fora da saida).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final ws = await WebSocket.connect(args[0]);
  var id = 0;
  final pending = <int, Completer<Map<String, Object?>>>{};
  final requests = <String, String>{}; // requestId -> url
  final done = <String>[];
  Future<Map<String, Object?>> cdp(String m, [Map<String, Object?> p = const {}]) {
    final c = Completer<Map<String, Object?>>();
    pending[++id] = c;
    ws.add(jsonEncode({'id': id, 'method': m, 'params': p}));
    return c.future.timeout(const Duration(seconds: 30));
  }
  ws.listen((d) {
    final m = jsonDecode(d as String) as Map<String, Object?>;
    final i = m['id'];
    if (i is int) {
      pending.remove(i)?.complete(m);
      return;
    }
    final method = m['method'];
    final p = m['params'] as Map<String, Object?>?;
    if (method == 'Network.requestWillBeSent') {
      final url = ((p!['request'] as Map)['url'] as String);
      if (url.contains('/rest/v1/') || url.contains('/functions/v1/')) {
        requests[p['requestId'] as String] = url;
      }
    } else if (method == 'Network.loadingFinished' || method == 'Network.loadingFailed') {
      final rid = p!['requestId'] as String;
      if (requests.containsKey(rid)) done.add(rid);
    }
  });
  await cdp('Network.enable');
  if (args.length > 1 && args[1] != '-') {
    await cdp('Page.navigate', {'url': args[1]});
  }
  await Future<void>.delayed(Duration(seconds: int.parse(args.length > 2 ? args[2] : '20')));
  for (final rid in done) {
    final url = requests[rid]!;
    final tail = url.replaceFirst(RegExp(r'^https?://[^/]+'), '');
    String body = '';
    var status = '';
    try {
      final r = await cdp('Network.getResponseBody', {'requestId': rid});
      body = ((r['result'] as Map?)?['body'] as String?) ?? '';
    } catch (_) {
      body = '(sem corpo)';
    }
    stdout.writeln('--- $tail $status');
    stdout.writeln(body.length > 700 ? '${body.substring(0, 700)}…' : body);
  }
  if (done.isEmpty) stdout.writeln('(nenhuma chamada REST/Functions observada)');
  await ws.close();
}
