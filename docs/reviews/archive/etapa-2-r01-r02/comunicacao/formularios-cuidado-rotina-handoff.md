---
title: "Handoff — grupo formularios-cuidado-rotina, Rodada 6 (noite de 11/09/2026)"
source: "Execução da frente G3 em 2026-09-11 19:37–21:37 (T0 19:36 pelo coordenador); comunicacao/formularios-cuidado-rotina.json revisões 47 a 53; deltas-r06-fcr.json; produção conferida pela aba Network e por RPC direta"
status: "entregue; 1 candidato SQL pronto para o coordenador aplicar; sem deploy de Edge Function nesta rodada"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# Handoff — formularios-cuidado-rotina (Rodada 6)

Recorte: 43 ações das famílias `forms_authoring`, `forms_responses`,
`forms_files`, `child_safety`, `health_care`, `medication`, `attendance` e
`daily_routine`; 26 já em E2E na abertura. Branch
`work/etapa2-r06-formularios-cuidado-rotina`, base `origin/dev ca60b096b`.
Usuário `qa-r06-formularios@coelo.me` (credencial só no `.env` de backups).
O handoff da R05 foi preservado em
`docs/reviews/evidence/etapa-2/r05-formularios-cuidado-rotina/handoff-r05.md`.

## O que fechou (prova na rota real, produção, sessão qa-r06)

| Ação | Estado proposto | Prova |
| --- | --- | --- |
| health-care.list | BE done, verified-e2e | `superadmin_health_care_directory` 200, perfil real listado, reload |
| medication.create/detail/edit | verified-e2e | plano `12f816e8` criado (v1), reaberto, dose 2.5→5 (v2), reload; P0002 para id alheio |
| medication.evidence | verified-e2e (novo no cliente) | `superadmin_medication_plan_record_evidence` 200 → `42e77772` (recusada, motivo); detalhe relido |
| daily-routine.list | verified-e2e (V-15 A+) | Criar em Modelos/Rotinas/Lançamentos (cards e tabela), ações na tabela, Arquivar (cópia `8d219282` arquivada) |
| daily-routine.edit | verified-e2e | 23505 medido e corrigido (id enviado sempre); `save_model` 200 v2, lista recarregada |
| daily-routine.publish | verified-e2e (D7) | Lançar hoje → `880b12a8` (rascunho) → Publicar → `published` v2, reload |
| child-safety.list / child-safety.child | verified-e2e | `child_safety_directory` e `child_safety_get` 200 no reload |
| Decisão 7 em Assiduidade | prova na rota real | `/attendance/new` e `/attendance/calls/d3821901` sem balão (capturas 40/42) |

Deltas: `docs/reviews/evidence/etapa-2/r06-formularios-cuidado-rotina/deltas-r06-fcr.json`
(25; ensaiados com `apply-tracker-delta.cjs` + `validate-trackers.cjs` PASS e
revertidos). Capturas em `.../r06-formularios-cuidado-rotina/rota-real/`.

## Código entregue (commits pequenos, em português)

- `19e00ba7a` golden `profile_directory_table_light_1440` regravado (item 0: célula alinhada pelo composto).
- `7ab1a05f8` medication.evidence: `recordEvidence` no repositório, evidências no detalhe, diálogo Registrar dose.
- `03ccdbf41` V-15: card Criar em toda aba (cards e tabela), seletor de origem, ações da tabela, Lançar hoje (D7).
- `2164739b3` Rotina: editar envia `model_id/application_id/launch_id` sempre que o id existe (23505 medido).
- `168cb64eb` candidato `20260912220000_form_save_draft_version_number_fix_v1.sql` (42702 ao salvar rascunho de formulário publicado).
- `d027e3aa5` nome da criança no editor de medicação após reload; diálogo de dose 520 px; Sentimento sem texto de demonstração (D3).
- `fd8e675af` Arquivar modelo/rotina (status `archived` pelo save existente), coluna Ações com três ícones.

## Pacote SQL pronto (coordenador aplica)

`packages/coelo_database/candidatos/formularios-cuidado-rotina/20260912220000_form_save_draft_version_number_fix_v1.sql`:
`app_private.form_save_draft` (230004, única definição em produção) falha com
42702 quando `working_version_id` é nulo (formulário já publicado). Mesmo corpo
com a variável renomeada; sem mudança de contrato. Prova no espelho
`supabase_db_coelo_baseline` em transação com rollback:
`forms_behavioral_rpc_test` aborta na linha 279 sem o candidato e passa 17/17
com ele. Desbloqueia `forms.edit` de formulário publicado e
`forms.location-question`.

## O que ficou aberto (primeiro gate)

- **forms.location-question / forms.location-answer**: pergunta Local
  adicionada pelo catálogo do editor (capturas 50–55); Salvar rascunho → 42702.
  Gate: aplicar o candidato acima e repetir a prova; a resposta exige nova
  ocorrência (cron) com o item Local publicado.
- **forms.upload/resolve-file/expire-file/delete-file** (item 4): não coube.
  O editor não tem UI de imagem da pergunta (picker, PUT com
  `required_headers`, finalize, resolve na exibição, delete); `/forms/media/:assetId`
  só lê pelo `action: read`. Gate FE do grupo; a `form-media` question-image em R2 já está implantada.
- **Item 6 (políticas macro da unidade)** e **item 7 (Lançar chamada na
  família Publicação)**: não couberam; a tela atual de chamada segue sem balão.
- **medication.create**: campo Responsável sem opções — o contrato de
  `superadmin_medication_plan_save` não recebe responsáveis (decisão/contrato).
- **medication.edit**: teste pré-existente `medication_plan_ui_contract_test`
  "375 pixels and 200 percent text" falha na base (overflow do `SuperadminFormFrame`).
- **child-safety.child**: Relação em enum cru (mother/father), herdado.
- **medication.evidence**: imagem da dose sem gateway (`media_asset_id` nulo).

## Harness (regras medidas nesta rodada)

- Botões preenchidos e o Aplicar do seletor de data só respondem ao clique com
  hover de ~300 ms e press de ~250 ms (`slowclick`); o clique rápido do
  `cdp_sem` não fecha o seletor. A "falha do seletor de hora/data" da R05 era
  do harness, não da tela.
- `set_semantics` e `get_diagnostics_tree` do driver travam no release; `login`,
  `get_health` e `enter_text` (após foco por CDP) funcionam.
- Chrome dedicado com `--user-data-dir=%TEMP%/coelo-chrome-formularios`
  preserva a sessão entre reaberturas.

## Dados sintéticos criados (limpeza no fim da Etapa 2)

Plano de medicação `12f816e8` (v2) e evidência `42e77772`; lançamento
`880b12a8` (publicado) da rotina `3d9f0a32`; modelo `176882c5` renomeado
"(R06)" (v2); cópia `8d219282` arquivada. Nenhuma chave criada por esta frente.
