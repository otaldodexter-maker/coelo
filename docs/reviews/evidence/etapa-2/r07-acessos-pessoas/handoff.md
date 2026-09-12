---
title: "Handoff - grupo acessos-pessoas, Rodada 7"
round: "E2-R07-20260911"
base: "origin/dev após git fetch; work/etapa2-r07-acessos-pessoas"
status: "checkpoint 30 min; rota real retida por renderer/driver"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# Handoff R07 — checkpoint 23:52

Recorte: `apps/superadmin` → Coelo (Principal) → Pessoas, Perfis/Modelos de
acesso, Usuários internos e Convites.

## Evidência local

- Build: `flutter build web --release -t test_driver/qa_main.dart
  --dart-define-from-file=.env.local` concluído; `apps/superadmin/build/web/main.dart.js`
  foi gerado.
- Análise: `flutter analyze lib/features/people lib/features/access_profiles
  lib/features/platform_users lib/features/invites lib/features/students` —
  `No issues found!`.
- Suíte direcionada: testes de `PersonHandleSection`, lookup de identidade,
  modelos/perfis, convites e students executados sem falha reportada no lote.

## Rota real

O `flutter run -d chrome -t test_driver/qa_main.dart --web-port=3020` abriu
Chrome separado com CDP. O `qa_drive.dart` não recebeu resposta do
`Runtime.evaluate`/`window.$flutterDriver` em 60 segundos; o app foi encerrado
sem login e sem escrita produtiva. Não há captura nem certificação E2E neste
checkpoint.

## Gates

- `internal-users.create`: Edge Function `internal-user-create` ainda sem
  deploy; manter FE/BE `local-green`.
- `invites.resend`: produção não tem convite expirado e nenhum pacote sintético
  foi criado sem fixture/pgTAP seguro.
- `internal-users.suspend`: não suspender usuários QA em uso; requer interno
  sobressalente.

Nenhum segredo foi copiado para Git, JSON ou este handoff.
