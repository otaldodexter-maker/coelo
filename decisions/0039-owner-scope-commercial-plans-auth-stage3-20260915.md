---
title: "Decisão do Owner: Planos comerciais fora do MVP e Auth na Etapa 3"
source: "Owner em 2026-09-15; decisions/0038-owner-decisions-etapa2-backlog-20260914.md; docs/reviews/etapa-2-operacao/next-round/R14-pendencias.md"
status: "accepted"
lifecycle: "current"
generated_at: "2026-09-15"
updated_at: "2026-09-15"
audience: "team"
supersedes: "decisions/0038-owner-decisions-etapa2-backlog-20260914.md (linha Planos — principal 039, parcialmente)"
---

# ADR 0039 — Escopo de Planos comerciais e recuperação de Auth

## Decisão

O Owner decidiu em 15/09/2026 que **Planos comerciais não entram no MVP**.
Isso inclui listar como operação do produto, criar, editar, arquivar, restaurar,
atribuir, vincular instituições e executar entitlements comerciais. O schema,
os IDs, as relações e as specs podem permanecer como preparação para V1/V2,
mas não autorizam tela, reader, mutation, enforcement ou E2E de Planos na fila
atual.

O reader de Planos previsto na transição nominal da ADR 0038 deixa de ser pacote
executável da R14 e fica reservado para V1/V2, quando o Owner abrir esse escopo.
Essa decisão não afeta **Planos de medicação**, que são um domínio separado de
Saúde e Cuidado.

O **reader self da Conta** permanece no MVP/R14: leitura somente dos dados do
próprio usuário interno autenticado, resolvido pelo servidor e sem ID arbitrário
do cliente. Ele não inclui edição, avatar, recuperação de senha ou acesso a
outras contas.

`auth.recover` e `auth.reset` ficam reservados para a **Etapa 3**. Não devem ser
executados na R14, nem por inferência a partir de login, bootstrap, perfil ou
do ajuste de allowlist local. A futura implementação deverá ter spec/contrato
próprio para entrega de e-mail, callback, expiração, uso único, sessão,
anti-enumeração, ambiente e evidência produtiva.

## Consequências operacionais

- O Bloco D da R14 mantém somente o reader self da Conta entre os readers e não
  executa reader de Planos nem recuperação/reset de Auth.
- A R14 conserva `plans.assign`, `auth.recover` e `auth.reset` nos inventários e
  rastreadores como IDs não terminais, sem alterar estados certificados por
  inferência. A classificação de escopo fica explícita na fila.
- PRDs, modelo de dados, mapa de domínios, segurança, specs e knowledge atuais
  devem tratar Planos comerciais como preparação futura e Auth recovery/reset
  como Etapa 3.
- Nenhum arquivo histórico é apagado ou reescrito para esconder a decisão;
  fontes antigas permanecem como proveniência, subordinadas a esta ADR.

## Fora do alcance desta decisão

Esta ADR não altera MFA/AAL2, login/bootstrapping corrente, Planos de medicação,
R2, Chat, Agora, Momentos, Formulários ou os contratos de autorização já
aprovados. Esses temas continuam sujeitos às suas ADRs e à fila R14.
