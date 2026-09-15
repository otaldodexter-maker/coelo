---
title: "Mapa de horizontes e pendências Coelo"
source: "docs/agent/current-state.md; decisões e PRDs canônicos"
status: "active"
lifecycle: "current"
generated_at: "2026-09-14"
updated_at: "2026-09-15"
audience: "team"
---

# Horizontes de trabalho

## Trabalho atual — Etapa 2 / R14

É a única fila executável neste momento. Use [current-state.md](current-state.md)
e a fila única `R14-pendencias.md` apontada nele.

## Pendências do MVP

Use os itens não terminais da fila R14 e o inventário por `action_id`. Itens
explicitamente `deferred-post-mvp` continuam registrados, mas não bloqueiam o
MVP e não devem ser implementados por inferência.

## Decisões do Owner de 15/09/2026 (abertura da execução da R14)

Registradas no artefato 89AVWHKEnq5hrvYN6SFv6M e detalhadas em
`docs/reviews/etapa-2-operacao/next-round/R14-execucao-paralela.md`:

- **Execução paralela:** duas sessões executoras (Blocos A–B e C–D) em worktrees
  próprias com push para `dev` por rebase; a sessão do Codex coordena e atualiza os MDs.
- **Bloco B autorizado:** `plans.assign`, `institutions.status`,
  `institutions.locations-map` e `catalog.*` (4) devem sair do ativo
  (`deferred-post-mvp`); o alvo é E2E ativo 199 → 192. Esta decisão ainda não foi
  aplicada ao inventário certificado neste SHA: até a execução controlada do
  delta, o estado vigente continua E2E 137/199. FE e BE não mudam de denominador;
  MFA já era gate formal.
- **Catálogo de UI:** "V1 ou Etapa 3 (a definir)".
- **OQ-033 = B** com regra de pessoas (desvincular, não excluir; só superadmin exclui ou
  suspende por período) → spec de ciclo de vida na R15.
- **OQ-034:** Locais com mapa por imagem inteira na R15.
- **Bloco C** na ordem Cardápios → Segurança infantil → Arquivos de Formulários →
  Fechar/Reabrir → Perfis de acesso; **Bloco D** completo, incluindo `localhost` na
  allowlist de redirect do Supabase Auth (não toca SMTP, DNS, senha nem token).

## Decisões do Owner de 14/09/2026 sobre escopo (fora da fila R14)

Registradas no fechamento da R13; valem como direção até virarem ADR/spec.

- **Fora do MVP:** `plans.assign` (Planos › Atribuir), qualquer módulo
  **Financeiro**, `institutions.status`, `institutions.locations-map`,
  `auth/account/internal-users.mfa` (gate formal). A decisão de escopo está
  registrada; a aplicação do delta aos sete action_ids aguarda execução
  controlada e evidência, sem alterar estados certificados por inferência.
- **V1 ou Etapa 3 (a definir):** Catálogo de UI (`catalog.list/validate/sync/
  publish`) — tela do catálogo `coelo-ui`; não é MVP.
- **Formulários autosave (H11):** se der muito trabalho, vai para V1; se já
  estiver mais de 60% em andamento, manter no MVP. H10 (regras de audiência)
  continua no MVP.
- **Chat › Anexar (`chat.attach`):** continua no MVP (asset_id + Edge Function),
  explicar ao Owner na abertura da R14.
- **Etapa 3:** 3 instituições fictícias com pessoas e hierarquia completa
  (unidades, turmas, responsáveis, crianças) para o Owner verificar a tela
  "Para você" do Principal; avaliar outro nome para "Para você" (já usado por
  concorrentes/TikTok) — nome atual é bom, decisão pendente.
- **Perfis oficiais do Coelo** (seguidos automaticamente por todos, 3 a 7
  perfis, 1 a 4 publicações/dia no total, para dar movimento e notificações
  na rede): decidir a lista antes de fechar o MVP (não é Etapa 3). Proposta
  inicial em `docs/open-questions.md` (OQ-032).
- **Na retomada da R14:** manter visíveis para o Owner e explicar, de forma simples e
  visual, os temas: telas de erro/acesso negado/arquivos/mapa de Instituições e
  Unidades; Catálogo de UI; Chat › Anexar; Formulários H10/H11; e as decisões
  acima.

## V1 e V2

Não há uma fila operacional V1/V2 única autorizada neste índice. Para entender
intenção de produto, consulte os PRDs:

- [PRD Master](../product/prd-master.md);
- [PRD Superadmin](../product/prd-superadmin.md);
- [PRD Admin](../product/prd-admin.md);
- [PRD Principal](../product/prd-app.md).

Uma tarefa V1/V2 só se torna executável quando o Owner a abrir, uma spec for
aprovada e o estado atual a apontar.

## Pendências gerais e conflitos

- [Perguntas abertas](../open-questions.md) reúne conflitos e decisões ainda
  necessárias.
- [ADRs](../../decisions/README.md) guardam decisões persistentes.
- [Specs](../../specs/README.md) guardam escopo e contratos, mas só specs
  marcadas como ativas/aprovadas para a tarefa autorizam implementação.

## Limpeza de artefatos

Não faz parte da fila de produto. Os lotes concluídos e os itens retidos estão
em [artifact-cleanup-backlog-20260914.md](artifact-cleanup-backlog-20260914.md).

## Histórico

R01–R12, checkpoints, prompts, handoffs e os arquivos em
`docs/reviews/archive/` preservam proveniência. Não são filas alternativas.
