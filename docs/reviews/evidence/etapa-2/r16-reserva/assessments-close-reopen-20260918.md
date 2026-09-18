---
source: "Sessão RESERVA da R16 (Opus 5, coelo-8d), 18/09/2026; R16-prompt-reserva-20260918.md (lote 82 item d → sem candidato, só prova); r14-sessao-3/assessments-close-reopen/assessments-close-reopen-20260915.md (alvo CDP auxiliar, não aceito); inventário assessments.close/assessments.reopen"
status: evidence
lifecycle: current
generated_at: 2026-09-18
owner_items: "owner.r12-49"
action_ids: "assessments.close, assessments.reopen"
---

# Avaliações › fechar e reabrir — prova na rota real, alvo visível autenticado (18/09/2026)

Ambiente: produção (`evvbomzejfijozbtgvpt`), build QA na porta `127.0.0.1:3014`, Chrome CDP `9414` — **a mesma aba
visível autenticada** como `qa-r06-operacoes` usada em todas as provas desta sessão (a captura de 15/09 tinha sido feita
num alvo CDP auxiliar e por isso não foi promovida). Diário reutilizado `d2c945d8-3809-4d84-b836-2bc6da7c381d`
(Escola R04 Estrutura › Unidade Centro R04 › Turma R05 Estrutura › Atividade R05 Estrutura (editada) · R08 sintético;
participante Crianca QA R04, nota 8,5). **Nenhum participante, vínculo, configuração ou diário foi criado ou
duplicado; nenhum SQL em produção.** O item (d) do lote 82 não tem candidato: `superadmin_assessment_review_gradebook`
e `superadmin_assessment_return_gradebook` estão em produção desde `20260910180350_superadmin_assessments_internal_v2`
(ordem real, linha 104) — confirmado no dump de 18/09.

| Passo | Resultado | Captura |
|---|---|---|
| `/assessments/closing/d2c945d8-…` | Histórico: "Revisado — R14 fechamento autorizado" v11 (15/09); rodapé Devolver / Revisar (desabilitado) / Publicar | `assessments-01-detalhe-revisado-v11.png` |
| Devolver → justificativa "R16 RESERVA reabertura autorizada" → Confirmar → `reload` | "Devolvido ao professor" **v12** · 18/09 11:37 · ator auditado (`assessments.reopen`) | `assessments-02-devolver-dialogo.png`, `assessments-03-devolvido-v12-reload.png` |
| `/assessments/gradebooks/d2c945d8-…/edit` › Revisão e envio › Enviar para fechamento | toast "Período enviado para fechamento."; fila mostra Situação **Enviado**; histórico "Enviado para fechamento" **v13** · 11:39 | `assessments-04-revisao-e-envio.png`, `assessments-05-enviado-fila.png` |
| Detalhe › Revisar → "R16 RESERVA fechamento autorizado" → Confirmar → `reload` | "Revisado" **v14** · 18/09 11:42 · ator auditado (`assessments.close`); Revisar desabilitado, Publicar habilitado | `assessments-06-revisar-dialogo.png`, `assessments-07-revisado-v14-reload.png` |
| Negativa de versão defasada (PostgREST, `expected_version 11` com o diário em v14): `superadmin_assessment_return_gradebook` e `superadmin_assessment_review_gradebook` | envelope `{"ok":false,"error":{"code":"SAI_CONCURRENT_CHANGE","http_status":409}}` (código da família; nunca 40001), sem mutação (detalhe segue v14) | — |

Escopo real: a fila `/assessments/closing` lista só o diário do escopo (1 linha, 0 pendências); deep-link de UUID
inexistente já provado em 15/09 ("Diário indisponível").

**Resultado:** `owner.r12-49` → **done**. `assessments.close` e `assessments.reopen` já eram `verified-e2e` no
inventário (certificação de 15/09); esta evidência substitui a captura do alvo auxiliar por prova no alvo visível.
Nenhum delta de inventário.
