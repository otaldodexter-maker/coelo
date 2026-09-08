import { assertEquals } from "@std/assert";
import * as XLSX from "xlsx";
import { sha256Hex } from "./multipart_s3.ts";
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
      ["export_xlsx", "export_xlsx_r2_v1"],
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

Deno.test("ambiguous export completion preserves uploaded artifact and persisted job", async () => {
  for (const completion of ["error", "throw"]) {
    const mutations: string[] = [];
    const dependencies: FormOperationsDependencies = {
      environment: () => environment,
      createClient: (() => ({
        rpc: (name: string) => {
          if (name === "form_worker_complete_export") {
            mutations.push("complete_attempt");
            // The database may already have committed. Neither an SDK error
            // nor a dropped response proves rollback of its transaction.
            if (completion === "throw") throw new Error(sensitiveError);
            return Promise.resolve({
              error: { message: sensitiveError },
              data: null,
            });
          }
          if (name === "form_worker_fail_export") mutations.push("mark_failed");
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
                    question: "Answer",
                    values: ["Synthetic"],
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
              _path: string,
              stream: ReadableStream<Uint8Array>,
            ) => {
              await new Response(stream).arrayBuffer();
              mutations.push("uploaded");
              return { error: null };
            },
            remove: () => {
              mutations.push("deleted");
              return Promise.resolve({ error: null });
            },
          }),
        },
      })) as unknown as FormOperationsDependencies["createClient"],
    };
    const response = await handleFormOperationsRequest(request(), dependencies);
    assertEquals(mutations, ["uploaded", "complete_attempt"]);
    assertEquals(response.status, 503);
    assertEquals(await response.json(), { error: "export_completion_unknown" });
  }
});

const fileId = "22222222-2222-4222-8222-222222222222";
const assetId = "33333333-3333-4333-8333-333333333333";
const institutionId = "44444444-4444-4444-8444-444444444444";
const objectKey =
  `tenants/${institutionId}/exports/forms/${fileId}/${assetId}/responses.xlsx`;
const xlsxMime =
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
type RpcCall = { name: string; params: Record<string, unknown> };

function r2WriterFixture() {
  const calls: RpcCall[] = [];
  const uploaded: Uint8Array[] = [];
  const prepared = {
    job_id: fileId,
    worker_job_id: id,
    attempt: 3,
    asset_id: assetId,
    institution_id: institutionId,
    provider: "r2",
    bucket: "coelo-transient-prod",
    object_key: objectKey,
    mime_type: xlsxMime,
    expires_at: "2026-09-09T20:00:00Z",
    snapshot_format_version: 1,
    snapshot_row_count: 1,
  };
  const page = {
    kind: "xlsx",
    snapshot_format_version: 1,
    has_more: false,
    next_cursor: "1",
    submissions: [{
      responseId: id,
      occurrenceId: id,
      versionId: id,
      metadata: { identity_mode: "anonymous", respondent: "" },
      answers: [{
        itemId: id,
        question: "Synthetic",
        values: ["=synthetic"],
        multiValued: false,
      }],
    }],
  };
  let completeError = false;
  let reconcileState = "pending";
  let completeReceipt: Record<string, unknown> | null = null;
  let transform = (_call: RpcCall, data: unknown): unknown => data;
  const dependencies: FormOperationsDependencies = {
    environment: () => ({
      ...environment,
      COELO_R2_ENDPOINT: "https://synthetic.r2.cloudflarestorage.com",
      COELO_R2_REGION: "auto",
      COELO_R2_ACCESS_KEY_ID: "synthetic-r2-key",
      COELO_R2_SECRET_ACCESS_KEY: "synthetic-r2-secret",
    }),
    now: () => new Date("2026-09-08T20:00:00Z"),
    createR2: (config) => ({
      put: (key, bytes, mime) => {
        assertEquals(config.bucket, "coelo-transient-prod");
        assertEquals(key, objectKey);
        assertEquals(mime, xlsxMime);
        uploaded.push(bytes.slice());
        return Promise.resolve();
      },
    }),
    createMultipart: () => ({
      initiate: () => Promise.reject(new Error("unexpected_multipart")),
      uploadPart: () => Promise.reject(new Error("unexpected_multipart")),
      complete: () => Promise.reject(new Error("unexpected_multipart")),
      abort: () => Promise.reject(new Error("must_never_abort")),
    }),
    createClient: (() => ({
      rpc: (name: string, params: Record<string, unknown>) => {
        calls.push({ name, params });
        let data: unknown = null;
        if (name === "form_worker_claim") {
          data = {
            id,
            aggregate_id: fileId,
            job_kind: "export_xlsx_r2_v1",
            attempts: 3,
          };
        }
        if (name === "form_worker_begin_xlsx_r2_v1") data = prepared;
        if (name === "form_worker_xlsx_snapshot_r2_v1") data = page;
        if (name === "form_worker_multipart_xlsx_r2_v1") {
          if (params.p_operation === "authorize") {
            data = { authorized: true, scope: params.p_scope };
          }
        }
        if (name === "form_worker_complete_xlsx_r2_v1") {
          completeReceipt = {
            job_id: fileId,
            asset_id: assetId,
            state: "succeeded",
            byte_length: params.p_actual_byte_length,
            checksum_sha256: params.p_actual_checksum_sha256,
            expires_at: prepared.expires_at,
          };
          if (completeError) throw new Error(sensitiveError);
          data = completeReceipt;
        }
        if (name === "form_worker_reconcile_xlsx_r2_v1") {
          data = { ...completeReceipt, state: reconcileState };
        }
        return Promise.resolve({
          error: null,
          data: transform({ name, params }, data),
        });
      },
      storage: {
        from: () => {
          throw new Error("must_not_use_storage");
        },
      },
    })) as unknown as FormOperationsDependencies["createClient"],
  };
  return {
    calls,
    uploaded,
    prepared,
    page,
    dependencies,
    transform: (value: typeof transform) => {
      transform = value;
    },
    completion: (state: string) => {
      completeError = true;
      reconcileState = state;
    },
  };
}

