---
title: "Ferramentas da prova real — R04 publicacoes-agenda"
source: "scratchpad da conversa R04 · Publicações e Agenda"
status: "utilitarios de prova; sem segredo; nao entram no build"
generated_at: "2026-09-11"
---

- `replay-pa.sh`: prova limpa do projeto descartavel (db reset + seed + migrations/ + candidatos + pgTAP), com contagem ok/not ok por teste.
- `cdp.js`: driver minimo do Chrome DevTools Protocol (`CDP_PORT`): shot, eval, click, type, nav, url; usado para `history.pushState` e para chamar `window.$flutterDriver` direto.
- `cdp-shot.js`, `cdp-viewport.js`, `cdp-wheel.js`: captura sem avaliar JS, viewport emulado (1024/375) e rolagem.
- `drv.sh`: atalho para `dart run test_driver/qa_drive.dart <ws> cmd chave=valor ...`.
- `prova-producao.js` (na pasta acima): CRUD por RPC em producao com a sessao qa-r03 (credencial so no ambiente).
