import { assertEquals } from "@std/assert";
import { R2Client } from "../_shared/r2_s3.ts";
import {
  type FormExportDownloadDependencies,
  handleFormExportDownloadRequest,
} from "./index.ts";

const jobId = "11111111-1111-4111-8111-111111111111";
const institutionId = "22222222-2222-4222-8222-222222222222";
const token = "33333333-3333-4333-8333-333333333333";
const assetId = "44444444-4444-4444-8444-444444444444";
const now = Date.parse("2026-09-08T17:00:00Z");
const env = {
  SUPABASE_URL: "https://database.example.test",
  SUPABASE_ANON_KEY: "synthetic-public",
  SUPABASE_SERVICE_ROLE_KEY: "synthetic-private",
  COELO_ALLOWED_ORIGINS: "https://superadmin.example.test",
};
const artifact = {
  job_id: jobId,
  institution_id: institutionId,
  asset_id: assetId,
  provider: "r2",
  bucket: "coelo-transient-prod",
  export_kind: "xlsx",
  purpose: "forms-responses-export",
  state: "ready",
  object_key:
    `tenants/${institutionId}/exports/forms/${jobId}/${assetId}/responses.xlsx`,
  expires_at: new Date(now + 42_900).toISOString(),
};
function request(
  body: unknown = { job_id: jobId },
  authorization = "Bearer synthetic-user",
) {
  return new Request("https://gateway.example.test/form-export-download", {
    method: "POST",
    headers: {
      authorization,
      "content-type": "application/json",
      origin: "https://superadmin.example.test",
    },
    body: JSON.stringify(body),
  });
}
function fixture(
  options: {
    authorized?: unknown;
    redeemed?: unknown;
    failAt?: string;
    advanceAfterSign?: boolean;
  } = {},
) {
  const calls: Array<
    { role: string; name: string; params: Record<string, unknown> }
  > = [];
  let signCalls = 0, currentTime = now;
  const dependencies: FormExportDownloadDependencies = {
    environment: () => env,
    now: () => new Date(currentTime),
    createClient: ((_url: string, key: string) => ({
      rpc: (name: string, params: Record<string, unknown>) => {
        const role = key === env.SUPABASE_ANON_KEY ? "user" : "service";
        calls.push({ role, name, params });
        if (options.failAt === role) {
          throw new Error("synthetic-sensitive-provider-details");
        }
        return Promise.resolve({
          error: null,
          data: role === "user"
            ? ("authorized" in options ? options.authorized : {
              ok: true,
              data: {
                job_id: jobId,
                download_token: token,
                expires_at: new Date(now + 120_000).toISOString(),
              },
              error: null,
            })
            : ("redeemed" in options ? options.redeemed : artifact),
        });
      },
    })) as unknown as FormExportDownloadDependencies["createClient"],
    createR2: () => ({
      presignGet: async (key, ttl) => {
        signCalls++;
        if (options.failAt === "sign") {
          throw new Error(
            "synthetic-sensitive-provider-details",
          );
        }
        const signed = await new R2Client({
          endpoint: "https://account.r2.cloudflarestorage.com",
          region: "auto",
          accessKeyId: "synthetic-key",
          secretAccessKey: "synthetic-secret",
          bucket: "coelo-transient-prod",
        }, { now: () => new Date(currentTime) }).presignGet(key, ttl);
        if (options.advanceAfterSign) currentTime += 60_000;
        return signed;
      },
    }),
  };
  return { dependencies, calls, signs: () => signCalls };
}

Deno.test("download authorizes user, redeems one-use token and signs only correlated R2 artifact", async () => {
  const f = fixture();
  const response = await handleFormExportDownloadRequest(
    request(),
    f.dependencies,
  );
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.job_id, jobId);
  assertEquals(body.expires_at, new Date(now + 42_000).toISOString());
  const url = new URL(body.download_url);
  assertEquals(url.hostname, "account.r2.cloudflarestorage.com");
  assertEquals(url.pathname, `/coelo-transient-prod/${artifact.object_key}`);
  assertEquals(url.searchParams.get("X-Amz-Expires"), "42");
  assertEquals(response.headers.get("cache-control"), "no-store");
  assertEquals(f.calls, [
    {
      role: "user",
      name: "superadmin_form_authorize_xlsx_download_v2",
      params: { p_file_job_id: jobId },
    },
    {
      role: "service",
      name: "form_redeem_xlsx_download_r2_v1",
      params: { p_download_token: token },
    },
  ]);
});

Deno.test("denied or mismatched authorization cannot call service or signer", async () => {
  for (
    const authorized of [null, {
      ok: false,
      data: null,
      error: { code: "denied" },
    }, {
      ok: true,
      data: {
        job_id: assetId,
        download_token: token,
        expires_at: artifact.expires_at,
      },
    }, {
      ok: true,
      data: {
        job_id: jobId,
        download_token: token,
        expires_at: new Date(now).toISOString(),
      },
    }]
  ) {
    const f = fixture({ authorized });
    const response = await handleFormExportDownloadRequest(
      request(),
      f.dependencies,
    );
    assertEquals(response.status, 404);
    assertEquals(f.calls.length, 1);
    assertEquals(f.signs(), 0);
  }
});

Deno.test("invalid, revoked or expired redeemed artifacts never reach signer", async () => {
  for (
    const redeemed of [
      null,
      { ...artifact, job_id: assetId },
      { ...artifact, bucket: "public" },
      { ...artifact, expires_at: new Date(now).toISOString() },
      { ...artifact, provider: "supabase" },
      { ...artifact, state: "deleted" },
    ]
  ) {
    const f = fixture({ redeemed });
    const response = await handleFormExportDownloadRequest(
      request(),
      f.dependencies,
    );
    assertEquals(response.status, 404);
    assertEquals(f.signs(), 0);
  }
});

Deno.test("invalid body, missing auth and untrusted origin cause no backend work", async () => {
  for (
    const req of [
      request({ job_id: jobId, bucket: "forged" }),
      request({ job_id: "invalid" }),
      request({ job_id: jobId }, ""),
      new Request(request(), {
        headers: {
          origin: "https://evil.example.test",
          authorization: "Bearer synthetic",
        },
      }),
    ]
  ) {
    const f = fixture();
    const response = await handleFormExportDownloadRequest(req, f.dependencies);
    assertEquals(response.status >= 400, true);
    assertEquals(f.calls.length, 0);
  }
});

Deno.test("oversized actual request bytes are refused even with a forged small length", async () => {
  const f = fixture();
  const req = new Request(request(), {
    body: JSON.stringify({ job_id: jobId }) + " ".repeat(5000),
    headers: { authorization: "Bearer synthetic", "content-length": "10" },
  });
  const response = await handleFormExportDownloadRequest(req, f.dependencies);
  assertEquals(response.status, 400);
  assertEquals(f.calls.length, 0);
});

Deno.test("dependency failures return safe errors and expired signing result is withheld", async () => {
  for (const failAt of ["user", "service", "sign"]) {
    const f = fixture({ failAt });
    const response = await handleFormExportDownloadRequest(
      request(),
      f.dependencies,
    );
    assertEquals(response.status, 503);
    assertEquals(await response.json(), { error: "service_unavailable" });
  }
  const f = fixture({ advanceAfterSign: true });
  const response = await handleFormExportDownloadRequest(
    request(),
    f.dependencies,
  );
  assertEquals(response.status, 404);
});
