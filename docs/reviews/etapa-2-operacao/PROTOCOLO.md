---
title: "Protocolo compartilhado E2 R01"
source: "Owner R01; docs/reviews/coelo-etapa-2-coordenacao.md; docs/reviews/inventario-etapa-2.json; AGENTS.md"
status: "active"
generated_at: "2026-09-08T12:19:18-03:00"
timezone: "America/Sao_Paulo"
---

# Protocolo R01 — revisão 1

Autoridade: C00, tarefa `01a0818b-2a34-7fa3-a9aa-f191fc91cc8d`, é o único integrador e escritor dos três rastreadores oficiais. Esta ordem do Owner prevalece sobre instruções antigas de múltiplos escritores ou atualização direta pelos executores. Histórico permanece no documento de coordenação, explicitamente histórico.

## Contrato e janela

- Objetivo: concluir Superadmin ponta a ponta reaproveitando implementação/evidências. Apenas `apps/superadmin` e suas dependências; “Coelo (Principal)” é seu menu. Não implementar Admin, Principal ou Site.
- Janela Owner: **08/09/2026 12:20 → 16/09/2026 12:20**, America/Sao_Paulo (UTC−03:00). Preparação antes das 12:20 não altera início da janela.
- Rodada R01: execução até fechamento seguro 09/09 05:30; entregas finais até06:00; a partir de06:00 novas atribuições suspensas; feedback e prompts R02 até07:40, mesmo com bloqueios.
- Incluído agora: preparação recuperável, ownership, continuidade, integração incremental e provas proporcionais. ETA total desconhecida até calibrar os primeiros lotes; não usar 36–60h histórico nem dividir horas por cinco.
- Destino de entrega autorizado pelo Owner: `dev`. C00 publica primeiro sua branch de integração; integração em dev exige preservar o checkout alheio e conferir ponta remota, sem force-push. Não equivale a deploy.
- Localhost deve usar a composição normal e Supabase real. `/dev` e fixtures são ferramentas locais, sem certificação E2E.

## Fontes e leitura

AGENTS.md, RTK.md e skills coelo-frontend, coelo-backend, coelo-frontend-backend, coelo-ui, coelo-knowledge, ponytail e rtk. C00 leu integralmente os três rastreadores na ordem FE → BE → integrado; campos idênticos foram cruzados sem perda com a camada já lida. Executores leem cabeçalhos, suas ações, dependências e evidências; auditoria ampla da camada exige seu rastreador integral. Carregar referências conforme ação e reutilizar contexto.

Use flutter-dart-code-review ao revisar Dart; skill oficial Supabase e supabase-postgres-best-practices para SQL/RLS/Supabase; plugin Cloudflare com sua skill cloudflare; cloudflare-manager só para gerenciamento pertinente. Se caminho da skill estiver ausente, descobrir a instalação real, sem inventar carregamento. As orientações técnicas não criam arquitetura, cobertura arbitrária ou dispensa dos aceites Coelo. Tutor somente por explicação didática pedida pelo Owner.

Antes de mudar código, registrar no próprio handoff objetivo, incluído/fora, IDs, pendências conhecidas, ordem, parada, evidências e ETA fundamentada. Escopo já autorizado não exige reconfirmação por ação. Procurar código/spec/ADR/evidência antes de implementar. `pending-verification` nunca significa código ausente.

## Arquivos e protocolo de entrega

Fonte operacional viva: `C:/Users/adrie/Documents/Coelo.worktrees/e2-c00/docs/reviews/etapa-2-operacao/PROTOCOLO.md` e `assignments/CXX.md` **diretamente na C00**; cópias locais podem estar antigas. Cada executor escreve seu código/testes e, como único documento operacional de entrega, `docs/reviews/etapa-2-operacao/handoffs/CXX.md` na própria worktree. Não editar assignments, coordenação, relatórios centrais, inventário ou rastreadores. Propostas de documentação/spec e deltas vão no handoff. Evidências técnicas minimizadas de testes podem acompanhar código; não copiar conversas, segredos, tokens ou logs brutos.

