---
source: "Sessão B′ (apoio ao Bloco B) da R15, 17/09/2026; AP-1 em R15-handoff-bloco-b.md (origin/r15/bloco-b bcf47d636); r15-bloco-b/massa-qa-r15-20260917.md; ADR 0042 E2; dump de produção pós-lote 75 (SHA-256 66f8bacc)"
status: evidence
lifecycle: current
generated_at: 2026-09-17
---

# AP-1 — fixture pós-contas da massa `QA R15` (fatia 2 do Bloco B)

Pedido do B (handoff `bcf47d636`): candidato SQL como fixture privada `app_private.seed_qa_r15_*`,
idempotente por e-mail, que crie `person_auth_links` (responsável ↔ conta Auth criada pelo Owner),
`guardian_links` (responsável → Criança 1 e 2), `guardian_context_permissions` (`can_view`) para os dois
contextos e aceite os `child_unit_links` pendentes; aplicação pelo rito assim que a conta
`qa-r15-responsavel@coelo.me` existir. Nenhuma escrita em produção nesta entrega.

## 1. Causa observada (por que a tela não fecha a massa)

Registrado pelo B na evidência da massa e conferido no dump pós-lote 75 (texto das funções, sem inferência):

- A tela `/people/new` cria a pessoa adulta em `draft` sem login ("Adultos não recebem login durante
  este cadastro") e **nenhuma função em `pg_proc` insere em `public.guardian_links`**; a única RPC que
  grava `child_unit_links` aceitos é `app_private.superadmin_student_link` (`status='active'`,
  `accepted_by=actor`, `accepted_at=now()`), não alcançada pelo fluxo de Pessoas.
- A convenção do projeto (seed R06 `20260911230100`) veda `insert em auth.users`: a conta nasce na Auth
  Admin do Owner e o vínculo à pessoa é feito por fixture versionada (mesmo padrão de
  `20260915185048_qa_r14_chat_cross_tenant_identity_v1`).
- Regras que a fixture precisa respeitar, lidas dos triggers/RPCs de produção:

| Regra | Onde | Efeito na fixture |
|---|---|---|
| responsável `adult`, criança `child` | `app_private.validate_guardian_link` | guardas por `person_type` |
| `relationship_type_id` obrigatório; `relation_type` 'responsavel' normaliza para `other` | `guardian_links` NOT NULL + `normalize_guardian_relationship` | usa o tipo `other` do catálogo explicitamente, `relation_type='responsavel'`, `relationship_detail='Responsável (QA R15)'` |
| permissão de contexto deve apontar a criança do vínculo | `validate_guardian_context_permission` | contexto → `child_person_id` → vínculo |
| aceite exige `accepted_by`+`accepted_at`; vínculo de unidade no mesmo tenant do contexto | `child_unit_links_acceptance_check`, `validate_child_unit_link` | `pending → active` com aceite do responsável, só na Unidade QA R04 |
| conta do realm interno não pode virar pessoa | `guard_person_auth_link_internal_realm` | recusa (`23505`) se a conta estiver em `superadmin_internal_auth_links` |
| um vínculo ativo por pessoa e por conta | índices únicos parciais de `person_auth_links` | recusa (`23505`) se pessoa ou conta já estiverem ligadas a outrem |
| leitores exigem `person.status='active'` | `child_care_notification_recipients_v1` (sino de cuidado, E7), `list_my_principal_contexts` | responsável `draft → active` ao receber a conta |
| audiência Famílias do Agora | `app_private.now_viewer_role_class`: `guardian_links` ativo + `guardian_context_permissions.can_view` ativa + contexto/unidade/turma ativos | tudo coberto pela fixture (`can_view/can_message/can_react = true`) |
| capacidades do Principal (`manage_authorized_people`, …) | `guardian_has_capability` exige `guardian_context_permission_grants`, criados só por `superadmin_access_profile_assignment_link` | **fora da fixture** (contrato de Perfis de acesso); não é exigido por Agora, sino nem B5/B6 |

## 2. Entrega

- `packages/coelo_database/migrations/20260917110000_qa_r15_guardian_fixture_v1.sql` (carimbo na faixa do
  Bloco B, posterior a `20260917090000`): cria `app_private.seed_qa_r15_guardian_fixture_v1(p_email,
  p_guardian_person_id, p_child_context_ids, p_institution_id, p_unit_id, p_relation_type)` com os
  defaults da massa de produção (`da915f98…`, contextos `1a6158fe…`/`519ef941…`, tenant `d0c4…0001`,
  unidade `d0c4…0002`); `security definer`, `search_path=''`, dona `postgres`, `revoke all` de
  `public/anon/authenticated/service_role` (invisível ao PostgREST); preflight/pós-verificação;
  idempotente (`create or replace`). A migration **não executa** a função.
- Guardas fail-closed (nada gravado): e-mail fora de `qa-r15-*@coelo.me` (`22023`), conta ausente
  (`P0002 qa_auth_user_missing`), conta do realm interno (`23505`), instituição fora de `qa-r04-*`,
  pessoa/criança sem prefixo `QA R15`, contexto fora do tenant, vínculo de unidade ausente.
- `packages/coelo_database/supabase/tests/qa_r15_guardian_fixture_v1_test.sql`: **22/22** no espelho
  `coelo_mirror_r15_b_apoio` (dump pós-lote 75 + catálogo): estrutura/exposição (4), cinco negativas sem
  gravação (6), caminho feliz (7), idempotência (3), conflitos de conta (2). Massa recriada com os ids de
  produção; `auth.users` recebe insert **só no replay local**.
- Aplicação da migration no espelho 2× sem erro (idempotente).
- Execução descartável (transação com rollback) com a massa do teste:

```
1ª execução → person_auth_link "created", guardian_status draft→active,
  guardian_links_created 2, context_permissions_created 2, unit_links_accepted 2
2ª execução → person_auth_link "existing", guardian_links_existing 2,
  context_permissions_existing 2, unit_links_already_active 2 (nada criado)
estado: person_auth_links ativo 1 · people.status active · guardian_links 2 · permissões can_view 2 ·
  child_unit_links active ×2 (accepted_by = responsável) · follow_links do responsável 6 ·
  app_private.now_viewer_role_class(responsável, tenant, unidade, turma) = 'guardian'
```

## 3. Aplicação em produção (rito) — ainda NÃO executada

Pré-condição: o Owner cria `qa-r15-responsavel@coelo.me` na Auth Admin (senha só em
`Coelo-backups/qa-r15-responsavel.env`). Depois, na worktree de quem aplicar:

1. Espelho restaurado de dump novo + pgTAP verde (feito aqui: `66f8bacc`, 22/22).
2. Dump prévio: `supabase db dump --linked --workdir packages/coelo_database -f C:\Users\adrie\Documents\Coelo-backups\schema-producao-20260917-b-apoio-ap1-before.sql` (+ SHA-256).
3. `Sync-SupabaseCliMigrations.ps1 -Mode Clean`.
4. `supabase db query --linked --workdir packages/coelo_database -f migrations/20260917110000_qa_r15_guardian_fixture_v1.sql`
5. `supabase migration repair --status applied 20260917110000 --linked --workdir packages/coelo_database`
   e `supabase migration list --linked --workdir packages/coelo_database`.
6. Execução da fixture (dado, não schema), como `postgres`, num arquivo `.sql` com uma linha
   `select app_private.seed_qa_r15_guardian_fixture_v1();` via `supabase db query --linked -f`;
   guardar o JSON de retorno na evidência (sem senha, sem `auth_user_id` se o Owner preferir).
7. Lote novo em `ordem-de-aplicacao-producao.txt` (próximo número livre no momento; 75 = B, 76 = C1,
   77+ = C2 conforme o handoff B) e aviso no handoff/arquivo de apoio para ninguém aplicar duas vezes.

Limite desta sessão: às 10:2x BRT o classificador do executor negou a B′ um `supabase db query --linked`
de **leitura** ("Production Reads"); o dump (`db dump --linked`) foi permitido. Se a negativa se repetir
no passo 4/6, a aplicação fica com o Bloco B (que aplicou o lote 75 pelo mesmo comando) após
`git cherry-pick` do commit desta entrega. Nada foi tentado contra a negativa.

## 4. O que fica com o B / fora desta entrega

- Massa: `qa-r15-educador@coelo.me` (opcional) precisa de pessoa + `institution_memberships` com escopo
  `group` na turma `368a5cea` — cabe ao fluxo de Pessoas/Perfis (não a esta fixture).
- Capacidades do Principal para o responsável (`guardian_context_permission_grants`): pela tela de
  Perfis de acesso › Atribuir, se alguma fatia exigir.
- Reversão manual, se o Owner pedir: `delete` das duas `guardian_context_permissions`, dos dois
  `guardian_links` e do `person_auth_links` do responsável (ids no JSON de retorno) e
  `child_unit_links` de volta a `pending` com `accepted_by/accepted_at` nulos.
