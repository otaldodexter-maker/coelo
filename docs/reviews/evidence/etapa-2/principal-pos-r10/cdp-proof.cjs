const fs = require('node:fs');
(async()=>{
 const pages=await(await fetch('http://127.0.0.1:9426/json')).json();const page=pages.find(p=>p.type==='page'&&/:(3000|3016)\//.test(p.url));
 const ws=new WebSocket(page.webSocketDebuggerUrl);await new Promise(r=>ws.onopen=r);let id=0;const pending=new Map();let chooser;let observe;
 ws.onmessage=e=>{const d=JSON.parse(e.data);if(d.id){const p=pending.get(d.id);if(p){pending.delete(d.id);d.error?p.reject(Error(JSON.stringify(d.error))):p.resolve(d.result)}}else if(observe&&d.method?.startsWith('Network.'))observe(d);else if(d.method==='Page.fileChooserOpened'&&chooser)chooser(d.params)};
 const send=(method,params={})=>new Promise((resolve,reject)=>{const n=++id;pending.set(n,{resolve,reject});ws.send(JSON.stringify({id:n,method,params}))});
 const click=async(x,y)=>{for(const type of ['mousePressed','mouseReleased'])await send('Input.dispatchMouseEvent',{type,x,y,button:'left',clickCount:1})};
 try{
 if(process.argv[2]==='retry-log'){
  const paths=new Map();const out=[];observe=d=>{const p=d.params;if(d.method==='Network.requestWillBeSent')paths.set(p.requestId,new URL(p.request.url).pathname);if(d.method==='Network.responseReceived')out.push({path:paths.get(p.requestId),status:p.response.status});if(d.method==='Network.loadingFailed')out.push({path:paths.get(p.requestId),error:p.errorText,cors:p.corsErrorStatus?.corsError})};
  await send('Network.enable');await click(1273,836);await new Promise(r=>setTimeout(r,12000));fs.writeFileSync(process.argv[3],JSON.stringify(out,null,2));console.log('sanitized network log saved');
 }
 if(process.argv[2]==='scroll'){await send('Input.dispatchMouseEvent',{type:'mouseWheel',x:650,y:650,deltaX:0,deltaY:+process.argv[3]});console.log('scrolled')}
 if(process.argv[2]==='viewport'){await send('Emulation.setDeviceMetricsOverride',{width:+process.argv[3],height:+process.argv[4],deviceScaleFactor:1,mobile:false});console.log('viewport set')}
 if(process.argv[2]==='upload'){
  await send('Page.enable');await send('Page.setInterceptFileChooserDialog',{enabled:true});
  const picked=new Promise((resolve,reject)=>{chooser=resolve;setTimeout(()=>reject(Error('No normal file chooser event')),10000)});
  await click(+process.argv[3],+process.argv[4]);const event=await picked;
  await send('DOM.setFileInputFiles',{backendNodeId:event.backendNodeId,files:process.argv.slice(5)});console.log('normal picker supplied synthetic files');
  await send('Page.setInterceptFileChooserDialog',{enabled:false});
 }
 }finally{ws.close()}
})().catch(e=>{console.error(e.message);process.exitCode=1});
