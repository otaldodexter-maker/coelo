---
title: "D01-P1 — invalidar detalhes ao trocar autorização"
source: "review central de c11614d5; E2E1 R03 5f840af5; testes locais"
status: "local-green; integration-review-required; not-verified-e2e"
generated_at: "2026-09-07"
---

# Causa e correção delimitada

As rotas D01 não escutavam a sessão nem recriavam o controller quando somente
autorização/sessão mudava. Mesmo com Session R03 notificando corretamente,
mesmo ID e repository mantinham payload carregado ou permitiam resposta antiga.
O review anterior não detectou esse caso; `c11614d5` não deve ser integrado sem
este follow-up e a dependência R03 do proprietário de Identidade.

Somente os dois builders D01 passam a usar `ListenableBuilder(session)` e
`ValueKey(session.authorizationInvalidationRevision)`. A chave nova desmonta
a página/controller anterior, limpando o estado. O controle de geração/dispose
existente ignora respostas pendentes antigas. Não há concessão de capability,
fallback, alteração de listas, mutações, guards, shell ou `/dev`.

## TDD

`test/app/router/structure_detail_authorization_test.dart`:

- 2 domínios × payload carregado ou pendente × troca de escopo na mesma sessão
  ou nova sessão com mesmo contexto = **8 casos**.
- Antes da correção, com Session R03 exata: **8 RED**; payload antigo continuava
  presente ou somente uma consulta existia após a revisão mudar.
- Depois: **8 GREEN**, exit0. Mesma rota, ID e repository; nova consulta começa,
  payload A desaparece no primeiro pump, B pode ser negado, e completar A
  depois não restaura o conteúdo antigo.
- Analyzer do router e teste: zero issues.

Comando em `apps/superadmin`:

```text
rtk proxy C:\src\flutter\bin\flutter.bat test --no-pub test/app/router/structure_detail_authorization_test.dart --reporter expanded
```

## Dependência local, NÃO integrar duplicada

O Coordenador autorizou aplicar via `apply_patch` exclusivamente o diff de
`apps/superadmin/lib/core/guards/superadmin_session.dart` de
`5f840af5564d2c9266a425578c6988ef8b43a2dc`, sem lógica própria.
Arquivo local e fonte foram verificados com `git hash-object`/`git rev-parse`:
blob **`a8d10307ee9b69eb54b06f8cd1f2d46c4411b58d`**, idênticos.

Essa dependência está isolada no commit
**`93df1044b61e36d7991d0644eb4d8e19af9ba6a9`**, que NÃO deve ser integrado.
A base central já contém R03 pela cadeia E2E1. Integrar somente o commit nominal
dos builders/testes/evidência P1, depois do D01, e reexecutar na base central.
Nenhuma conexão anterior do diretório interno foi importada.

## Limites

Widgets e double de repository, sem Supabase/Cloudflare real. Sem prova de
produção, sem promoção `verified`, `done` ou E2E. NAV-LOGOUT01 é outro pacote,
com arquivo/testes/commit próprios. Memória: no-op, correção de isolamento já
exigido pelo contrato, sem nova regra durável ou projeção de atividade.
