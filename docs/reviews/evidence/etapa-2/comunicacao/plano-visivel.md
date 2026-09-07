---
title: "E2E 3 — plano visível por tela e camada"
source: "pedido do Owner via Coordenador em 2026-09-07; reservas E2E3-M01 e E2E3-N01; evidências locais desta frente"
status: "in-progress; not-e2e-complete"
generated_at: "2026-09-07"
updated_at: "2026-09-07"
---

# Plano por tela

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
| 2/6 | Avisos / publicação, leitura, worker e métricas / `notices.publish`, `notices.read` | `public.platform_notices`, `app_private.notice_publication_jobs`, `public.notice_receipts`, RPCs v2/worker; nenhum SQL executado | `crosswalk_media`, `review_media_session`, `review_chat_receipt` | 17+14+10 assertivas preparadas e revisadas, NÃO executadas; aguarda perfil/baseline e lease exclusivo Eng1 |
| 6/6 da fatia | Avisos / formulário-publicar / `notices.publish` | Nenhum BD nesta fatia; mensagem Flutter pelo status retornado | `review_chat_receipt`, `crosswalk_media` | RED scheduled, GREEN focal 2/2; ampliado 38 verdes e 2 falhas mobile preexistentes; replay/visual continuam abertos |
| 6/6 da fatia | Momentos / transporte privado R2 / mídia server-side | Deno `moments-media/r2_s3.ts` e `_shared/r2_s3.ts`; nenhum BD nesta fatia | `review_media_session`, `review_chat_receipt`, `crosswalk_media` | M02 com extensão index_test autorizada; RED seis falhas, GREEN 29/29 completo, lint/typecheck; commit e integração real pendentes |

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
