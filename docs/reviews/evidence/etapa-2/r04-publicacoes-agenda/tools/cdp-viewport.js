(async()=>{ const list=await (await fetch('http://127.0.0.1:'+(process.env.CDP_PORT||'9333')+'/json')).json(); const page=list.find(t=>t.type==='page'&&/3006/.test(t.url)); const ws=new WebSocket(page.webSocketDebuggerUrl); await new Promise(r=>ws.onopen=r);
 const w=Number(process.argv[2]||1024), h=Number(process.argv[3]||900);
 ws.onmessage=(m)=>{const d=JSON.parse(m.data); if(d.id===1){ console.log('viewport', w, h, JSON.stringify(d.error||'ok')); setTimeout(()=>{ws.close();process.exit(0)},300);} };
 ws.send(JSON.stringify({id:1,method:'Emulation.setDeviceMetricsOverride',params:{width:w,height:h,deviceScaleFactor:1,mobile:false}})); setTimeout(()=>{console.log('timeout');process.exit(1)},10000); })();
