---
title: "Deltas propostos às skills a partir do grupo realm-interno (Rodada 4)"
grupo: "realm-interno"
source: "comunicacao/realm-interno.json (rev 1–14); candidatos/realm-interno/README.md; prova-producao-2026-09-10.md; ordem do Owner de 11/09 08:20"
status: "proposta ao coordenador; aplicada na branch work/etapa2-r04-realm-interno nos três SKILL.md, para merge"
generated_at: "2026-09-11"
---

# Deltas às skills — grupo realm-interno

O coordenador já levou à skill `coelo-backend` as regras transversais da
Rodada 4 (ordem real de aplicação, `db query -f`, MFA fora do MVP, ponte de
ator, revokes 240500/240600) e à skill `coelo-frontend-backend` o formato dos
deltas e o método de rota real. O que segue é o que **só este grupo mediu** e
ainda não está nas skills. Os trechos foram aplicados nos três `SKILL.md`
desta branch (seções marcadas "Rodada 4") para o coordenador integrar.

## 1. `coelo-backend` (`.agents/skills/coelo-supabase/SKILL.md`)

Acrescentar em "Regras medidas na Rodada 4":

- **Chat do Superadmin roda no realm interno v2 em produção** (lote 9): 12
  RPCs `superadmin_chat_*_v2` (`inbox`, `unread_total`, `thread`,
  `send_message`, `edit_message`, `revoke_message`, `mark_read`,
  `realtime_refresh`, `set_pinned`, `set_flag`, `create_group`,
  `group_members`), capacidades `chat.internal.read` (owner, operations),
  `chat.internal.send` e `chat.internal.manage` (owner), envelope spec-039
  `{ok, data, error{code, message, http_status, correlation_id}}`, códigos
  `CHAT_*`/`SAI_*`; outro tenant responde `CHAT_NOT_FOUND` (não enumera).
  Contrato completo em `comunicacao/realm-interno.json` → `contrato`.
  `chat.attach` continua sem função de escrita em `chat_attachment_metadata`
  e sem Edge Function `chat-media`: depende do gateway de mídia comum.
- **Reescrever migration histórica sobre a baseline** exige, além dos labels
  `NOT NULL`: `app_private.audit_append_superadmin_internal` com **13
  argumentos** (o histórico chamava com um 14º `jsonb` que produção não tem),
  `requires_mfa=false` e sessões `aal1` nas fixtures. As suítes históricas
  `superadmin_internal_chat_v2_test`, `..._receipts_edit_revoke_test` e
  `..._preferences_test` não valem sobre a baseline; as `*_baseline_test.sql`
  as substituem (arquivar as antigas é decisão do coordenador).
- **`ALTER DEFAULT PRIVILEGES ... REVOKE ... FROM anon` não protege função
  nova**: testado no descartável, função criada depois continua executável por
  `anon` via `PUBLIC` (`proacl` nulo). A única proteção é o
  `revoke all on function ... from public, anon, authenticated, service_role`
  explícito antes do `grant execute` mínimo, em cada função de cada pacote.
- **Prova em produção de uma família de RPCs**: script Deno que entra por
  senha com `qa-r03` (GoTrue) e chama as RPCs por PostgREST com
  `Prefer: params=single-object`; credenciais só no ambiente do processo
  (`Invoke-ChatInternalProductionProof.sh` lê `Coelo-backups/qa-r03.env` e a
  chave anon do CLI em memória); saída só `PASS|FAIL|SKIP` por caso; modo
  `--read-only` para reconferir produção sem escrever na conversa de outra
  frente. Padrão reutilizável (`packages/coelo_database/scripts/chat-internal-production-proof.ts`).
- **Dado sintético que gerou auditoria não pode ser apagado**:
  `audit.audit_logs` (append-only) referencia `institution_id`, pessoa,
  membership e identidade interna por FK. A limpeza arquiva
  (`status=archived`, `deleted_at`, nome marcado "QA ...") em vez de
  `delete`, e a fixture reativa ao ser reaplicada. Fixture e limpeza nascem em
  par, com ids fixos por prefixo do grupo, registrados no JSON (P37).
- **Não há `psql` na máquina**: usar o do container
  (`docker exec -i supabase_db_<project_id> psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f -`)
  para aplicar pacotes e rodar pgTAP no descartável (`-qtA` e contar `ok`/`not ok`).

## 2. `coelo-frontend` (`.agents/skills/coelo-flutter-review/SKILL.md`)

Acrescentar em "Dependências por recorte":

