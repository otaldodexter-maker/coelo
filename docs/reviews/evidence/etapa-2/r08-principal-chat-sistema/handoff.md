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
- Naquele pacote G4: deploy e preflight remoto ainda nao executados.
- C0 confirmou depois moments-media v10 ACTIVE e preflight 3014/producao200,
  externo403; prova propria em `r08-coordenacao/moments-media-preflight.md`.
- CRUD UI, leitura, reload e remocao do PNG continuam nao executados R08.

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


## Pacote 2 em preparo — consumidor de anexos do Chat

apps/superadmin → Conversas → conversa → anexar/abrir arquivo → `chat.attach`.
Sem mudar o comando de texto v2, o repositorio implementa o contrato opcional
ChatAttachmentRepository: prepare autorizado, PUT com cliente HTTP isolado,
finalize e leitura reautorizada por attachment_id. Uma repeticao apos resposta
perdida usa a mesma request_id; se o ticket estiver consumido, somente leitura
autorizada do binding confirma que ficou pronto. PUT falho nunca finaliza.

O dialogo mantem o arquivo no retry e envia uma mensagem separada; texto do
composer fica preservado. Imagens usam o viewer existente com TTL/purge e
PDFs usam abertura explicita apos autorizacao. Troca de conversa/repositorio
invalida resultados e fecha dialogos da origem. Sem URL publica ou segredo.

Divergencia a decidir pelo C0 antes de certificar: spec028 descreve assetId
canonico; o contrato SQL aplicado e chat-media usam attachment_id real e nao
retornam assetId. G5 confirmou e C0 autorizou preparar leitura explicita do
binding, preservando assetId nulo. Nenhuma tabela, gateway ou ID foi inventado.

C0 confirmou chat-media v4 ACTIVE, Deno6/6 e preflight 3014/producao200 e
externo403. Fonte C0: `r08-coordenacao/chat-media-preflight.md`.

Verificacao local em preparo: pub get sem upgrade; analyze inicial focal sem
issues. Apos acrescentar teste de fluxo da pagina, analyze apontou1warning
no tipo de retorno do fakeFilePicker; corrigido, rerun ainda nao executado.
Testes novos escritos antes da implementacao, mas RED nao executado devido ao
slot global; nao registrar TDD completo. Flutter test ainda nao executado.
Arquivos WIP locais nao representam entrega integrada nem aceite FE/BE/E2E.

H09: G5 publicou candidato76aed97cb com cron5min/sweep500. Ainda sem pgTAP
nem aplicacao; C0 precisa medir cron.job e aplicar no lote autorizado. O
candidato muda estado expirado, preserva master R2; filtro de leitura sozinho
nao prova agendamento. Nenhuma promocao de status proposta por G4.


## Conciliacao focal de Perfil (H02/H03)

Inspecao estatica R08 na base6d6cbef32+1d09cb3c8, sem novo aceite visual/E2E:

- `principal_profile_route_page.dart:206` e`:219` constroem feeds de Acontece
  e Momentos com institution/unit/group do runtime autorizado; dependem dos
  repositorios injetados. Em`:272` o host produtivo injeta os feeds e Sobre.
- `principal_profile_preview_page.dart:13` enumera quatro abas;`:947`,`:954`,
  `:961`,`:968` apresentam Acontece/Momentos/Circulares/Sobre com keys propias.
  O nome Preview nao significa que este componente esteja ausente da producao.
- `PrincipalProfileContentTabs` antigo sem consumidor pertence ao recorte G6;
  nao foi removido nem substituido. Destino recomendado: preservar ate G6/C0
  reconciliar referencias, sem duplicar a composicao que ja existe.
- `packages/coelo_domain/lib/src/profile_about/profile_about.dart:446` possui
  ProfileAboutOfficialUpdateRequest e as decisoes aboutOnly/aboutAndOfficial,
  mas nenhum consumidor produtivo foi localizado. O save de Sobre nao prova
  atualizacao de cadastro oficial. C0 recebeu a lacuna para decisao vigente.
- H05/H06/H13 continuam conciliacao contratual com Owner/C0; sem alterar
  denominador de recibos, permissao de revogar ou destino de CTA por inferencia.

A ausencia de um consumidor legado foi conciliada com o host atual; nao se
conclui que as quatro abas estao certificadas sem prova da rota normal.

Checkpoint documental11:27: codigo do pacote2 permanece WIP local; somente
JSON e este handoff estao no commit de checkpoint. Nao integrar como feature.
