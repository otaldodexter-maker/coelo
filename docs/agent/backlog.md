---
title: "Mapa de horizontes e pendências Coelo"
source: "docs/agent/current-state.md; decisions/0035-etapa3-mvp-contextual-access-and-app-delivery.md; decisions/0038, 0039, 0041, 0042, 0043, 0044; R16-pendencias.md; specs/README.md; docs/open-questions.md"
status: "active"
lifecycle: "current"
generated_at: "2026-09-14"
updated_at: "2026-09-17"
audience: "team"
---

# Horizontes de trabalho

## Trabalho atual — Etapa 2 / R16 (reserva)

A execução FE/BE/E2E do MVP terminou em 17/09/2026 (100%;
`R16-checkpoint-20260917.md`). A única fila viva é `R16-pendencias.md`, hoje em
**reserva** para a revisão de telas antes da Etapa 3 (decisão do Owner de 17/09):

- 14 Owner items abertos/parciais (7 marcados "R16" e 7 "Etapa 3" na ADR 0044);
- 19 resíduos H (12 "R16", 10 "Etapa 3" — H11 → V1);
- dívida técnica da Mesa R16: `oq048-membership`, `recipients-bug`, `can-remove`,
  `momentos-ux`, `celular-mascara`, `orfaos-cardapio`, `form-diario`,
  `forms-v2-qa`, `espelho-cli`, `h02-aal2`, `testes-vermelhos`;
- resíduos operacionais (goldens fora do E4, CORS R2, deploy público, espelho CLI).

Nenhum desses itens é executado sem pedido do Owner.

## Etapa 3 — o que já está predefinido (ADR 0035, 0039, 0041, 0044)

1. **Acesso contextual de funcionários**: telas de acesso por instituição/unidade
   (plataformas, dias/horários, vigência) e de afastamentos; restrição imposta no
   servidor ao vínculo profissional; popups configuráveis e só informativos.
2. **Tour funcional** e **home com IA** sobre os fluxos reais do app.
3. Levar páginas/fluxos a **admin.coelo.me** e **app.coelo.me** (`apps/admin`,
   `apps/principal`) com adaptação de papel; **sem lojas** neste momento.
4. Itens enviados pela Mesa R16: Owner items r12-10/19/23/29/30/46/53; H02, H03,
   H04, H07, H09, H10, H12, H14, H16, H26; Local interno da ADR 0038; goldens
   (componentizar o cabeçalho); CORS dos buckets R2 e deploy público (host,
   allowlist de Auth); mensagem de `ACTIVITY_INVALID_REFERENCE`; SMTP próprio e
   prova detalhada do reset de senha (E8/E10).
5. Specs com implementação pendente: 065 (Perfis de cuidado), 066 (ciclo de vida
   OQ-033 + `institutions.status`), 067 (Locais com mapa por imagem, OQ-034),
   069 (Avisos H08/H13/H23) — aprovadas; 064 (perfil transversal / Principal para
   responsável sem membership, OQ-044/OQ-048) e 068 (perfis oficiais, OQ-032) —
   rascunho.
6. Três instituições fictícias com hierarquia completa para o Owner validar o
   "Para você" (nome a confirmar).

## Etapa 3 — o que falta o Owner decidir

1. Abrir formalmente a Etapa 3, após a revisão de telas, com a proposta
   consolidada exigida pela ADR 0035 (escopo, ordem, dependências, aceites,
   estimativa).
2. Formato e agenda da revisão de telas (todas as telas; aprovar ou mandar para
   a Etapa 3).
3. Acesso contextual: localização das telas, permissões de quem administra,
   fuso/virada de dia/janelas múltiplas, precedência instituição × unidade,
   distinção web/mobile/tablet/app instalado, frequência dos popups.
4. Tour e IA: roteiro, fonte e limites das respostas, audiências, custo de
   provedor.
5. Deploy público: host de `superadmin.coelo.me`, allowlist de Auth, CORS dos
   buckets, distribuição do app instalado fora das lojas.
6. Aprovar as specs 064 e 068 e o nome "Para você".
7. Destino da dívida técnica da reserva (revisão de telas × Etapa 3).

## V1 e V2

Sem fila operacional. As 33 ações de escopo `v1` (importação/exportação exceto
Formulários, MFA ×3, Catálogo de UI, `plans.assign`,
`institutions.status/files/locations-map`) continuam no inventário fora dos
denominadores (ADR 0044). Planos comerciais e Financeiro são V1/V2 (ADR 0039).
Intenção de produto nos PRDs: [Master](../product/prd-master.md),
[Superadmin](../product/prd-superadmin.md), [Admin](../product/prd-admin.md),
[Principal](../product/prd-app.md). Uma tarefa V1/V2 só se torna executável
quando o Owner a abrir e uma spec for aprovada.

## Pendências gerais e conflitos

- [Perguntas abertas](../open-questions.md): OQ-032, OQ-033, OQ-034 (decididas,
  specs 066–068), OQ-046, OQ-047 (encerrada, lote 75), OQ-048 (parcial: Agora
  resolvido no lote 81; Principal para responsável sem membership → spec 064).
- [ADRs](../../decisions/README.md) e [specs](../../specs/README.md): índices
  com `lifecycle`.

## Limpeza de artefatos

Não é fila de produto: [artifact-cleanup-backlog-20260914.md](artifact-cleanup-backlog-20260914.md)
e [archive-manifest-20260917.md](archive-manifest-20260917.md).

## Histórico

Decisões de 14–17/09 (R13–R16): ADR 0038–0044 e `docs/reviews/archive/rounds/`.
