---
source: "specs/009-media-r2-spike.md"
status: "draft-plan"
generated_at: "2026-06-22"
---

# Media R2 Spike Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Validate the private media R2 decision with documented architecture, test matrix, disposable prototype, evidence log, and ADR update.

**Architecture:** The spike keeps product apps untouched. It documents a future server-side Media Gateway that authorizes requests, signs short-lived R2 URLs, records media metadata in Postgres/Supabase, and denies cross-tenant access before any URL is issued. Any runnable code lives under `spikes/media-r2/` as disposable verification tooling, never under `apps/` or production packages.

**Tech Stack:** Markdown documentation, Cloudflare R2 S3-compatible API, presigned URL flow, optional Node.js disposable prototype using AWS SDK v3, Postgres/Supabase metadata contract.

## Global Constraints

- This plan implements `specs/009-media-r2-spike.md` only.
- No product code in Flutter, Astro, `packages/coelo_api`, or `packages/coelo_database`.
- No deploy, real migrations, production bucket, or real child/family/institution media.
- No `service_role`, R2 key, access token, signed URL, or secret committed to the repository.
- R2 stores bytes only; Postgres/Supabase remains the source of truth for metadata, ownership, permissions, and audit.
- Every access decision must include tenant, institution, membership, contextual role, resource audience, and consent/restriction checks.
- The final spike result must update `decisions/0010-private-media-r2.md`.

## Source Notes

- Cloudflare R2 presigned URLs support single-object operations such as GET and PUT, can expire from 1 second to 7 days, and should be treated as bearer tokens.
- Cloudflare recommends restricting upload `Content-Type` in the signature and configuring CORS for browser-based use of presigned URLs.
- The Coelo spec is stricter than the platform maximum: sensitive media URLs should use short expirations and be reissued after authorization, not reused as durable links.
- Official references checked on 2026-06-22:
  - https://developers.cloudflare.com/r2/api/s3/presigned-urls/
  - https://developers.cloudflare.com/r2/buckets/cors/
  - https://developers.cloudflare.com/r2/buckets/object-lifecycles/
  - https://developers.cloudflare.com/r2/platform/limits/

---

### Task 1: Create Spike Evidence Workspace

**Files:**
- Create: `docs/spikes/media-r2/README.md`
- Create: `docs/spikes/media-r2/evidence-log.md`

**Interfaces:**
- Consumes: `specs/009-media-r2-spike.md`
- Produces: `docs/spikes/media-r2/evidence-log.md`, used by later tasks and the ADR update

- [ ] **Step 1: Create the evidence directory**

Run:

```powershell
New-Item -ItemType Directory -Path 'docs\spikes\media-r2' -Force
```

Expected: directory exists at `docs/spikes/media-r2/`.

- [ ] **Step 2: Create `docs/spikes/media-r2/README.md`**

Write:

```markdown
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
```

- [ ] **Step 3: Create `docs/spikes/media-r2/evidence-log.md`**

Write:

```markdown
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

## Evidence

| ID | Scenario | Result | Evidence | Date |
| --- | --- | --- | --- | --- |
| EV-001 | Upload authorization design | pending | pending execution | 2026-06-22 |
| EV-002 | Read authorization design | pending | pending execution | 2026-06-22 |
| EV-003 | Cross-tenant denial design | pending | pending execution | 2026-06-22 |
| EV-004 | Expired URL behavior | pending | pending execution | 2026-06-22 |
| EV-005 | Orphan cleanup strategy | pending | pending execution | 2026-06-22 |
| EV-006 | Secret scan | pending | pending execution | 2026-06-22 |

## Decision Input

The ADR can move from proposed to accepted only if EV-001 through EV-006 are passing or have documented mitigations accepted by the project owner.
```

- [ ] **Step 4: Verify the files**

Run:

```powershell
rg -n "pending execution|Product apps touched|Safety Rules" docs\spikes\media-r2
```

Expected: matching lines appear in the two created files.

- [ ] **Step 5: Commit Task 1**

Run:

```powershell
git add docs/spikes/media-r2/README.md docs/spikes/media-r2/evidence-log.md
git commit -m "docs: add media R2 spike evidence workspace"
```

Expected: commit succeeds.

---

### Task 2: Write Media Gateway Technical Spec

**Files:**
- Create: `docs/spikes/media-r2/media-gateway-technical-spec.md`
- Modify: `docs/spikes/media-r2/evidence-log.md`

**Interfaces:**
- Consumes: evidence workspace from Task 1
- Produces: a technical architecture document used by the test matrix and ADR update

- [ ] **Step 1: Create `docs/spikes/media-r2/media-gateway-technical-spec.md`**

Write:

```markdown
---
source: "specs/009-media-r2-spike.md"
status: "draft"
generated_at: "2026-06-22"
---

# Media Gateway Technical Spec

## Decision Being Tested

Cloudflare R2 is the single private media object store from the MVP. Postgres/Supabase stores metadata, ownership, permission links, and audit records.

## Non-Negotiables

- Buckets are private.
- Product clients never receive R2 credentials, service role keys, or durable public object URLs.
- Signed URLs are issued only after server-side authorization.
- Signed URLs are logged only as redacted values.
- Object keys are generated by the server and are not based on user-provided filenames.

## Actors

| Actor | Allowed action |
| --- | --- |
| Authorized staff | Request upload for permitted context |
| Authorized responsible adult | Request read for media linked to allowed child, group, or communication |
| Unauthorized person | Receive denial before any signed URL is issued |
| Coelo operator | Review logs and cleanup status without seeing media content |

## Proposed Object Key Shape

`tenant/<tenant_id>/institution/<institution_id>/media/<yyyy>/<mm>/<asset_id>/<variant>`

Rules:

- `tenant_id`, `institution_id`, and `asset_id` come from server-owned records.
- Original filenames are stored only as sanitized metadata when needed.
- Variants use fixed names such as `original`, `thumb`, or `compressed`.

## Proposed Metadata Contract

| Field | Required | Notes |
| --- | --- | --- |
| `asset_id` | yes | Server-generated identifier |
| `tenant_id` | yes | Isolation boundary |
| `institution_id` | yes | Institution boundary |
| `owner_person_id` | yes | Actor that initiated upload |
| `context_type` | yes | post, now, moment, routine, chat, agenda |
| `context_id` | yes | Business object that owns access decision |
| `object_key` | yes | Server-generated R2 key |
| `mime_type` | yes | Validated at request and finalization |
| `byte_size` | yes | Validated at finalization |
| `checksum` | yes | Recorded when available |
| `status` | yes | requested, uploaded, finalized, available, failed, orphaned, removed, purged |
| `classification` | yes | private tenant, group, child, family, sensitive |
| `consent_state` | yes | allowed, restricted, unknown |
| `created_at` | yes | Audit and retention input |
| `expires_at` | no | Future retention input |
| `removed_at` | no | Logical removal input |

## Upload Flow

1. Client asks Media Gateway to start upload with context, MIME, size, checksum, and intended classification.
2. Media Gateway validates session, active context, membership, role, context ownership, allowed MIME, size limit, and consent/restriction state.
3. Media Gateway creates a `media_assets` record with status `requested`.
4. Media Gateway generates an R2 object key and a short-lived PUT URL.
5. Client uploads synthetic or user-selected bytes directly to R2 using the signed URL.
6. Client calls finalize.
7. Media Gateway verifies expected size, MIME/checksum where possible, object existence, tenant/context ownership, and changes status to `available` or `failed`.

## Read Flow

1. Client asks Media Gateway to read an asset by `asset_id`.
2. Media Gateway loads metadata from Postgres/Supabase.
3. Media Gateway validates session, active context, membership, role, audience, child/group/family link, consent restrictions, and object status.
4. If allowed, Media Gateway issues a short-lived GET URL.
5. If denied, Media Gateway returns no URL and records a denial event.

## URL Policy

| URL type | Recommended default | Maximum for Coelo MVP spike |
| --- | --- | --- |
| PUT upload | 5 minutes | 15 minutes |
| GET read | 2 minutes | 10 minutes |
| HEAD verify | 2 minutes | 10 minutes |

R2 permits longer expirations, but Coelo should keep sensitive media URLs short and reissue them after authorization.

## CORS Policy Recommendation

The first live spike can use command-line HTTP clients and does not require browser CORS. Before browser upload is added, configure exact allowed origins for planned app surfaces and local test origins. Allowed methods should match the signed operation: `PUT` for upload, `GET` and `HEAD` for read/verify. Expose `ETag` only when the client needs it for upload verification.

## Orphan Cleanup

An upload is orphaned when a `requested` or `uploaded` asset is not finalized within the allowed finalization window. Cleanup should:

1. Select stale media records by status and age.
2. Confirm there is no valid business link.
3. Delete or mark the R2 object according to the approved retention policy.
4. Mark metadata as `orphaned`, `removed`, or `purged`.
5. Log IDs and status only.

## Audit Events

- `media_upload_requested`
- `media_upload_finalized`
- `media_upload_failed`
- `media_read_authorized`
- `media_read_denied`
- `media_orphan_detected`
- `media_orphan_cleanup_executed`

## Open Risks

- Retention period is not legally approved.
- CPF and broader identity policies remain outside this spike.
- Browser CORS must be validated before real web/mobile upload UI.
- Video transformations and adaptive streaming are outside this spike.
```

