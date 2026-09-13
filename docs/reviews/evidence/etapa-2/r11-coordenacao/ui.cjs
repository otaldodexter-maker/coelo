const fs = require('node:fs');
(async () => {
  const args = process.argv.slice(2);
  const auth = args[0] === 'auth';
  if (auth) args.shift();
  const pages = await (await fetch('http://127.0.0.1:9427/json')).json();
  const authTargetFile='C:/Users/adrie/Documents/Coelo-backups/r11-auth-target.txt';
  const authPath = p => /^\/(login|forgot-password|reset-password|recover)/.test(new URL(p.url).pathname);
  const page = pages.find(p => p.type === 'page' && p.url.startsWith('http://127.0.0.1:3000') && (auth ? authPath(p) : !authPath(p)));
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise(r => ws.onopen = r);
  let id = 0; const pending = new Map();
  ws.onmessage = e => { const d = JSON.parse(e.data); if (d.id && pending.has(d.id)) { const p = pending.get(d.id); pending.delete(d.id); d.error ? p.reject(Error(d.error.message)) : p.resolve(d.result); } };
  const send = (method, params = {}) => new Promise((resolve, reject) => { const n = ++id; pending.set(n, {resolve,reject}); ws.send(JSON.stringify({id:n,method,params})); });
  const evaluate = async expression => (await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true})).result?.value;
  const driver = async command => {
    await evaluate(`window.$flutterDriverResult=null; window.$flutterDriver(${JSON.stringify(JSON.stringify(command))}); true`);
    for(let n=0;n<100;n++) {
      const raw=await evaluate('window.$flutterDriverResult');
      if(typeof raw==='string') {const result=JSON.parse(raw); if(result.isError) throw Error(`Driver failed: ${command.command}`); return 'Driver completed';}
      await new Promise(r=>setTimeout(r,150));
    }
    throw Error(`Driver timed out: ${command.command}`);
  };
  try {
    await send('Page.bringToFront');
    await send('Emulation.setFocusEmulationEnabled',{enabled:true});
    const browserWindow=await send('Browser.getWindowForTarget');
    await send('Browser.setWindowBounds',{windowId:browserWindow.windowId,bounds:{windowState:'normal'}});
    if (args[0] === 'auth-context') {
      const context=await send('Target.createBrowserContext');
      const target=await send('Target.createTarget',{url:'http://127.0.0.1:3000/login',browserContextId:context.browserContextId});
      fs.writeFileSync(authTargetFile,target.targetId); console.log('Isolated Auth QA tab created; shared session preserved');
    }
    if (args[0] === 'shot') { const r = await send('Page.captureScreenshot',{format:'png'}); fs.writeFileSync(args[1],Buffer.from(r.data,'base64')); console.log('Screenshot saved'); }
    if (args[0] === 'viewport') await send('Emulation.setDeviceMetricsOverride',{width:+args[1],height:+args[2],deviceScaleFactor:1,mobile:false});
    if (args[0] === 'click') { const x=+args[1],y=+args[2]; await send('Input.dispatchMouseEvent',{type:'mouseMoved',x,y}); await new Promise(r=>setTimeout(r,300)); for(const type of ['mousePressed','mouseReleased']) {await send('Input.dispatchMouseEvent',{type,x,y,button:'left',clickCount:1}); await new Promise(r=>setTimeout(r,250));} }
    if (args[0] === 'scroll') await send('Input.dispatchMouseEvent',{type:'mouseWheel',x:+args[1],y:+args[2],deltaX:0,deltaY:+args[3]});
    if (args[0] === 'sync') console.log(await driver({command:'set_frame_sync',enabled:'false'}));
    if (args[0] === 'text') console.log(await driver({command:'enter_text',text:args[1]}));
    if (args[0] === 'native-text') await send('Input.insertText',{text:args[1]});
    if (args[0] === 'reveal') console.log(await driver({command:'scrollIntoView',finderType:'ByValueKey',keyValueString:args[1],keyValueType:'String',alignment:'0.5'}));
    if (args[0] === 'key') {console.log(await driver({command:'tap',finderType:'ByValueKey',keyValueString:args[1],keyValueType:'String'})); await new Promise(r=>setTimeout(r,1200));}
    if (args[0] === 'select-all') { await send('Input.dispatchKeyEvent',{type:'keyDown',key:'a',code:'KeyA',windowsVirtualKeyCode:65,modifiers:2}); await send('Input.dispatchKeyEvent',{type:'keyUp',key:'a',code:'KeyA',windowsVirtualKeyCode:65,modifiers:2}); }
    if (args[0] === 'tree') console.log(await driver({command:'get_semantics_tree'}));
    if (args[0] === 'tap-text') console.log(await driver({command:'tap',finderType:'ByText',text:args[1]}));
    if (args[0] === 'diagnostic') console.log(await evaluate(`JSON.stringify({width:innerWidth,height:innerHeight,dpr:devicePixelRatio,viewport:visualViewport?.scale,driver:typeof window.$flutterDriver,result:window.$flutterDriverResult,active:document.activeElement?.tagName,inputs:[...document.querySelectorAll('input')].map(e=>({type:e.type,focused:e===document.activeElement,length:e.value.length}))})`));
    if (args[0] === 'reload') await send('Page.reload',{ignoreCache:true});
    if (args[0] === 'goto') await send('Page.navigate',{url:'http://127.0.0.1:3000'+args[1]});
    if (args[0] === 'login-text') {
      const env = Object.fromEntries(fs.readFileSync('C:/Users/adrie/Documents/Coelo-backups/qa-r03.env','utf8').split(/\r?\n/).filter(l=>l.includes('=')).map(l=>{const n=l.indexOf('=');return[l.slice(0,n),l.slice(n+1).replace(/^['"]|['"]$/g,'')]}));
      const key=Object.keys(env).find(k=>new RegExp(args[1],'i').test(k)); if(!key) throw Error('QA field unavailable');
      await send('Input.insertText',{text:env[key]}); console.log('Private QA field entered');
    }
  } finally { ws.close(); }
})().catch(e=>{console.error(e.message);process.exitCode=1});
