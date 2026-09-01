---
source: ".superpowers/sdd/task-2-brief.md; docs/superpowers/plans/2026-09-01-principal-ui-ux-closure.md"
status: "local-green"
generated_at: "2026-09-01"
---

# Task 2 — Momentos fullscreen como Agora

## Escopo entregue

- A rota `/dev/principal-moments` passou a ser top-level, fora do `ShellRoute`, com `embedded: false`.
- O viewer preenche a viewport, remove o quadro `AspectRatio` e a aside desktop, e preserva mídia `BoxFit.cover`.
- Os controles somam `MediaQuery.viewPaddingOf(context)` sem reduzir a área da mídia.
- Escape/retorno continuam usando `_closePrincipalViewer`, com restauração de foco à origem coberta pelo teste de rota.

## TDD

- RED: `rtk flutter test test/app/router/principal_now_preview_route_test.dart test/features/principal_moments/presentation/principal_moments_preview_page_test.dart`
  - Falhou como esperado: Momentos ainda era `embedded: true`, o shell persistente ainda estava presente, o PageView media 319,8 px em 375 px e a aside desktop ainda era renderizada.
- GREEN: o mesmo comando terminou com `28` testes aprovados.

## Arquivos

- `apps/superadmin/lib/app/router/superadmin_router.dart`
- `apps/superadmin/lib/features/principal_moments/presentation/principal_moments_preview_page.dart`
- `apps/superadmin/test/app/router/principal_now_preview_route_test.dart`
- `apps/superadmin/test/features/principal_moments/presentation/principal_moments_preview_page_test.dart`

## Verificação

- `rtk dart analyze apps/superadmin/lib/app/router/superadmin_router.dart apps/superadmin/lib/features/principal_moments/presentation/principal_moments_preview_page.dart apps/superadmin/test/app/router/principal_now_preview_route_test.dart apps/superadmin/test/features/principal_moments/presentation/principal_moments_preview_page_test.dart` — sem issues.
- `rtk git diff --check` — sem whitespace inválido.

## Hash e preocupações

- Hash do commit: registrado no handoff do commit exclusivo desta Task 2.
- Esta evidência é Flutter local para `/dev`; composição produtiva, autorização, mídia remota e E2E permanecem fora do escopo.
- O publicador de Momentos não foi alterado; o launcher removido pertencia somente à aside descartada do viewer.

## Memória Coelo

- `no-op`: a fonte canônica e a projeção `principal-moments-viewer` já descrevem o viewer fullscreen, sem shell/dock e com retorno de foco. Nenhuma regra durável aprovada mudou.
- `Test-CoeloKnowledge.ps1 -Root <worktree>` — base de conhecimento válida.
