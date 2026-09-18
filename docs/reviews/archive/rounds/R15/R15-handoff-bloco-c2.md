---
title: "R15 — handoff do Bloco C2 (B5 busca de pessoa, B6 pessoa sem conta, r12-38 Cardápios R2)"
source: "R15-prompts.md (Prompt C2); ADR 0041 B5/B6; ADR 0032; R15-pendencias.md"
status: "active"
lifecycle: "current"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# R15 — handoff do Bloco C2

Worktree `C:\Users\adrie\Documents\Coelo.worktrees\r15-bloco-c2`, branch
`r15/bloco-c2` (base `dev` `57162cee4`, `dev` mergeado até `315887f5d`). Porta
3017 / CDP 9417; build QA servido também em `127.0.0.1:3016` (única origem
local livre permitida no CORS de `coelo-media-prod`, liberada pela coordenadora
após o C1 encerrar). Espelho `coelo_mirror_r15_c2` (624xx) restaurado do dump
`schema-producao-20260917-r15-c2-before.sql` (SHA-256 `c87f4d67…`).

## Reivindicações

- Segurança da criança › wizard Criar/Editar (`child-safety.create/edit`) — apenas o
  campo de pessoa autorizada (B5/B6); o Bloco B mantém `edit/suspend` e a massa.
- Cardápios (`meal-plans.create/edit/publish/model-edit`) — imagem R2 (r12-38).

## Fatias entregues

| SHA | Fatia | Estado | Evidência |
|---|---|---|---|
| `650297873` | B5 — `superadmin_person_search_v1` (spec 061) + FE do wizard | pgTAP 33/33; **produção (lote 78)**; rota real provada | `person-search-and-person-without-account-20260917.md`, `rota-real-b5-b6-r12-38-20260917.md` |
| `4e96c8840` / `1a43b0435` | B6 — pessoa sem conta (spec 062): migration + pgTAP 40/40 + Edge `child-safety-media` + FE | **produção (lote 78)**, Edge v2 (`5ea5984c6`); rota real provada (documento pelo gateway em Node; wizard com documento `ready`) | idem |
| `13f4a8c9b` | r12-38 — Cardápios imagem R2 (spec 063): migration + pgTAP 26/26, Edge `meal-plan-media` + cleanup R2, adapter FE pelo gateway | **produção (lote 78)**; rota real provada na 3016 (upload pelo navegador, prévia após reload, publicar, model-edit) | `rota-real-b5-b6-r12-38-20260917.md` |
| `09edfde35` | Fatia 4 — specs sem prova: 064 (OQ-044, `draft-for-review`), 065 (§5), 066 (OQ-033), 067 (OQ-034), 068 (OQ-032, `draft-for-review`), 069 (H08/H13/H23) | só spec | — |
| `5ea5984c6` | Edge `child-safety-media`: `finalize` aceita o bilhete sem `storage_provider` (422 na rota real) | integrado em `dev` `315887f5d`; v2 implantada | rota real |
| `4c89d3065` | Wizard de Cardápios: arquivo pendente satisfaz "Anexe a imagem" | rota real | rota real |
| `ece99cc3a` | Cardápios: FE persiste/relê `simpleImageMeta` (chave do backend); antes a imagem salva nunca voltava no reload | rota real (revisão 5 do cardápio 6272879e) + teste de contrato | rota real |
| (este commit) | Evidência da rota real, ferramentas (`qa_drive.dart`, `edge_probe.mjs`, roteiros), capturas, deltas propostos | — | `deltas-r15-c2-b5-b6-r12-38.json` |

## Deltas propostos (não aplicados — a coordenadora aplica)

`docs/reviews/etapa-2-operacao/next-round/deltas-r15-c2-b5-b6-r12-38.json`:
`meal-plans.create/edit/publish/model-edit` e `child-safety.create/edit` →
`integrated verified-e2e` (com certificação em produção). `validate-trackers`
PASS antes da aplicação (`actions 232, frontendCompleted 204, backendCompleted 182,
e2eCompleted 179, activeE2E 186`, contadores da `dev` mergeada).

Linhas de Owner propostas (R15-pendencias.md, tokens exatos):

- `owner.r12-17` → **done**: B5 provado na rota real em 17/09 (mínimo por tipo,
  nome/@ com resultado minimizado sem CPF, seleção, autorização criada e relida,
  rate limit 422 PT422, escopo vazio fora do ator). Resíduo sem prova de tela:
  celular/CPF (massa sem celular/CPF; pgTAP) e "responsável lista crianças"
  (depende de `guardian_links` da fixture AP-1 do B; pgTAP).
