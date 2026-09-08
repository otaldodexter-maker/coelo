---
title: "E2E 3 — plano visível por tela e camada"
source: "pedido do Owner via Coordenador em 2026-09-07; reservas E2E3-M01 e E2E3-N01; evidências locais desta frente"
status: "in-progress; not-e2e-complete"
generated_at: "2026-09-07"
updated_at: "2026-09-08"
---

# Plano por tela

Checkpoint focal posterior a `4132c0aa`: `7cb636ef` corrige negação e cache de
Momentos (79/79 publicação, incluindo goldens); `76a14d73` corrige duração de
ticket, expiração e cache Acontece (56/56 funcionais + 10/10 goldens de galeria).
Chat manteve código existente: 73/73 diálogo/tile/composição reexecutados.
Referências por cenário e gates reais em
`2026-09-08-media-lifecycle-handoff.md`. Nenhum PNG ou recurso remoto alterado;
o lote amplo 898 não foi repetido. A tabela preserva também evidências anteriores.

## Posição atual — escopo original integral

O Owner reiterou que o escopo original não deve ser esquecido. Cada fatia
abaixo continua subordinada à entrega real da vertical completa. Somente
Superadmin e dependências; Coelo (Principal) é o menu, não `apps/principal`.
Os quadros posteriores preservam a cronologia, não substituem este checkpoint.

| Superfície original | Última evidência desta frente | Próximo gate real / situação |
| --- | --- | --- |
| Chat/Conversas canônico e Mensagens | `86e4fdad`/`0fff8779`: retry e fechar imagem por origem; 139 testes incluindo 8 goldens do diálogo | Composição/gateway/catálogo M03, transporte real, autorização/reload; goldens históricos e revisão visual completa ainda abertos |
| Avisos | `9abd4a74` + correção central `1165ee5c`: prévia vinculada à origem e confirmação once, 111 não-golden; 46 expectativas SQL não executadas aqui | N01: replay nominal/ponte sob Eng1, geração/job/worker/auditoria e produção |
| Convites | `e4171bdb`/`72b24d25`: 61 não-golden; confirmação própria, callbacks obsoletos e purge de negação | OQ039/spec047 de emissão continuam pendentes; não habilitar default false; prova server-side/E2E aberta |
| Circulares administrativas e menu | `38870d1`, `17c6286a`, `8f7d9c6d`: editor, reader, contexto e purge; 112 não-golden | Respostas/publicação/mídia reais, revogação/reload e regressão visual completa |
| Acontece | `8b48d271`: header de contexto mede espaço real, 50 funcionais/16 matriz; galeria 10 goldens; `8c2c7009`: publicação 55 testes | Catálogo/gateway e mídia reais; 422 legado recuperável; dez goldens feed abertos, diferença desktop remanescente PublishNowCard sem autorização de rebaseline |
| Agora | `1a14784d`: ownership dos editores, 91 testes; `f353fee2`/`9219e02e`: opções, geração de mídia e purge, 59 testes de prévia, ambos incluindo goldens | Master R2, HOT privado até 24h quando necessário, fallback, expiração só da cópia Stream e prova real |
| Momentos | `5e53ea4f`: contexto; 86 funcionais/rota e 14 goldens naquela fatia; `6e7bc23b` transporte R2 comum | Catálogo/gateway, upload/reprodução real e promoção HOT por necessidade medida |
| Para Você | `d9942d88`/`7115a6f7`: seletor por origem e scroll em pouca altura, 55 testes incluindo 13 goldens, Tab/Enter e toque | Leitura/revogação/persistência real e conteúdo conectado |
| Perfil/preview do menu | `19c6d6c7`/`88fb2cf1`: aba Circulares, cursor/contexto/prévia; lote 172 não-golden e 19 goldens Circulares | Avatar/capa/gateway, autorização real e revisão dos dez goldens completos obsoletos; não restaurar seguidores públicos |
| Cabeçalho global | `da6eb4cf`: relato contextual; `e8bbad3c`: controller de notificações acompanha injeção; 101 shell/roteamento | Todas as rotas no browser e composição real; suporte/atividades em memória não são persistência; baselines históricos abertos |
| Media Gateway/R2/Stream compartilhado | `33d7f751`, `589214b7`, `6e7bc23b`, `3efe3865`; inventário read-only dos três buckets; DDL candidato `69f5e8a` | Guard AMR/proveniência E1, máximo batch Owner, decoder/entitlement e credenciais/lease nominais; sem SQL/composiçãoScope autorizados |

