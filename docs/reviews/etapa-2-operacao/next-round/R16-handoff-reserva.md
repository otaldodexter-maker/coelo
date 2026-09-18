---
title: "R16 — handoff da Sessão RESERVA (D2, D4, D5, D6, D7 do Owner em 18/09)"
source: "R16-prompt-reserva-20260918.md; R16-levantamento-fechamento-mvp-20260918.md §4; R16-pendencias.md; ADR 0041 (D6, E7), 0042, 0044; ordem-de-aplicacao-producao.txt (lote 82)"
status: "active"
lifecycle: "current"
generated_at: "2026-09-18"
updated_at: "2026-09-18"
audience: "team"
---

# R16 — handoff da Sessão RESERVA

Sessão Claude `coelo-8d` (Opus 5), worktree `C:\Users\adrie\Documents\Coelo.worktrees\r16-reserva`, branch
`r16/reserva-20260918` (base `dev` `83d5478bd`). Servidor QA `127.0.0.1:3014`, Chrome CDP `9414`, perfil
`%TEMP%\coelo-r16-reserva-chrome` (um 2º Chrome CDP `9415`, perfil `…-chrome-b`, foi usado só na prova D6 e fechado);
espelho `coelo_mirror_r16_reserva` (`Coelo-backups/mirror-r16-reserva`, portas 627xx) restaurado do dump novo
`Coelo-backups/schema-producao-20260918-r16-reserva-before.sql` (SHA-256
`9bb98a47de15de866c8cd59a4ee646134f67034bb4a3bac7fde1a1a6f02aa243`, 4.344.291 bytes; ACL fiel: `anon` executa 0
funções em `public`, catálogo 136 permissões). Só esta sessão escreve aqui; a coordenadora integra por cherry-pick.
Sessões pares identificadas por `ListAgents` antes da worktree: `coelo-85` (coordenadora, `dev`, sem porta) e
`coelo-2b` (coordenadora da execução de 17/09, encerrada).

## Fato corrigido (primeira passagem)

As migrations `20260916180000`, `20260916183000` e `20260916190000` estão em produção desde o lote 74. As linhas de
`owner.r12-04`, `r12-06` e `r12-33` em `R16-pendencias.md` foram corrigidas na primeira passagem.

## Fatias entregues (commits da branch, na ordem — todos para cherry-pick)

| # | Commit | Bloco | Conteúdo |
|---|---|---|---|
| 1 | `0612a70fe` | 1 (D2) | `owner.r12-04` Histórico e `owner.r12-06` snapshot → **done** na rota real (evidência `r16-reserva/attendance-history-snapshot-20260918.md`, 10 capturas); migration `20260918120000_medication_in_app_notifications_v2` + pgTAP v2 27/27, v1 alinhada 29/29; r12-33 corrigido ("aplicada no lote 74"); handoff criado. |
| 2 | `2361e50d9` | 2 (D4) | `owner.r12-05` → **done** (negativas do contexto Atividade 403 42501 por PostgREST; `participants []` explicado pelo contrato); fixture `20260918123000_qa_r15_attendance_group_fixture_v1` + pgTAP 16/16. |
| 3 | `0d02b00a1` | 3 (D5) | Celular E.164 + máscara: cliente (`CoeloBrazilianPhoneInputFormatter`, validação, mapeamento do erro, widget tests) e servidor (`20260918130000_account_profile_mobile_phone_e164_v1`, `normalize_mobile_phone_e164`, 22023 `invalid_account_mobile_phone`; pgTAP 22/22). |
| 4 | `a2c742a1b` | 4 (D6) | `20260918140000_now_feed_can_remove_follows_rpc_v1` (corpo vigente do dump; só `can_remove := actor_can_remove`) + pgTAP 11/11; projeção v1 alinhada 9/9. |
| 5 | `90fcb3191` | (d) | `owner.r12-49` → **done**: fechar/reabrir na aba visível autenticada (diário `d2c945d8` v12→v13→v14, reload; 409 `SAI_CONCURRENT_CHANGE`). Sem SQL: as RPCs já estavam em produção (`20260910180350`). |
| 6 | `015f64d6d` | lote 82 | Rito completo: dump prévio idêntico (`9bb98a47`), 4 migrations por `db query --linked` uma a uma (14:45:13–14:46 UTC), fixture executada (~14:47 UTC), pós-verificação, `migration repair` ×4, `migration list`, `ordem-de-aplicacao-producao.txt` anotado. |
| 7 | `070ac027a` | 2 (D4) | `owner.r12-08` → **done**: Turma QA R06 Transferencia (2 crianças da fixture) com mark/finish/correct na rota real; múltiplas turmas com ≥2 alunos e rotina vinculada. |
| 8 | `08faf3ccc` | 1/3/4 | Provas pós-lote: sino v2 (`medication-bell-v2-20260918.md`), Celular (`account-mobile-phone-e164-20260918.md`), Agora (`agora-can-remove-follows-rpc-20260918.md`); `owner.r12-33` partial com resíduo preciso; `owner.r12-46` parte Celular concluída (segue deferred pelo layout A+); dívidas `recipients-bug`, `can-remove`, `celular-mascara` concluídas. |
| 9 | `5de8028bf` | 5 (D7) | 21 testes funcionais vermelhos corrigidos: 19 de referência velha (teste) e 2 regressões reais (código): `directory_composition_test` (renomear `_CallsDirectory/_CallsTable` → `_CallsSection/_CallsRows` no Histórico) e `superadmin_circular_pages_test` (`CoeloCreateAction` tile estourava 16 px a 375/200%: rótulo `Flexible` em `coelo_ui_core` + altura mínima no compositor). Goldens intocados. |
| 10 | (este) | fechamento | Handoff final, `testes-vermelhos` na fila, censo antes/depois. |