- [ ] **Step 2: Update EV-001 through EV-005 in `evidence-log.md`**

Change the `Result` column from `pending` to `designed` for EV-001 through EV-005 and set `Evidence` to `media-gateway-technical-spec.md`.

- [ ] **Step 3: Verify no unresolved markers**

Run:

```powershell
rg -n "TBD|TODO|NEEDS CLARIFICATION|secretAccessKey|X-Amz-Signature" docs\spikes\media-r2
```

Expected: no matches.

- [ ] **Step 4: Commit Task 2**

Run:

```powershell
git add docs/spikes/media-r2/media-gateway-technical-spec.md docs/spikes/media-r2/evidence-log.md
git commit -m "docs: define media gateway R2 spike design"
```

Expected: commit succeeds.

---

### Task 3: Write Test Matrix And Threat Checklist

**Files:**
- Create: `docs/spikes/media-r2/test-matrix.md`
- Create: `docs/spikes/media-r2/threat-checklist.md`
- Modify: `docs/spikes/media-r2/evidence-log.md`

**Interfaces:**
- Consumes: technical spec from Task 2
- Produces: verification criteria for the live or simulated spike

- [ ] **Step 1: Create `docs/spikes/media-r2/test-matrix.md`**

Write:

```markdown
---
source: "docs/spikes/media-r2/media-gateway-technical-spec.md"
status: "draft"
generated_at: "2026-06-22"
---

# Media R2 Test Matrix

| ID | Scenario | Setup | Action | Expected result |
| --- | --- | --- | --- | --- |
| R2-T001 | Upload authorized | Valid tenant, institution, membership, role, context, MIME, size | Request upload authorization | PUT URL issued; secret not exposed |
| R2-T002 | Upload MIME mismatch | Valid authorization signed for one MIME | Upload with a different `Content-Type` | Upload fails or finalization rejects the object |
| R2-T003 | Finalize valid upload | Uploaded synthetic object exists | Finalize asset | Metadata status becomes `available` |
| R2-T004 | Read authorized | Asset available and user has valid link | Request read URL | GET URL issued with short expiry |
| R2-T005 | Read denied by tenant | Asset belongs to tenant A, user context is tenant B | Request read URL | No URL issued; denial event recorded |
| R2-T006 | Read denied by removed membership | Membership removed after upload | Request read URL | No URL issued; denial event recorded |
| R2-T007 | Expired URL | Signed URL older than policy | Reuse URL | Request fails or client asks Media Gateway for a new URL |
| R2-T008 | Orphan cleanup | Upload requested but not finalized in window | Run cleanup logic | Asset marked orphaned/removed and event recorded |
| R2-T009 | Secret scan | Repository after spike | Search for secrets and signatures | No secrets, credentials, or signed URL signatures committed |

## Synthetic Media Rule

Use a text fixture or generated bytes, not real child, family, school, or institution media.
```

