---
title: "Principal — matriz de composição das rotas"
source: "specs/050-principal-ui-ux-closure.md; commit a6c48751; revisão independente crosswalk_media"
status: "local-green; E2E aberto"
generated_at: "2026-09-07"
---

## Recorte e conflito explícito

Somente os dois testes de composição Principal em
`apps/superadmin/test/app/router/persistent_shell_routes_test.dart`.
Não houve alteração de rotas, código produtivo ou imagens golden.

A spec 050 exige composição própria sem chrome administrativo concorrente e
Momentos imersivo. O commit a6c48751 implementou rotas standalone, também
esperadas por `principal_happens_preview_route_test.dart`. O plano
`docs/superpowers/plans/2026-09-01-principal-ui-ux-closure.md` mantém prosa
conflitante nas linhas 42 e 117 sobre permanência no shell, enquanto sua
arquitetura na linha 60 explicita a separação. O Coordenador autorizou alinhar
somente os testes à spec aprovada e à composição implementada. A divergência
documental não foi resolvida silenciosamente nem usada para alterar produto.

## Evidência

- Baseline: os dois testes antigos falhavam também sem o ajuste anterior de
  callback do cabeçalho; exigiam um shell removido pelo commit a6c48751.
- Preservadas sete rotas, larguras 375/768/1024/1440 e texto a 100%/200%.
- URI verificada para impedir sucesso por redirecionamento; bounds e ausência
  de exceções preservados. Cabeçalho próprio único, dock/mensagens dos feeds
  e Momentos ocupando a viewport sem chrome externo são explicitamente testados.
- Focal: 2/2 passaram. Regressão: 26/26 passaram nos arquivos
  header_support_routing_test, persistent_shell_routes_test,
  production_repository_wiring_red_test e principal_happens_preview_route_test.
- Comando: Flutter test --no-pub --dart-define=COELO_APP_ENV=local.
- Analyzer do arquivo sem problemas; formatter aplicado; revisão estática
  independente sem bloqueante.

Não comprova foco/teclado, retorno contextual, autorização remota ou persistência
E2E. Supabase, R2 e Stream não foram alterados ou exercitados nesta fatia.
