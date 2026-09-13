---
source: R10 C1 chat-upload
status: local-green
generated_at: 2026-09-13
---

# Chat attachment retry handoff

## Scope

Etapa 2 → `apps/superadmin` → Comunicação → Conversas → R08-G4 PNG privado QA → `chat.attach`.

## Cause and correction

The prepare RPC returns authoritative `upload_status`, but the deployed
`chat-media` envelope did not forward it. The Edge patch now preserves that
field. `SupabaseChatRepository` permits PUT/finalize only for explicit
`pending`; a replayed `ready` attachment is confirmed by authorised `read`.
Explicit `failed`, `expired`, and malformed states fail before PUT/finalize.

During the rollout, the deployed Edge can still omit `upload_status`. A replay
with that legacy envelope remains a read-only confirmation path, and a fresh
non-replayed prepare preserves the existing PUT/finalize behavior. This avoids
rejecting a legitimate ready replay before the Edge deployment; the explicit
state allowlist applies as soon as the new envelope is present.

## Evidence

The focal regression covers `prepare → PUT → finalize` with one returned
`message_id`, ready replay/read refusal without PUT, legacy replay without the
new field, and failed/expired/malformed prepare without PUT/finalize. No remote
service, RLS policy, ownership check, SQL or Cloudflare configuration changed.

`flutter test test/features/chat/data/chat_attachment_upload_test.dart`: PASS,
15 tests.

`deno test --config deno.json --allow-all index_test.ts`: PASS, 4 tests.
`deno fmt --check index.ts index_test.ts` reports pre-existing formatting in
both files; it was not applied to keep the patch scoped.

## Status

Frontend remains `local-green`; backend/integration certification is unchanged.
The first UI gate is C0's real R08-G4 PNG selection and retry after the CORS
runtime transfer, followed by thread reload and the existing tenant-negative
proof.
