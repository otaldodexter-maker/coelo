// Fallback sem flutter_driver: dirige o app web pela arvore de semantica do
// Flutter (flt-semantics) via CDP. Uso:
//   cdp_sem.dart <ws> enable            liga a semantica (placeholder)
//   cdp_sem.dart <ws> dump              lista nos com label/valor/rect
//   cdp_sem.dart <ws> click <trecho>    clica no centro do no cujo label/valor contem o trecho
//   cdp_sem.dart <ws> clickxy <x> <y>
//   cdp_sem.dart <ws> type <texto>      insere texto no elemento focado
//   cdp_sem.dart <ws> key <Enter|Tab|Escape>
//   cdp_sem.dart <ws> goto <url> | reload | url | shot <png> | eval <js> | texts
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
  return c.future.timeout(const Duration(seconds: 60));
}

Future<Object?> ev(String expr) async {
  final r = await cdp('Runtime.evaluate', {
    'expression': expr,
    'returnByValue': true,
    'awaitPromise': true,
  });
  final res = r['result'] as Map<String, Object?>?;
  final inner = res?['result'] as Map<String, Object?>?;
  if (res?['exceptionDetails'] != null) {
    throw StateError('JS: ${jsonEncode(res!['exceptionDetails'])}');
  }
  return inner?['value'];
}

const _dumpJs = r'''
(() => {
  const out = [];
  const nodes = document.querySelectorAll('flt-semantics, flt-semantics-host [role], flt-semantics-host input, flt-semantics-host textarea');
  const seen = new Set();
  for (const n of nodes) {
    if (seen.has(n)) continue;
    seen.add(n);
    const r = n.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) continue;
    const label = n.getAttribute('aria-label') || '';
    const isInput = n.tagName === 'INPUT' || n.tagName === 'TEXTAREA';
    const value = isInput ? (n.value || '') : (n.getAttribute('aria-valuetext') || '');
    let text = '';
    for (const c of n.childNodes) if (c.nodeType === 3) text += c.textContent;
    const role = n.getAttribute('role') || (isInput ? 'textbox' : '');
    if (!label && !value && !text && !role) continue;
    out.push({id: n.id, tag: n.tagName, role, label, value, text: text.trim(),
      x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height)});
  }
  return JSON.stringify(out);
})()
''';

Future<List<Map<String, Object?>>> dump() async {
  final raw = await ev(_dumpJs) as String;
  return (jsonDecode(raw) as List).cast<Map<String, Object?>>();
}

Future<void> clickAt(num x, num y) async {
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
}

Future<void> waitApp() async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(seconds: 2));
    final ready = await ev(
      'document.querySelector("flutter-view") !== null && document.readyState === "complete"',
    );
    if (ready == true) {
      await Future<void>.delayed(const Duration(seconds: 3));
      return;
    }
  }
  throw TimeoutException('app nao carregou');
}

Future<void> main(List<String> args) async {
  _ws = await WebSocket.connect(args[0]);
  _ws.listen((d) {
    final m = jsonDecode(d as String) as Map<String, Object?>;
    final i = m['id'];
    if (i is int) _pending.remove(i)?.complete(m);
  });
  try {
    switch (args[1]) {
      case 'enable':
        final has = await ev('!!document.querySelector("flt-semantics-placeholder")');
        if (has == true) {
          final r = jsonDecode(await ev(
            'JSON.stringify(document.querySelector("flt-semantics-placeholder").getBoundingClientRect())',
          ) as String) as Map;
          await clickAt((r['x'] as num) + 2, (r['y'] as num) + 2);
          await Future<void>.delayed(const Duration(seconds: 2));
        }
        final count = await ev('document.querySelectorAll("flt-semantics").length');
        stdout.writeln('semantica: $count nos');
      case 'dump':
        for (final n in await dump()) {
          stdout.writeln(
            '${n['tag']}/${n['role']}\t${n['label']}\t${n['value']}\t${n['text']}\t@${n['x']},${n['y']} ${n['w']}x${n['h']}',
          );
        }
      case 'click':
        final needle = args.sublist(2).join(' ').toLowerCase();
        final nodes = await dump();
        final hit = nodes
            .where((n) => '${n['label']} ${n['text']} ${n['value']}'.toLowerCase().contains(needle))
            .toList();
        if (hit.isEmpty) {
          stderr.writeln('nao achei "$needle"');
          exit(1);
        }
        final n = hit.first;
        await clickAt((n['x'] as num) + (n['w'] as num) / 2, (n['y'] as num) + (n['h'] as num) / 2);
        stdout.writeln('click: ${n['label']}${n['text']} @${n['x']},${n['y']} (${hit.length} candidatos)');
      case 'clickxy':
        await clickAt(num.parse(args[2]), num.parse(args[3]));
        stdout.writeln('click @${args[2]},${args[3]}');
      case 'type':
        await cdp('Input.insertText', {'text': args.sublist(2).join(' ')});
        stdout.writeln('type: ok');
      case 'key':
        final k = args[2];
        final code = {'Enter': 13, 'Tab': 9, 'Escape': 27}[k] ?? 0;
        for (final t in ['keyDown', 'keyUp']) {
          await cdp('Input.dispatchKeyEvent', {
            'type': t,
            'key': k,
            'code': k,
            'windowsVirtualKeyCode': code,
            'nativeVirtualKeyCode': code,
          });
        }
        stdout.writeln('key: $k');
      case 'goto':
        await cdp('Page.navigate', {'url': args[2]});
        await waitApp();
        stdout.writeln(await ev('location.href'));
      case 'reload':
        await cdp('Page.reload', {'ignoreCache': false});
        await waitApp();
        stdout.writeln(await ev('location.href'));
      case 'url':
        stdout.writeln(await ev('location.href'));
      case 'eval':
        stdout.writeln(await ev(args.sublist(2).join(' ')));
      case 'texts':
        final nodes = await dump();
        stdout.writeln(
          nodes.map((n) => '${n['label']}${n['text']}${n['value']}').where((s) => s.isNotEmpty).join(' | '),
        );
      case 'shot':
        final r = await cdp('Page.captureScreenshot', {'format': 'png'});
        final data = (r['result'] as Map)['data'] as String;
        File(args[2]).writeAsBytesSync(base64Decode(data));
        stdout.writeln('screenshot: ${args[2]}');
      default:
        stderr.writeln('comando desconhecido');
        exit(2);
    }
  } finally {
    await _ws.close();
  }
}
