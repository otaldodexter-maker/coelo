import { handler } from "./index.ts";

const JOB_ID = "e4e00000-0000-4000-8000-000000000101";
const REQUEST_ID = "e4e00000-0000-4000-8000-000000000102";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function assert(condition: unknown, message: string) {
  if (!condition) throw new Error(message);
}

type Scenario =
  | "replay_success"
  | "complete_response_lost"
  | "signed_url_failed"
  | "revoked_after_complete";

async function runScenario(scenario: Scenario) {
  const originalFetch = globalThis.fetch;
  const originalEnv = new Map<string, string | undefined>();
  for (
    const [name, value] of Object.entries({
      SUPABASE_URL: "http://supabase.test",
      SUPABASE_ANON_KEY: "anon-test-key",
      SUPABASE_SECRET_KEYS: JSON.stringify({ default: "secret-test-key" }),
      COELO_UNIT_EXPORT_WORKER_SECRET: "worker-test-secret",
    })
  ) {
    originalEnv.set(name, Deno.env.get(name));
    Deno.env.set(name, value);
  }

  const calls: string[] = [];
  let completeApplied = false;
  let reauthorizationCalls = 0;
  globalThis.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    const request = new Request(input, init);
    const url = new URL(request.url);
    const call = `${request.method} ${url.pathname}`;
    calls.push(call);

    if (url.pathname.endsWith("/rpc/superadmin_request_unit_export")) {
      return json({
        job_id: JOB_ID,
        domain: "units_export",
        state: scenario === "replay_success" ? "SUCESSO" : "PENDENTE",
        format: "csv",
        summary: scenario === "replay_success"
          ? {
            storage_path:
              `exports/units/${JOB_ID}/e4e00000-0000-4000-8000-000000000103.csv`,
          }
          : {},
      });
    }
    if (
      url.pathname.endsWith("/rpc/superadmin_materialize_unit_export_from_edge")
    ) {
      return json({ job_id: JOB_ID, domain: "units_export" });
    }
    if (url.pathname.endsWith("/rpc/superadmin_unit_export_page_v2")) {
      return json({
        items: [{ id: JOB_ID, name: "Unidade" }],
        has_more: false,
      });
    }
    if (url.pathname.endsWith("/rpc/superadmin_get_unit_file_job")) {
      reauthorizationCalls += 1;
      if (scenario === "revoked_after_complete" && reauthorizationCalls >= 3) {
        return json({ message: "revoked" }, 403);
      }
      return json({
        job_id: JOB_ID,
        domain: "units_export",
        state: "PENDENTE",
      });
    }
    if (url.pathname.endsWith("/rpc/superadmin_complete_unit_file_job")) {
      completeApplied = true;
      if (scenario === "complete_response_lost") {
        return json({ message: "lost" }, 500);
      }
      return json({ job_id: JOB_ID, domain: "units_export", state: "SUCESSO" });
    }
    if (url.pathname.endsWith("/import_jobs")) {
      return json({ request_id: REQUEST_ID });
    }
    if (url.pathname.endsWith("/rpc/superadmin_fail_unit_file_job")) {
      return json({ job_id: JOB_ID, state: "ERRO" });
    }
    if (url.pathname.includes("/storage/v1/object/sign/")) {
      if (scenario === "signed_url_failed") {
        return json({ message: "sign failed" }, 500);
      }
      return json({ signedURL: "/signed/export.csv" });
    }
    if (url.pathname.includes("/storage/v1/object/")) {
      return json({ Key: "stored" });
    }
    return json({ message: `unhandled ${call}` }, 500);
  };

  try {
    await handler(
      new Request("http://edge.test/unit-export", {
        method: "POST",
        headers: {
          Authorization: "Bearer actor-session",
          "Content-Type": "application/json",
          "x-coelo-worker-secret": "worker-test-secret",
        },
        body: JSON.stringify({
          action: "generate",
          format: "csv",
          filters: {},
          current_view: {},
          idempotency_key: REQUEST_ID,
        }),
      }),
    );
    return { calls, completeApplied, reauthorizationCalls };
  } finally {
    globalThis.fetch = originalFetch;
    for (const [name, value] of originalEnv) {
      if (value === undefined) Deno.env.delete(name);
      else Deno.env.set(name, value);
    }
  }
}

Deno.test("replay of an already successful job never rematerializes or uploads a new artifact", async () => {
  const { calls } = await runScenario("replay_success");
  assert(
    !calls.some((call) =>
      call.endsWith("/rpc/superadmin_materialize_unit_export_from_edge")
    ),
    "successful replay rematerialized the snapshot",
  );
  assert(
    !calls.some((call) => call.startsWith("POST /storage/v1/object/")),
    "successful replay uploaded a second artifact",
  );
});

Deno.test("lost completion response never deletes an artifact whose completion may have committed", async () => {
  const { calls, completeApplied } = await runScenario(
    "complete_response_lost",
  );
  assert(
    completeApplied,
    "fixture did not reach the ambiguous completion boundary",
  );
  assert(
    !calls.some((call) => call.startsWith("DELETE /storage/v1/object/")),
    "ambiguous completion deleted the possibly canonical artifact",
  );
});

Deno.test("signed URL failure after completion preserves the successful artifact and job", async () => {
  const { calls, completeApplied } = await runScenario("signed_url_failed");
  assert(completeApplied, "fixture did not complete the export");
  assert(
    !calls.some((call) => call.startsWith("DELETE /storage/v1/object/")),
    "post-completion signing failure deleted the canonical artifact",
  );
  assert(
    !calls.some((call) => call.endsWith("/rpc/superadmin_fail_unit_file_job")),
    "post-completion signing failure tried to demote a successful job",
  );
});

Deno.test("actor is reauthorized after completion and before minting the signed URL", async () => {
  const { calls, completeApplied, reauthorizationCalls } = await runScenario(
    "revoked_after_complete",
  );
  assert(completeApplied, "fixture did not complete the export");
  assert(
    reauthorizationCalls >= 3,
    "worker did not reauthorize after completion",
  );
  assert(
    !calls.some((call) => call.includes("/storage/v1/object/sign/")),
    "revoked actor reached signed URL minting",
  );
});