Handoff obrigatório: rodada; nome/ID real da conversa; revisão monotônica; última instrução processada; timestamp com fuso; branch; baseline; SHAs de código; estado/ponta do push; action_ids; arquivos; testes, resultado e ambiente; evidências; bloqueios; primeiro critério ainda aberto; próximo passo; ETA separada e fundamentada; proposta de delta FE/BE/E2E por ID. Registrar processo/sessão/horário de teste/build em andamento, quando houver, sem credenciais. Revisão nova no mesmo turno de correção, regressão, bloqueio ou ETA. Separar commit de código do commit posterior de handoff para evitar SHA circular.

C00 processa chave `(R01,CXX,revisão)`, grava received/accepted/integrated (estados distintos) na assignment e revisões sincronizadas nos rastreadores. Recebido não significa aprovado. Nunca processar duas vezes a mesma revisão. Handoff ausente = evidência ausente, não tarefa parada. Cada Markdown derivado exige frontmatter source/status/generated_at.

## Ownership e reservas

R01-C02-I004: decoder comum local `_shared/media_image_decoder.ts` e `_shared/media_image_decoder_test.ts` reservados ao C02, sem manifests/serviço remoto implícitos; limites na assignment viva.


Às13:03, R01-C04-I002 concede a C04 somente hunks Locais/CHILD em superadmin_routes.dart, superadmin_router.dart e main.dart. Nenhum outro escritor altera esses três arquivos até release por SHA/ack. Também reservado candidato local20260908031000_superadmin_location_catalog_v2.sql de9e689374, sem produção/replay implícito. Detalhes na assignment viva.

R01-C05-I002: golden não aprovado retém certificação visual, não implementação autorizada. Masters preservados, sem contornar classificador; capturas candidatas separadas e testes nominais para revisão C00. Ativar mecanismo local de continuidade disponível e reportar ID, sem presumir que Markdown acorda a sessão.


Reserva R01-C01-I002 (08/09 12:50): C01 escreve `apps/superadmin/lib/features/errors/presentation/screens/superadmin_error_screen.dart`, inclusive onAction FutureOr compatível, e testes próprios; router/composition root continuam C00. Retry real exige consumidor nominal seguro, não mutação genérica repetida.


Reserva SQL R01-C03-I002 (08/09 12:43): C03 escreve candidato `packages/coelo_database/migrations/20260908154257_superadmin_activity_save_v2.sql` e teste `packages/coelo_database/supabase/tests/superadmin_activity_save_v2_test.sql`; apenas save transacional Atividades create/edit/publish, sem histórico/runner/remoto. Nome gerado por CLI em TEMP C00; detalhes na assignment viva.


Reserva SQL R01-C02-I003 (08/09 12:41:19−03:00): C02 escreve somente o candidato local `packages/coelo_database/migrations/20260908160000_private_media_catalog_r2_v1.sql` e `packages/coelo_database/supabase/tests/private_media_catalog_r2_v1_test.sql`. Evolução compatível do catálogo existente conforme ADR0032; nenhuma aplicação remota. Limites completos na assignment viva C02. C04/C05 não alteram esses arquivos nem constroem catálogo paralelo.


Release recebido em 08/09 12:30:25−03:00: C01 devolve auth scope e shell sem alterações; C00 retoma esses dois arquivos. `packages/coelo_auth` foi devolvido também às12:34:18−03:00 após integrar1fd7f9ec em2dd5a9bc e testes C00; R01-SHARED-01 encerrada, os arquivos passam a C00. Esta atualização prevalece sobre a concessão inicial R01-SHARED-01 da tabela.


`assignments/ownership.json` expande os 219 IDs, um dono por ID, sem duplicados ou sem dono. Classificação operacional: 194 ativas (189 `mvp` +5 shell somente cliente), 22 adiadas,3 gates formais; N/A é anotado por camada para sete ações, não exclui seu trabalho FE. IDs de Planos/Catálogo com dúvida permanecem rastreáveis, sem retirar denominadores por conveniência.

Arquivos de domínio pertencem à assignment. Um arquivo compartilhado tem um escritor por vez, mesmo em branches distintas:

| Reserva R01 | Escritor atual | Limite e entrega |
|---|---|---|
| `apps/superadmin/lib/app/router/superadmin_router.dart`; `apps/superadmin/lib/main.dart`; composition roots não listados | C00 | Executores entregam delta mínimo no handoff; C00 integra ou concede reserva nominal antes da edição. |
| `apps/superadmin/lib/core/config/superadmin_auth_scope.dart`; `apps/superadmin/lib/app/shell/superadmin_shell.dart`; `packages/coelo_auth/` | C00; R01-SHARED-01 encerrada | C01 devolveu após integração2dd5a9bc; nova edição exige reserva. |
| `packages/coelo_api/lib/src/media/`; `packages/coelo_database/supabase/functions/_shared/media_image_contract.ts` e seu teste; `packages/coelo_database/supabase/functions/moments-media/r2_s3.ts` e seu teste | C02, lease R01-MEDIA-01 | Núcleo comum já existente; preservar consumidores C04/C05, publicar contrato no primeiro lote. |
| `packages/coelo_database/supabase/functions/_shared/r2_s3.ts` e `_shared/r2_s3_test.ts` | C00 após release C02 | Contrato v2 integrado6fd676e2; C02/C04/C05 consomem, nova escrita exige reserva. |
| Barrel exports `packages/coelo_api/lib/coelo_api.dart`, `packages/coelo_domain/lib/coelo_domain.dart`; tokens/componentes UI centrais; manifests/lockfiles compartilhados | C00 | Propor export/delta no handoff; nenhuma edição concorrente. |
| Migrations históricas, runner/replay/foundation manifests | C00 | Reserva nominal por arquivo antes de mudar. Autores podem preparar SQL candidato e teste dentro de domínio reservado, sem aplicar remoto. |
| Novas migrations | Reserva nominal C00 antes de criar | Informar nome, dependências, domínio e IDs no primeiro handoff; C00 concede nome/arquivo por vez. Não renomear ou repinar para mascarar drift. Trabalho independente continua. |
| Gateway server-side por domínio (`form-media`, `form-operations`: C02; `happens-media`, `moments-media`, `now-media`, `circular-media`: C05) | Dono indicado, exceto auxiliares comuns C02 | Reutilizar entradas existentes; não construir gateway universal concorrente. |
| Testes globais de rotas/shell, pacotes centrais UI, arquivos não cobertos | C00 até reserva nominal | Executores podem criar testes focados de sua feature. |

Lease cobre somente arquivos existentes nomeados e domínio; alteração transversal nova precisa nome/reserva, não permissão genérica. Transferir após release do escritor e acknowledgement C00. Bloqueio retém só as ações dependentes.

## Contrato mínimo de mídia já disponível — R01-MEDIA-01/v1

Candidato v2 recebido C02/r3 em código76a34dda: `R2Client.get(key,maxBytes)` retorna bytes com limite server-side e `put(key,bytes,mimeType)` escreve server-side, preservando API anterior. Integrado e testado na C00 como6fd676e2 às12:46,49/49+4/4 e lint. Escrita dos dois arquivos `_shared/r2_s3` transferida temporariamente a C00 para essa revisão; restante do lease de mídia segue C02. Consumidores podem usar6fd676e2 para os métodos novos após sincronização coordenada, sem criar transporte concorrente.


Atualização C02/r1 recebida em 2026-09-08T12:28:13−03:00: o wrapper Moments delega a `_shared/r2_s3.ts`, transporte comum com presignPut/presignGet/head/delete, TTL 1–900 segundos. C02 recebe também os dois arquivos comuns pela I002 para extensão compatível GET limitado/PUT server-side; C04/C05 consomem o contrato sem criar gateway concorrente. Forms `form-media` e XLSX `form-operations` ainda usam Supabase Storage legado: migração para R2 requer catálogo/autorização nominal, não apenas troca de bucket. Validador de métricas não é decoder nem prova MIME/checksum. 40/40 Deno sintéticos relatados, sem certificação de ação. A ausência dos nomes de tabelas ADR na busca não prova ausência de catálogo ou autorização.

Fontes: ADR0032; `packages/coelo_api/lib/src/media/media_read_contract.dart`, `media_reader.dart`, `media_session.dart`; evidência `docs/reviews/evidence/etapa-2/comunicacao/2026-09-07-media-m03-read-contract.md`.

