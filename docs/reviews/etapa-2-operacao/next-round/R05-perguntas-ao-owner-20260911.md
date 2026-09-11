---
title: "Rodada 5 — perguntas ao Owner (tarde de 11/09/2026)"
source: "coordenacao.json revs 38-45; JSONs das sete frentes da R05; docs/reviews/evidence/etapa-2/r05-*/"
status: "open"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# Rodada 5 — perguntas ao Owner

Lote único da tarde. Visuais têm página lado a lado (**R** referência guardada,
**A** render atual). Responder por arquivo (`nome - decisão, observação`) ou
"tudo aprovado". Respostas entram em `coordenacao.json`, na ADR 0034 e nas
skills no mesmo turno em que chegarem.

## Visuais

| Item | Frente | Página | Estado |
| --- | --- | --- | --- |
| G-SUP-R05 — Suporte e Em implantação alinhados como Instituições (16 goldens claros) e `plan_table_light_*` | operacoes | https://claude.ai/code/artifact/7737ccf7-1489-4d67-ba5f-858c051150d2 (cópia em `evidence/etapa-2/r05-operacoes/g-sup/`) | **Respondido às 14:20: "está tudo aprovado, ficou legal"** → `ownerVisualApproval = A` |
| P33/P34-R05 — calendário da Agenda conforme o iPhone (P33, R) e rodapé do detalhe do evento (P34, A+): 12 goldens `agenda_calendar_*` e `agenda_detail_*` | publicacoes-agenda | https://claude.ai/code/artifact/881e760e-4a7a-456e-9f1e-54fd26be3975 (cópia em `evidence/etapa-2/r05-publicacoes-agenda/duvidas-visuais.html`) | aguardando |

## Produto e processo

| Item | Frente | Pergunta | Recomendação |
| --- | --- | --- | --- |
| P43 | operacoes | `account.sessions` (listar e revogar as próprias sessões) não tem tela nem API de cliente; exigiria Edge Function sobre o Admin API do Auth. Entra no MVP? | A) pós-MVP (recomendado; Sair já encerra a sessão e MFA está fora do MVP); B) tela mínima no MVP (lista + revogar todas) com Edge Function |
| P44 | operacoes | Catálogo (`catalog.validate/sync`): 5 componentes do composto da Fase 0 sem entrada no índice e 7 exemplos com fingerprint desatualizado. Atualizar agora ou depois do MVP? | A) depois do MVP, junto da revisão de UI (recomendado); B) agora, por uma frente de UI |

## Registro

- Chaves criadas na rodada e dados sintéticos: ver `R05-fechamento.md`.
