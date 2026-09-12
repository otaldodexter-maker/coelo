---
title: "Deltas propostos às skills — grupo formularios-cuidado-rotina, Rodada 6"
source: "Execução da frente G3 em 11/09/2026 19:37–21:37; comunicacao/formularios-cuidado-rotina.json rev 47–53"
status: "proposta ao coordenador (escritor único das skills em dev)"
generated_at: "2026-09-11"
---

# Deltas propostos às skills (R06, formularios-cuidado-rotina)

## coelo-frontend (`.agents/skills/coelo-flutter-review/SKILL.md`), seção "Regras medidas"

- Rota real por CDP no build release: botões preenchidos (`FilledButton`) e o
  Aplicar do `CoeloDateRangePicker` só respondem ao clique com `mouseMoved`
  ~300 ms antes do `mousePressed` e ~250 ms até o `mouseReleased`
  (`slowclick`); o clique de 60 ms do `cdp_sem` seleciona dias e abre
  diálogos, mas não dispara esses botões. A "falha do seletor de hora/data"
  registrada na R05 em Medicação era do harness, não da tela.
- Driver web no release: `login`, `get_health`, `enter_text` (após foco por
  CDP) funcionam; `set_semantics`, `get_diagnostics_tree` e `tap` travam.
  Texto entra só pelo `enter_text` do driver; `Input.insertText` não chega ao
  campo Flutter.
- Sentinela "novo × edição" nunca é `expectedVersion == 0`: produção devolve
  `management_version 0` para agregados recém-criados (Rotina), e o cliente
  que usava esse sentinela mandava `model_id` nulo e criava um duplicado
  (23505). O id vazio decide criação; a versão esperada só vai no comando.
- Estado vazio e V-15 (Owner): o card Criar aparece em todas as abas de um
  diretório com abas por tipo (Modelos/Rotinas/Lançamentos), em cards e na
  tabela, mesmo com dados; quando o tipo nasce de outro (rotina de modelo,
  lançamento de rotina) o card abre um seletor da origem; a tabela repete as
  ações do card como ícones com tooltip numa coluna "Ações".
- D3 na chamada de Assiduidade: "Sentimento (demonstração local)" e "Não
  persistido nesta etapa" viraram "Sentimento" + "Ainda não está disponível
  nesta versão." até a reconstrução da tela na família Publicação (item 7).

## coelo-backend (`.agents/skills/coelo-supabase/SKILL.md`), seção "Regras medidas"

- `app_private.form_save_draft` (230004) tinha a variável `version_number`
  homônima da coluna de `form_versions` no `select … into`: 42702 só ao salvar
  rascunho de formulário já publicado (`working_version_id` nulo). A suíte
  histórica `forms_behavioral_rpc_test` cobria esse caso e falhava no
  espelho com o corpo de produção; prova E2E de "editar" sobre rascunho não
  cobre "publicado → nova versão de trabalho". Candidato
  `20260912220000_form_save_draft_version_number_fix_v1`. Regra: em plpgsql
  com `search_path=''`, nome de variável nunca repete nome de coluna usada em
  `select … into`; prefixar (`next_…`) e aliasar a tabela.
- Prova de candidato num espelho compartilhado sem mutá-lo: `begin; \i
  candidato; savepoint; <suíte com begin/rollback trocados por savepoint>;
  rollback;` no `psql` do container. Serve para confirmar o diagnóstico antes
  de o coordenador fazer o preflight canônico.
- Medicação: `superadmin_medication_plan_save` não recebe responsáveis; o
  campo Responsável do formulário fica honesto ("Nenhuma opção disponível")
  até haver contrato. `superadmin_medication_plan_record_evidence`
  (010400) está em produção e passou a ter cliente (motivo obrigatório fora
  de `administered`; `media_asset_id` sem gateway no MVP).
- Rotina: arquivar modelo/rotina não precisa de RPC nova — `save_model` e
  `save_application` já aceitam `status` no payload (010100, linhas 745 e
  1126) e revalidam escopo e `expected_version`.

## coelo-frontend-backend (`.agents/skills/coelo-flutter-supabase-review/SKILL.md`), seção "Regras de integração"

- Usuário sintético por frente (`qa-r06-<grupo>`) + Chrome com
  `--user-data-dir` próprio: a sessão sobrevive à reabertura do Chrome
  ("Manter sessão") e ninguém derruba ninguém; conferir o e-mail da sessão
  em `localStorage['coelo.superadmin.auth.session']` antes da primeira
  captura (a página abre já logada).
- Negativa da régua do MVP por RPC direta com a sessão da frente
  (`rpc6.py` lê `.env.local` da worktree e o `.env` de backups do usuário):
  `superadmin_medication_plan_detail`/`record_evidence` com id inexistente
  → P0002 "medication plan unavailable".
- `serve.py` novo por build: matar o listener antigo da porta pelo PID
  (`netstat -ano` + `Stop-Process`) e conferir o md5 de
  `flutter_bootstrap.js` servido contra o do build antes de capturar.
