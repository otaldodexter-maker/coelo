import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import {
  authorizedOperationsRequest,
  operationsBearerToken,
} from "./auth_contract.ts";
import { opaqueArtifactPath, streamXlsx } from "./export_contract.ts";
import { MultipartS3Client, multipartS3Config } from "./multipart_s3.ts";
import {
  createSnapshotRows,
  type SnapshotPageLoader,
} from "./snapshot_paging.ts";
import { cleanupExpiredItems } from "./cleanup_contract.ts";
import {
  OPERATIONAL_JOB_KINDS,
  operationForJob,
} from "./operational_contract.ts";

const BUCKET = "coelo-forms-private";
const PAGE_SIZE = 250;
const MAX_ROWS_PER_LEASE = 50_000;
const SAFE_JOB_ERRORS = new Set([
  "artifact_upload_failed",
  "cleanup_complete_failed",
  "cleanup_snapshot_failed",
  "cleanup_snapshot_invalid",
  "cleanup_storage_remove_failed",
  "empty_export",
  "export_begin_failed",
  "export_complete_failed",
  "export_cursor_missing",
  "export_cursor_repeated",
  "export_lease_row_limit",
  "export_page_empty",
  "export_snapshot_failed",
  "export_snapshot_invalid",
  "export_snapshot_kind_changed",
  "export_snapshot_kind_invalid",
  "finish_failed",
  "operational_job_failed",
  "unsupported_job_kind",
  "xlsx_column_limit",
  "xlsx_snapshot_changed",
  "zip64_not_supported",
]);

type Json = Record<string, unknown>;
type Snapshot = {
  kind: string;
  submissions?: import("./export_contract.ts").ExportSubmission[];
  rows?: import("./export_contract.ts").ExportRow[];
  media?: Array<{ asset_id: string; storage_path: string; mime_type: string }>;
  has_more: boolean;
  next_cursor?: string | null;
};
export type FormOperationsDependencies = Readonly<{
  environment: () => Record<string, string | undefined>;
  createClient: typeof createClient;
}>;
const productionDependencies: FormOperationsDependencies = {
  environment: () => Deno.env.toObject(),
  createClient,
};

function serviceKey(environment: Record<string, string | undefined>): string {
  const configured = environment.SUPABASE_SECRET_KEYS ?? "";
  if (configured.startsWith("{")) {
    try {
      const values = JSON.parse(configured) as Record<string, string>;
      if (values.default) return values.default;
    } catch {
      return "";
    }
  }
  return configured.split(",").map((value) => value.trim()).find(Boolean) ??
    environment.SUPABASE_SERVICE_ROLE_KEY ?? "";
}

function reply(status: number, body: Json): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
      "referrer-policy": "no-referrer",
    },
  });
}

function snapshotPageLoader(
  client: SupabaseClient,
  fileJobId: string,
): SnapshotPageLoader {
  return async (cursor) => {
    const result = await client.rpc("form_worker_export_snapshot", {
      p_file_job_id: fileJobId,
      p_after_id: cursor,
      p_limit: PAGE_SIZE,
    });
    if (result.error || !result.data) throw new Error("export_snapshot_failed");
    const snapshot = result.data as Snapshot;
    if (snapshot.kind !== "xlsx") {
      throw new Error("export_snapshot_kind_invalid");
    }
    return snapshot;
  };
}

function readableBytes(
  source: AsyncIterable<Uint8Array>,
  onBytes: (byteLength: number) => void,
): ReadableStream<Uint8Array> {
  const iterator = source[Symbol.asyncIterator]();
  return new ReadableStream({
    async pull(controller) {
      const next = await iterator.next();
      if (next.done) controller.close();
      else {
        onBytes(next.value.byteLength);
        controller.enqueue(next.value);
      }
    },
    async cancel() {
      await iterator.return?.();
    },
  });
}

function cleanupExpiredStorage(
  client: SupabaseClient,
  jobId: string,
  workerId: string,
  environment: Record<string, string | undefined>,
): Promise<number> {
  return cleanupExpiredItems({
    jobId,
    workerId,
    snapshot: async () => {
      const result = await client.rpc("form_worker_cleanup_snapshot", {
        p_job_id: jobId,
        p_worker_id: workerId,
        p_limit: 100,
      });
      if (result.error || !result.data) {
        throw new Error("cleanup_snapshot_failed");
      }
      return result.data;
    },
    abortMultipart: async (bucket, path, uploadId) => {
      const multipart = new MultipartS3Client(
        multipartS3Config(environment),
      );
      await multipart.abort(bucket, path, uploadId);
    },
    removeStorage: async (paths) => {
      const removed = await client.storage.from(BUCKET).remove(paths);
      if (removed.error) throw new Error("cleanup_storage_remove_failed");
    },
    complete: async (ids) => {
      const completed = await client.rpc("form_worker_complete_cleanup", {
        p_job_id: jobId,
        p_worker_id: workerId,
        p_item_ids: ids,
      });
      if (completed.error) throw new Error("cleanup_complete_failed");
    },
  });
}