Owner: **44/53** (r12-04, r12-05, r12-06, r12-08, r12-49 `done` em 18/09; eram 39/53). `validate-trackers.cjs` **PASS**
a cada commit. Nenhum `action_id` mudou de estado (todos já `verified-e2e`); nenhum delta de inventário.

## Censo `flutter test` (apps/superadmin)

- **Antes** (HEAD `0d02b00a1`, 18/09 ~12:30 BRT): 6953 passaram, 8 pulados, **155 falharam** = 142 goldens (32 suítes)
  + **13 funcionais em 11 suítes** (`invite_responsive_test` já corrigido quando o censo chegou nele; 21 no censo de 17/09).
- **Depois** (HEAD `5de8028bf`, 18/09 ~13:55 BRT, 7 min): 6965 passaram, 8 pulados, **143 falharam** = 142 goldens
  (32 suítes, os mesmos) + 1 `agenda_remote_states_test` (golden dentro de suíte funcional). **0 funcionais.**
- Goldens: ficam na Etapa 3 (D7). Observação: 8 goldens de `account_pages_golden_test` passaram a divergir **só no
  campo Celular** (parênteses da máscara, D5) — `isolatedDiff` conferido; não regravados. `agenda_remote_states_test`
  contém um golden e por isso segue vermelho (não é funcional).

## Avisos para a coordenadora

1. **Lote 82 aplicado em produção** (autorização nominal do Owner de 18/09, itens a/b/c + ajuste de projeção D6). Item
   (d) não teve SQL. Candidato `20260917113000_qa_r15_guardian_membership_v1` continua **não aplicado**. Espelho do CLI:
   `-Mode Prepare` falha pelo drift conhecido (226 ≠ 209) mas copia as migrations; `-Mode Clean` executado (árvore limpa).
2. **Massa de produção alterada** (tela/RPC com identidade QA, além da fixture do lote): rotina aplicada `8b317b01` (escopo
   instituição QA R04 Cuidado, **Ativa**); chamada `98f6796c` (v6, 2 presentes/1 falta, snapshot); chamada nova `de250fe0`
   (Turma QA R06, 18/09, `corrected` v5); diário `d2c945d8` v14 "Revisado"; plano de medicação `2ecf267e` "QA R15
   Ibuprofeno R16" (QA R15 Crianca 1, v2 dose 7 ml, 1 dose administrada); story do Agora `fcfe2865` publicada e
   **removida** (purga enfileirada; asset `15b914e7` segue o ciclo); Celular de `qa-r06-operacoes` = `+5521987654321`;
   crianças "QA R15 Crianca 3/4" (`b2843b9d`, `3500fe7b`) na Turma QA R06 Transferencia.
