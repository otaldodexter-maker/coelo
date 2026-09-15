// Intercepta o seletor de arquivo do Chrome via CDP e injeta um arquivo real
// do disco: Page.setInterceptFileChooserDialog + Page.fileChooserOpened +
// DOM.setFileInputFiles. Uso: cdp_filechooser <ws> <arquivo> [segundos]
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final ws = await WebSocket.connect(args[0]);
  final file = args[1];
  final wait = int.parse(args.length > 2 ? args[2] : '60');
  var id = 0;
  final pending = <int, Completer<Map<String, Object?>>>{};
  final opened = Completer<Map<String, Object?>>();
  ws.listen((data) {
    final m = jsonDecode(data as String) as Map<String, Object?>;
    if (m['id'] is int) pending.remove(m['id'])?.complete(m);
    if (m['method'] == 'Page.fileChooserOpened' && !opened.isCompleted) {
      opened.complete(m['params'] as Map<String, Object?>);
    }
  });
  Future<Map<String, Object?>> cdp(String method, [Map<String, Object?> p = const {}]) {
    final i = ++id;
    final c = Completer<Map<String, Object?>>();
    pending[i] = c;
    ws.add(jsonEncode({'id': i, 'method': method, 'params': p}));
    return c.future.timeout(const Duration(seconds: 30));
  }
  await cdp('Page.enable');
  await cdp('DOM.enable');
  await cdp('Page.setInterceptFileChooserDialog', {'enabled': true});
  stdout.writeln('intercept armado; aguardando seletor por ${wait}s');
  try {
    final ev = await opened.future.timeout(Duration(seconds: wait));
    stdout.writeln('fileChooserOpened: mode=${ev['mode']} backendNodeId=${ev['backendNodeId']}');
    final r = await cdp('DOM.setFileInputFiles', {
      'files': [file],
      if (ev['backendNodeId'] != null) 'backendNodeId': ev['backendNodeId'],
    });
    stdout.writeln('setFileInputFiles: ${jsonEncode(r)}');
  } on TimeoutException {
    stdout.writeln('seletor nao abriu');
  } finally {
    await cdp('Page.setInterceptFileChooserDialog', {'enabled': false});
    await ws.close();
  }
}