- `MediaReadRequest(assetId, rendition)` envia UUID e `original|preview`; IDs de attachments legados não se tornam asset IDs por suposição.
- `MediaReader.read` retorna `MediaReadResult`: available/processing/expired/unavailable; somente available tem ticket temporário HTTPS, expiresAt e headers. `SessionMediaReader` confere correlação do ativo, expiração e invalidação de sessão; não é transporte HTTP nem autorização.
- Consumidor revalida ticket no uso, purga ticket/bytes em logout, revogação, mudança de contexto e resposta obsoleta. Não logar/persistir URLs/headers; não prometer revogação instantânea de URL já emitida.
- Gateway reautoriza ator, sessão, tenant, ownership, entidade e finalidade em cada operação. Upload completo prepare/finalize/discard, transporte, catálogo e validação real de bytes precisam crosswalk do C02: esta publicação não inventa essas assinaturas nem afirma que estão completas.
- R2 privado guarda master; Postgres guarda catálogo/permissões/vínculos/auditoria. Mesma plataforma sem nome de app na chave. C02 anuncia mudança compatível ou migração coordenada aos consumidores antes de exigir nova API.
- Forms inclui imagens/perguntas/respostas/anexos e um XLSX com as respostas do formulário no R2 privado. Nunca dar Forms por completo sem mídia exigida. Demais import/export: botão acessível e indisponibilidade honesta, sem picker/parser/job/arquivo/RPC/persistência.
- Chat usa R2; Acontece e Momentos R2 com Stream por necessidade medida; Agora R2 master e Stream HOT quando necessário por até24h, removendo somente a cópia Stream. PDF nunca Stream.

## Qualidade, métricas e produção

FE verified: composição normal sem fallback fake, UI/estados, validação, navegação, foco/teclado/toque, responsividade, acessibilidade, tema, contrato repository/gateway e regressão. Pode ser certificado sem backend, usando double fiel em teste. BE done: contrato/validação/sessão/capability/tenant/ownership/RLS/grants/persistência/idempotência/auditoria/negativas/reload e todos os provedores aplicáveis no remoto autorizado, sem exigir UI. E2E: UI normal → backend real e provedores → persistência/reload → negativas aplicáveis e auditoria/cleanup. Tela aberta, fail-closed, local-green, fixture ou golden isolado não certifica E2E.

Separar quatro medições: ações efetivamente auditadas (inclusive falhas), conclusão FE, BE e E2E. Numerador, denominador, IDs, critérios, data e evidências sempre explícitos. Não somar percentuais nem inventar implementação %. Fonte inicial 0/219 FE,0/212 BE normativas aplicáveis,0/187 E2E ativas; escopo ativo backend187, gate3,adiadas22 separados. Nenhuma promoção nesta preparação. Ausência de evidência de auditoria nominal R01 significa 0 ações reauditoradas em runtime nesta rodada, não zero histórico implementado.

Preservar famílias coelo-ui administrativas e Principal, inclusive referências parciais aprovadas em Publicar. Não atualizar goldens automaticamente. Componentizar se ajudar agora e for barato; refatoração ampla pode virar dívida explícita sem adiar comportamento, segurança ou acessibilidade necessária.

Todo remoto Coelo é produção. Só C00 coordena/aplica pacote nominal já autorizado, revisado, testado localmente, forward-only e serializado, com recuperação. Coordenação não se autoaprova. Autorização anterior não se transfere a pacote novo. Nenhum executor faz migrations/deploy/config remotos. UI mutante requer cenário/personas/janela nominalmente autorizados e registrados. Só usar personas sintéticas e tenants A/B isolados; catálogo/claims/ID enviado pelo cliente não autoriza. Segredos fora de Git/bundle/log/URL permanente; não copiar credenciais entre worktrees. Guardar evidências minimizadas.

## Continuidade, checkpoints e integração

Executores continuam lotes independentes sem pedir confirmação por ação. Publicam handoffs às12:50,14:50,17:30 e quando houver mudança material. C00 confere aproximadamente às :00/:30 apenas revisões novas, snapshots compactos de tarefas, commits novos e dependências/fila. Intervir só por decisão/dependência que muda próximo passo, conflito, falha de coordenação, ociosidade comprovada com passo executável ou fechamento. Verificar teste/build/ferramenta antes de chamar parado; uma retomada por causa/revisão, investigar se não resolve. Não mandar continue a tarefa ativa nem reler conversas inteiras.

Codex: acompanhamento/retomada pelas ferramentas nativas quando houver IDs. Claude: assignment versionada, consultada por mecanismo nativo da própria sessão, se disponível; registrar mecanismo/ID/cadência e limites. Markdown sozinho não acorda sessão. Sem ponte de teclado, integração inventada ou API paga.

