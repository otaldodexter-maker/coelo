// Driver mínimo do Chrome DevTools Protocol para provar a rota real do app Flutter web.
// uso: node cdp.js <comando> [args]  — comandos: shot <arquivo>, eval <js>, click <x> <y>, type <texto>, key <Enter|Tab>, sem, nodes [filtro], clicksem <texto-do-label>, nav <url>, wait <ms>
const fs = require('fs');
const PORT = process.env.CDP_PORT || '9333';
async function target() {
  const list = await (await fetch(`http://127.0.0.1:${PORT}/json`)).json();
  const page = list.find((t) => t.type === 'page' && /3006/.test(t.url)) || list.find((t) => t.type === 'page');
  if (!page) throw new Error('página não encontrada');
  return page.webSocketDebuggerUrl;
}
async function session() {
  const ws = new WebSocket(await target());
  await new Promise((r, j) => { ws.onopen = r; ws.onerror = j; });
  let id = 0; const pending = new Map();
  ws.onmessage = (m) => { const d = JSON.parse(m.data); if (d.id && pending.has(d.id)) { pending.get(d.id)(d); pending.delete(d.id); } };
  const send = (method, params = {}) => new Promise((res, rej) => { const i = ++id; pending.set(i, (d) => d.error ? rej(new Error(JSON.stringify(d.error))) : res(d.result)); ws.send(JSON.stringify({ id: i, method, params })); });
  return { send, close: () => ws.close() };
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function evalJs(s, expr) { const r = await s.send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true }); return r.result.value; }
// nós semânticos do Flutter web (após ligar a semântica)
const NODES_JS = `(() => { const out=[]; const els=document.querySelectorAll('flt-semantics, [role]'); for (const e of els) { const r=e.getBoundingClientRect(); if (r.width<2||r.height<2) continue; const label=e.getAttribute('aria-label')||e.getAttribute('flt-semantics-label')||e.textContent.trim().slice(0,80)||''; const role=e.getAttribute('role')||e.tagName.toLowerCase(); const tf=e.querySelector('input,textarea'); out.push({label, role, x:Math.round(r.x+r.width/2), y:Math.round(r.y+r.height/2), w:Math.round(r.width), h:Math.round(r.height), input: !!tf}); } return out; })()`;
async function enableSemantics(s) {
  // o placeholder de acessibilidade do Flutter web fica no canto; clicar nele liga a árvore semântica
  await evalJs(s, `(() => { const p=document.querySelector('flt-semantics-placeholder'); if(p){ p.click(); return 'placeholder'; } return 'none'; })()`);
  await sleep(800);
}
async function click(s, x, y) {
  await s.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
  await s.send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
  await s.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
}
async function nodes(s, filter) { let n = await evalJs(s, NODES_JS); if (!n.length) { await enableSemantics(s); n = await evalJs(s, NODES_JS); } if (filter) n = n.filter((x) => (x.label + ' ' + x.role).toLowerCase().includes(filter.toLowerCase())); return n; }
(async () => {
  const [cmd, ...args] = process.argv.slice(2);
  const s = await session();
  try {
    await s.send('Page.enable'); await s.send('Runtime.enable');
    switch (cmd) {
      case 'shot': { const r = await s.send('Page.captureScreenshot', { format: 'png' }); fs.writeFileSync(args[0], Buffer.from(r.data, 'base64')); console.log('ok', args[0]); break; }
      case 'eval': console.log(JSON.stringify(await evalJs(s, args.join(' ')))); break;
      case 'click': await click(s, Number(args[0]), Number(args[1])); console.log('clicked'); break;
      case 'type': await s.send('Input.insertText', { text: args.join(' ') }); console.log('typed'); break;
      case 'key': { const key = args[0]; const code = key === 'Enter' ? 13 : key === 'Tab' ? 9 : key === 'Escape' ? 27 : 0; await s.send('Input.dispatchKeyEvent', { type: 'keyDown', key, code: key, windowsVirtualKeyCode: code, nativeVirtualKeyCode: code }); await s.send('Input.dispatchKeyEvent', { type: 'keyUp', key, code: key, windowsVirtualKeyCode: code, nativeVirtualKeyCode: code }); console.log('key', key); break; }
      case 'sem': console.log(await enableSemantics(s)); break;
      case 'nodes': { const n = await nodes(s, args[0]); for (const x of n) console.log(`${x.role}\t${x.x},${x.y}\t${x.w}x${x.h}\t${x.input ? '[input] ' : ''}${x.label}`); break; }
      case 'clicksem': { const n = await nodes(s, args.join(' ')); if (!n.length) { console.log('não achou'); process.exit(2); } await click(s, n[0].x, n[0].y); console.log('clicked', n[0].label, n[0].x, n[0].y); break; }
      case 'nav': await s.send('Page.navigate', { url: args[0] }); await sleep(3000); console.log('nav', args[0]); break;
      case 'url': console.log(await evalJs(s, 'location.href')); break;
      case 'wait': await sleep(Number(args[0])); break;
      default: console.log('comando?');
    }
  } finally { s.close(); }
})().catch((e) => { console.error('erro', e.message); process.exit(1); });