Coordenador confirmou em 2026-09-08: Circulares `38870d1`/`17c6286a` integrados
com lote central 386 PASS; Chat `cdb542a5` integrado com lote Chat/Cardápios
172 PASS/analyzer5. São resultados comunicados pela coordenação, não execução
independente desta frente. Nenhum desses lotes promove automaticamente E2E.

Próximo trabalho: continuar achados independentes do escopo enquanto os gates
M03 são resolvidos por seus responsáveis. Não escrever SQL, conectar Scope,
inventar máximo ou autorizar sessão por AAL isolado. ETA global segue dependente
dos gates externos; não trocar critério de entrega por quantidade de commits.

Parecer E1 retransmitido pelo Coordenador neste checkpoint: não existe guard
AMR/proveniência pronto nas migrations e não há helper iminente. AAL persistido
1/2 não prova origem operacional; recovery PKCE identificável não resolve OTP
implícito ambíguo. O GoTrue congelado é fonte nominal, não versão de produção
comprovada. Nenhuma proibição nova de OTP/magiclink foi aprovada. O gate exige
contrato server-side e prova dos fluxos admitidos, sem ampliar lease/credenciais.

## Histórico das fatias

Checkpoint em `9219e02e`: 898/898 não-golden no escopo original e shell,
55/55 rotas; cinco testes novos de negação/contexto sobre os 893 anteriores.
API de mídia 45/45 e Deno 40/40 reexecutados em `f3f994fa`, antes dessa última
correção Flutter. Smoke adicional das superfícies em
`2026-09-08-browser-remaining-surfaces.md`; servidor local encerrado, aba
fechada e viewport restaurada. Nenhuma prova substitui os gates reais da tabela.

Checkpoint de regressão independente root em `e8bbad3c`: 846/846 testes
não-golden das superfícies originais + shell; 55/55 roteamento; 45/45
coelo_api/test/media; 40/40 Deno de métricas de imagem e transporte R2.
Esses lotes usam fixtures/fakes/contratos locais e não são prova de E2E real.
Detalhes e limites em `2026-09-08-original-scope-regression.md`.

N01: coordenação autorizou Eng1 a preparar/executar diagnóstico local nominal
N01PrerequisitesRed de 50+2 entradas. Não é GREEN, ponte, migration N01 ou lease
remoto. Root continua sem operar Docker, histórico, runner ou produção.

Os marcos são por tela: 1 contrato/inventário; 2 backend/segurança/negativas;
3 cliente/estados; 4 integração real/persistência/reload; 5 regressão/visual;
6 review/evidências/commit. Concluir uma fatia no marco 6 não conclui a tela
nem os marcos ainda abertos. Os três rastreadores oficiais pertencem ao
Coordenador; este arquivo registra somente esta frente.

| Passo atual | Tela | Subtela / action_id | Camada e BD | Teste / evidência | Próximo gate |
| --- | --- | --- | --- | --- | --- |
| 6/6 da fatia recibo | Chat | `chat.receipts` | Cliente; RPC `superadmin_chat_mark_read_v2` lida no SQL local; nenhum BD executado na correção | `2725d615`; adapter 9/9 na entrega | Replay e negação real do recibo, revogação e reload |
| 6/6 da fatia envio parcial | Chat | `chat.send`, `chat.attach` | Cliente; RPC textual `superadmin_chat_send_message_v2` somente lida | `7bfb69ba`; adapter 11/11 | Anexos continuam sem gateway; persistência/negativas do texto reais |
| 6/6 da fatia negação | Chat | `chat.list`, `chat.open`, `chat.send`, `chat.receipts` | Estado Flutter; nenhum BD executado | `d3ecc908`; página 23/23; suíte total 56 verdes e 9 goldens preexistentes divergentes | Prova real de revogação; baseline visual e E2E abertos |
| 6/6 da fatia refresh | Chat | `chat.list`, `chat.open`, `chat.send` | Estado Flutter; summary autorizada preserva readonly | RED 23 verdes / 3 falhas; GREEN 26/26; review, analyzer e validador verdes | Commit local deste plano; backend, baseline visual e E2E continuam abertos |
| 2/6 | Avisos | `notices.publish`, `notices.schedule`, `notices.edit` | SQL preparado: `public.platform_notices`, `app_private.notice_publication_jobs`, `public.notice_receipts`; wrappers v2 e worker | 17 expectativas pgTAP preparadas; NÃO executadas. Baseline worker TS 2/2 | Replay nominal local após reparo exclusivo Eng1; então RED e migration N01 |
| 6/6 da fatia sessão | Mídia compartilhada | Logout/revogação/contexto, consumo E2E1 | `coelo_api.MediaSession`; nenhum BD | `33d7f751`; pacote 23/23 | Conectar cache/tickets/player e Auth reais |
| 1/6 | Mídia compartilhada | Catálogo/Forms/exportações/imagens | Migrations locais; metadados Supabase e configuração Cloudflare lidos em produção, SEM mutação | `ba75d4eb` crosswalk local; inventário remoto complementar em preparação | Evolução nominal do catálogo; transporte reutilizável solicitado como M02 |

