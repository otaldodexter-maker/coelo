---
title: "R15 — apoio ao Bloco B (respostas aos pedidos AP-<n>)"
source: "Prompt B′ em R15-prompts.md (1d941e5d1); R15-execucao-paralela.md (linha B′); R15-handoff-bloco-b.md em origin/r15/bloco-b (seção ## Pedidos de apoio); docs/reviews/evidence/etapa-2/r15-bloco-b-apoio/"
status: "active"
lifecycle: "current"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# R15 — apoio ao Bloco B

Só a sessão B′ escreve neste arquivo. Os pedidos nascem em `R15-handoff-bloco-b.md`
(`## Pedidos de apoio`, `### AP-<n>`: fatia, erro exato, o que o B já tentou, o que precisa) e são
atendidos na ordem de chegada, um por vez. Cada resposta traz a causa **observada** (comando e saída),
a entrega — (a) passo a passo para o B executar na worktree dele, (b) commit em `r15/bloco-b-apoio`
para `git cherry-pick <sha>`, ou (c) "assumo a fatia" — e o que falta ao B fazer. B′ nunca edita a
worktree nem a branch do B; toda escrita em produção segue o rito e fica registrada aqui com o lote.

## Ambiente da sessão de apoio (17/09/2026, pronto às 09:25 BRT)

- Worktree `C:\Users\adrie\Documents\Coelo.worktrees\r15-bloco-b-apoio`, branch `r15/bloco-b-apoio`
  (base `dev` `1d941e5d1`); `.env.local` e `.temp` do CLI copiados; porta `3018`, CDP `9418`, perfil
  `%TEMP%\coelo-r15-b-apoio-chrome` (Chrome só abre quando um pedido exigir tela).
- Dump de produção `Coelo-backups/schema-producao-20260917-b-apoio.sql` (09:04, SHA-256 `c87f4d67…`),
  **idêntico** ao `schema-producao-20260917-r15-b-before.sql` do B (08:51): produção parada no lote 74.
- Espelho `coelo_mirror_r15_b_apoio` (`Coelo-backups/mirror-r15-b-apoio`, portas 625xx) restaurado do
  dump com **0 erros**, ACL fiel à produção (drift dos default privileges corrigido antes da restauração)
  e catálogo semeado (seed de referência + 49 trechos das migrations + papéis de sistema). As seis suítes
  pgTAP do lote 74 estão verdes nele: 44/44, 43/43, 29/29, 15/15, 11/11, 63/63.
- **09:48 BRT — espelho atualizado para o lote 75** (dump novo `schema-producao-20260917-b-apoio-pos-lote75.sql`,
  SHA-256 `66f8bacc…`: 0 `raise serialization_failure`, 0 `errcode='40001'`, 183 `PT409`), mesma receita,
  seis suítes verdes de novo; a suíte do B `pt409_stale_version_v1_test` dá 36/37 aqui (ver aviso 6).
- Build QA compilado (`test_driver/qa_main.dart`, 406 s, `build/web/main.dart.js`).
- Detalhe, comandos e ferramentas reutilizáveis: `docs/reviews/evidence/etapa-2/r15-bloco-b-apoio/ambiente-20260917.md`
  e `…/ferramentas/` (`restaurar-espelho.sh`, `extract_catalogo_pos_baseline.py`,
  `catalogo-pos-baseline.sql`, `run_pgtap.sh`).
- Nenhuma escrita em produção; nenhum lote aplicado por B′.

## Pedidos atendidos

`origin/r15/bloco-b` foi publicado às 09:4x (`6c2f02ee0`, fatia 1 OQ-047 → lote 75) sem pedidos; o AP-1
chegou no push `bcf47d636` (massa `QA R15`) e foi relé pela coordenadora às 10:2x BRT.

### AP-1 — fixture pós-contas da massa `QA R15` (fatia 2) — entregue (b) e fechado (executada pelo B, lote 80)

