---
source: "R08 G2"
status: "local-green; nao E2E"
generated_at: "2026-09-12"
---

# Convite expirado — teste focal

Base: `origin/dev 7e889abac` incorporada antes da prova.

Comando executado uma vez, no slot Flutter de G2:

`flutter test --concurrency=1 test/features/invites/invite_detail_page_test.dart test/features/invites/invite_directory_page_test.dart test/features/invites/invite_clipboard_test.dart`

Resultado terminal: **45 passed, 0 failed**.

Cobertura: convite expirado e reenvio, pendente não reenviável, retry com mesmo
`request_id`, erro/negação/troca de contexto e cópia efêmera. Não houve
mutação remota, E2E, regravação visual ou exposição de link.
