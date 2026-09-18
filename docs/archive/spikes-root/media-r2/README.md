---
source: "specs/009-media-r2-spike.md"
status: "draft"
generated_at: "2026-06-22"
---

# Media R2 Disposable Prototype

This harness validates R2 presigned URL generation with synthetic media only.

## Setup

1. Copy `.env.example` to `.env`.
2. Fill `.env` with credentials for a private disposable R2 test bucket.
3. Do not commit `.env`.
4. Install dependencies with `npm install`.

## Checks

Run syntax check:

```powershell
npm run check
```

Generate redacted presigned URLs:

```powershell
npm run smoke
```

Execute live upload/read/delete against the disposable bucket:

```powershell
$env:R2_EXECUTE_LIVE_HTTP='true'
npm run smoke
```

## Evidence Rules

- Store only redacted output in `docs/spikes/media-r2/evidence-log.md`.
- Do not paste signed URL query strings into tracked files.
- Do not use real media.
