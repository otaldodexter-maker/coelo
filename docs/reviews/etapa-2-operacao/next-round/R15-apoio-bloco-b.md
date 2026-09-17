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
- Build QA compilado (`test_driver/qa_main.dart`, 406 s, `build/web/main.dart.js`).
- Detalhe, comandos e ferramentas reutilizáveis: `docs/reviews/evidence/etapa-2/r15-bloco-b-apoio/ambiente-20260917.md`
  e `…/ferramentas/` (`restaurar-espelho.sh`, `extract_catalogo_pos_baseline.py`,
  `catalogo-pos-baseline.sql`, `run_pgtap.sh`).
- Nenhuma escrita em produção; nenhum lote aplicado por B′.

## Pedidos atendidos

Nenhum pedido recebido até 09:25 BRT de 17/09: `origin/r15/bloco-b` ainda não foi publicado
(`git ls-remote --heads origin 'r15/*'` só devolve `r15/bloco-c1`). A coordenadora faz o relé dos
pedidos; esta seção recebe um `### AP-<n>` por pedido.

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
4. Nenhum lote aplicado por B′ até agora; o próximo número livre continua sendo o que o ledger de
   `ordem-de-aplicacao-producao.txt` mostrar no momento (último registrado: 74).

## Para o Owner

Nenhuma pergunta pendente.

## Estado dos pedidos

| AP | Fatia do B | Recebido | Entrega | Estado |
|---|---|---|---|---|
| — | — | — | — | sem pedidos até 09:25 BRT |