- [ ] **Step 2: Create `docs/spikes/media-r2/threat-checklist.md`**

Write:

```markdown
---
source: "specs/009-media-r2-spike.md"
status: "draft"
generated_at: "2026-06-22"
---

# Media R2 Threat Checklist

| Risk | Required mitigation |
| --- | --- |
| Public child media | Bucket remains private; no public permanent URL |
| Client credential exposure | R2 credentials and service role keys stay server-side |
| Cross-tenant leakage | Authorization checks tenant, institution, membership, role, audience, and consent |
| URL sharing | URLs expire quickly and are treated as bearer tokens |
| Predictable object path | Object key generated by server using opaque `asset_id` |
| Over-logging | Logs store IDs, status, actor, tenant, and reason; no media content or full signed URL |
| Orphaned object cost | Cleanup process detects stale requested/uploaded assets |
| Retention ambiguity | Spike records the gap and does not invent legal retention periods |
```

- [ ] **Step 3: Update `evidence-log.md`**

Set EV-006 result to `designed` and evidence to `test-matrix.md; threat-checklist.md`.

- [ ] **Step 4: Verify the test matrix covers the approved spec**

Run:

```powershell
rg -n "R2-T00[1-9]|Cross-tenant|Orphan|Secret" docs\spikes\media-r2
```

Expected: test IDs and risk terms appear.

- [ ] **Step 5: Commit Task 3**

Run:

```powershell
git add docs/spikes/media-r2/test-matrix.md docs/spikes/media-r2/threat-checklist.md docs/spikes/media-r2/evidence-log.md
git commit -m "docs: add media R2 spike test matrix"
```

Expected: commit succeeds.

---

### Task 4: Add Disposable Prototype Harness

**Files:**
- Create: `spikes/media-r2/.gitignore`
- Create: `spikes/media-r2/.env.example`
- Create: `spikes/media-r2/package.json`
- Create: `spikes/media-r2/README.md`
- Create: `spikes/media-r2/src/r2-presign-smoke.mjs`
- Create: `spikes/media-r2/fixtures/synthetic-media.txt`

**Interfaces:**
- Consumes: test matrix from Task 3
- Produces: a disposable harness for live R2 smoke checks when credentials are available

- [ ] **Step 1: Create directories**

Run:

```powershell
New-Item -ItemType Directory -Path 'spikes\media-r2\src' -Force
New-Item -ItemType Directory -Path 'spikes\media-r2\fixtures' -Force
```

Expected: both directories exist.

- [ ] **Step 2: Create `spikes/media-r2/.gitignore`**

Write:

```gitignore
.env
node_modules/
*.log
```

- [ ] **Step 3: Create `spikes/media-r2/.env.example`**

Write:

```dotenv
R2_ACCOUNT_ID=
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_BUCKET=
R2_TEST_PREFIX=tenant/test-tenant/institution/test-institution/media/spike
```

- [ ] **Step 4: Create `spikes/media-r2/package.json`**

Write:

```json
{
  "name": "coelo-media-r2-spike",
  "private": true,
  "type": "module",
  "scripts": {
    "check": "node --check src/r2-presign-smoke.mjs",
    "smoke": "node src/r2-presign-smoke.mjs"
  },
  "dependencies": {
    "@aws-sdk/client-s3": "^3.600.0",
    "@aws-sdk/s3-request-presigner": "^3.600.0"
  }
}
```

- [ ] **Step 5: Create `spikes/media-r2/fixtures/synthetic-media.txt`**

Write:

```text
Coelo synthetic media fixture for R2 spike.
This is not real child, family, school, or institution media.
```

