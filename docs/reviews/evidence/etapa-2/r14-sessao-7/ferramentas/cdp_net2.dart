// Observa rede (somente leitura) sem imprimir cabecalhos, query strings nem
// URLs assinadas: /rest/v1/, /functions/v1/ e hosts fora do Supabase (R2).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final ws = await WebSocket.connect(args[0]);
  var id = 0;
  final pending = <int, Completer<Map<String, Object?>>>{};
  final requests = <String, Map<String, String>>{};
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
    if (i is int) { pending.remove(i)?.complete(m); return; }
    final method = m['method'];
    final p = m['params'] as Map<String, Object?>?;
    if (method == 'Network.requestWillBeSent') {
      final req = p!['request'] as Map;
      final url = req['url'] as String;
      if (url.startsWith('http://127.0.0.1') || url.startsWith('data:') || url.contains('fonts.g')) return;
      requests[p['requestId'] as String] = {'url': url, 'method': req['method'] as String};
    } else if (method == 'Network.responseReceived') {
      final rid = p!['requestId'] as String;
      if (requests.containsKey(rid)) requests[rid]!['status'] = ((p['response'] as Map)['status']).toString();
    } else if (method == 'Network.loadingFinished' || method == 'Network.loadingFailed') {
      final rid = p!['requestId'] as String;
      if (requests.containsKey(rid)) { if (method == 'Network.loadingFailed') requests[rid]!['status'] = 'FAILED ${p['errorText']}'; done.add(rid); }
    }
  });
  await cdp('Network.enable');
  await Future<void>.delayed(Duration(seconds: int.parse(args.length > 1 ? args[1] : '30')));
  final redact = RegExp(r'"(signed_url|upload_url|url)"\s*:\s*"[^"]*"');
  for (final rid in done) {
    final r = requests[rid]!;
    final u = Uri.parse(r['url']!);
    final host = u.host.endsWith('supabase.co') ? 'supabase' : (u.host.contains('r2.cloudflarestorage.com') ? 'r2' : u.host);
    final path = host == 'r2' ? '/<objeto-privado>' : u.path;
    String body = '';
    try {
      final res = await cdp('Network.getResponseBody', {'requestId': rid});
      body = ((res['result'] as Map?)?['body'] as String?) ?? '';
    } catch (_) { body = ''; }
    body = body.replaceAllMapped(redact, (m) => '"${m.group(1)}":"<redigido>"');
    stdout.writeln('--- ${r['method']} $host$path -> ${r['status']}');
    if (body.isNotEmpty) stdout.writeln(body.length > 600 ? '${body.substring(0, 600)}…' : body);
  }
  if (done.isEmpty) stdout.writeln('(nenhuma chamada observada)');
  await ws.close();
}
