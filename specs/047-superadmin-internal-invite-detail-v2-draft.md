---
title: "Rascunho técnico — Convites DETAIL/RELOAD CORE v2 e ponte de schema"
source: "decisions/0019-superadmin-internal-identity.md; specs/039-superadmin-internal-auth-session-context.md; specs/011-superadmin-database-rls.md; specs/015-contextual-people-access-attendance.md; histórico removido specs/026-superadmin-invites-production.md e 20260811233609_superadmin_invites_production.sql; OQ-039"
status: "draft-for-review"
generated_at: "2026-08-28"
---

# Convites DETAIL/RELOAD CORE v2 — rascunho

## Status e limite desta spec

Este documento registra proveniência, alternativas e um contrato candidato. Ele
não aprova migration, capability, grant, backfill, schema físico, output final,
teste executável ou acesso produtivo. A etapa atual é estritamente documental e
de inventário; RED e SQL permanecem bloqueados até as decisões da OQ-039.

Nenhuma decisão deste rascunho autoriza restaurar
`20260811233609_superadmin_invites_production.sql`, alterar o remoto, revogar o
legado ou conectar Flutter.

## Objetivo

Preparar uma futura leitura aditiva e minimizada de um convite pelo
Superadmin interno, com reload posterior, sem usar Pessoa como principal e sem
inventar autoria para registros legados.

## Problema atual

O baseline canônico e o remoto possuem `public.invitations` do realm global.
A leitura existente é destinada ao próprio alvo ou emissor people-based por
`current_person_id()`. Ela não é uma API do principal interno da spec 039.

A antiga implementação produtiva local adicionava diretório, detalhe,
emissão, reenvio e revogação, mas:

- derivava autoridade de `people`, `person_auth_links` e
  `platform_memberships`;
- usava `actor_person_id` em recibos, outbox e audit v1;
- exigia `invited_by` ligado a `people`;
- criou shape e capabilities somente numa migration local-only removida;
- nunca implementou aceite e não comprovou delivery externo.

Ela não pode ser restaurada ou usada como ponte de autorização.

## Estado físico e proveniência

### Baseline atual

- `20260623191021` cria `public.invitations`.
- `20260720180000` adiciona estado, hierarquia, alvo mascarado, emissor
  people-based, envio e aceite people-based.
- hardenings posteriores mantêm SELECT `authenticated` e policy self-read por
  `current_person_id()`.
- `platform.invites.read` e `platform.invites.manage` não existem no canônico
  nem no remoto consultado.
- não existem RPCs `superadmin_invite_*` no HEAD ou no remoto.
- Flutter produtivo injeta `UnavailableInviteRepository`.

O remoto consultado somente por SELECT tem 21 colunas legadas, RLS habilitada
sem FORCE, policy `invitations_self_read`, SELECT direto de `authenticated` e
ALL de `service_role`. Não houve prova comportamental de BOLA; a superfície
direta e a minimização exigem inventário/cutover separado.

### Pacote histórico não promovível

`20260811233609_superadmin_invites_production.sql`:

- commit de origem `33087e25`;
- blob Git `840e4cab50a3b37929822ca88ed3919ae7d2e8b2`;
- SHA-256 LF preservado
  `D387F117DDE47462787F89D94026464FAA0956FFB6D7CF576D89A1CD888B1077`;
- removida em `f71b6a9c`;
- ausente do ledger remoto;
- teste histórico original blob
  `6227565a8e3b973dcc29aa690aeb82b75c2eaf84`, 31.141 bytes;
- teste posterior/hardened blob `b489853...`, 31.206 bytes, dependente também
  de `20260813123901` e do estado `configuration_missing`.

A evidência histórica 60/60 pertence à cadeia composta e não comprova
`20260811233609` isoladamente.

A evolução delivery `20260813123901` teve os blobs intermediários
`8b535453...` e `5e61f5e0...`, e o blob final recuperado
`2b71de3540bc1e6e8d2b23946f2e3a3b61bfa184` (SHA-256
`D1668626A74AD3A942EB10748E5F70AA9E134907295A7D335909E1828FA1A4CD`).
Ela também está ausente do ledger remoto e não possui provider, domínio de
aceite ou rate limit reconciliados.

