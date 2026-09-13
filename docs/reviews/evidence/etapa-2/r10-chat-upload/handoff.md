---
source: R10 C1 chat-upload
status: local-green
generated_at: 2026-09-13
---

# Chat attachment retry handoff

## Scope

Etapa 2 → `apps/superadmin` → Comunicação → Conversas → R08-G4 PNG privado QA → `chat.attach`.

## Cause and correction

`chat-media` returns the authorised `upload_status` with every prepare result.
`SupabaseChatRepository` treated `replayed` alone as a ready attachment and
called `read`, so a replayed pending ticket could not resume its PUT/finalize
path. The repository now calls `read` only when `replayed == true` and
`upload_status == ready`; a pending ticket keeps the existing attachment and
message IDs, then executes PUT and finalize.

## Evidence

The new focal regression test first failed before the repository condition was
changed (`ChatFailureException` from the erroneous read path). It then passed
with the asserted sequence `prepare → PUT → finalize` and one returned
`message_id`. No remote service, RLS policy, ownership check, SQL or Cloudflare
configuration changed.

`flutter test test/features/chat/data/chat_attachment_upload_test.dart`: PASS,
10 tests.

## Status

Frontend remains `local-green`; backend/integration certification is unchanged.
The first UI gate is C0's real R08-G4 PNG selection and retry after the CORS
runtime transfer, followed by thread reload and the existing tenant-negative
proof.
