---
source: "Sessão B′ (apoio ao Bloco B) da R15, 17/09/2026; pedido antecipado da coordenadora (coelo-85, achado D1) e ordem de espera posterior; ap-1-fixture-qa-r15-20260917.md; dump de produção pós-lote 75 (SHA-256 66f8bacc); apps/superadmin/lib/features/principal_shared/"
status: evidence
lifecycle: current
generated_at: 2026-09-17
---

# AP-2 (candidato em espera) — membership de responsável para o Principal abrir

Estado: **candidato pronto e validado no espelho; NÃO aplicado em produção**. A coordenadora pediu o
preparo (achado D1: `list_my_principal_contexts` exige `institution_memberships` ativa e a responsável
QA R15 tem 0) e depois colocou o AP-2 em espera: só abre se o Bloco B registrar que a leitura do Agora
pela responsável devolve vazio por falta de membership.

## 1. Causa observada

- Único leitor de contextos do Principal no cliente:
  `apps/superadmin/lib/features/principal_shared/data/supabase_principal_runtime_context_repository.dart`
  → RPC `list_my_principal_contexts`, que faz `join public.institution_memberships … status='active'`
  (obrigatório), `institution.status='active'` e `person.status='active'`. Não existe leitor de contextos
  de responsável em `pg_proc` (`health_care_profile_for_guardian` e `medication_plans_for_guardian` são
  leitores de conteúdo, não de contexto).
- O cliente já espera membership de família: `PrincipalRuntimeContext.isGuardianRole =>
  roleCode == 'guardian' || roleCode == 'student'`. Em produção `role_code` é texto livre (sem check);
  só `owner` e `legal_representative` são tratados nas funções; os papéis de sistema são
  `institution_admin`, `coordinator`, `teacher`, `secretary` (nenhum de responsável).
- `app_private.now_viewer_role_class`: `guardian_context` prevalece sobre `active_membership`; uma
  membership sem `institution_role_assignments` não gera `staff_effects` → o Agora continua tratando a
  pessoa como `guardian` (confirmado no teste, asserção 14).
- Efeito colateral (contrato, para o Owner): `child_care_notification_recipients_v1` e
  `medication_notification_recipients_v1` contam memberships de escopo `institution`/`unit` como equipe da
  unidade e de escopo `group` como educadoras da turma — com qualquer membership a responsável passa a
  receber os eventos de cuidado também por esse caminho, o que confunde a prova E7 ("responsável vê o
  sino por ser responsável"). Nenhuma RPC foi alterada.

## 2. Candidato

`packages/coelo_database/migrations/20260917113000_qa_r15_guardian_membership_v1.sql` cria
`app_private.seed_qa_r15_guardian_membership_v1(p_email default 'qa-r15-responsavel@coelo.me',
p_institution_id, p_unit_id, p_group_id default 368a5cea…, p_role_code default 'guardian')`: uma
membership ativa `guardian`, `scope_kind='group'` na turma com `scope_unit_id` da unidade, sem
`institution_role_assignments`; `security definer`, `search_path=''`, `revoke all` de
`public/anon/authenticated/service_role`; idempotente por e-mail; fail-closed (conta ausente/realm
interno, pessoa sem vínculo de conta do AP-1 ou sem prefixo `QA R15`, tenant fora de `qa-r04-*`, turma
fora da unidade, responsável sem `guardian_link` ativo para criança com contexto/turma ativos, membership
ativa divergente → `23505` sem sobrescrever). A migration não executa a função.

## 3. Prova no espelho (`coelo_mirror_r15_b_apoio`, dump pós-lote 75 + catálogo)

- Migration aplicada 2× sem erro (idempotente).
- `supabase/tests/qa_r15_guardian_membership_v1_test.sql`: **16/16** — estrutura/exposição (3); recusa
  antes do AP-1 (1); **achado D1 reproduzido**: após o AP-1, `list_my_principal_contexts()` como a conta
  da responsável devolve **0** contextos (1); negativas sem gravação (4); caminho feliz: membership
  `guardian/group/368a5cea…/d0c4…0002`, o leitor passa a devolver **1** contexto com esses valores e
  `now_viewer_role_class` continua `guardian` (5); idempotência e conflito (2).
- `qa_r15_guardian_fixture_v1_test.sql` (AP-1) segue 22/22.

## 4. Se o AP-2 for aberto

Rito de sempre (dump prévio → `db query --linked -f migrations/20260917113000_…` → `migration repair`
→ `migration list` → `select app_private.seed_qa_r15_guardian_membership_v1();` como `postgres` → lote
novo no ledger). Reversão manual: revogar a membership (`status='inactive'`, `revoked_at=now()`).
Antes de aplicar, o Owner decide o efeito colateral do §1 (audiência dos eventos de cuidado).
