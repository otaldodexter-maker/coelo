---
source: "specs/009-media-r2-spike.md"
status: "draft"
generated_at: "2026-06-22"
---

# Media R2 Evidence Log

## Environment

| Field | Value |
| --- | --- |
| Environment kind | local disposable spike |
| Media used | synthetic file only |
| Product apps touched | no |
| Production infrastructure touched | no |
| Disposable R2 credentials available | no |

## Evidence

| ID | Scenario | Result | Evidence | Date |
| --- | --- | --- | --- | --- |
| EV-001 | Upload authorization design | blocked | missing disposable R2 credentials; design in media-gateway-technical-spec.md | 2026-06-22 |
| EV-002 | Read authorization design | blocked | missing disposable R2 credentials; design in media-gateway-technical-spec.md | 2026-06-22 |
| EV-003 | Cross-tenant denial design | designed | media-gateway-technical-spec.md | 2026-06-22 |
| EV-004 | Expired URL behavior | blocked | missing disposable R2 credentials; design in media-gateway-technical-spec.md | 2026-06-22 |
| EV-005 | Orphan cleanup strategy | designed | media-gateway-technical-spec.md | 2026-06-22 |
| EV-006 | Secret scan | passed | tracked secret scan returned no matches; npm syntax check passed | 2026-06-22 |

## Verification Commands

```powershell
Test-Path -LiteralPath 'spikes\media-r2\.env'
git grep -n -E "X-Amz-Signature|sk-[A-Za-z0-9_-]{20,}|github_pat_|ghp_|SUPABASE_SERVICE_ROLE_KEY=.{12,}|R2_SECRET_ACCESS_KEY=.{24,}" -- ':!docs/**' ':!specs/**' ':!decisions/**' ':!spikes/media-r2/.env.example'
npm.cmd run check
```

Results:

- `.env` check returned `False`.
- Secret scan returned no matches.
- `npm.cmd run check` completed successfully.

## Decision Input

The ADR can move from proposed to accepted only if EV-001 through EV-006 are passing or have documented mitigations accepted by the project owner.
