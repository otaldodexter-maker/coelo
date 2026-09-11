#!/usr/bin/env bash
# uso: drv.sh command=tap finderType=ByText text=...  (pares chave=valor do qa_drive)
WS=$(curl -s http://127.0.0.1:9333/json | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{const l=JSON.parse(s);const p=l.find(t=>t.type==='page'&&/3006/.test(t.url));console.log(p.webSocketDebuggerUrl)})")
cd /c/Users/adrie/Documents/Coelo.worktrees/e2-r04-publicacoes-agenda/apps/superadmin
timeout 90 dart run test_driver/qa_drive.dart "$WS" cmd "$@" 2>&1 | grep -v 'Running build hooks' | grep -v '^#\|suspension' | tail -2