Deno.test("R2 XLSX writer uploads a valid private workbook and persists measured SHA256", async () => {
  const { dependencies, uploaded, calls } = r2WriterFixture();
  const response = await handleFormOperationsRequest(request(), dependencies);
  assertEquals(response.status, 200);
  assertEquals(uploaded.length, 1);
  const workbook = XLSX.read(uploaded[0], { type: "array" });
  assertEquals(workbook.SheetNames, ["Respostas"]);
  assertEquals(XLSX.utils.sheet_to_json(workbook.Sheets.Respostas).length, 1);
  const completed = calls.find((call) =>
    call.name === "form_worker_complete_xlsx_r2_v1"
  );
  assertEquals(completed?.params.p_actual_byte_length, uploaded[0].length);
  assertEquals(
    completed?.params.p_actual_checksum_sha256,
    await sha256Hex(uploaded[0]),
  );
  assertEquals(
    calls.some((call) => call.name === "form_worker_fail_export"),
    false,
  );
});

Deno.test("R2 writer reconciles an ambiguous asset completion without legacy failure", async () => {
  for (const state of ["committed", "pending"]) {
    const { dependencies, calls, completion } = r2WriterFixture();
    completion(state);
    const response = await handleFormOperationsRequest(request(), dependencies);
    assertEquals(response.status, state === "committed" ? 200 : 503);
    assertEquals(calls.at(-1)?.name, "form_worker_reconcile_xlsx_r2_v1");
    assertEquals(
      calls.some((call) => call.name === "form_worker_fail_export"),
      false,
    );
  }
});

Deno.test("R2 writer rejects a mismatched prepared asset path without legacy failure", async () => {
  const { dependencies, prepared, calls, uploaded } = r2WriterFixture();
  prepared.object_key = "other/asset.xlsx";
  const response = await handleFormOperationsRequest(request(), dependencies);
  assertEquals(response.status, 503);
  assertEquals(uploaded, []);
  assertEquals(
    calls.some((call) => call.name === "form_worker_fail_export"),
    false,
  );
});

