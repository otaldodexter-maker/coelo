import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import {
  authorizedOperationsRequest,
  operationsBearerToken,
} from "./auth_contract.ts";
import {
  opaqueArtifactPath,
  streamCsv,
  streamXlsx,
  streamZip,
  type ZipMediaSource,
} from "./export_contract.ts";
import {
  multipartArtifactConfig,
  uploadAdaptiveArtifact,
} from "./multipart_export.ts";
import { MultipartS3Client, multipartS3Config } from "./multipart_s3.ts";
import {
  createSnapshotMedia,
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

type Json = Record<string, unknown>;
type Snapshot = {
  kind: string;
  submissions?: import("./export_contract.ts").ExportSubmission[];
  rows?: import("./export_contract.ts").ExportRow[];
  media?: Array<{ asset_id: string; storage_path: string; mime_type: string }>;
  has_more: boolean;
  next_cursor?: string | null;
};
function serviceKey(): string {
  const configured = Deno.env.get("SUPABASE_SECRET_KEYS") ?? "";
  if (configured.startsWith("{")) {
    try {
      const values = JSON.parse(configured) as Record<string, string>;
      if (values.default) return values.default;
    } catch {
      return "";
    }
  }
  return configured.split(",").map((value) => value.trim()).find(Boolean) ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
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

function extensionForMime(mime: string): string {
  return mime === "image/png" ? "png" : mime === "image/webp" ? "webp" : "jpg";
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
    return result.data as Snapshot;
  };
}

async function* streamMedia(
  client: SupabaseClient,
  loader: SnapshotPageLoader,
): AsyncIterable<ZipMediaSource> {
  for await (const asset of createSnapshotMedia(loader)) {
    const result = await client.storage.from(BUCKET).download(
      asset.storage_path,
    );
    if (result.error) throw new Error("media_download_failed");
    yield {
      name: `${asset.asset_id}.${extensionForMime(asset.mime_type)}`,
      source: new Uint8Array(await result.data.arrayBuffer()),
    };
  }
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

async function cleanupExpiredStorage(
  client: SupabaseClient,
  jobId: string,
  workerId: string,
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
        multipartS3Config(Deno.env.toObject()),
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

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return reply(405, { error: "method_not_allowed" });
  }
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = serviceKey();
  const authorization = request.headers.get("authorization") ?? "";
  let operationsToken = "";
  try {
    operationsToken = operationsBearerToken(Deno.env.toObject());
  } catch {
    return reply(503, { error: "service_unavailable" });
  }
  if (
    !url || !key ||
    !authorizedOperationsRequest(authorization, operationsToken)
  ) {
    return reply(401, { error: "unauthorized" });
  }
  const client = createClient(url, key, { auth: { persistSession: false } });
  const workerId = `form-operations-${crypto.randomUUID()}`;
  const claimed = await client.rpc("form_worker_claim", {
    p_worker_id: workerId,
    p_lease_seconds: 600,
    p_job_kinds: [
      ...OPERATIONAL_JOB_KINDS,
      "export_csv",
      "export_xlsx",
      "export_zip",
      "export_anonymous_participation",
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
      );
      return reply(200, { processed: true, job_id: job.id, items: itemCount });
    }
    if (!isExportJob) {
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
    let streamedMediaCount = 0;
    let contentType: string;
    let artifactByteLength = 0;
    if (
      job.job_kind === "export_csv" ||
      job.job_kind === "export_anonymous_participation"
    ) {
      contentType = "text/csv; charset=utf-8";
    } else if (job.job_kind === "export_xlsx") {
      contentType =
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    } else {
      contentType = "application/zip";
      for await (const _asset of createSnapshotMedia(loader)) {
        streamedMediaCount++;
      }
      const artifactId = crypto.randomUUID();
      artifactPath = opaqueArtifactPath(artifactId);
      const adaptiveConfig = multipartArtifactConfig(Deno.env.toObject());
      const multipartClient = new MultipartS3Client(
        multipartS3Config(Deno.env.toObject()),
      );
      const adaptive = await uploadAdaptiveArtifact({
        jobId: String(job.id),
        workerId,
        fileJobId,
        bucket: BUCKET,
        proposedPath: artifactPath,
        contentType,
        source: streamZip({
          workbook: streamXlsx(rowsFactory),
          manifest: {
            generated_at: String(job.created_at),
            response_row_count: streamedRowCount,
            media_count: streamedMediaCount,
          },
          media: streamMedia(client, loader),
        }),
        ...adaptiveConfig,
        rpc: async (call) => {
          const result = await client.rpc(call.name, call.params);
          if (result.error) throw new Error(`${call.name}_failed`);
          return result.data;
        },
        standardUpload: async (path, uploadBytes, uploadContentType) => {
          const result = await client.storage.from(BUCKET).upload(
            path,
            uploadBytes,
            {
              contentType: uploadContentType,
              upsert: false,
              cacheControl: "no-store",
            },
          );
          if (result.error) throw new Error("artifact_upload_failed");
          standardArtifactUploaded = true;
        },
        s3: multipartClient,
      });
      artifactPath = adaptive.artifactPath;
      artifactByteLength = adaptive.byteLength;
    }
    if (job.job_kind !== "export_zip") {
      const artifactId = crypto.randomUUID();
      artifactPath = opaqueArtifactPath(artifactId);
      const source = job.job_kind === "export_xlsx"
        ? streamXlsx(rowsFactory)
        : streamCsv(rowsFactory);
      const uploaded = await client.storage.from(BUCKET).upload(
        artifactPath,
        readableBytes(source, (byteLength) => artifactByteLength += byteLength),
        {
          contentType,
          upsert: false,
          cacheControl: "no-store",
        },
      );
      if (uploaded.error) throw new Error("artifact_upload_failed");
      standardArtifactUploaded = true;
    }
    const completed = await client.rpc("form_worker_complete_export", {
      p_job_id: job.id,
      p_worker_id: workerId,
      p_file_job_id: fileJobId,
      p_artifact_path: artifactPath,
      p_artifact_byte_length: artifactByteLength!,
      p_manifest: {
        row_count: streamedRowCount,
        media_count: streamedMediaCount,
      },
    });
    if (completed.error) throw new Error("export_complete_failed");
    return reply(200, { processed: true, job_id: job.id });
  } catch (error) {
    if (artifactPath && standardArtifactUploaded) {
      await client.storage.from(BUCKET).remove([artifactPath]);
    }
    const errorCode = error instanceof Error ? error.message : "unknown";
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
});
