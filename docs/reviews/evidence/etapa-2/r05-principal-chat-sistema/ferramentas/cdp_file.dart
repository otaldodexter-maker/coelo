// Intercepta o seletor de arquivo da pagina e entrega um arquivo (CDP).
// Uso: dart run cdp_file.dart <ws> <x> <y> <caminho do arquivo>
import 'dart:async';
import 'dart:convert';
import 'dart:io';
Future<void> main(List<String> args) async {
  final ws = await WebSocket.connect(args[0]);
  var id = 0;
  final pending = <int, Completer<Map<String, Object?>>>{};
  final chooser = Completer<Map<String, Object?>>();
  ws.listen((d) {
    final m = jsonDecode(d as String) as Map<String, Object?>;
    final i = m['id'];
    if (i is int) pending.remove(i)?.complete(m);
    if (m['method'] == 'Page.fileChooserOpened' && !chooser.isCompleted) chooser.complete(m['params'] as Map<String, Object?>);
  });
  Future<Map<String, Object?>> call(String method, [Map<String, Object?> params = const {}]) {
    final c = Completer<Map<String, Object?>>(); pending[++id] = c;
    ws.add(jsonEncode({'id': id, 'method': method, 'params': params}));
    return c.future.timeout(const Duration(seconds: 30));
  }
  await call('Page.enable');
  await call('Page.setInterceptFileChooserDialog', {'enabled': true});
  final x = double.parse(args[1]), y = double.parse(args[2]);
  for (final type in ['mouseMoved', 'mousePressed', 'mouseReleased']) {
    await call('Input.dispatchMouseEvent', {'type': type, 'x': x, 'y': y, 'button': 'left', 'clickCount': 1});
  }
  final ev = await chooser.future.timeout(const Duration(seconds: 15));
  stdout.writeln('fileChooserOpened: mode=${ev['mode']} backendNodeId=${ev['backendNodeId']}');
  final r = await call('DOM.setFileInputFiles', {'backendNodeId': ev['backendNodeId'], 'files': [args[3]]});
  stdout.writeln('setFileInputFiles => ${r['result'] ?? r['error']}');
  await call('Page.setInterceptFileChooserDialog', {'enabled': false});
  await ws.close();
}
