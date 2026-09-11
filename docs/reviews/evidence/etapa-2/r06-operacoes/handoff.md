---
title: "R06 · Operações — handoff ao coordenador"
source: "comunicacao/operacoes.json rev 39–44; commits de work/etapa2-r06-operacoes; rota real com qa-r06-operacoes sobre o build web release (qa_main) em 127.0.0.1:3021; pgTAP no descartável coelo_ops_r06"
status: "handoff; o coordenador aplica deltas e edita skills/rastreadores"
generated_at: "2026-09-11"
group: "operacoes"
---

# 1. O que fechou (por action_id, com prova)

| Ação | FE | BE | E2E | Prova |
| --- | --- | --- | --- | --- |
| imports.list (teste) | — | — | — | `fail_closed_screens_with_data_probe_test` 16/16: Importações deixou de transbordar com dados após o composto (R05); entrada invertida (2a28545d3). |
| account.sessions | verified (proposto) | done (proposto) | verified-e2e (proposto) | P43 = B. Pacote `20260911200200_superadmin_account_sessions_v1` (pgTAP 14/14, ordem real com 141 migrations; **aplicado no lote 50**). Card "Sessões" em Configurações: lista real, segunda sessão via API aparece após Atualizar, "Encerrar as outras sessões (1)" → GoTrue `scope=others` → volta a 1, reload mantém. Capturas `rota-real/01-04`. |
| account.settings / account.theme | verified (reconfirmado) | n/a | flutter-only | Claro persiste em `coelo.superadmin.theme-mode` e sobrevive ao reload (captura 05). |
| support.table / support.kanban | verified (P49) | done | verified-e2e (recertificado) | P49 = A: abas Todos/Novo/Em andamento/Aguardando solicitante/Concluído na tabela no lugar do filtro Status; visão cards/tabela persistida por dispositivo (`coelo.superadmin.support.display`); `superadmin_support_list` 200 com o filtro no servidor; reload reabre em tabela. 24 goldens regravados (SUP-R06). Capturas `rota-real/10-14`. |
| plans.activate | verified (proposto) | done (proposto) | verified-e2e (proposto) | Conciliado com a spec 051 como Restaurar (arquivado → ativo): Arquivar + motivo → `plan_save` 200 → Restaurar + motivo → `plan_save` 200; reload e aba Ativos mantêm. Capturas `rota-real/20-25`. |
| catalog.validate / catalog.sync | verified (proposto) | n/a (validação local) | — | P44 = B: composto de diretório e 4 componentes no índice e no registry; 16 exemplos atualizados; `validate_catalog_index`, `validate_package_boundaries` e `validate_catalog_sync` com zero diagnóstico; relatório regenerado sem caminhos absolutos. |
| imports.create (texto) | — | — | — | IMP-R05-2: `/imports/new` diz "Este recurso fica disponível depois do MVP." (`SuperadminErrorKind.deferred`, mesma família do 503). Goldens `error_503_deferred_*` e `import_hub_wizard_unavailable_light_1440_200` regravados (DEF-R06). |

Deltas: `deltas-r06-ops.json` (16), ensaiado com `apply-tracker-delta.cjs` + `validate-trackers.cjs` PASS e revertido.

# 2. Pacotes SQL

- `20260911200200_superadmin_account_sessions_v1.sql` — aplicado pelo coordenador no lote 50. Sem chave de composição. Sem Edge Function: a revogação usa o endpoint nativo do GoTrue.

# 3. O que ficou aberto (primeiro gate)

1. **plans.assign** — a spec 051 mantém vínculos plano-instituição somente leitura; não existe comando de atribuição. **P51 ao Owner** (recomendação: pós-MVP).
2. **catalog.publish** — deploy do app do Catálogo (Cloudflare Pages): decisão nominal do Owner.
3. **audit.export** — não iniciado (Edge Function `audit-export` sem deploy); continua adiado pela ADR 0034.
4. **Aprovação visual** — SUP-R06 (24 goldens de Suporte), DEF-R06 (texto do recurso adiado) e SES-R06 (card Sessões): página https://claude.ai/code/artifact/1d18a357-f2ed-40ee-827b-63798967a700 (cópia em `aprovacao-r06-ops/`).
5. **Testes pré-existentes em apps/catalog** (falham também na base limpa `2a579335e`): `catalog_app_test` (modo público temporário) e `validate_admin_visual_contracts_test` (usos crus em `agenda_calendar_page`, `superadmin_chat_page`, `superadmin_chat_create_group_dialog`, `institution_card`, `institution_filter_menu`; 3 arquivos allowlistados que não existem mais).

# 4. Pendências novas registradas

- `account.sessions`: sem auditoria própria em `audit.audit_logs` (GoTrue registra em `auth.audit_log_entries`); sem revogação individual (GoTrue só expõe `scope=others`). Revisão profunda.
- `support.table`: a 1424 px úteis a toolbar quebra o filtro Leitura para a segunda linha (golden 1440 em uma linha).
- `support.table`: corrigido em 8776eb424 — lista vazia com filtro ativo mostrava a mensagem de vazio; agora "sem resultados" na tabela (o repositório filtra no servidor); kanban mantém colunas vazias.
- `qa_drive.dart` ganhou o comando `eval` (diagnóstico de rede por `performance`).
- Resíduos sintéticos: plano `5b0fc76b-…` arquivado e restaurado (2 recibos novos em `plan_change_receipts`); sessões do `qa-r06-operacoes` (uma revogada); eventos de auditoria das provas.

# 5. Regras para as skills (o coordenador edita)

- **coelo-backend:** listar sessões do próprio usuário é RPC `security definer` sobre `auth.sessions` filtrando por `auth.uid()` e marcando a atual pelo claim `session_id`; nunca aceita `user_id`. Revogar as outras é `POST /auth/v1/logout?scope=others` (SDK `signOut(scope: SignOutScope.others)`), server-side e auditado pelo GoTrue — não precisa de Edge Function nem de Admin API.
- **coelo-frontend / coelo-ui:** abas de status com conjunto próprio usam `CoeloAdminUnderlineTabs<T?>` no slot `tabs` do composto (`null` = Todos) e valem só na tabela quando o kanban já tem colunas por estado (Suporte, P49). Preferência de visão cards/tabela é local por dispositivo (`SharedPreferencesAsync`, chave `coelo.superadmin.<tela>.display`), injetada só na composição real.
- **coelo-frontend:** recurso adiado por decisão usa `SuperadminErrorKind.deferred` ("fica disponível depois do MVP"); `unavailable` (503 "temporariamente") fica para indisponibilidade real.
- **coelo-frontend:** teste que rola a página do Catálogo rola pela `ScrollPosition`, porque o composto de diretório no registry captura o gesto no centro da viewport.
- **coelo-frontend-backend:** `dart run` pelo `dart.bat` passa por `cmd.exe` e quebra expressões JS com `>`; usar `dart.exe` do SDK diretamente e `MSYS_NO_PATHCONV=1` no Git Bash. Campo de diálogo no release: clique por CDP na coordenada do campo (o `tap` por texto do rótulo trava) e `enter_text` do driver.