- [ ] **Step 6: Create `spikes/media-r2/src/r2-presign-smoke.mjs`**

Write:

```javascript
import { readFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

const required = [
  "R2_ACCOUNT_ID",
  "R2_ACCESS_KEY_ID",
  "R2_SECRET_ACCESS_KEY",
  "R2_BUCKET",
  "R2_TEST_PREFIX"
];

for (const key of required) {
  if (!process.env[key]) {
    throw new Error(`Missing required env var: ${key}`);
  }
}

const fixturePath = new URL("../fixtures/synthetic-media.txt", import.meta.url);
const body = await readFile(fixturePath);
const checksum = createHash("sha256").update(body).digest("hex");
const assetId = `spike-${Date.now()}`;
const objectKey = `${process.env.R2_TEST_PREFIX}/${assetId}/original.txt`;
const endpoint = `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`;

const client = new S3Client({
  region: "auto",
  endpoint,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY
  }
});

const putCommand = new PutObjectCommand({
  Bucket: process.env.R2_BUCKET,
  Key: objectKey,
  Body: body,
  ContentType: "text/plain"
});

const getCommand = new GetObjectCommand({
  Bucket: process.env.R2_BUCKET,
  Key: objectKey
});

const putUrl = await getSignedUrl(client, putCommand, { expiresIn: 300 });
const getUrl = await getSignedUrl(client, getCommand, { expiresIn: 120 });

console.log(JSON.stringify({
  result: "presigned_urls_generated",
  bucket: process.env.R2_BUCKET,
  objectKey,
  byteSize: body.length,
  checksum,
  putUrlRedacted: redactSignedUrl(putUrl),
  getUrlRedacted: redactSignedUrl(getUrl)
}, null, 2));

if (process.env.R2_EXECUTE_LIVE_HTTP === "true") {
  const upload = await fetch(putUrl, {
    method: "PUT",
    headers: { "Content-Type": "text/plain" },
    body
  });

  if (!upload.ok) {
    throw new Error(`PUT failed: ${upload.status} ${upload.statusText}`);
  }

  const read = await fetch(getUrl);
  if (!read.ok) {
    throw new Error(`GET failed: ${read.status} ${read.statusText}`);
  }

  const downloaded = Buffer.from(await read.arrayBuffer());
  const downloadedChecksum = createHash("sha256").update(downloaded).digest("hex");

  if (downloadedChecksum !== checksum) {
    throw new Error("Downloaded checksum did not match fixture checksum");
  }

  await client.send(new DeleteObjectCommand({
    Bucket: process.env.R2_BUCKET,
    Key: objectKey
  }));

  console.log(JSON.stringify({
    result: "live_upload_read_delete_passed",
    objectKey,
    byteSize: downloaded.length,
    checksum: downloadedChecksum
  }, null, 2));
}

function redactSignedUrl(url) {
  const parsed = new URL(url);
  return `${parsed.origin}${parsed.pathname}?redacted_signature=true`;
}
```

- [ ] **Step 7: Create `spikes/media-r2/README.md`**

Write:

```markdown
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
```

- [ ] **Step 8: Run syntax check**

Run:

```powershell
Set-Location spikes\media-r2
npm install
npm run check
Set-Location ..\..
```

Expected: dependency install succeeds and Node reports no syntax errors.

- [ ] **Step 9: Commit Task 4**

Run:

```powershell
git add spikes/media-r2
git commit -m "chore: add disposable R2 spike harness"
```

Expected: commit succeeds.

---

### Task 5: Execute Live Or Simulated Verification

**Files:**
- Modify: `docs/spikes/media-r2/evidence-log.md`

**Interfaces:**
- Consumes: disposable harness from Task 4
- Produces: evidence for ADR decision

- [ ] **Step 1: Confirm credential availability**

Run:

```powershell
Test-Path -LiteralPath 'spikes\media-r2\.env'
```

Expected:

- `True`: continue live verification.
- `False`: run simulated verification only and mark live verification blocked by missing disposable R2 credentials.

- [ ] **Step 2: Run secret scan before live verification**