export async function handleFormOperationsRequest(
  request: Request,
  dependencies: FormOperationsDependencies = productionDependencies,
): Promise<Response> {
  try {
    return await processFormOperationsRequest(request, dependencies);
  } catch {
    return reply(503, { error: "service_unavailable" });
  }
}

async function processFormOperationsRequest(
  request: Request,
  dependencies: FormOperationsDependencies,
): Promise<Response> {
  if (request.method !== "POST") {
    return reply(405, { error: "method_not_allowed" });
  }
  const environment = dependencies.environment();
  const url = environment.SUPABASE_URL ?? "";
  const key = serviceKey(environment);
  const authorization = request.headers.get("authorization") ?? "";
  let operationsToken = "";
  try {
    operationsToken = operationsBearerToken(environment);
  } catch {
    return reply(503, { error: "service_unavailable" });
  }
  if (
    !url || !key ||
    !authorizedOperationsRequest(authorization, operationsToken)
  ) {
    return reply(401, { error: "unauthorized" });
  }
  const client = dependencies.createClient(url, key, {
    auth: { persistSession: false },
  });
  const workerId = `form-operations-${crypto.randomUUID()}`;
  const claimed = await client.rpc("form_worker_claim", {
    p_worker_id: workerId,
    p_lease_seconds: 600,
    p_job_kinds: [
      ...OPERATIONAL_JOB_KINDS,
      "export_xlsx",
      "cleanup_uploads",
      "cleanup_artifacts",
    ],
  });
  if (claimed.error) return reply(500, { error: "claim_failed" });
  if (!claimed.data) return reply(200, { processed: false });
  const job = claimed.data as Json;
  const fileJobId = String(job.aggregate_id ?? "");
  const isExportJob = String(job.job_kind).startsWith("export_");
  const isCleanupJob = job.job_kind === "cleanup_uploads" ||
    job.job_kind === "cleanup_artifacts";
  let artifactPath: string | null = null;
  let standardArtifactUploaded = false;
  try {
    const operation = operationForJob(job.job_kind, job.aggregate_id);
    if (operation) {
      const completed = await client.rpc(operation.rpc, operation.params);
      if (completed.error) throw new Error("operational_job_failed");
      const finished = await client.rpc("form_worker_finish", {
        p_job_id: job.id,
        p_worker_id: workerId,
        p_progress: { completed: true },
      });
      if (finished.error) throw new Error("finish_failed");
      return reply(200, { processed: true, job_id: job.id });
    }
    if (isCleanupJob) {
      const itemCount = await cleanupExpiredStorage(
        client,
        String(job.id),
        workerId,
        environment,
      );
      return reply(200, { processed: true, job_id: job.id, items: itemCount });
    }
    if (job.job_kind !== "export_xlsx") {
      throw new Error("unsupported_job_kind");
    }
    const started = await client.rpc("form_worker_begin_export", {
      p_job_id: job.id,
      p_worker_id: workerId,
      p_file_job_id: fileJobId,
    });
    if (started.error) throw new Error("export_begin_failed");
    const loader = snapshotPageLoader(client, fileJobId);
    const rowsFactory = () =>
      createSnapshotRows(loader, { maxRows: MAX_ROWS_PER_LEASE });
    let streamedRowCount = 0;
    for await (const _row of rowsFactory()) streamedRowCount++;
    const contentType =
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    let artifactByteLength = 0;
    artifactPath = opaqueArtifactPath(crypto.randomUUID());
    const uploaded = await client.storage.from(BUCKET).upload(
      artifactPath,
      readableBytes(
        streamXlsx(rowsFactory),
        (byteLength) => artifactByteLength += byteLength,
      ),
      { contentType, upsert: false, cacheControl: "no-store" },
    );
    if (uploaded.error) throw new Error("artifact_upload_failed");
    standardArtifactUploaded = true;
    const completed = await client.rpc("form_worker_complete_export", {
      p_job_id: job.id,
      p_worker_id: workerId,
      p_file_job_id: fileJobId,
      p_artifact_path: artifactPath,
      p_artifact_byte_length: artifactByteLength!,
      p_manifest: {
        row_count: streamedRowCount,
        media_count: 0,
      },
    });
    if (completed.error) throw new Error("export_complete_failed");
    return reply(200, { processed: true, job_id: job.id });
  } catch (error) {
    if (artifactPath && standardArtifactUploaded) {
      await client.storage.from(BUCKET).remove([artifactPath]);
    }
    const errorCode =
      error instanceof Error && SAFE_JOB_ERRORS.has(error.message)
        ? error.message
        : "job_execution_failed";
    if (isExportJob) {
      await client.rpc("form_worker_fail_export", {
        p_job_id: job.id,
        p_worker_id: workerId,
        p_file_job_id: fileJobId,
        p_error_code: errorCode,
        p_retry_after_seconds: 60,
      });
    } else {
      await client.rpc("form_worker_fail", {
        p_job_id: job.id,
        p_worker_id: workerId,
        p_error_code: errorCode,
        p_retry_after_seconds: 60,
        p_progress: { completed: false },
      });
    }
    return reply(500, { error: "job_failed" });
  }
}

if (import.meta.main) {
  Deno.serve((request) => handleFormOperationsRequest(request));
}