Heartbeat único da C00, ID `e2-r01-c00-acompanhamento-30-min`: despertar de10min para alcançar :40; consultas aos executores somente :00/:30 ou evento devido. Demais despertares silenciosos. 13:00,15:00,17:40 em08/09: feedback ao Owner e relatório datado com deltas, quatro medições, implementado/verificado/falta implementar/falta testar, bloqueios/owner/próximo passo, SHAs/integração/push/produção separados, ETA por dependências e risco/menor mitigação. Sem handoff novo usar “última evidência às HH:MM”. Registrar atraso real se app não disparar pontualmente. Não prometer acordar com app/host desligado. Nenhuma configuração nativa Claude foi verificada ainda.

Revisar e integrar lotes aptos continuamente: confirmar baseline/SHAs/files/reservas/diff/testes, separar WIP, aplicar somente commits de código aptos, executar regressão proporcional no destino, registrar SHA origem→destino e acknowledgement, publicar baseline. Executores não fazem merge; commits/push pequenos nas próprias branches em `origin` são autorizados, sem force-push/dev. C00 publica branch de integração e entrega dev sem misturar trabalho externo. Antes de cada operação confira árvore/index e arquivos nominais; proibidos reset --hard, clean, stash global, add -A ou commit indiscriminado.

05:30 em09/09: fechamento seguro, sem abandonar operação em curso. Até06:00: commits, push verificado, handoff final, evidências, pendências e comandos exatos de retomada; WIP separado. A partir06:00 suspenda novas atribuições R01, integre aptos, teste e reconcilie rastreadores/inventário/coordenação. Antes de limpar preserve SHA/evidência; remover somente worktree R01 sem sessão ativa, limpa e com preservação/integração/arquivamento comprovados, sem force ou apagar branches com commits únicos. Até07:40 entregue feedback e next-round/R02 completo, mesmo com bloqueios. Renovar C00 exige transferência explícita, confirmação do sucessor e desativação do heartbeat antigo antes do novo writer. Não criar as conversas automaticamente.

## Reservas reconciliadas — 2026-09-08T13:50:02-03:00

C04 I003 amplia nominalmente I002 para app/superadmin_app.dart (pass-through Locais/CHILD) e recuperação local do candidato CHILD20260908051500/testes. C02 I005 reserva os quatro handlers/testes form-export-download e candidato XLSX20260908170000/teste, nos caminhos exatos da assignment viva. C01 devolveu Erros; arquivo/testes sob C00. Nenhum pacote remoto aprovado. Guardar SQL candidato separado de UI.

## Continuidade reforçada pelo Owner — 2026-09-08T15:30:22-03:00

Handoff é um checkpoint de entrega, não encerramento do trabalho. Após publicar evidência/commit/push, cada executor inicia o próximo lote independente no mesmo turno. Bloqueio parcial retém apenas os IDs dependentes. C00 retoma por ferramenta nativa uma tarefa Codex comprovadamente ociosa com próximo passo executável, no máximo uma vez por causa/revisão; se não resolver, investiga em vez de repetir mensagens. Heartbeats são recuperação espaçada, não motivo para encerrar cedo. Claude consulta assignments pelo mecanismo local registrado; C00 não tem ferramenta direta de despertar Claude. Encerramento seguro, limites do aplicativo e bloqueios totais devem ser relatados honestamente. C00 continua único escritor dos três rastreadores.


## Reservas operacionais — 2026-09-08T16:17:15-03:00

Assignments C02 I008, C03 I009, C04 I008 e C05 I007 concedem arquivos nominais e prevalecem sobre esperas anteriores. Lease R01-LOCAL-XLSX-02 exclusiva C02 até release; outros executores/C00 não iniciam replay concorrente. Shell e auth_scope retornam à C00. Os dois caminhos People da I009 ficam temporariamente C03, excluídos de C04 até release. Nenhuma autorização remota nova.


## Instrução do Owner — máximo de subagentes — 2026-09-08T17:05:59-03:00

