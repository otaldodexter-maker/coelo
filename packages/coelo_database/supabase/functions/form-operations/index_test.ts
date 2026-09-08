import { assertEquals } from "@std/assert";
import * as XLSX from "xlsx";
import {
  type FormOperationsDependencies,
  handleFormOperationsRequest,
} from "./index.ts";

const environment = {
  SUPABASE_URL: "https://database.example.test",
  SUPABASE_SERVICE_ROLE_KEY: "synthetic-server-key",
  FORMS_OPERATIONS_BEARER_TOKEN: "synthetic-operations-token-for-local-test",
};
const id = "11111111-1111-4111-8111-111111111111";
const sensitiveError =
  "synthetic-sensitive-value https://private.example.test/object?token=synthetic";

Deno.test("worker never persists an unexpected dependency error as a job code", async () => {
  for (const job_kind of ["export_xlsx", "reconcile_audience"]) {
    let failureCode: unknown;
    const dependencies: FormOperationsDependencies = {
      environment: () => environment,
      createClient: (() => ({
        rpc: (name: string, params: Record<string, unknown>) => {
          if (name === "form_worker_claim") {
            return Promise.resolve({
              error: null,
              data: { id, aggregate_id: id, job_kind },
            });
          }
          if (
            name === "form_worker_fail_export" || name === "form_worker_fail"
          ) {
            failureCode = params.p_error_code;
            return Promise.resolve({ error: null, data: null });
          }
          throw new Error(sensitiveError);
        },
      })) as unknown as FormOperationsDependencies["createClient"],
    };
    const response = await handleFormOperationsRequest(request(), dependencies);
    assertEquals(response.status, 500);
    assertEquals(await response.json(), { error: "job_failed" });
    assertEquals(failureCode, "job_execution_failed");
  }
});

Deno.test("worker returns a safe response when environment, client or claim throws", async () => {
  for (const stage of ["environment", "client", "claim"]) {
    const dependencies: FormOperationsDependencies = {
      environment: () => {
        if (stage === "environment") throw new Error(sensitiveError);
        return environment;
      },
      createClient: (() => {
        if (stage === "client") throw new Error(sensitiveError);
        return {
          rpc: () => {
            throw new Error(sensitiveError);
          },
        };
      }) as unknown as FormOperationsDependencies["createClient"],
    };
    const response = await handleFormOperationsRequest(request(), dependencies);
    assertEquals(response.status, 503);
    assertEquals(await response.json(), { error: "service_unavailable" });
  }
});
function request() {
  return new Request("https://gateway.example.test", {
    method: "POST",
    headers: {
      authorization: `Bearer ${environment.FORMS_OPERATIONS_BEARER_TOKEN}`,
    },
  });
}

Deno.test("XLSX worker refuses another export snapshot kind before artifact upload", async () => {
  for (const kind of ["csv", "zip", "anonymous_participation"]) {
    let uploads = 0;
    const calls: string[] = [];
    const dependencies: FormOperationsDependencies = {
      environment: () => environment,
      createClient: (() => ({
        rpc: (name: string) => {
          calls.push(name);
          return Promise.resolve({
            error: null,
            data: name === "form_worker_claim"
              ? { id, aggregate_id: id, job_kind: "export_xlsx" }
              : name === "form_worker_export_snapshot"
              ? {
                kind,
                has_more: false,
                rows: [{ Pessoa: "Synthetic identity" }],
                submissions: [{
                  responseId: id,
                  occurrenceId: id,
                  versionId: id,
                  metadata: {},
                  answers: [],
                }],
              }
              : null,
          });
        },
        storage: {
          from: () => ({
            upload: async (
              _path: string,
              stream: ReadableStream<Uint8Array>,
            ) => {
              uploads++;
              await new Response(stream).arrayBuffer();
              return { error: null };
            },
          }),
        },
      })) as unknown as FormOperationsDependencies["createClient"],
    };
    const response = await handleFormOperationsRequest(request(), dependencies);
    assertEquals(response.status, 500);
    assertEquals(uploads, 0);
    assertEquals(calls.includes("form_worker_complete_export"), false);
    assertEquals(calls.at(-1), "form_worker_fail_export");
  }
});