- **Causa observada** (dump pós-lote 75, texto das funções): a tela cria o responsável em `draft` sem
  login; nenhuma função em `pg_proc` insere em `guardian_links`; só `superadmin_student_link` aceita
  `child_unit_links` (`active` + `accepted_by/accepted_at`); a convenção R06 veda `insert em auth.users`.
  Regras que a fixture respeita: `validate_guardian_link` (adulto/criança), `normalize_guardian_relationship`
  (tipo `other`), `validate_guardian_context_permission` (mesma criança), `child_unit_links_acceptance_check`,
  `guard_person_auth_link_internal_realm` (`23505` para conta interna), índices únicos de `person_auth_links`.
  Dois requisitos que o pedido não citava e a fixture cobre: `child_care_notification_recipients_v1` (sino,
  E7) e `list_my_principal_contexts` exigem `person.status='active'` → o responsável sai de `draft`;
  `now_viewer_role_class` (Agora, audiência Famílias) exige `can_view` ativo + unidade/turma ativas → com a
  fixture responde `guardian`. Fora: `guardian_context_permission_grants` (capacidades do Principal nascem
  de Perfis de acesso › Atribuir; não são exigidas por Agora, sino, B5/B6).
- **Entrega (b)** — commit `6401cace9` em `r15/bloco-b-apoio` (`git cherry-pick 6401cace9`): `packages/coelo_database/migrations/20260917110000_qa_r15_guardian_fixture_v1.sql`
  cria `app_private.seed_qa_r15_guardian_fixture_v1(p_email default 'qa-r15-responsavel@coelo.me', …)`
  com os defaults da massa de produção, sem grant a `anon/authenticated/service_role`, fail-closed (conta
  ausente `P0002 qa_auth_user_missing`, conta interna, pessoa/contexto sem prefixo `QA R15`, tenant fora de
  `qa-r04-*`), idempotente por e-mail; a migration **não executa** a função. pgTAP
  `supabase/tests/qa_r15_guardian_fixture_v1_test.sql` **22/22** no meu espelho (dump `66f8bacc`);
  migration aplicada 2× sem erro; execução descartável: 1ª chamada cria 1 vínculo de conta, ativa a pessoa,
  2 `guardian_links`, 2 permissões `can_view`, 2 aceites; 2ª chamada relata tudo como existente.
  Evidência: `docs/reviews/evidence/etapa-2/r15-bloco-b-apoio/ap-1-fixture-qa-r15-20260917.md`.
- **O que falta ao B** (depois de o Owner criar `qa-r15-responsavel@coelo.me`): `git fetch origin && git
  cherry-pick <sha>`; rito: dump prévio → `Sync-SupabaseCliMigrations.ps1 -Mode Clean` → `supabase db query
  --linked --workdir packages/coelo_database -f migrations/20260917110000_qa_r15_guardian_fixture_v1.sql` →
  `migration repair --status applied 20260917110000 --linked` → `migration list --linked` → executar a
  fixture como `postgres` (`select app_private.seed_qa_r15_guardian_fixture_v1();` via `db query -f`, JSON de
  retorno na evidência) → lote novo no ledger + aviso no handoff. Posso executar os passos 4–6 eu mesma se o
  Owner/coordenadora preferir, com a ressalva do aviso 7 (classificador).

### AP-2 — membership de responsável para o Principal abrir (achado D1 da coordenadora) — candidato pronto, EM ESPERA

- **Origem**: pedido antecipado da coordenadora (`coelo-85`), não do handoff B; depois posto em espera:
  só abre se o B registrar que `list_visible_now_publications` com a sessão `qa-r15-responsavel` devolve
  vazio por falta de `institution_memberships`.
- **Causa observada**: o Principal abre só por `list_my_principal_contexts` (join obrigatório em
  `institution_memberships` ativa; `person.status='active'`); não há leitor de contextos de responsável;
  o cliente espera `role_code='guardian'` (`PrincipalRuntimeContext.isGuardianRole`); não existe papel de
  sistema de responsável. Teste reproduz: após o AP-1, 0 contextos; com a membership, 1.
