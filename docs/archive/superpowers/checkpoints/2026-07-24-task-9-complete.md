---
title: "Checkpoint Task 9 - catalogo independente e gate fail-closed"
source: "docs/superpowers/plans/2026-07-22-coelo-ui-foundation-componentization-catalog.md"
status: "complete"
generated_at: "2026-07-24"
---

# Task 9 concluida

## 1. Resultado obtido

O app Flutter independente do catalogo foi materializado com autenticacao Coelo
separada, sessao `coelo.catalog.auth.session` e autorizacao fail-closed baseada
na policy RLS de `platform_memberships`.

Query string e fragmento nao estabelecem sessao
(`detectSessionInUri: false`). Erro, revogacao observada, corrida assincrona,
falha do stream, login e logout mantem o conteudo fechado.

## 2. Arquivos alterados

- `apps/catalog/pubspec.yaml` e `pubspec.lock`;
- `apps/catalog/web/index.html`;
- `apps/catalog/assets/brand/NunitoSans-VariableFont.ttf`;
- `apps/catalog/lib/main.dart`;
- `apps/catalog/lib/app/catalog_app.dart`;
- `apps/catalog/lib/auth/catalog_access_gateway.dart`;
- `apps/catalog/lib/auth/supabase_catalog_access_gateway.dart`;
- testes em `apps/catalog/test/app/` e `apps/catalog/test/auth/`;
- `docs/reviews/2026-07-24-catalog-security-boundaries.md`;
- plano, relatorio e ledger de execucao.

## 3. Componentes

Nenhum componente do Design System foi criado ou promovido nesta task. Login e
mensagens do catalogo permanecem composicoes locais do app.

## 4. Diferenca visual

Nenhuma alteracao foi feita na tela de instituicoes ou em seus goldens. O
catalogo ainda exibe apenas a fundacao autorizada; seus componentes reais entram
na Task 10.

## 5. Testes executados

Workdir `apps/catalog`:

- `dart analyze`: `No issues found!`;
- `dart flutter_tools.snapshot test --no-pub`: 51 testes passaram;
- `dart flutter_tools.snapshot build web --no-pub`: build concluido;
  `main.dart.js` com 2.362.285 bytes;
- buscas por secrets, credenciais por URL/mensagem e storage do Superadmin:
  zero caminho indevido no codigo do app;
- `git diff --check`: limpo nos arquivos da task;
- revisao independente final: spec e qualidade aprovadas, zero P0/P1/P2.

## 6. Pendencias

Antes de qualquer publicacao:

- autenticar todos os arquivos estaticos no host/edge;
- publicar o catalogo em origem propria, distinta do Superadmin;
- aplicar CSP `frame-ancestors` restritiva;
- aprovar e testar hardening SQL para `deny`, revogacoes e papel `Owner`.

Essas pendencias estao registradas e nao foram mascaradas pelo gate Flutter.

## 7. Decisao que precisa de aprovacao

Na Task 15 sera necessaria aprovacao explicita da infraestrutura/origem privada
e, antes do deploy, da migration/matriz SQL de autorizacao. Nenhum deploy,
migration, commit ou push foi executado.
