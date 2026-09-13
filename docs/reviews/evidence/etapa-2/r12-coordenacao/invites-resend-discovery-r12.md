---
source: R12 C0 — R12-45 invites.resend discovery
status: local-green; positive E2E pending
generated_at: 2026-09-13
---

# R12-45 — ação Reenviar convite encontrada e delimitada

Recorte: Etapa 2 → `apps/superadmin` → Convites → diretório/detalhe → menu de
ações da linha → `invites.resend`.

A ação já está disponível em português como `Reenviar convite` no menu da
linha quando o contrato local permite: convite expirado ou pending vencido.
Convite pending ainda vigente não oferece reenvio. O detalhe também expõe
`Reenviar` como ação primária no estado expirado. O comando usa
`managementVersion`, `requestId` idempotente e o RPC
`superadmin_invite_resend_v2`; o link retornado é exibido somente no diálogo
temporário, sem persistência ou reconstrução no cliente.

Provas locais, Windows, checkout `dev`:

- `flutter test test/features/invites/invite_detail_page_test.dart`: 32 PASS;
- `flutter test test/features/invites/data/supabase_invite_repository_test.dart`:
  13 PASS;
- a suíte de diretório R12-44 cobre a seleção `InviteRowAction.resend`,
  recibo e link: 24 PASS.

Não foi enviado convite, não foi usado Admin API para simular SMTP e nenhum
contrato backend foi alterado. O aceite fechado nesta fatia é FE
`local-green` para descoberta/guardas/feedback local. O positivo E2E continua
`pending-verification`: falta abrir a rota normal com convite expirado real,
reautorizar o ator, comprovar recibo, reload e escopo. R12-44 permanece
table-only; R12-45 não reintroduz cards.

Próximo gate: preparar ou localizar, pela rota autorizada e sem dados
inventados, um convite expirado permitido pelo contrato; reenviar uma vez,
verificar recibo/link de uso único, persistência/reload e negação fora do
escopo. Se a sessão/dado real não estiver disponível, manter este bloqueio.
