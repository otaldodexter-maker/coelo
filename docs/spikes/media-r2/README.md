---
source: "specs/009-media-r2-spike.md"
status: "draft"
generated_at: "2026-06-22"
---

# Media R2 Spike

This folder records the technical spike for private Coelo media on Cloudflare R2.

## Scope

- Validate private R2 as the single media destination from the MVP.
- Validate short-lived upload and read authorization flows.
- Keep product apps untouched.
- Use only synthetic files during live checks.

## Deliverables

- `media-gateway-technical-spec.md`
- `test-matrix.md`
- `evidence-log.md`
- Optional disposable prototype under `spikes/media-r2/`
- Updated `decisions/0010-private-media-r2.md`

## Safety Rules

- Do not use real child, family, school, or institution media.
- Do not commit `.env`, R2 credentials, service role keys, access tokens, signed URLs, or raw provider secrets.
- Redact account IDs and object keys in public summaries when they could identify a real environment.