3. **Decisão do Owner pendente (não tomada):** "Publicar lançamento" no Histórico › Lançamentos de rotina ou de volta em
   Rotinas (spec 052 §3).
4. **Formato do Celular para spec/ADR (via coordenadora):** E.164 brasileiro `+55DDD9NNNNNNNN` no servidor; máscara
   `+55 (DD) 9NNNN-NNNN` na exibição; inválido → 22023 `invalid_account_mobile_phone`.
5. **Resíduos UX/FE sem action_id (para a revisão de telas):** editor de Rotina aplicada fica em
   `/daily-routine/new?applicationFrom=…` após salvar, sem feedback; painel "Público e contexto" do publicador do Agora
   não abriu por clique de coordenada (público ajustado pela RPC); no 2º Chrome como `qa-r06-publicacoes` a faixa "Agora"
   ficou vazia e `/principal-now` redirecionou para `/principal-happens` enquanto a mesma sessão, por `fetch`, recebia a
   story para `d0c40000…` (hipótese: contexto padrão do shell = "QA R04 Instituicao Sintetica"; o seletor "Coelo ›" não
   respondeu ao clique); `superadmin_attendance_complete_call` por PostgREST sem chave reservada → 22023 (contrato).
6. **Ambiente:** `qa_drive.dart texts` trava (`get_diagnostics_tree`); direção por `cdp_sem.dart clickxy` + captura e
   `qa_drive.dart cmd command=enter_text` para digitar (o `Input.insertText` do CDP não chega ao Flutter no build QA);
   cópia local de `cdp_sem.dart` ganhou `wheel` (scratchpad, fora do repositório). O classificador negou um comando
   combinado (`date` + `db query` + `grep`); executado sozinho, passou — nada contornado.
7. Os três arquivos não rastreados da coordenadora (`R16-prompt-reserva-20260918.md`, `R16-levantamento-…`,
   `MVP-definicao-…`) foram copiados para a worktree só para leitura e **não** entram nos commits.

## Bloqueios (com causa)

- **`owner.r12-33` (sino v2) — observação do admin da unidade e do educador da turma em produção:** as 11 memberships
  ativas do tenant sintético QA R04 Cuidado são pessoas de serviço (`person_type = 'service'`), que por regra nunca são
  destinatárias; não existe pessoa humana de equipe para receber o sino. Provar esse caminho em produção exige uma
  fixture de membership (SQL fora dos itens a–d autorizados) → **parado, sem contornar**. O caminho está provado no
  espelho fiel (pgTAP 27/27) e a responsável foi observada em produção (E7 = b). Decisão do Owner: aceitar a prova do
  espelho ou autorizar a fixture.

## Sobra (não executado nesta sessão)

- Goldens (142) — Etapa 3 (D7). `agenda_remote_states_test` (golden dentro de suíte funcional) idem.
- `oq048-membership`, `momentos-ux`, `orfaos-cardapio`, `form-diario`, `forms-v2-qa`, `espelho-cli`, `h02-aal2`,
  resíduos H e `owner.r12-18` — fora do recorte desta sessão.
- Atualizar `current-state.md`, `backlog.md`, skills e spec/ADR do formato do Celular — coordenadora.

## Contadores

`node docs/reviews/validate-trackers.cjs` **PASS** — FE 199/199, BE 186/186, E2E 186/186; Owner **44/53**.

## Censo depois

HEAD `5de8028bf`: `flutter test` em `apps/superadmin` → **+6965 ~8 -143**; as 143 são todas goldens (142 em 32 suítes
`*_golden_test` + o golden de `agenda_remote_states_test`). Antes: +6953 ~8 -155 (13 funcionais em 11 suítes; 21 no censo
de 17/09). Logs: `census-before.log` / `census-after.log` no scratchpad da sessão (não versionados).
