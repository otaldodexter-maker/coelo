---
source: "R08-prompts.md; R08-plano.md; R08-backlog.md; execucao G4"
status: "em execucao; primeiro pacote local verificado"
generated_at: "2026-09-12"
---

# R08 G4 — Principal, Chat e Sistema

Host: `apps/superadmin`. Worktree `e2-r08-principal-chat-sistema`, branch
`work/etapa2-r08-principal-chat-sistema`, base `6d6cbef32`.
T0 C0: 10:52:16 -03; corte 14:52:16; handoff final ate 15:02:16.

Objetivo: publicar PNG privado em Acontece/Agora/Momentos e provar leitura,
reload e remocao; seguir Cardapios lote55, Chat, Perfil/Para Voce e erros.
Autoria de happens-media/now-media/moments-media. Circular e G6; deploy,
SQL de producao, inventario e rastreadores sao C0. V-1 residual e revisao
profunda historica continuam pos-MVP. Nenhuma alteracao no checkout principal.

## Pacote 1 — preflight de Momentos

Etapa 2 → apps/superadmin → Coelo (Principal) → Momentos → Publicar/ler
midia → `momentos.create`, `momentos.publish`, `momentos.view`.

O handler de `moments-media` omitia `x-client-info` de
`Access-Control-Allow-Headers`. Acontece e Agora ja incluem esse cabecalho.
A falta explica um bloqueio de preflight de clientes Supabase; ainda nao
comprova ser a unica causa da falha historica do navegador.

Correcao: adicionar o cabecalho a allowlist existente, preservando origens
permitidas e toda autorizacao. Sem nova dependencia ou alteracao de contrato SQL.
Teste executa o handler real capturado de `Deno.serve`, sem servidor, rede ou
credenciais. Confere todos os cabecalhos solicitados e nega origem externa.

Prova local em Windows/Deno, 12/09 aproximadamente 10:57 -03:

- Antes: `deno test --allow-env --allow-read cors_test.ts`: 0 PASS / 1 FAIL,
  assercao `x-client-info` false versus true.
- Depois: `deno test --allow-env --allow-read`: 27 PASS / 0 FAIL,
  cobrindo CORS, contratos, assinaturas, R2 e validacao dos bytes.
- Aviso da dependencia: `punycode` deprecated; nenhum erro de tipo ou teste.
- Nao executados: deploy, preflight remoto atual, CRUD UI e reload com PNG.

Deploy solicitado a C0: `moments-media`, fonte deste pacote. Depois medir
OPTIONS na origem `http://127.0.0.1:3014` incluindo `x-client-info` e seguir
prepare → PUT → finalize → publicar → leitura → reload → remocao.
Nenhum delta FE/BE/E2E proposto por este teste local isolado.

Fonte tecnica consultada: [CORS Supabase](https://supabase.com/docs/guides/functions/cors).

## Proximos gates

1. Prova real dos publicadores quando G0/C0 liberarem runtime/Chrome.
2. Cliente `chat.attach`: inspecionar contrato existente com G5 e implementar
   prepare/PUT/finalize/read no consumidor Flutter.
3. Cardapios list/create/edit/publish na fila de navegador, contrato lote55.
4. Perfil/Para Voce e erros conforme primeiro gate; sem inventar fluxo 409/500.
5. G5/C0 verificam disparador efetivo de expiracao Agora (H09).

Memoria: regras de produto preservadas; nenhum conhecimento novo de produto
aprovado neste pacote. Projecao final pertence a C0; no-op por enquanto.
