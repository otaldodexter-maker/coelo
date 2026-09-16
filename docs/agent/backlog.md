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

R16 está somente preparada, não aberta. Seus resíduos estão registrados na
seção `R16 preparado — não aberto` da fila R14; não criar action_ids ou iniciar
uma fila concorrente. O corte de 15/09 concluiu o que era executável sem prova
remota adicional: `assessments.close/reopen` recebeu delta oficial; Forms
`expire-file/delete-file` e `attendance.create`/Atividade foram liberados para
R15 por bloqueio de ambiente, RPC ou massa; a próxima execução deve priorizar
as fatias C quando houver sessão/contrato/massa e manter em R16 a negativa
específica de `agora.remove`, Stream genérico e resíduos sem contrato.

Em 16/09 o Owner respondeu às 27 pendências que dependiam dele
(`decisions/0041-owner-decisions-r14-mesa-20260916.md`): aceites de Cardápios,
`r12-09/11`, OQ-031 e reader self; contratos B1–B9 fixados; autorizações de
produção D1–D5; `institutions.files` fora do MVP; páginas de erro `flutter-only`;
H11 → V1. Para R15 ficaram duas specs novas: perfil transversal/funcionário no
Principal (OQ-044) e Perfis de cuidado redesenhados (§5 da ADR).

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
  `institutions.locations-map` e `catalog.*` (4) saíram do ativo
(`deferred-post-mvp`); o alvo E2E ativo 199 → 192 já foi aplicado pelo delta
controlado e a formalização posterior de `agora.remove` leva a base ativa a 193.
Neste corte, o inventário registra E2E 159/193; FE e BE não mudam de denominador
  de denominador. MFA já era gate formal.
- **Catálogo de UI:** "V1 ou Etapa 3 (a definir)".
- **OQ-033 = B** com regra de pessoas (desvincular, não excluir; só superadmin exclui ou
  suspende por período) → spec de ciclo de vida na R15.
- **OQ-034:** Locais com mapa por imagem inteira na R15.
- **Bloco C** na ordem Cardápios → Segurança infantil → Arquivos de Formulários →
  Fechar/Reabrir → Perfis de acesso; **Bloco D** segue com
  reader self da Conta e owner.r12-29/30. Para alergias e orientações, o produto
  aceita vários registros independentes; a prova não fica limitada a dois e o
  backend deve impor apenas um limite defensivo alto de 100 registros por
  coleção/entidade. Recuperação/reset de Auth e sua
  allowlist ficam na Etapa 3.

## Decisões do Owner de 14/09 e 15/09/2026 sobre escopo (fora da fila R14)

Registradas no fechamento da R13; valem como direção até virarem ADR/spec.

- **Fora do MVP:** `plans.assign` (Planos › Atribuir), qualquer módulo
  **Financeiro**, `institutions.status`, `institutions.locations-map`,
  `auth/account/internal-users.mfa` (gate formal). A decisão de escopo está
  registrada; a aplicação do delta aos sete action_ids aguarda execução
  controlada e evidência, sem alterar estados certificados por inferência.
- **Decisão de 15/09:** nenhum Plano comercial é operação do MVP (listar,
  criar, editar, arquivar, restaurar, atribuir, vincular ou aplicar
  entitlements). Schema e specs ficam como preparação V1/V2. O reader self da
  Conta continua no MVP/R14; o reader de Planos no Principal não entra na R14.
- **Etapa 3:** `auth.recover` e `auth.reset`, incluindo e-mail, callback,
  expiração, uso único, sessão e prova produtiva. Não executar recuperação/reset
  nem a allowlist específica desse fluxo dentro da R14.
- **V1 ou Etapa 3 (a definir):** Catálogo de UI (`catalog.list/validate/sync/
  publish`) — tela do catálogo `coelo-ui`; não é MVP.
- **Formulários autosave (H11):** **V1** por decisão de 16/09 (ADR 0041 B10),
  sem medir o limiar de 60%. H10 (regras de audiência) continua no MVP.
- **Instituições › Arquivos (`institutions.files`):** fora do MVP (ADR 0041 A4);
  o flyout permanece e avisa "em desenvolvimento". `institutions.error` e
  `institutions.access-denied` ficam no MVP.
- **Páginas de erro (`errors.*`):** `flutter-only` (ADR 0041 A5); aceite terminal
  é FE na rota real.
- **Chat › Anexar (`chat.attach`):** continua no MVP (asset_id + Edge Function),
  explicar ao Owner na abertura da R14.
- **Saúde e Cuidado — múltiplos registros (15/09):** owner.r12-29/30 cobre
  coleções de alergias e orientações independentes, com adicionar/remover/reload
  na rota real. O limite defensivo de 100 por coleção/entidade é proteção de
  integridade, não uma meta de uso nem motivo para reduzir a capacidade a dois.
  **16/09 (ADR 0041 A2/§5):** o Owner não aceitou ainda e redesenhou o contrato
  (wizard Alimentos × Restrições, nomes de lista categorizada com busca e
  "Outro", reordenar, campo "O que fazer se consumido?"); vira spec na R15.
- **Perfil transversal / funcionário no Principal (OQ-044, r12-19/23):** spec
  própria na R15 (ADR 0041 B7).
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
