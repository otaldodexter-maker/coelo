import { assertEquals, assertThrows } from "@std/assert";
import {
  allowedOrigin,
  DOWNLOAD_TTL_SECONDS,
  downloadHeaders,
  downloadToken,
  effectiveDownloadTtl,
  handleCorsPreflight,
  parseDownloadRequest,
  r2ExportArtifact,
  storagePath,
  validSignedDownload,
} from "./download_contract.ts";

const jobId = "11111111-1111-4111-8111-111111111111";
const institutionId = "22222222-2222-4222-8222-222222222222";
const assetId = "33333333-3333-4333-8333-333333333333";

Deno.test("R2 artifact binds the requested job, institution, purpose and private bucket", () => {
  const valid = {
    job_id: jobId,
    institution_id: institutionId,
    asset_id: assetId,
    provider: "r2",
    bucket: "coelo-transient-prod",
    export_kind: "xlsx",
    state: "ready",
    purpose: "forms-responses-export",
    object_key:
      `tenants/${institutionId}/exports/forms/${jobId}/${assetId}/responses.xlsx`,
    expires_at: "2026-09-08T19:00:00Z",
  };
  assertEquals(r2ExportArtifact(valid, jobId)?.object_key, valid.object_key);
  for (
    const invalid of [
      { ...valid, job_id: assetId },
      { ...valid, institution_id: assetId },
      { ...valid, asset_id: null },
      { ...valid, asset_id: institutionId },
      {
        ...valid,
        object_key:
          `tenants/${institutionId}/exports/forms/${jobId}/responses.xlsx`,
      },
      { ...valid, provider: "supabase" },
      { ...valid, state: "pending" },
      { ...valid, state: "deleted" },
      { ...valid, bucket: "public" },
      { ...valid, export_kind: "csv" },
      { ...valid, purpose: "answer-image" },
      { ...valid, object_key: "https://evil.test/file.xlsx" },
      { ...valid, object_key: `${valid.object_key}/../other.xlsx` },
      {
        ...valid,
        object_key: valid.object_key.replace("responses.xlsx", "responses.csv"),
      },
    ]
  ) assertEquals(r2ExportArtifact(invalid, jobId), null);
});

Deno.test("rejects credentials or fragments in a signed URL", () => {
  assertEquals(
    validSignedDownload("https://user:secret@storage.example.test/object"),
    false,
  );
  assertEquals(
    validSignedDownload("https://storage.example.test/object#fragment"),
    false,
  );
});

Deno.test("allows only configured browser origins and preflight", () => {
  const request = new Request("https://example.test/form-export-download", {
    method: "OPTIONS",
    headers: { origin: "https://superadmin.coelo.me" },
  });
  const origin = allowedOrigin(request, "https://superadmin.coelo.me");
  assertEquals(origin, "https://superadmin.coelo.me");
  assertEquals(handleCorsPreflight(request, origin)?.status, 204);
  assertEquals(downloadHeaders(origin)["cache-control"], "no-store");
  const denied = new Request(request.url, {
    method: "OPTIONS",
    headers: { origin: "https://evil.test" },
  });
  assertEquals(
    handleCorsPreflight(
      denied,
      allowedOrigin(denied, "https://superadmin.coelo.me"),
    )?.status,
    403,
  );
});

Deno.test("accepts only a job id UUID", () => {
  assertEquals(parseDownloadRequest({ job_id: jobId }), { job_id: jobId });
  assertThrows(() => parseDownloadRequest({ job_id: "another-tenant" }));
  assertThrows(() =>
    parseDownloadRequest({ job_id: jobId, artifact_path: "leak" })
  );
});

Deno.test("uses a five minute private download contract", () => {
  assertEquals(DOWNLOAD_TTL_SECONDS, 300);
  assertEquals(downloadHeaders()["cache-control"], "no-store");
  assertEquals(downloadHeaders()["x-content-type-options"], "nosniff");
});

Deno.test("caps signed URL TTL by artifact expiry and fails closed at zero", () => {
  const now = Date.parse("2026-08-20T15:00:00Z");
  assertEquals(effectiveDownloadTtl("2026-08-20T15:10:00Z", now), 300);
  assertEquals(effectiveDownloadTtl("2026-08-20T15:00:42.900Z", now), 42);
  assertEquals(effectiveDownloadTtl("2026-08-20T15:00:00Z", now), null);
  assertEquals(effectiveDownloadTtl("invalid", now), null);
});

Deno.test("accepts only HTTPS signed URLs", () => {
  assertEquals(
    validSignedDownload(
      "https://storage.example.test/object/sign/private?token=short",
    ),
    true,
  );
  assertEquals(
    validSignedDownload("http://storage.example.test/private"),
    false,
  );
  assertEquals(validSignedDownload("javascript:alert(1)"), false);
});

Deno.test("separates the public opaque token from the service-only storage path", () => {
  assertEquals(downloadToken({ download_token: jobId }), jobId);
  assertEquals(downloadToken({ storage_path: "aa/private" }), null);
  assertEquals(storagePath({ storage_path: `aa/${jobId}` }), `aa/${jobId}`);
  assertEquals(storagePath({ storage_path: "tenant/person/export.csv" }), null);
});