- **Candidato** (não aplicado): migration `20260917113000_qa_r15_guardian_membership_v1` →
  `app_private.seed_qa_r15_guardian_membership_v1()` cria uma membership `guardian`, escopo `group` na
  turma `368a5cea` (unidade `d0c4…0002`), sem permissões de equipe; fail-closed e idempotente; pgTAP
  `qa_r15_guardian_membership_v1_test.sql` **16/16** no espelho; `now_viewer_role_class` continua
  `guardian`. Evidência: `docs/reviews/evidence/etapa-2/r15-bloco-b-apoio/ap-2-membership-responsavel-20260917.md`.
- **Para decidir antes de aplicar** (ver "Para o Owner"): qualquer membership faz a responsável contar
  como equipe/educadora nos destinatários de cuidado (`child_care_notification_recipients_v1`,
  `medication_notification_recipients_v1`), o que confunde a prova E7.

## Avisos para o Bloco B e para a coordenadora

1. **Drift de ACL do espelho (afeta pgTAP de grants por família, OQ-047).** Num espelho restaurado de
   dump schema-only, `anon`/`authenticated`/`service_role` ganham `execute` em **todas** as funções de
   `public` (519/519) porque o `pg_default_acl` local de `postgres` em `public` concede a esses papéis e
   `ALTER DEFAULT PRIVILEGES … GRANT` é aditivo; produção só concede a `postgres`. Correção que deixa o
   espelho igual à produção: antes de restaurar, `alter default privileges for role postgres in schema
   public revoke all on functions from anon, authenticated, service_role;` (depois: `anon` executa 0
   funções; `authenticated` 430; `service_role` 235). Script: `ferramentas/restaurar-espelho.sh`.
   Sem isso, asserções como "anon cannot execute" falham por ambiente, não por defeito da migration.
2. **Catálogo do espelho.** `seed.sql` (10/09) não tem `child_safety.*`, `routine.*`, `medication.*`,
   `now.*`, `care_policies.manage`, tipos `sede`/`escola` nem `global_type_catalogs`; os trechos de
   nível superior das migrations (`ferramentas/catalogo-pos-baseline.sql`, gerado por
   `extract_catalogo_pos_baseline.py`) mais `select app_private.seed_institution_role_system_templates();`
   completam o catálogo sem nenhum dado pessoal. Resultado no meu espelho: 136 `platform_permissions`,
   182 concessões de plataforma, 57 `institution_permissions`, 4 papéis de sistema, 123 concessões.
3. **Inventário de 40001 no dump de hoje** (texto, sem inferência): 169 `raise serialization_failure` em
   115 funções; 6 `raise exception … errcode='40001'` (`superadmin_agenda_command/_save`,
   `superadmin_plan_save`, `superadmin_support_reply/_set_assignee/_set_status`); 10 handlers `when
   serialization_failure` / `sqlstate '40001'` (locations v2, forms save_draft v2, internal_user
   denial_code, child_context_directory v2, institution contacts/core v2, invites issue/resend/revoke v2,
   structure_handle_set v1); 8 `PT409` já em produção (lote 74). Os handlers precisam continuar
   capturando o que os corpos passarem a levantar (ou capturar `PT409` também), senão a família perde a
   tradução para `SAI_CONCURRENT_CHANGE`.
4. Nenhum lote aplicado por B′ até agora. Lotes registrados: 75 (B, OQ-047, 12:30 UTC); C1 usa 76 e
   C2 77+ (aviso 7 do handoff B). B′ só numera um lote se um pedido exigir escrita em produção.
