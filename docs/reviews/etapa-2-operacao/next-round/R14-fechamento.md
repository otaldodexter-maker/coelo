---
title: "R14 — Fechamento (16/09/2026)"
source: "decisions/0042-r14-closure-r15-opening-20260916.md; R14-checkpoint-20260915.md; R14-checkpoint-20260916.md; R14-pendencias.md (congelado); R14-handoff-sessao-1..10.md; validate-trackers.cjs em 8334d3695"
status: "historical"
lifecycle: "historical"
generated_at: "2026-09-16"
updated_at: "2026-09-16"
execution_status: "PASS DOCUMENTED_PARTIAL em 2026-09-16; três aceites E2E novos no dia; fila transferida integralmente para a R15"
audience: "team"
---

> Documento histórico. R14 foi encerrada em 16/09/2026 por decisão do Owner
> (ADR 0042) e sua fila foi consolidada na R15. A fonte atual é
> `R15-pendencias.md` e `docs/agent/current-state.md`.

# R14 — Fechamento

R14 abriu em 14/09/2026 (fila única consolidada de R12/R13 + H02–H28) e fechou
em 16/09/2026 em `dev`/`origin/dev` `8334d3695`, sem abrir Etapa 3 e sem deploy
público. Rodou em três ondas de sessões paralelas (1–4 em 15/09; 5–8 e 9–10 em
16/09) com integração por rebase (onda 1) e cherry-pick (ondas 2–3).

## Resultado por contador (abertura → fechamento)

| Métrica | 14/09 (abertura) | 16/09 Mesa (ADR 0041) | 16/09 fechamento |
|---|---|---|---|
| FE verificado | 186/232 | 186/232 | **189/232 (81,5%)** |
| BE concluído | 168/225 | 168/219 | **171/219 (78,1%)** |
| E2E verificado | 142/199 → 159/193 | 159/186 | **162/186 (87,1%)** |
| Owner items done | 15/53 | 21/53 | **21/53 (39,6%)** |

Os denominadores caíram por reclassificação autorizada (Bloco B em 15/09;
`institutions.files` e `errors.*` em 16/09), não por certificação.

## O que fechou na R14

- Bloco A 10/10 na rota real (Circulares, Agenda, Assiduidade, Rotina, Acontece,
  Shell, Atividades, Convites, Chat grupo, Unidades) — Sessão 1.
- Cardápios (`r12-34/35/36/37`), `assessments.close/reopen`, coleções de
  cuidado com limite 100, catálogos OQ-031, reader self da Conta, `r12-09`,
  `r12-11` — Sessões 2/C/D + aceites da Mesa.
- Chat: fixture cross-tenant, `asset_id` no envelope, Edge `chat-media`;
  Agora: pacote de remoção imediata (ADR 0040) — Sessão E.
- 16/09: `access-profiles.create`, `agora.create`, `agora.view` (E2E);
  `agora.publish/expire` (BE); OQ-046 (lote 72); lote 73 de Formulários;
  causa do 504 de Segurança da criança observada (OQ-047) e corrigida em
  migration; escopo de atividades corrigido em migration; cabeçalho global
  estabilizado e 30 goldens regravados (C1); r12-01 (C3); B1/B2/B3/B8
  especificados e implementados localmente com pgTAP verde.

## O que não fechou e por quê

- **Ambiente**: incidente do PostgREST de produção a partir de ~12:28 BRT de
  16/09 (pool esgotado por laços de retentativa em SQLSTATE 40001) parou todas
  as provas de rota real das Sessões 5/6/7 (Perfis edit/assign, Instituições,
  Conta, Formulários, Chat, Momentos, errors.409).
- **Permissão do executor**: escritas em produção autorizadas pela ADR 0041
  (D3/D4) negadas pelo modo automático; seis migrations verdes no espelho
  ficaram sem aplicação (`20260916152000/154500/180000/183000/190000/193000`).
- **Massa/decisão**: `agora.publish` E2E e `r12-08` (D6), `r12-33` (identidades
  de unidade/educador).
- **Contrato**: mosaico de várias mídias por mensagem no Chat não é alcançável
  pela rota normal (`r12-52`).
- **Specs decididas para a próxima rodada**: perfil transversal (OQ-044,
  `r12-19/23`), Perfis de cuidado §5 (`r12-29/30`), OQ-033, OQ-034, OQ-032,
  B5/B6/B9, H08/H13/H23.

## Transferência para a R15

Tudo o que está aberto/parcial em `R14-pendencias.md` (32 Owner items, 19 H,
2 itens da ADR 0038, 27 ações não terminais) e os resíduos operacionais da
varredura R01–R14 foram levados para `R15-pendencias.md` com os mesmos IDs.
Itens `done` não retornam. Nenhum estado mudou na passagem.

## Git e artefatos

- `dev` = `origin/dev` = `8334d3695`; stash vazio; gate PASS DOCUMENTED_PARTIAL.
- Worktrees `Coelo.worktrees\r14-*` (seis) e branches `r14/*` integradas por
  cherry-pick, protegidas no `entrega-atual.json`; disposição final na R15.
- Dumps de produção fora do Git em `Coelo-backups/schema-producao-20260916-*.sql`.
- Evidências: `docs/reviews/evidence/etapa-2/r14-sessao-1..10/` e
  `r14-coordenacao/`.