## Escopo candidato

Somente após aprovação desta spec e das decisões da OQ-039:

- detalhe por UUID;
- reload/read-after-read do registro persistido;
- principal interno da spec 039;
- resposta envelope `{ok,data,error}` com status HTTP apenas semântico;
- negativa indistinguível para ausente e fora do escopo;
- audit v2/v3 correlacionado e append `fail-closed` após sessão válida;
- ACL opt-in do wrapper e zero EXECUTE cliente em helpers privados.

## Fora de escopo

- listagem, filtros e opções;
- emissão/criação;
- reenvio, revogação, aceite ou expiração por scheduler;
- token, link copiável, outbox, provider, rate limit ou Edge Function;
- convite de Usuário Interno, ativação de instituição ou convite familiar;
- alteração Flutter, repository produtivo ou E2E;
- revogação de policy/grants legados;
- backfill automático ou criação de ator sintético.

## Decisões abertas — não implementar antes de aprovação

### 1. Capability e matriz

Alternativa A, candidata conservadora:

- criar `platform.invites.read`, ativa e `requires_mfa=false`;
- grant inicial ao Owner;
- exigir Owner em AAL2 pela regra estrutural da spec 039;
- aceitar somente membership interna `scope_kind=platform` e
  `scope_institution_id is null`;
- negar Support e Content.

Alternativa B: reutilizar `platform.read` somente para esta leitura, mediante
decisão explícita e allowlist separada, sem torná-la autoridade genérica de
Convites.

Alternativa C: permanecer sem capability e sem API interna. A capability
existente `platform.member.invite` não equivale a leitura de convites de
instituição/família e não pode ser reutilizada por semelhança de nome.

A matriz precisa decidir separadamente entre grant Owner-only inicial e papéis
catalogáveis futuros, inclusive Operations/Auditor. O alcance precisa escolher
entre platform-only e scope institution derivado da membership; neste último
caso, a leitura deve validar `invitation.institution_id` sem oracle.

Nenhuma alternativa está aprovada nesta versão.

### 2. Emissor legado e emissor interno

Alternativa A, ponte tipada sem backfill inventado:

- preservar `invited_by` para registros do realm global;
- adicionar `invited_by_internal_identity_id` nullable apenas para novos
  registros criados por um futuro comando interno;
- exigir exatamente um tipo de emissor somente quando o ciclo de criação for
  aprovado;
- não converter `invited_by` para identidade interna sem prova determinística.

Alternativa B: criar entidade tipada de issuer separada, mantendo ambos os FKs
no registro de origem e projetando apenas um discriminador minimizado.

Alternativa C: omitir completamente o emissor no primeiro detalhe, mantendo a
proveniência somente no banco/audit até existir contrato de exibição.

Em todas as alternativas, `invited_by` legado é dado de domínio e nunca fonte
de autoridade do wrapper interno.

### 3. Representação minimizada do emissor

Candidatos de output, ainda não aprovados:

- `{kind: legacy_person, display: "Emissor institucional"}` sem ID/nome;
- `{kind: superadmin_internal, display: "Usuário interno"}` sem IDs;
- omissão total do campo.

Não devolver `person_id`, internal identity/link/membership IDs, e-mail, Auth
ID, sessão ou hash de sessão.

### 4. Shape física do convite

O histórico local-only introduziu `profile_id`, `channels`, `version` e
`updated_at`, mas isso não os torna canônicos.

Alternativa A: primeira leitura usa somente colunas físicas atuais e omite
perfil/canais/versão. Isso reduz o bridge, mas não satisfaz o modelo Flutter
atual e não serve de cutover.

Alternativa B: aprovar colunas tipadas mínimas:

- `profile_id` com FK e regra de escopo;
- `channels` com allowlist futura; para registros legados o valor permanece
  `unknown`, pois preencher `link` por padrão inventaria histórico;
- `version > 0` para comandos futuros;
- `updated_at` para reload e concorrência futura.

Alternativa C: criar uma nova entidade versionada de convite e preservar
`public.invitations` apenas como legado.

Não há autorização para backfill. Se uma coluna futura for NOT NULL, o
preflight deve falhar antes de mutar quando não existir derivação inequívoca.