- `owner.r12-18` → **done** (limites aceitos): cadastro com CPF mascarado, documento obrigatório
  em R2 privado `ready` (gateway), dedupe por (instituição, CPF) pela tela e por
  RPC, wizard até a revisão com a pessoa sem conta, envio com
  `authorized_person_id` (RPC com o payload do wizard → pendente `b729f6b8`) e
  releitura no detalhe (RPC). Limites: upload do documento pelo navegador (CORS,
  Owner 17/09); `PERSON_HAS_ACCOUNT` só pgTAP; o clique final "Enviar" pela
  tela não concluiu (aba travada) — se o Owner exigir esse clique, **partial**
  por esse único motivo.
- `owner.r12-38` → **done**: upload pelo gateway a partir do navegador (3016),
  prévia após reload, publicar e model-edit sem regressão; sem 409 legado.
  Resíduo: dois ativos órfãos `active` (`35dd7c74`, `2541d4b5`) no cardápio
  publicado — `request_image_delete` devolve 22023 (cardápio imutável); limpeza
  exige revisão aberta ou o cleanup do Owner.

## Bloqueios e limites (por causa)

| Gate | Causa | Detalhe |
|---|---|---|
| Upload do documento B6 pelo navegador | **ambiente (CORS R2)** — decisão do Owner 17/09 | `coelo-documents-prod` sem origem CORS; `coelo-media-prod` só 3014/3016/superadmin.coelo.me. Prova pelo gateway em Node + wizard com documento `ready`. |
| `PERSON_HAS_ACCOUNT` | **massa** | nenhuma pessoa com conta do tenant tem CPF em `person_identity_identifiers`; só pgTAP. |
| Busca por celular/CPF com resultado; responsável listando crianças | **massa** (AP-1 do B) | só pgTAP até a fixture entrar. |
| Negativa cross-tenant do descritor de imagem | **massa** | todos os atores QA são do tenant QA R04 com `meal_plans.read`; só pgTAP. |
| Limpeza dos ativos órfãos | **regra de produto** | cardápio publicado é imutável para imagens (`20260910190100`). |
| Goldens `meal_plan_pages_golden_test` (5) | deriva do cabeçalho (E4), já falham em `dev` | não regravados. |

## Massa residual em produção (prefixo QA R15, tenant QA R04 Cuidado)

- `authorized_people` `e9f02f4b-1dd5-4287-bf92-034e8aa3e807` (QA R15 Tio Sem Conta, CPF só HMAC) + documento `9a01711e-1bf9-49d3-ab7a-de930d11aa2e` (`ready`, `coelo-documents-prod`).
- Autorização pendente B5 para a Crianca QA R04 (QA R04 Responsavel · Mãe) e autorização pendente B6 `b729f6b8-ac69-4201-b289-27d87c1a7c86` (QA R15 Tio Sem Conta · other/Tio · pickup).
- Cardápio `6272879e-9a52-4ce5-8922-5777c18ea82b` (`published`, imagem `362777eb-2404-4aee-98c6-246b3abad755`) + ativos órfãos `35dd7c74…`, `2541d4b5…` (`coelo-media-prod`).
- `app_private.person_search_hits` com as buscas do dia (rate limit).

## Avisos

1. Specs 064–069 numeradas acima da faixa informada (061–064); sem colisão em
   `origin/r15/bloco-a|b|c1` no commit. Renumerar na integração se preciso.
2. Regra durável (ADR 0041): CPF nunca em claro → busca por CPF só com o número
   completo (HMAC). Registrado nas specs 061/062.
3. Ativos legados (`supabase_mvp`) seguem lidos pelo caminho v1 no servidor; o
   cliente novo lê pelo gateway (409 `legacy_storage_asset`); não há legados.
4. Driver web do Flutter: taps por finder travam a fila quando um `waitFor`
   pendente expira; os roteiros finais usam coordenadas (`clickxy`) + `enter`.
5. Ao encerrar: espelho parado, Chrome/servidores 3016/3017 encerrados, stash vazio.

## Sobra para a R16

- Upload do documento B6 pelo navegador quando o Owner liberar CORS (3014–3024).
- Limpeza dos dois ativos órfãos do cardápio 6272879e; decidir se o cleanup deve
  cobrir ativos `active` sem referência.
- Provas dependentes de massa: celular/CPF na busca, responsável com crianças
  vinculadas (fixture AP-1), `PERSON_HAS_ACCOUNT`, negativa cross-tenant.
- Specs 064–069: decisão do Owner e implementação.