## Subagentes e exclusividade

## Execução atual detalhada

| Passo | Tela / subtela / action_id | Backend efetivamente trabalhado | Subagente revisor | Evidência / próximo gate |
| --- | --- | --- | --- | --- |
| 6/6 da fatia | Conversas / recibo após refresh / `chat.receipts` | Nenhum BD nesta fatia; Flutter | `review_chat_receipt` | RED reproduzido, GREEN 29/29, analyzer e review aprovados; commit e revogação real pendentes |
| 2/6 | Avisos / publicação, leitura, worker e métricas / `notices.publish`, `notices.read` | `public.platform_notices`, `app_private.notice_publication_jobs`, `public.notice_receipts`, RPCs v2/worker; nenhum SQL executado | `crosswalk_media`, `review_media_session`, `review_chat_receipt` | 17+19+10 assertivas preparadas e revisadas, com papéis SQL reais; NÃO executadas; aguarda perfil/baseline e lease exclusivo Eng1 |
| 6/6 da fatia | Avisos / formulário-publicar / `notices.publish` | Nenhum BD nesta fatia; mensagem Flutter pelo status retornado | `review_chat_receipt`, `crosswalk_media` | RED scheduled, GREEN focal 2/2; ampliado 38 verdes e 2 falhas mobile preexistentes; replay/visual continuam abertos |
| 6/6 da fatia | Avisos / criar e navegar formulário / `notices.manage` | Cliente valida receipt da RPC v2; nenhum BD executado | `review_chat_receipt`, `review_media_session` | Criação versão 1 alinhada; duas falhas mobile resolvidas por interação com rolagem; 99/99 sem goldens, analyzer/review verdes; próximo gate scheduled-edit e replay SQL |
| 6/6 da fatia | Avisos / editar agendado e retry / `notices.manage`, `notices.publish` | Cliente; nenhum BD executado | `review_chat_receipt`, `crosswalk_media` | RED quatro falhas; GREEN 103/103 sem goldens; sem publish adicional ou retomada implícita; próximo gate geração SQL N01 |
| 6/6 da fatia | Avisos / imagem legada e feedback / `notices.publish` | Cliente; nenhum BD executado | `review_media_session` | RED três mensagens; GREEN 106/106 sem goldens; bloqueio preservado, zero request e conversão textual; próximo gate gateway R2 e regressão visual |
| 6/6 da fatia | Circulares / criar-editar, salvar e retomar publicação | Controller Flutter; RPC save_draft v2 somente inspecionada | `review_chat_receipt` | RED três falhas; GREEN 68/68 não-golden; replay de save recupera ID/versão antes de edições; próximo gate publish ambíguo e integração real |
| 6/6 da fatia | Circulares / publicar e recuperar receipt | Controller e feedback das duas páginas no Superadmin; SQL somente inspecionado | `review_chat_receipt` | RED7 controller+4 UI; GREEN79/79 não-golden; intenção original preservada, próximas edições exigem ação explícita; próximo gate integração e lifecycle tardio |
| 6/6 da fatia leitura | Chat / anexo imagem, mídia M03 | coelo_api puro; catálogo ainda não alterado | `review_media_session`, `crosswalk_media` | 59/59 pacote, analyzer e dois reviews sem bloqueante; próximo gate asset_id canônico, catálogo/gateway e consumidor real |
| 6/6 da fatia referência | Chat / anexo, mídia M03 | DTO e adapter Flutter; nenhum BD | `review_media_session` | 16/16 adapter e 62/62 Chat não-golden; assetId distinto da metadata; catálogo/projeção/gateway ainda abertos |
| 6/6 da fatia | Momentos / transporte privado R2 / mídia server-side | Deno `moments-media/r2_s3.ts` e `_shared/r2_s3.ts`; nenhum BD nesta fatia | `review_media_session`, `review_chat_receipt`, `crosswalk_media` | M02 com extensão index_test autorizada; RED seis falhas, GREEN 29/29 completo, lint/typecheck; commit e integração real pendentes |
| 6/6 da fatia | Momentos / publicação e troca de contexto | Estado Flutter; nenhum BD | `review_media_session` | RED3; GREEN86/86 funcional/rota +14/14 goldens; A não restaura conteúdo/callback em B; próximo gate contexto e mídia reais |
| 6/6 da fatia | Para Você / validade dos destaques | Estado Flutter; nenhum BD | `crosswalk_media` | RED3; GREEN49/49 incluindo 13 goldens; timer cancelado em troca/dispose; próximo gate leitura/revogação reais |

