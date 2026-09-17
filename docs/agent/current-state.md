---
title: "Estado atual do trabalho do Coelo"
source: "Owner em 2026-09-14, 2026-09-15 e 2026-09-16 (ADR 0042); docs/reviews/etapa-2-operacao/ETAPA-2-estado-atual.md; R15-pendencias.md; RODADAS.md; decisions/0042-r14-closure-r15-opening-20260916.md; decisions/0039-owner-scope-commercial-plans-auth-stage3-20260915.md; decisions/0040-agora-immediate-removal.md"
status: "active"
lifecycle: "current"
generated_at: "2026-09-14"
updated_at: "2026-09-17"
audience: "team"
---

# Estado atual

## Agora

- A Etapa 2 está na **R15**, aberta em 16/09/2026 pelo Owner (ADR 0042) como
  fila única consolidada com **tudo o que ficou pendente de R01 a R14** (IDs
  preservados; itens `done` não retornam). R14 fechou no mesmo dia
  (`R14-fechamento.md`); R12/R13/R14 são históricos congelados.
- Corte de abertura (validate-trackers em `8334d3695`): FE 189/232 (81,5%),
  BE 171/219 (78,1%), E2E 162/186 (87,1%), Owner 21/53 (39,6%). Fila: 27
  ações não terminais (22 executáveis), 32 Owner items abertos/parciais (27
  executáveis), 19 resíduos H, 2 itens da ADR 0038 e resíduos operacionais.
- **Desbloqueios de 16/09 (fim do dia)**: o Owner liberou a escrita em
  produção para a coordenação; as seis migrations da R14 foram aplicadas (lote
  74, ledger 302–309) e o incidente do PostgREST terminou com a primeira delas
  (`PT409` no lugar de 40001). Mesa R15 respondida (ADR 0042 E1–E7): OQ-047
  sistêmica autorizada; massa mínima `QA R15` autorizada (responsável + 2
  crianças + admin/educador); Chat passa a aceitar vários anexos por mensagem
  (contrato novo); goldens regravam suíte a suíte; B2 publica no Histórico;
  sino de Medicação inclui o responsável. E8: reset de senha no MVP, provado
  com a caixa do Owner (`auth.recover` BE done; SMTP próprio → Etapa 3). E9:
  MFA ×3 → pós-MVP. Corte: FE 189/232, BE 172/219, E2E 162/186. CORS das Edge por porta aplicado
  (`127.0.0.1:3014–3024` nas seis `*_ALLOWED_ORIGINS`); sem pendência de ambiente.
- **17/09 — execução paralela em curso** (`R15-execucao-paralela.md`): cinco
  sessões do Owner em worktrees `r15-bloco-a|b|b-apoio|c1|c2`; a coordenadora
  integra em `dev` por cherry-pick. **Lote 75 aplicado em produção (12:30 UTC,
  Bloco B)**: `20260917090000_pt409_stale_version_v1` troca os 175 `40001`
  restantes por `PT409` em 126 RPCs (OQ-047 encerrada; negativas de versão
  defasada por PostgREST são seguras em todas as famílias). Integradas em `dev`
  como local-green: Chat E3 (spec 058, C1), busca de pessoa B5 (spec 061) e
  pessoa sem conta B6 (spec 062, C2); **lote 78 aplicado em produção pela coordenadora** (autorização nominal do
  Owner, ~14:00 UTC): migrations de B5/B6/r12-38 + Edges `child-safety-media`,
  `meal-plan-media`, `meal-plan-image-cleanup`; falta só a prova E2E da C2. **Corte de 17/09 (integrações do dia)**: FE 206/232, BE 183/219, E2E 181/186, Owner
  36/53 — certificados em produção `chat.attach` (C1, lote 76 + Edge `chat-media`),
  `access-profiles.edit` e `access-profiles.assign` (A); Owner items r12-20/21/22/24/25/26/27
  e r12-52 → done.
- Ordem da R15 (E5): quatro prompts — coordenadora + um por bloco. Bloco A (rota real já pronta na R14: Perfis
  edit/assign, Instituições, Conta, Formulários, Chat, Momentos, errors.409) →
  Bloco B (após migrations: Segurança da criança, contexto Atividade,
  `agora.remove`, B1/B2/B3/B8) → Bloco C (contratos novos: B5/B6/B9, specs
  OQ-044/§5/OQ-033/OQ-034/OQ-032, H08/H13/H23, r12-38).
- Execução paralela: as seis worktrees `Coelo.worktrees
14-*` continuam
  protegidas (integradas por cherry-pick) e podem ser reaproveitadas pelas
  sessões da R15; regra: filhas commitam na própria branch, a coordenadora
  integra. Nunca `git add -A`/`stash`.
- Regra durável (OQ-047): nenhuma RPC nova sinaliza versão defasada com
  SQLSTATE 40001; usar `PT409`.
- Decisões vigentes do Owner: ADR 0038 (Etapa 2), 0039 (Planos/Auth → V1/Etapa
  3), 0040 (remoção imediata do Agora), 0041 (Mesa da R14: aceites,
  contratos B1–B10, visual C1–C4, autorizações D1–D8), 0042 (R14 → R15). Não
  reabrir.
- Histórico detalhado da R14 (ondas, sessões, incidente): `R14-fechamento.md`,
  `R14-checkpoint-20260916.md`, `R14-execucao-paralela.md` (histórico).

## Fonte da fila atual

Use, nesta ordem:

1. [Fila única R15](../reviews/etapa-2-operacao/next-round/R15-pendencias.md) — Owner
   items (fonte do sync), H, itens da ADR 0038, ações não terminais e resíduos operacionais;
2. [Estado atual da Etapa 2](../reviews/etapa-2-operacao/ETAPA-2-estado-atual.md) —
   percentuais canônicos;
3. [Inventário por action_id](../reviews/inventario-etapa-2.json) — detalhe e
   certificação por ação (estados só mudam por `apply-tracker-delta.cjs`);
4. [Fechamento da R14](../reviews/etapa-2-operacao/next-round/R14-fechamento.md) e
   [checkpoint de 16/09](../reviews/etapa-2-operacao/next-round/R14-checkpoint-20260916.md)
   — apenas para o delta do último corte; checkpoints anteriores são históricos.

Os três rastreadores grandes são projeções do inventário para auditoria; não são a
entrada inicial. `R12-pendencias.md`, `R13-pendencias.md`, `R14-pendencias.md`, `R14-catalogo.md`,
`R13-projecao-atual.md` e `R13-owner-items-atual.json` são históricos/derivados.

## Regra de passagem entre rodadas (aplicada em 14/09 na R13 → R14 e em 16/09 na R14 → R15)

A cada fechamento de rodada:

- itens `done` ou aceitos não são transferidos nem reabertos;
- itens `open`, `partial`, bloqueados ou sem prova são levados para a rodada nova com o
  mesmo `action_id`/Owner ID e nova referência de rodada;
- não criar cópia concorrente em R12, R13, R14 ou R15;
- atualizar este arquivo, `RODADAS.md`, o catálogo corrente, o inventário e os
  rastreadores no mesmo ciclo;
- somente depois registrar que a rodada nova está aberta.

## Fora do trabalho corrente

Etapa 3, V1, V2, pós-MVP, históricos R01–R14 e artefatos de execução não são
trabalho corrente. Consulte [backlog.md](backlog.md) apenas quando a tarefa
explicitamente tratar desses horizontes.

Para uma tarefa explícita de limpeza, use o
[backlog de artefatos](artifact-cleanup-backlog-20260914.md), não a fila R15.