Deno.test("worker claims only XLSX exports and refuses legacy export jobs", async () => {
  for (
    const kind of [
      "export_csv",
      "export_zip",
      "export_anonymous_participation",
      "export_response_pdf",
    ]
  ) {
    const calls: Array<{ name: string; params: Record<string, unknown> }> = [];
    const dependencies: FormOperationsDependencies = {
      environment: () => environment,
      createClient: (() => ({
        rpc: (name: string, params: Record<string, unknown>) => {
          calls.push({ name, params });
          return Promise.resolve({
            data: name === "form_worker_claim"
              ? { id, aggregate_id: id, job_kind: kind }
              : null,
            error: null,
          });
        },
      })) as unknown as FormOperationsDependencies["createClient"],
    };
    const response = await handleFormOperationsRequest(request(), dependencies);
    assertEquals(response.status, 500);
    assertEquals(await response.json(), { error: "job_failed" });
    assertEquals(
      (calls[0].params.p_job_kinds as string[]).filter((kind) =>
        kind.startsWith("export_")
      ),
      ["export_xlsx"],
    );
    assertEquals(calls.map((call) => call.name), [
      "form_worker_claim",
      "form_worker_fail_export",
    ]);
  }
});

Deno.test("worker preserves normal operational jobs without creating an artifact", async () => {
  const calls: string[] = [];
  const dependencies: FormOperationsDependencies = {
    environment: () => environment,
    createClient: (() => ({
      rpc: (name: string) => {
        calls.push(name);
        return Promise.resolve({
          data: name === "form_worker_claim"
            ? { id, aggregate_id: id, job_kind: "reconcile_audience" }
            : null,
          error: null,
        });
      },
    })) as unknown as FormOperationsDependencies["createClient"],
  };
  const response = await handleFormOperationsRequest(request(), dependencies);
  assertEquals(response.status, 200);
  assertEquals(calls, [
    "form_worker_claim",
    "form_worker_reconcile_audience",
    "form_worker_finish",
  ]);
});

Deno.test("worker rejects a request without operations authorization before backend", async () => {
  const dependencies: FormOperationsDependencies = {
    environment: () => environment,
    createClient: (() => {
      throw new Error("must not execute");
    }) as FormOperationsDependencies["createClient"],
  };
  const response = await handleFormOperationsRequest(
    new Request("https://gateway.example.test", { method: "POST" }),
    dependencies,
  );
  assertEquals(response.status, 401);
});

Deno.test("worker generates one valid XLSX and completes the form job with measured bytes", async () => {
  const uploads: Array<{ path: string; bytes: Uint8Array; options: unknown }> =
    [];
  const calls: Array<{ name: string; params: Record<string, unknown> }> = [];
  const dependencies: FormOperationsDependencies = {
    environment: () => environment,
    createClient: (() => ({
      rpc: (name: string, params: Record<string, unknown>) => {
        calls.push({ name, params });
        return Promise.resolve({
          error: null,
          data: name === "form_worker_claim"
            ? { id, aggregate_id: id, job_kind: "export_xlsx" }
            : name === "form_worker_export_snapshot"
            ? {
              kind: "xlsx",
              has_more: false,
              submissions: [{
                responseId: id,
                occurrenceId: id,
                versionId: id,
                metadata: {},
                answers: [{
                  itemId: id,
                  question: "Sintético",
                  values: ["Resposta sintética"],
                  multiValued: false,
                }],
              }],
            }
            : null,
        });
      },
      storage: {
        from: () => ({
          upload: async (
            path: string,
            stream: ReadableStream<Uint8Array>,
            options: unknown,
          ) => {
            uploads.push({
              path,
              bytes: new Uint8Array(await new Response(stream).arrayBuffer()),
              options,
            });
            return { error: null };
          },
        }),
      },
    })) as unknown as FormOperationsDependencies["createClient"],
  };
  const response = await handleFormOperationsRequest(request(), dependencies);
  assertEquals(response.status, 200);
  assertEquals(uploads.length, 1);
  const workbook = XLSX.read(uploads[0].bytes, { type: "array" });
  assertEquals(workbook.SheetNames.length, 1);
  const rows = XLSX.utils.sheet_to_json(
    workbook.Sheets[workbook.SheetNames[0]],
  );
  assertEquals(rows.length, 1);
  assertEquals(
    Object.values(rows[0] as Record<string, unknown>).includes(
      "Resposta sintética",
    ),
    true,
  );
  assertEquals(uploads[0].options, {
    contentType:
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    upsert: false,
    cacheControl: "no-store",
  });
  const completed = calls.find((call) =>
    call.name === "form_worker_complete_export"
  );
  assertEquals(completed?.params.p_file_job_id, id);
  assertEquals(completed?.params.p_artifact_path, uploads[0].path);
  assertEquals(
    completed?.params.p_artifact_byte_length,
    uploads[0].bytes.length,
  );
  assertEquals(completed?.params.p_manifest, { row_count: 1, media_count: 0 });
});