## Shape candidata de detalhe

O output mínimo só poderá ser fixado após a decisão física. A allowlist máxima
para revisão é:

- `id`;
- `scope_kind`;
- `institution` com `id` e `name`;
- `unit` nullable com `id` e `name`;
- `group` nullable com `id` e `name`;
- alvo coarse `person` ou `email_masked`, sem hash/ID de Pessoa;
- perfil coarse somente se `profile_id` for aprovado;
- status efetivo e `expires_at`;
- canais somente se aprovados;
- versão/`updated_at` somente se aprovados;
- emissor conforme uma das alternativas anteriores.

Sempre omitir `token_hash`, `target_contact_hash`, contato integral,
`target_person_id`, `invited_by`, Auth/session IDs, receipts, outbox e audit
bruto.

## Autorização candidata

Se a alternativa A de capability for aprovada, o futuro wrapper deverá:

1. validar `auth.uid()` e `session_id` contra `auth.sessions` do mesmo usuário;
2. resolver link/membership interna ativa e não revogada;
3. exigir papel/capability/grant ativos, allow e não revogados;
4. exigir Owner e AAL2;
5. exigir scope platform/null;
6. consultar o convite somente depois do contexto válido;
7. convergir ausente e fora de escopo em `SAI_PERMISSION_DENIED`;
8. nunca consultar `people`, `person_auth_links` ou `platform_memberships` para
   autorizar.

## Envelope e auditoria candidatos

- wrapper público `SECURITY DEFINER`, `SET search_path=''`, `VOLATILE`, EXECUTE
  somente para `authenticated`;
- helper privado sem EXECUTE para PUBLIC/anon/authenticated/service_role;
- envelope seguro conforme specs 039/040;
- nenhuma auditoria antes de uma sessão Auth validada;
- negativa com ator interno completo usa audit v2;
- negativa com sessão válida sem vínculo completo usa audit v3;
- falha do append aborta a RPC;
- audit nunca recebe token, contato/hash, Pessoa alvo ou output bruto.

## RED e SQL bloqueados

Não existe RED executável aprovado nesta etapa. Um teste que exija capability,
shape, colunas ou assinaturas candidatas transformaria alternativas ainda
abertas em contrato por acidente. O baseline ausente fica registrado por
inventário e proveniência, não por um teste a ser promovido.

Somente depois das decisões da OQ-039, uma revisão desta spec poderá fixar o
contrato e autorizar o RED de aceitação. O futuro GREEN exigirá migration
forward-only e regressão dos realms existentes.

## Testes exigidos após aprovação

- papeis, AAL e scopes selecionados pela matriz aprovada positivos;
- papeis, AAL e scopes não aprovados negativos;
- sessão ausente, divergente, expirada e revogada;
- link/membership/role/capability/grant inativos, suspensos, revogados ou deny;
- ID ausente/cross-scope sem oracle;
- payload e nested keys exatos, sem hashes/PII/IDs de atores;
- reload após mudança persistida autorizada;
- audit v2/v3 1:1, digest e append adversarial;
- ACL/owner/SECURITY DEFINER/search_path/overloads;
- coexistência e regressão do self-read legado em Admin/Principal; aceite
  permanece não implementado e bloqueado;
- cross-app e cross-tenant;
- cleanup transacional e zero fixtures.

## Critério para sair de draft

A OQ-039 precisa selecionar explicitamente:

1. capability e matriz;
2. modelo de issuer e ausência/política de backfill;
3. shape física mínima;
4. representação minimizada do emissor;
5. coexistência/cutover do legado.

Depois da decisão, testes de aceitação devem preceder qualquer migration.
Nenhum objeto candidato pode ser criado apenas para materializar uma
alternativa ainda não aprovada.

Até lá, o estado é `blocked-schema/provenance`, Flutter permanece
`UnavailableInviteRepository` e nenhuma ação de Convites é promovida.
Importação/exportação, delivery, aceite e mudança de status continuam fora.

A revisão desta spec deve registrar explicitamente se permaneceu draft ou se
cada uma das cinco decisões foi aprovada; silêncio não significa aprovação.