5. **Bloqueio registrado pelo B** ("prova comportamental por família no espelho — drift do espelho:
   fixtures param antes da asserção de versão defasada", Formulários/Planos/Suporte/Segurança da
   criança/Acontece): a causa é a mesma dos avisos 1 e 2 (default privileges locais + catálogo
   incompleto: o B semeou só `mirror-r14/supabase/seed.sql`, sem os trechos pós-baseline nem a função de
   papéis de sistema). No meu espelho, com a receita completa, `archive_models_v1` dá 63/63 (no dele,
   61/2) e `child_safety_lifecycle_timeout_fix_v1` 15/15. Se o B pedir (AP), rodo as suítes por família
   aqui e devolvo antes/depois; a receita está em `ferramentas/restaurar-espelho.sh`.
7. **Classificador do executor nesta sessão**: às 10:2x BRT negou a B′ um `supabase db query --linked` de
   leitura ("Production Reads"); o `db dump --linked` foi permitido. Logo a aplicação do AP-1 em produção
   pode ficar com o B (que aplicou o lote 75 pelo mesmo comando) via cherry-pick; tento pelo rito se me
   pedirem e, se negado, devolvo sem tentar contornar.
6. **Asserção 8 de `pt409_stale_version_v1_test.sql` está calibrada no drift do espelho do B.** Rodada
   no meu espelho fiel (dump pós-lote 75): 36/37. Comparação mecânica `pt409_props` × `pg_proc`: 0
   diferenças em security definer, `search_path`, dono, volatilidade e retorno; **54 diferenças de ACL**,
   todas do mesmo tipo — o "esperado" do teste traz `anon=X` (e, em 45 funções, `service_role=X`) nas
   funções `public`, que produção não concede (0 `GRANT … TO "anon"` no dump). A migration preserva ACL;
   é o teste que falharia contra produção. Bloco corrigido, pronto para substituir o `insert into
   pt409_props values` original: `docs/reviews/evidence/etapa-2/r15-bloco-b-apoio/ferramentas/pt409_props_producao_pos_lote75.sql`
   (com ele a suíte do B passa 37/37 aqui). Detalhe em `ambiente-20260917.md` §5.1. Não editei a branch
   do B. **Fechado às 10:1x BRT**: o B aplicou o bloco em `c59e5ebf3` (0 linhas com `anon=X`) e a suíte
   dele, lida de `origin/r15/bloco-b`, passa **37/37** no meu espelho fiel (dump pós-lote 75).

## Para o Owner

- **AP-2 (só se for aberto)**: para o Principal abrir para um responsável, a única rota hoje é uma
  `institution_memberships` com `role_code='guardian'`. Isso faz o responsável entrar também nos
  destinatários de cuidado como equipe/educador (RPCs acima). Pergunta fechada: (a) aceitar esse efeito na
  massa QA R15 (prova E7 fica ambígua) ou (b) tratar como lacuna de contrato do Principal (leitor de
  contextos de responsável sem membership) para uma spec própria? Sem resposta, o candidato fica só no
  espelho.

## Estado dos pedidos

| AP | Fatia do B | Recebido | Entrega | Estado |
|---|---|---|---|---|
| AP-2 | 7 — `agora.publish` (Principal da responsável) | pedido antecipado da coordenadora, 17/09 ~15:1x BRT; em espera | candidato: migration `20260917113000_qa_r15_guardian_membership_v1` + pgTAP 16/16 (não aplicado) | **em espera** — abre só se o B registrar leitura vazia por falta de membership; decisão do Owner sobre o efeito colateral |
| AP-1 | 2 — massa `QA R15` (E2): vínculos do responsável | `bcf47d636` (10:2x BRT, relé da coordenadora) | (b) commit `6401cace9` (`git cherry-pick 6401cace9`): migration `20260917110000_qa_r15_guardian_fixture_v1` + pgTAP 22/22 + evidência | **entregue e aplicada pelo B**: cherry-pick `6b06a3381`, migration em produção como **lote 80** (`ded7c006f`); **fechado**: conta criada pelo Owner (`ff3682a1…`) e função executada pelo B em produção (`dedcd83ee`: responsável ativo com login, 2 `guardian_links`, 2 permissões, vínculos de unidade aceitos); antes disso respondeu `P0002 qa_auth_user_missing` (fail-closed, como projetado) |
