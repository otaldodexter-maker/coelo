// Retained synthetic call only. The after mode aborts every Supabase request
// while reproducing the banner with a native click. Inspect before/after version.
// Earlier diagnostic attempts changed versions; see R12-checkpoint.md.
const fs = require('node:fs');
(async () => {
  if (!['after', 'inspect', 'restore'].includes(process.argv[2])) throw Error('Use after, inspect or restore');
  const pages = await (await fetch('http://127.0.0.1:9427/json')).json();
  const page = pages.find(p => p.type === 'page' && p.url.includes('/attendance/calls/53006a48-cadd-406d-80d9-4cd77454bcd5'));
  if (!page) throw Error('Expected retained synthetic call route');
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise(r => ws.onopen = r);
  let id = 0;
  let aborted = 0;
  const pending = new Map();
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const n = ++id; pending.set(n, {resolve, reject}); ws.send(JSON.stringify({id:n, method, params}));
  });
  ws.onmessage = e => {
    const d = JSON.parse(e.data);
    if (d.method === 'Fetch.requestPaused') {
      aborted++;
      void send('Fetch.failRequest', {requestId:d.params.requestId, errorReason:'Failed'});
    }
    if (d.id && pending.has(d.id)) {
      const p = pending.get(d.id); pending.delete(d.id);
      d.error ? p.reject(Error(d.error.message)) : p.resolve(d.result);
    }
  };
  const evaluate = async expression => (await send('Runtime.evaluate', {expression, awaitPromise:true, returnByValue:true})).result?.value;
  const shot = async name => {
    const r = await send('Page.captureScreenshot',{format:'png'});
    fs.writeFileSync(`C:/Users/adrie/Documents/Coelo-backups/r12-error-${process.argv[2]}-${name}.png`, Buffer.from(r.data,'base64'));
  };
  try {
    if (process.argv[2] === 'inspect' || process.argv[2] === 'restore') {
      const config = JSON.parse(fs.readFileSync('C:/Users/adrie/Documents/Coelo-backups/r12-public-build-config.json','utf8'));
      const restore = process.argv[2] === 'restore';
      const result = await evaluate(`(async()=>{
        const session=JSON.parse(localStorage.getItem('coelo.superadmin.auth.session'));
        const token=session?.access_token ?? session?.currentSession?.access_token;
        if(!token) return {error:'session shape unavailable',keys:Object.keys(session||{})};
        const rpc=async(name,body)=>{
          const r=await fetch(${JSON.stringify(config.COELO_SUPABASE_URL)}+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:${JSON.stringify(config.COELO_SUPABASE_PUBLISHABLE_KEY)},Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify(body)});
          const data=await r.json(); if(!r.ok) throw Error('RPC '+name+' HTTP '+r.status); return data;
        };
        const callId='53006a48-cadd-406d-80d9-4cd77454bcd5';
        let call=await rpc('superadmin_attendance_call_detail',{p_call_id:callId});
        if(${restore} && call.status==='closed') call=await rpc('superadmin_attendance_reopen_call',{p_call_id:callId,p_expected_version:call.version,p_reason:'R12 QA: restaurar chamada sintética após reprodução do alerta'});
        return {id:call.id,status:call.status,version:call.version,canManage:call.can_manage,keys:Object.keys(call)};
      })()`);
      console.log(JSON.stringify(result));
      return;
    }
    await send('Network.setBypassServiceWorker', {bypass:true});
    await send('Fetch.enable', {patterns:[{urlPattern:'*supabase.co/*', requestStage:'Request'}]});
    for(const type of ['mousePressed','mouseReleased']) await send('Input.dispatchMouseEvent',{type,x:1316,y:950,button:'left',clickCount:1});
    await new Promise(r=>setTimeout(r,2500));
    if (!aborted) throw Error('No RPC request intercepted; cannot certify browser failure');
    await shot('desktop');
    await send('Emulation.setDeviceMetricsOverride',{width:375,height:900,deviceScaleFactor:1,mobile:false});
    await new Promise(r=>setTimeout(r,700));
    await shot('mobile');
    await send('Input.dispatchKeyEvent',{type:'keyDown',key:'Tab',code:'Tab',windowsVirtualKeyCode:9});
    await send('Input.dispatchKeyEvent',{type:'keyUp',key:'Tab',code:'Tab',windowsVirtualKeyCode:9});
    await shot('keyboard');
    console.log(`Captured browser failure at desktop/mobile and keyboard traversal; ${aborted} RPC request(s) aborted. Verify rendered error and recovery separately.`);
  } finally {
    await send('Fetch.disable');
    ws.close();
  }
})().catch(e=>{console.error(e.message);process.exitCode=1});