Deno.test("R2 writer rejects every crossed begin field and expired preparation", async () => {
  for (
    const delta of [
      { job_id: id },
      { worker_job_id: fileId },
      { attempt: 2 },
      { asset_id: id },
      { institution_id: id },
      { provider: "storage" },
      { bucket: "public" },
      { mime_type: "application/zip" },
      { snapshot_format_version: 2 },
      { snapshot_row_count: -1 },
      { expires_at: "2020-01-01T00:00:00Z" },
    ]
  ) {
    const fixture = r2WriterFixture();
    fixture.transform((call, data) =>
      call.name === "form_worker_begin_xlsx_r2_v1"
        ? { ...(data as object), ...delta }
        : data
    );
    assertEquals(
      (await handleFormOperationsRequest(request(), fixture.dependencies))
        .status,
      503,
    );
    assertEquals(fixture.uploaded, []);
    assertEquals(
      fixture.calls.some((call) => call.name.includes("fail")),
      false,
    );
  }
});

Deno.test("R2 writer rejects wrong snapshot format, cursor, count and malformed data before upload", async () => {
  for (
    const delta of [
      { kind: "csv" },
      { snapshot_format_version: 2 },
      { next_cursor: "2" },
      { has_more: true },
      { submissions: [] },
      { submissions: [{ responseId: "invalid" }] },
    ]
  ) {
    const fixture = r2WriterFixture();
    fixture.transform((call, data) =>
      call.name === "form_worker_xlsx_snapshot_r2_v1"
        ? { ...(data as object), ...delta }
        : data
    );
    assertEquals(
      (await handleFormOperationsRequest(request(), fixture.dependencies))
        .status,
      503,
    );
    assertEquals(fixture.uploaded, []);
    assertEquals(
      fixture.calls.some((call) =>
        call.name === "form_worker_complete_xlsx_r2_v1"
      ),
      false,
    );
  }
});

Deno.test("R2 writer refuses authorization denial or another scope before provider writes", async () => {
  for (const denied of [true, false]) {
    const fixture = r2WriterFixture();
    fixture.transform((call, data) => {
      if (call.params.p_operation !== "authorize") return data;
      return {
        authorized: !denied,
        scope: denied
          ? call.params.p_scope
          : { ...(call.params.p_scope as object), attempt: 1 },
      };
    });
    assertEquals(
      (await handleFormOperationsRequest(request(), fixture.dependencies))
        .status,
      503,
    );
    assertEquals(fixture.uploaded, []);
  }
});

Deno.test("R2 writer rejects a changing sealed page across XLSX passes", async () => {
  const fixture = r2WriterFixture();
  let pages = 0;
  fixture.transform((call, data) => {
    if (call.name !== "form_worker_xlsx_snapshot_r2_v1" || ++pages < 2) {
      return data;
    }
    return {
      ...fixture.page,
      submissions: fixture.page.submissions.map((submission) => ({
        ...submission,
        metadata: { ...submission.metadata, respondent: "changed" },
      })),
    };
  });
  assertEquals(
    (await handleFormOperationsRequest(request(), fixture.dependencies)).status,
    503,
  );
  assertEquals(fixture.uploaded, []);
});

Deno.test("R2 writer rejects mismatched asset completion and reconciliation digests", async () => {
  for (
    const delta of [{ job_id: id }, { asset_id: id }, { byte_length: 1 }, {
      checksum_sha256: "0".repeat(64),
    }]
  ) {
    const fixture = r2WriterFixture();
    fixture.completion("committed");
    fixture.transform((call, data) =>
      call.name === "form_worker_reconcile_xlsx_r2_v1"
        ? { ...(data as object), ...delta }
        : data
    );
    assertEquals(
      (await handleFormOperationsRequest(request(), fixture.dependencies))
        .status,
      503,
    );
    assertEquals(fixture.uploaded.length, 1);
    assertEquals(
      fixture.calls.some((call) => call.name.includes("fail")),
      false,
    );
  }
});

Deno.test("R2 writer reconciles malformed successful completion receipts instead of acknowledging them", async () => {
  for (
    const delta of [{ asset_id: id }, { byte_length: 1 }, {
      checksum_sha256: "0".repeat(64),
    }, { expires_at: "invalid" }]
  ) {
    const fixture = r2WriterFixture();
    fixture.transform((call, data) =>
      call.name === "form_worker_complete_xlsx_r2_v1"
        ? { ...(data as object), ...delta }
        : data
    );
    assertEquals(
      (await handleFormOperationsRequest(request(), fixture.dependencies))
        .status,
      503,
    );
    assertEquals(
      fixture.calls.at(-1)?.name,
      "form_worker_reconcile_xlsx_r2_v1",
    );
    assertEquals(fixture.uploaded.length, 1);
  }
});