C00 abriu3subagentes nos3slots disponíveis: models_replay_profile (2runners/perfil/teste nominais, sem SQLruntime), forms_sql_review (somente leitura de candidatos) e client_integration_review (somente leitura de lotes). C01I009/C02I011/C03I010/C04I010/C05I008 propagam máxima concorrência útil e todas as reservas/leases. Pais continuam únicos escritores do Git/handoff em cada worktree; apenas C00 altera trackers. IDs/atividade efetivos devem constar no handoff, sem simular agentes criados.


## Coordenação Claude C06 — 2026-09-08T17:29:41-03:00

Owner incluiu E2 R01 C06 — Coordenador Claude. Worktree `C:/Users/adrie/Documents/Coelo.worktrees/e2-r01-c06`, branch `claude/e2-r01-c06-coordenacao`, ID real ainda pendente. Assignment C06I001 na C00; resumo exclusivo `C:\Users\adrie\Documents\Coelo.worktrees\e2-r01-c06\docs\reviews\etapa-2-operacao\handoffs\C06.md`. Preparação r0 não é ack. Depois de r1 com operational_ack I001, C06 assume acompanhamento/retomadas C04/C05 e C00 lê seu resumo primeiro, mantendo acesso aos originais e responsabilidade exclusiva por integração, rastreadores e reservas/leases. Até ack, C00 cobre exceções; não há duas cobranças ativas. C06 usa ledger por executor/revisão/causa, máximo uma retomada por causa; encaminha decisões técnicas C00 sem inventar autorização. C04/C05 continuam seus próprios handoffs, commits e mecanismos de trabalho, consultam instruções operacionais C06 no limite de lote; código/política permanecem assignments C00. Sem ponte de teclado/API paga. Nenhuma nova conversa criada automaticamente. C06 não recebe action_ids e não altera denominadores.


## C07 — validação adicional, 2026-09-08T18:01:23-03:00

WorktreeC:/Users/adrie/Documents/Coelo.worktrees/e2-r01-c07,branchclaude/e2-r01-c07-validacao-visual,baseline4af42925ff6f05fa14a7e28dffb31edbee321c3e;assignmentcanônicaC00/C07I002. C06 chefiaoperações e confirmoupreparação;C00 integra/reserva/trackers. Quatrotestesnominais novos,semSQL/Docker/mídiacompartilhada/masters. SemtransferirIDs. Antesdeteste,reconfirmarausênciadeexecuçãoidêntica. C06recolhe05:30/06:00;C00feedback07:40. HandoffC07r0 não é sessãoativa.


## R01-ALL-RTK-1808 — continuidade e RTK (2026-09-08T18:08:11-03:00)

O Owner reforçou a continuidade até o fechamento combinado. Use a skill `.agents/skills/rtk/SKILL.md` e RTK.md; use `rtk` explicitamente nos comandos compatíveis e `rtk proxy` quando necessário preservar a saída original. C00 conferiu RTK 0.35.0 e `rtk gain` funcional; a ausência de hook automático no Codex não impede uso explícito. Não reinstale nem reconfigure ferramentas globalmente apenas para cumprir este reforço.

Handoff e feedback são checkpoints: prossiga no mesmo turno para o próximo lote autorizado. Use o máximo de subagentes úteis para tarefas concretas independentes, mantendo um escritor por arquivo. Bloqueio retém somente dependentes; sem próximo passo independente real, descreva a dependência exata para o coordenador resolver, sem fabricar testes/trabalho nem violar reservas ou produção. Antes de qualquer retomada, confira teste/build/ferramenta em andamento. Uma mensagem por causa/revisão, sem loops de cobrança.

Em 09/09, America/Sao_Paulo: 05:30 preparar fechamento seguro; até 06:00 commits, push verificado, handoff final, evidências e WIP preservado separado, com comandos de retomada. Após 06:00 não iniciar atribuições novas R01. C00 integra, reconcilia os três rastreadores e prepara feedback/prompts até 07:40. Somente C00 remove worktree inativa, limpa e com preservação comprovada; nenhuma limpeza forçada ou descarte para aparentar conclusão.

C00 acompanha C01/C02/C03 por ferramentas nativas; C06 acompanha C04/C05/C07 e repassa este reforço uma vez pelo seu mecanismo nativo, registrando envio e ack no próprio handoff. Apenas C00 escreve rastreadores, assignments, reservas e integração. Confirme esta instrução no próximo handoff material, sem parar para confirmação.
