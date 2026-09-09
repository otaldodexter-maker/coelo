---
source: "D00 assignment r10/recibo14:42; gateway retry RED/GREEN; independent auth_fix_review"
status: "retry-local-green; cold-storage-failure-gate-open"
generated_at: "2026-09-09"
---

Etapa2 → apps/superadmin → Autenticação → Redefinir senha → falha transitória
ao remover sessão persistida → auth.reset. Mesmos dois paths reservados D00;
somente o gateway mudou neste delta, sem nova API, rota, tela ou regra visual.

RED: após a primeira remoção falhar, um refresh da mesma sessão não fazia
nova tentativa (attempts1/persistedtrue). O cache era mantido como se a remoção
tivesse sucedido. Log `recovery-persistence-retry-red-cold-fixture.txt`;
somente a falha do retry é RED válido nesse log, a tentativa inicial do outro
teste cold apresentou problema de fixture e não prova de produto.

Correção: limpar o marcador da tentativa falha somente se ele ainda corresponder
à mesma sessão. Um evento Auth posterior pode tentar novamente, sem loop
imediato, sem mexer na sessão B e sem publicar erro após dispose.

GREEN: novo retry mais dois testes existentes de erro síncrono/assíncrono,
3/3PASS, `recovery-persistence-retry-green.txt`. Somente um novo ID entrou
no plano. Análise Dart dos dois arquivos alterados sem diagnósticos; revisão
fria independente aprovou o delta. Demais147casos não foram repetidos.

Isso não resolve falha permanente de armazenamento. O RED frio válido está em
`recovery-persistence-cold-failure-red.txt`: SDK/storage reais, remoção falha,
reinício limpo restaura credencial, backend simulado permissivo permite contexto.
O diagnóstico permanece opt-in por variável explícita, sem convertê-lo em
PASS por inverter expectativas ou fabricar negativa HTTP. A prova de aceite
será SDK/scope/rota reais contra o backend real local corrigido, ainda pendente
da janela D00. O hook usa recovery sintético dedicado e admite o logout
automático da aplicação; nenhuma conta ou sessão do Owner é utilizada.

FEauth.reset permanece pending; BE/E2E não certificados. O release deste
retry não antecipa a prova fria nem aplicação remota.