Deno.test("R2 writer preserves uncertain PUT and lease revocation without deleting or failing legacy jobs", async () => {
  for (const failure of ["put", "revoked_after_put"]) {
    const fixture = r2WriterFixture();
    let uploaded = false;
    fixture.transform((call, data) => {
      if (uploaded && call.params.p_operation === "authorize") {
        throw new Error(sensitiveError);
      }
      return data;
    });
    const response = await handleFormOperationsRequest(request(), {
      ...fixture.dependencies,
      createR2: () => ({
        put: () => {
          uploaded = true;
          if (failure === "put") {
            return Promise.reject(new Error(sensitiveError));
          }
          return Promise.resolve();
        },
      }),
    });
    assertEquals(response.status, 503);
    assertEquals(
      fixture.calls.some((call) => call.name.includes("fail")),
      false,
    );
    assertEquals(
      fixture.calls.some((call) =>
        call.name === "form_worker_complete_xlsx_r2_v1"
      ),
      false,
    );
    assertEquals(await response.json(), { error: "export_completion_unknown" });
  }
});

Deno.test("R2 writer validates shared config before constructing a provider", async () => {
  const fixture = r2WriterFixture();
  let constructed = false;
  const response = await handleFormOperationsRequest(request(), {
    ...fixture.dependencies,
    environment: () => ({
      ...fixture.dependencies.environment(),
      COELO_R2_ENDPOINT: "http://unsafe.test",
    }),
    createR2: () => {
      constructed = true;
      throw new Error("must_not_construct");
    },
  });
  assertEquals(response.status, 503);
  assertEquals(constructed, false);
});

Deno.test("R2 writer reads sealed numeric pages with exact total across every XLSX pass", async () => {
  const fixture = r2WriterFixture();
  fixture.prepared.snapshot_row_count = 251;
  const submissions = Array.from(
    { length: 251 },
    (_, index) => ({
      ...fixture.page.submissions[0],
      responseId: `55555555-5555-4555-8555-${String(index).padStart(12, "0")}`,
    }),
  );
  fixture.transform((call, data) => {
    if (call.name !== "form_worker_xlsx_snapshot_r2_v1") return data;
    assertEquals(call.params.p_asset_id, assetId);
    assertEquals(call.params.p_file_job_id, fileId);
    const after = call.params.p_after_sequence as number;
    assertEquals([0, 250].includes(after), true);
    return {
      ...fixture.page,
      submissions: submissions.slice(after, after + 250),
      has_more: after === 0,
      next_cursor: after === 0 ? "250" : "251",
    };
  });
  const response = await handleFormOperationsRequest(
    request(),
    fixture.dependencies,
  );
  assertEquals(response.status, 200);
  const workbook = XLSX.read(fixture.uploaded[0], { type: "array" });
  assertEquals(XLSX.utils.sheet_to_json(workbook.Sheets.Respostas).length, 251);
});

Deno.test("R2 writer refuses duplicate response IDs and runtime page authorization failure", async () => {
  for (const failure of ["duplicate", "denied"]) {
    const fixture = r2WriterFixture();
    fixture.prepared.snapshot_row_count = 2;
    fixture.transform((call, data) => {
      if (call.name !== "form_worker_xlsx_snapshot_r2_v1") return data;
      if (failure === "denied") throw new Error(sensitiveError);
      return {
        ...fixture.page,
        next_cursor: "2",
        submissions: [fixture.page.submissions[0], fixture.page.submissions[0]],
      };
    });
    assertEquals(
      (await handleFormOperationsRequest(request(), fixture.dependencies))
        .status,
      503,
    );
    assertEquals(fixture.uploaded, []);
    assertEquals(
      fixture.calls.some((call) => call.name.includes("fail")),
      false,
    );
  }
});

