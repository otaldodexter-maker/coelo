(async()=>{ const list=await (await fetch('http://127.0.0.1:'+(process.env.CDP_PORT||'9333')+'/json')).json(); const page=list.find(t=>t.type==='page'&&/3006/.test(t.url)); const ws=new WebSocket(page.webSocketDebuggerUrl); await new Promise(r=>ws.onopen=r);
 const [x,y,dy]=[Number(process.argv[2]),Number(process.argv[3]),Number(process.argv[4]||600)];
 ws.onmessage=(m)=>{const d=JSON.parse(m.data); if(d.id===1){ setTimeout(()=>{ws.close();process.exit(0)},800);} };
 ws.send(JSON.stringify({id:1,method:'Input.dispatchMouseEvent',params:{type:'mouseWheel',x,y,deltaX:0,deltaY:dy}})); setTimeout(()=>{process.exit(1)},10000); })();