- **Chat (administrativo e Principal hospedado no Superadmin)**:
  `SupabaseChatRepository` é o único caminho produtivo; a composição real
  (`superadmin_auth_scope.dart`) injeta o repositório com sessão e
  `UnavailableChatRepository` fica só como padrão do construtor. As 12 RPCs
  `superadmin_chat_*_v2` estão em produção com o contrato de
  `comunicacao/realm-interno.json`; assinatura não muda sem pacote novo do
  backend. Criar grupo (`ChatCreateGroupCommand`) exige **uma** instituição e
  `personIds` do realm de pessoas (profissional com vínculo ativo ou
  responsável com criança ativa nela); grupo entre instituições não existe no
  modelo. `CHAT_MEMBER_INVALID` (422) é validação
  (`ChatMemberInvalidException`), nunca perda de sessão; `CHAT_READ_ONLY`,
  `CHAT_EDIT_WINDOW_CLOSED` e `CHAT_ALREADY_REVOKED` são conflito de estado.
  Recibo só renderiza quando o servidor projeta `receipt`; bandeira
  desconhecida vira `none`.
- **Pendências FE da família chat**: `chat.create-group` pela UI não fechou
  na retomada da R04 (diálogo fechou e nenhum grupo apareceu após reload;
  causa não isolada); `chat.attach` fica visível e inerte até o gateway de
  mídia comum.

## 3. `coelo-frontend-backend` (`.agents/skills/coelo-flutter-supabase-review/SKILL.md`)

Acrescentar em "Regras de integração medidas na Rodada 4":

- **Contrato antes da aplicação**: o grupo de backend publica assinaturas,
  envelope, códigos e capacidades no próprio JSON antes de o coordenador
  aplicar; o grupo de cliente liga o repositório real sem mudar assinatura.
  Foi assim que a família chat virou o primeiro `verified-e2e` da Etapa 2
  (backend realm-interno no lote 9 + UI do principal-chat-sistema).
- **Fixture sintética compartilhada**: ids fixos com prefixo por grupo
  (`9f040000-` para o chat), aplicada uma vez, mantida até o fechamento e
  repassada pelo JSON à frente que precisa dela; a frente que a criou
  responde pela limpeza, que arquiva o que a auditoria referencia.
- **Negativa cross-tenant no MVP quando produção não tem segunda identidade
  escopada**: pgTAP com Owner escopado a outra instituição chamando **todas**
  as RPCs da família (`superadmin_internal_chat_cross_tenant_test.sql`,
  21/21) mais, em produção, `anon` negado e id inexistente não enumerável.
  Vale como gate de RLS do MVP; a prova por segunda sessão real fica para a
  revisão profunda.
- **Pacote transversal de privilégios** (revoke de `anon`/`authenticated`):
  medir antes e depois, por papel, tabelas e funções em produção e no espelho
  (contagens iguais para os papéis preservados) e reconferir a rota real com
  o modo somente leitura da prova da família.

## 4. Correção a levar ao Owner (P24)

O texto de P24 em `R04-perguntas-ao-owner-20260911.md` descreve o 240400 como
"membros são identidades internas ativas". **Não é o que foi entregue**: no
pacote em produção os membros são pessoas da instituição (profissional com
`institution_memberships` ativo ou responsável com `guardian_links` de criança
com `child_contexts` ativo na instituição); o criador interno não entra como
participante. Se o Owner responder "só identidades internas", é uma variante
nova (~1 h, `240700`), não o pacote atual. A pergunta deve ser reescrita antes
da resposta.

## 5. O que a Etapa 2 evoluiu com este grupo

- Backend da família chat: de 0 `done` para 7 `done` (chat.list, open, send,
  edit, receipts, revoke, create-group), com certificação de produção.
- Primeiro `verified-e2e` da Etapa 2 (família chat, com o principal-chat-sistema).
- Segurança básica em produção: `anon` sem tabela, sequência ou função nos
  schemas da aplicação (240500); `authenticated` sem TRUNCATE/REFERENCES/TRIGGER
  (240600); 30 tabelas com `GRANT ALL` a `anon` e 22 com TRUNCATE a
  `authenticated` deixaram de existir.
- Método reprodutível de espelho local (baseline + seed + ordem real) e de
  prova em produção por sessão sintética.

## 6. Pendências que ficam para depois do MVP

| Pendência | Onde está registrada | Gate |
| --- | --- | --- |
| `chat.attach` (metadados + `chat-media`) | rastreadores (blocked-environment) | pacote de mídia comum |
| Grants CRUD de `authenticated` sem policy (INSERT 23, UPDATE 26, DELETE 18, SELECT 7 tabelas) | `varredura-authenticated-2026-09-11.md` | análise por tabela na revisão profunda; não aplicar antes da demonstração |
| Policies de `conversations/messages/participants` com bypass `platform.read` (produção) vs. `can_access_chat_conversation` (histórico) | cabeçalho do 240000 | revisão profunda de segurança |
| Realtime do chat (nenhuma publication; cliente não assina) | JSON rev 3 | decisão de produto |
| Suítes históricas do chat a arquivar | README dos candidatos | coordenador |
| P24 (escopo de membros do grupo) e P25/P37 (dados sintéticos) | perguntas ao Owner | Owner |
| Instituição sintética `9f040000-…-0010` em produção (reativada às 22:53 para o principal-chat; arquivar na limpeza) | JSON rev 8, P37 | limpeza da Etapa 2 |