Deno.test("R2 XLSX writer streams a real multipart workbook and records the whole digest", async () => {
  const fixture = r2WriterFixture();
  fixture.prepared.snapshot_row_count = 180;
  fixture.page.next_cursor = "180";
  fixture.page.submissions = Array.from({ length: 180 }, (_, index) => ({
    ...fixture.page.submissions[0],
    responseId: `55555555-5555-4555-8555-${String(index).padStart(12, "0")}`,
    answers: [{
      itemId: id,
      question: "Synthetic",
      values: ["x".repeat(30000)],
      multiValued: false,
    }],
  }));
  let snapshot: Record<string, unknown> | null = null;
  const parts: Array<Record<string, unknown>> = [];
  const providerEvents: string[] = [];
  fixture.transform((call, data) => {
    if (call.name !== "form_worker_multipart_xlsx_r2_v1") return data;
    const payload = call.params.p_payload as Record<string, unknown>;
    if (call.params.p_operation === "authorize") return data;
    if (call.params.p_operation === "begin") {
      snapshot = {
        scope: call.params.p_scope,
        bucket_id: "coelo-transient-prod",
        object_path: objectKey,
        upload_id: payload.upload_id,
        state: "initiated",
        uploaded_bytes: 0,
        next_part_number: 1,
        parts: [],
        checksum_sha256: null,
      };
    }
    if (call.params.p_operation === "record_part") {
      parts.push({
        part_number: payload.part_number,
        etag: payload.etag,
        byte_length: payload.byte_length,
        checksum_sha256: payload.checksum_sha256,
      });
      snapshot = {
        ...snapshot,
        state: "uploading",
        uploaded_bytes: parts.reduce(
          (sum, part) => sum + Number(part.byte_length),
          0,
        ),
        next_part_number: parts.length + 1,
        parts: [...parts],
      };
    }
    if (call.params.p_operation === "complete") {
      snapshot = {
        ...snapshot,
        state: "completed",
        checksum_sha256: payload.checksum_sha256,
      };
    }
    return snapshot;
  });
  const response = await handleFormOperationsRequest(request(), {
    ...fixture.dependencies,
    environment: () => ({
      ...fixture.dependencies.environment(),
      FORMS_ZIP_MULTIPART_THRESHOLD_BYTES: String(5 * 1024 * 1024),
      FORMS_ZIP_MULTIPART_PART_BYTES: String(5 * 1024 * 1024),
    }),
    createR2: () => ({
      put: () => Promise.reject(new Error("must_use_multipart")),
    }),
    createMultipart: (config) => ({
      initiate: (bucket, key) => {
        assertEquals(bucket, config.bucket);
        assertEquals(key, objectKey);
        providerEvents.push("begin");
        return Promise.resolve({ uploadId: "r2-upload" });
      },
      uploadPart: (_bucket, _key, _upload, partNumber, bytes) => {
        fixture.uploaded.push(bytes.slice());
        providerEvents.push("part");
        return Promise.resolve({ partNumber, etag: `"etag-${partNumber}"` });
      },
      complete: () => {
        providerEvents.push("complete");
        return Promise.resolve({ etag: '"complete"' });
      },
      abort: () => Promise.reject(new Error("must_never_abort")),
    }),
  });
  assertEquals(response.status, 200);
  assertEquals(providerEvents, ["begin", "part", "part", "complete"]);
  const bytes = new Uint8Array(
    fixture.uploaded.reduce((sum, part) => sum + part.length, 0),
  );
  let offset = 0;
  for (const part of fixture.uploaded) {
    bytes.set(part, offset);
    offset += part.length;
  }
  assertEquals([...bytes.slice(0, 4)], [80, 75, 3, 4]);
  const workbook = XLSX.read(bytes, { type: "array" });
  assertEquals(XLSX.utils.sheet_to_json(workbook.Sheets.Respostas).length, 180);
  const completed = fixture.calls.find((call) =>
    call.name === "form_worker_complete_xlsx_r2_v1"
  );
  assertEquals(completed?.params.p_actual_byte_length, bytes.length);
  assertEquals(
    completed?.params.p_actual_checksum_sha256,
    await sha256Hex(bytes),
  );
});