Run:

```powershell
git grep -n -E "X-Amz-Signature|sk-[A-Za-z0-9_-]{20,}|github_pat_|ghp_|SUPABASE_SERVICE_ROLE_KEY=.{12,}|R2_SECRET_ACCESS_KEY=.{24,}" -- ':!docs/**' ':!specs/**' ':!decisions/**' ':!spikes/media-r2/.env.example'
```

Expected: no tracked secrets or signed URLs.

- [ ] **Step 3: Run live smoke if `.env` exists**

Run:

```powershell
Set-Location spikes\media-r2
Get-Content .env | ForEach-Object {
  if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
    [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
  }
}
$env:R2_EXECUTE_LIVE_HTTP='true'
npm run smoke
Set-Location ..\..
```

Expected: output includes `live_upload_read_delete_passed` and no full signed URL is copied into tracked files.

- [ ] **Step 4: Update evidence log**

If live smoke passed, update EV-001, EV-002, EV-004, and EV-006 to `passed`, with evidence `spikes/media-r2 smoke output redacted`. Keep EV-003 and EV-005 as `designed` unless a separate authorization simulation was performed.

If no `.env` exists, update EV-001, EV-002, EV-004, and EV-006 to `blocked`, with evidence `missing disposable R2 credentials`.

- [ ] **Step 5: Commit Task 5**

Run:

```powershell
git add docs/spikes/media-r2/evidence-log.md
git commit -m "docs: record media R2 spike evidence"
```

Expected: commit succeeds.

---

### Task 6: Update ADR And Next-Step Decision

**Files:**
- Modify: `decisions/0010-private-media-r2.md`
- Modify: `docs/open-questions.md`

**Interfaces:**
- Consumes: evidence log from Task 5
- Produces: updated architecture decision and remaining open questions

- [ ] **Step 1: Read evidence**

Run:

```powershell
Get-Content -LiteralPath 'docs\spikes\media-r2\evidence-log.md'
```

Expected: EV-001 through EV-006 have `designed`, `passed`, or `blocked` status.

- [ ] **Step 2: Update ADR status**

Use this decision rule:

- If EV-001, EV-002, EV-004, and EV-006 passed, set ADR status to `Accepted for MVP with constraints`.
- If live credentials were missing but design evidence is complete, keep ADR status as `Proposed - live verification blocked`.
- If any live R2 behavior fails without mitigation, set ADR status to `Proposed - changes required`.

Add a `## Resultado Do Spike` section with the evidence summary and the next required action.

- [ ] **Step 3: Update open questions**

Update OQ-002 based on the ADR status. Keep OQ-003 and OQ-009 open unless the spike produces legally approved retention and operational limits, which this plan does not assume.

- [ ] **Step 4: Verify final docs**

Run:

```powershell
rg -n "Resultado Do Spike|OQ-002|EV-00" decisions\0010-private-media-r2.md docs\open-questions.md docs\spikes\media-r2\evidence-log.md
git diff --check
```

Expected: ADR result, OQ-002, and evidence IDs appear; whitespace check passes.

- [ ] **Step 5: Commit Task 6**

Run:

```powershell
git add decisions/0010-private-media-r2.md docs/open-questions.md
git commit -m "docs: update R2 media decision after spike"
```

Expected: commit succeeds.

---

## Self-Review

- Spec coverage: Tasks cover upload, read, cross-tenant denial design, expired URL behavior, orphan cleanup, secret safety, evidence, and ADR update.
- Placeholder scan: The plan avoids unresolved placeholder markers and uses explicit file paths.
- Type consistency: The same evidence IDs EV-001 through EV-006 are used across tasks.
- Scope check: Product implementation remains out of scope; disposable harness is isolated under `spikes/media-r2/`.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-22-media-r2-spike.md`.

Two execution options:

1. Subagent-Driven (recommended) - dispatch a fresh subagent per task, review between tasks, fast iteration.
2. Inline Execution - execute tasks in this session using executing-plans, with checkpoints for review.
