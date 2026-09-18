---
title: "Existe caminho de produção? — auditoria de composição do recorte operacoes-sistema"
source: "execução própria do grupo operacoes-sistema sobre a base d784462c1"
status: "medição; corrige uma classificação anterior do próprio autor"
generated_at: "2026-09-09"
group: "operacoes-sistema"
branch: "work/etapa2-noturna-operacoes-sistema"
---

# Existe caminho de produção?

## Por que esta auditoria existe

Rodei a suíte de Suporte, vi 61 casos verdes e reportei "aceite funcional
exercitado". Depois descobri que aqueles 61 casos exercitam um controlador de
protótipo e que a rota `/support` **nem abre em produção**. O número estava
certo; a conclusão que ele sugeria, não.

O erro foi meu e a lição é geral: **suíte verde não prova que a tela existe em
produção**. Antes de tratar uma ação como exercitada, é preciso perguntar se
`main.dart` compõe aquele caminho. Este documento aplica essa pergunta às onze
famílias do recorte.

## Método

Para cada família, verificar se `apps/superadmin/lib/main.dart` injeta a
dependência, o que `apps/superadmin/lib/app/router/superadmin_router.dart` monta
na rota produtiva, e se existe implementação de produção do repositório — não
apenas a interface.

## Resultado

| Família | Caminho de produção | Observação |
| --- | --- | --- |
| `auth` | Sim | Composto por `authScope` em `main.dart`. |
| `shell` | Sim | Router e shell são a própria superfície produtiva. |
| `error_pages` | Sim | `SuperadminErrorScreen` é usada pelo router, inclusive como fail-closed de outras rotas. |
| `agenda` | Sim | `agendaRepository` vem de `authScope`. |
| `audit` | Sim | `auditRepository` vem de `authScope`. |
| `plans` | Sim | `planCatalogRepository` vem de `authScope`. |
| `meal_plans` | Sim | `mealPlanRepository` e `mealPlanImageRepository` vêm de `authScope`. |
| `imports` | Sim, porém adiada por política | A rota produtiva monta `ImportDirectoryPage` com o repositório injetado; a indisponibilidade honesta é da política, não da composição. |
| `catalog` | Sim | Externo, por `COELO_CATALOG_URL`, com padrão `https://catalog.coelo.me`. |
| `account` | **Parcial** | Ver abaixo. |
| `support` | **Não** | Ver abaixo. |

## Support — não há caminho de produção

A feature tem apenas `domain` e `presentation`. Não existe `data/`, não existe
repositório, não existe interface de repositório, e nada em `packages/` define
`SupportTicket`. A tela roda sobre `SupportPrototypeController`, que semeia
`_defaultTickets` em memória.

Em produção a rota nem monta a página. O router só constrói `SupportPage`
quando `productionSupportController` não é nulo, e **nenhum ponto de composição
em `lib` injeta `supportController`** — `main.dart` tem zero ocorrências. Com o
controlador nulo, `/support` devolve `SuperadminErrorScreen` com
`kind: unavailable`, ou seja 503.

Consequência para o rastreador: `support.*` não está bloqueado por decisão de
rebaseline de golden, como eu havia classificado. Está sem camada de dados e
fail-closed em produção. A obsolescência dos 24 goldens continua verdadeira, mas
é o segundo problema.

## Account — metade tem produção, metade não

- `account.settings` e `account.theme`: **têm** caminho produtivo. O router usa
  `productionPreferencesController`, que cai no padrão
  `UserPreferencesController(SharedPreferencesUserPreferencesRepository())`.
  Persistência local real.
- `account.profile`: **não tem**. `ProfilePage` só é montada em
  `SuperadminRoutes.devProfile`, que é `/dev/profile`, com
  `InMemoryAccountProfileRepository`. Não existe implementação Supabase de
  `AccountProfileRepository` no repositório: só a interface e a versão em
  memória.
- `account.sessions`: **não existe tela**. Não há nenhum arquivo de sessões em
  `features/account/presentation/screens`, que contém apenas `profile_page.dart`
  e `settings_page.dart`.

## O que isto não afirma

Não afirma que as famílias marcadas "Sim" estejam corretas, autorizadas ou
verificadas ponta a ponta — apenas que a composição produtiva existe e aponta
para uma implementação real. Também não substitui execução remota, que esta
rodada não autorizou.
