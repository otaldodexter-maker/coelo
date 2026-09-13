---
source: "R10 C1 read-only map; ADR 0032; specs/028-superadmin-conversations-production.md"
status: "proposal-required"
generated_at: "2026-09-13"
---

# Chat video attachment: focal contract map

## Approved boundaries

ADR 0032 keeps Chat attachments and videos in private R2, without Stream in the
MVP. The Media Gateway must reauthorise session, tenant, capability and scope;
validate real MIME, bytes and checksum; issue short presigned PUT/GET URLs;
and audit. Spec 028 also requires that the Flutter client never receives R2
credentials or a permanent URL.

The current Chat contract deliberately accepts only JPEG, PNG, WebP and PDF:

- `ChatAttachmentUpload.validate` and the picker in
  `apps/superadmin/lib/features/chat/` only allow those four types.
- `chat-media/index.ts`, `stored_bytes.ts`, and
  `20260911210200_superadmin_internal_chat_attachments_v1.sql` use the same
  four-type allowlist, extension map and limits (images 4 MiB; PDF 10 MiB).
- `chat_attachment_metadata` carries MIME, byte size, checksum and upload
  state, but no duration field. The prepare/finalize/read RPC chain validates
  owner, internal identity, conversation scope, ticket, status, size and
  checksum. Its `read` RPC signs only ready attachments.

## Existing video material that can be reused selectively

| Surface | MIME / byte rule | Duration rule | Byte signature | Reuse limit |
| --- | --- | --- | --- | --- |
| Now | `video/mp4`, 25 MiB | plan-backed `now_max_video_seconds`; UI default 30 s | MP4 `ftyp` in `now-media/index.ts` | Now-specific capability, asset schema and rights model; do not import its limit into Chat. |
| Moments | `video/mp4`, 25 MiB | 1–300000 ms in Edge input | MP4 `ftyp` in `moments-media/stored_bytes.ts` | Its 5-minute limit and publication schema are surface-specific. |
| Acontece | `video/mp4`, default 10 MiB | no duration validation found | MP4 `ftyp` in `happens-media/index.ts` | No duration contract to reuse. |

There is no MP4/WebM shared sniffer: each surface owns a small MP4 `ftyp`
check. No existing function accepts `video/webm`, and no Chat player exists.
`apps/superadmin/pubspec.yaml` contains no video playback dependency. The
current happens viewer explicitly renders a video-unavailable state; it is not
a player implementation. The only reusable Flutter duration reader is
`principal_now_publication/domain/now_media_metadata.dart`, which parses an MP4
`mvhd` atom from local bytes for UX only; it is not server authority and does
not support WebM.

## Smallest complete chain after a product decision

1. **Decision/spec first:** approve the Chat MIME allowlist (MP4 only, or MP4
   plus WebM), max bytes, max duration, count per message, and retention.
   ADR 0032 permits Chat video in R2 but supplies none of those Chat-specific
   values. The Now, Moments and Circular limits are not transferable by
   implication.
2. **Contract and client upload:** extend the Chat attachment command with a
   video duration only if approved; extend picker extension-to-MIME mapping and
   preflight. Preserve current request ID replay, signed PUT isolation, and
   no-secret behavior.
3. **SQL/RLS:** make a forward-only migration that extends the Chat metadata
   model and `chat_attachment_limit_v1`/extension mapping; validates the new
   MIME, bytes, duration and idempotent request hash; keeps the existing
   ownership, tenant, scope and ready-only read checks. Add pgTAP for anon,
   wrong tenant/scope, MIME/size/duration, replay mismatch, expired ticket and
   ready read.
4. **Gateway:** extend `chat-media` prepare allowlist and descriptor; extend
   stored-byte verification with the approved container signatures and server
   duration validation. Keep R2 `head` plus bounded read/checksum and delete a
   mismatched object. WebM needs a distinct container/duration parser; MP4
   cannot validate WebM.
5. **Read/player:** retain `readAttachment` server reauthorisation. Route
   image to the existing image dialog and video to a dedicated accessible
   player backed only by the short read URL, with loading, expiry, revocation,
   retry and context invalidation. A player implementation/dependency needs
   its own approved choice; none is present to reuse. Do not expose the R2 URL
   in metadata or cache it as durable access.
6. **Proof:** focused Dart/Deno/pgTAP tests, then C0's normal UI flow with an
   approved synthetic MP4 fixture, real private R2, reload and cross-tenant
   negative. Video playback must not claim Stream or public delivery.

## Open decision

The requested experience, “photo if photo; play if video”, does not define the
Chat video MIME set, byte maximum, duration maximum, retention, or playback
technology. These must be approved before an implementation/SQL package; this
map deliberately does not choose values from other products.