## Deltas locais adicionais

| Fatia | Evidência e resultado local | Gate ainda aberto |
| --- | --- | --- |
| M03 métricas de imagem | `3efe3865`; 19/19 métricas, 30/30 com transporte R2; revisão aprovada | Decoder real, catálogo, reautorização, lease e cadeia R2 |
| Cabeçalho: isolamento preview | `f612f639`; 3/3 focal, 69/69 shell | Composition root real e regressão global; controller de suporte ainda em memória |
| Cabeçalho: contexto do relato | `7cac7b19`; 3/3 focal, 69/69 shell | Goldens Turmas divergentes também no baseline; sem atualizar PNG |
| Principal: matriz standalone | `9d88b87e`; 26/26 rotas; spec 050, 7 rotas × 4 larguras × 2 escalas | Foco/teclado, retorno contextual e backend real |
| Agora: legenda após reload | `a4c1943d`; 70/70 feature antes da fatia seguinte | Draft e contexto reais |
| Agora: negação e callbacks tardios | `2026-09-07-now-denial-purge.md`; RED11, GREEN81/81 feature, analyzer/visual/review | Revogação real, mídia compartilhada e persistência E2E |

Sem API de plano nativo disponível nesta sessão. Este documento é a alternativa
aberta no painel direito; não substitui nem controla o contador nativo do app.

## Responsabilidades dos subagentes

- `review_chat_receipt`: revisão read-only de Chat, negação e refresh; propõe
  testes e faz review independente do diff do writer.
- `crosswalk_media`: crosswalk local entregue; revisão read-only dos testes e
  contratos de Avisos N01, incluindo bypass de lifecycle durante leitura.
- `review_media_session`: review M01/crosswalk; diagnóstico golden preexistente;
  recomendação de extrair transporte R2 real de Momentos para consumo comum.
- Um único writer/integrador nesta branch. Subagentes não alteram arquivos,
  Docker, produção ou rastreadores. Slots são reutilizados para recortes úteis,
  sem criar trabalho artificial.

## Autoridade e ambiente

- Apps permitidos: somente Superadmin e dependências. Admin/Principal/Site
  não são alterados.
- N01 reservada localmente:
  `20260907222708_superadmin_notice_publication_pipeline.sql`. Ainda não
  escrita; nenhum lease remoto. Históricas/ledger/runner permanecem intactos.
- Docker está sob responsabilidade exclusiva Eng1. Esta frente não inicia,
  reseta ou limpa recursos Docker compartilhados.
- Supabase remoto consultado: `coelo`, `evvbomzejfijozbtgvpt`, apenas catálogos
  de schema, constraints e assinaturas. Não foram lidas linhas de usuários.
- Cloudflare: conta provisionada `2363eb1eadce9b73279d3c8ce46eb424`, GETs de
  configuração. Os três buckets existem; não criar/recriar. Workers retornou
  lista vazia nesta conta. Isso não valida credenciais de runtime/deploy.
- Hard stop vigente: 2026-09-08 03:20 America/Sao_Paulo; commits e balanços
  intermediários não encerram o trabalho. ETA global E2E ainda não calculável
  sem replay, catálogo/gateway e credenciais nominais.

## Deltas de estado para o Coordenador

As fatias Chat acrescentam provas locais, não `verified`, `done` ou
`verified-e2e`. A divergência golden é anterior ao delta de negação e permanece
aberta; não atualizar referências automaticamente. Avisos segue auditado com
RED planejado; não registrar as expectativas SQL como testes executados.
Mídia segue inventariada, com uma dependência de sessão local pronta e sem
catálogo/gateway produtivo concluído.
