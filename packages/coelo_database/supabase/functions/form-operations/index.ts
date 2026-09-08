import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { R2Client, type R2Config, validateR2Config } from "../_shared/r2_s3.ts";
import {
  authorizedOperationsRequest,
  operationsBearerToken,
} from "./auth_contract.ts";
import {
  opaqueArtifactPath,
  streamXlsx,
  streamXlsxWorkbook,
} from "./export_contract.ts";
import {
  MultipartS3Client,
  multipartS3Config,
  sha256Hex,
} from "./multipart_s3.ts";
import {
  type ArtifactDigest,
  multipartArtifactConfig,
  type MultipartAttemptScope,
  type MultipartPersistenceAdapter,
  type MultipartSnapshot,
  uploadAdaptiveArtifact,
  validateMultipartSnapshot,
} from "./multipart_export.ts";
import {
  createSnapshotRows,
  createVersionedXlsxSheets,
  parseXlsxSnapshotSchema,
  parseXlsxSubmission,
  type SnapshotPageLoader,
  type XlsxSnapshotSubmission,
} from "./snapshot_paging.ts";
import { cleanupExpiredItems } from "./cleanup_contract.ts";
import {
  OPERATIONAL_JOB_KINDS,
  operationForJob,
} from "./operational_contract.ts";

const BUCKET = "coelo-forms-private";
const PAGE_SIZE = 250;
const MAX_ROWS_PER_LEASE = 50_000;
// Diagnostics do not prove absence of provider side effects or authorize cleanup.
const R2_SCHEMA_ERRORS = new Set([
  "zero_respostas_aberto",
  "export_snapshot_invalid",
  "xlsx_snapshot_changed",
  "export_lease_row_limit",
  "xlsx_column_limit",
  "xlsx_row_limit",
  "xlsx_number_unrepresentable",
  "xlsx_currency_unrepresentable",
  "invalid_xlsx_civil_date",
  "xlsx_civil_date_out_of_range",
  "invalid_xlsx_media_origin",
  "invalid_xlsx_media_asset",
  "invalid_xlsx_media_link",
]);
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
  now?: () => Date;
  createR2?: (config: R2Config) => Pick<R2Client, "put">;
  createMultipart?: (
    config: R2Config,
  ) => Pick<
    MultipartS3Client,
    "initiate" | "uploadPart" | "complete" | "abort"
  >;
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

const XLSX_MIME =
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
const R2_EXPORT_BUCKET = "coelo-transient-prod";
const uuid = (value: unknown): value is string =>
  typeof value === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
    .test(value);
const jsonObject = (value: unknown): value is Json =>
  !!value && typeof value === "object" && !Array.isArray(value);
const checksum = (value: unknown): value is string =>
  typeof value === "string" && /^[0-9a-f]{64}$/.test(value);

async function writeR2Xlsx(
  client: SupabaseClient,
  job: Json,
  workerId: string,
  environment: Record<string, string | undefined>,
  dependencies: FormOperationsDependencies,
): Promise<void> {
  const now = dependencies.now ?? (() => new Date());
  if (
    !uuid(job.id) || !uuid(job.aggregate_id) ||
    !Number.isSafeInteger(job.attempts) || Number(job.attempts) < 1
  ) {
    throw new Error("export_begin_invalid");
  }
  const params = Object.freeze({
    p_job_id: job.id,
    p_worker_id: workerId,
    p_file_job_id: job.aggregate_id,
  });
  const rpc = async (name: string, values: Json): Promise<unknown> => {
    const result = await client.rpc(name, values);
    if (result.error) throw new Error("r2_export_rpc_failed");
    return result.data;
  };
  const begun = await rpc("form_worker_begin_xlsx_r2_v1", params);
  if (
    !jsonObject(begun) || begun.job_id !== job.aggregate_id ||
    begun.worker_job_id !== job.id ||
    begun.attempt !== job.attempts || !uuid(begun.asset_id) ||
    !uuid(begun.form_id) ||
    !uuid(begun.institution_id) ||
    begun.provider !== "r2" || begun.bucket !== R2_EXPORT_BUCKET ||
    begun.mime_type !== XLSX_MIME ||
    begun.object_key !==
      `tenants/${begun.institution_id}/exports/forms/${job.aggregate_id}/${begun.asset_id}/responses.xlsx` ||
    begun.snapshot_format_version !== 2 ||
    typeof begun.snapshot_schema_sha256 !== "string" ||
    !/^[0-9a-f]{64}$/.test(begun.snapshot_schema_sha256) ||
    !Number.isSafeInteger(begun.snapshot_row_count) ||
    Number(begun.snapshot_row_count) < 0 ||
    typeof begun.expires_at !== "string" ||
    !Number.isFinite(Date.parse(begun.expires_at)) ||
    Date.parse(begun.expires_at) <= now().getTime()
  ) throw new Error("export_begin_invalid");
  const schema = parseXlsxSnapshotSchema(begun.snapshot_schema, begun.form_id);
  if (!schema.versions.length || begun.snapshot_row_count === 0) {
    throw new Error("zero_respostas_aberto");
  }
  const schemaHash = begun.snapshot_schema_sha256;
  const prepared = Object.freeze({ ...begun });
  const scope: MultipartAttemptScope = Object.freeze({
    jobId: job.id,
    workerId,
    fileJobId: job.aggregate_id,
    attempt: job.attempts as number,
    assetId: begun.asset_id,
    bucket: R2_EXPORT_BUCKET,
    objectPath: begun.object_key as string,
    snapshotFormatVersion: 2,
    snapshotRowCount: begun.snapshot_row_count as number,
  });
  const wireScope = Object.freeze({
    worker_job_id: scope.jobId,
    worker_id: scope.workerId,
    file_job_id: scope.fileJobId,
    attempt: scope.attempt,
    asset_id: scope.assetId,
    bucket: scope.bucket,
    object_key: scope.objectPath,
    snapshot_format_version: scope.snapshotFormatVersion,
    snapshot_row_count: scope.snapshotRowCount,
  });
  const sameWireScope = (value: unknown) =>
    jsonObject(value) &&
    Object.keys(value).length === Object.keys(wireScope).length &&
    Object.entries(wireScope).every(([key, field]) => value[key] === field);
  const artifactConfig = multipartArtifactConfig(environment);
  const fresh = () => {
    if (Date.parse(prepared.expires_at as string) <= now().getTime()) {
      throw new Error("export_expired");
    }
  };
  const multipartRpc = async (operation: string, payload: Json = {}) => {
    if (operation !== "reconcile") fresh();
    const result = await rpc("form_worker_multipart_xlsx_r2_v1", {
      p_scope: wireScope,
      p_operation: operation,
      p_payload: payload,
    });
    if (operation !== "reconcile") fresh();
    return result;
  };
  const multipartSnapshot = (
    value: unknown,
    uploadId?: string,
  ): MultipartSnapshot | null => {
    if (value === null) return null;
    if (
      !jsonObject(value) || !sameWireScope(value.scope) ||
      (uploadId !== undefined && value.upload_id !== uploadId)
    ) throw new Error("export_multipart_receipt_invalid");
    return validateMultipartSnapshot(
      {
        ...value,
        scope,
        ...(value.checksum_sha256 == null
          ? { checksum_sha256: undefined }
          : {}),
      },
      { bucket: scope.bucket, partSizeBytes: artifactConfig.partSizeBytes },
      scope,
    );
  };
  const persistence: MultipartPersistenceAdapter = {
    scope,
    authorize: async () => {
      const result = await multipartRpc("authorize");
      if (
        !jsonObject(result) || result.authorized !== true ||
        !sameWireScope(result.scope)
      ) throw new Error("export_authorization_invalid");
    },
    snapshot: async () => multipartSnapshot(await multipartRpc("snapshot")),
    begin: async (_scope, uploadId) => {
      const result = multipartSnapshot(
        await multipartRpc("begin", { upload_id: uploadId }),
        uploadId,
      );
      if (
        !result || result.state !== "initiated" || result.parts.length !== 0 ||
        result.next_part_number !== 1 || result.uploaded_bytes !== 0
      ) throw new Error("export_multipart_receipt_invalid");
    },
    recordPart: async (_scope, uploadId, part) => {
      const result = multipartSnapshot(
        await multipartRpc("record_part", { upload_id: uploadId, ...part }),
        uploadId,
      );
      const saved = result?.parts.at(-1);
      if (
        !result || result.state !== "uploading" ||
        result.next_part_number !== part.part_number + 1 ||
        !saved ||
        Object.entries(part).some(([key, value]) =>
          (saved as unknown as Json)[key] !== value
        )
      ) throw new Error("export_multipart_receipt_invalid");
    },
    complete: async (_scope, uploadId, digest) => {
      const result = multipartSnapshot(
        await multipartRpc("complete", {
          upload_id: uploadId,
          byte_length: digest.byteLength,
          checksum_sha256: digest.checksumSha256,
        }),
        uploadId,
      );
      if (
        !result || result.state !== "completed" ||
        result.uploaded_bytes !== digest.byteLength ||
        result.checksum_sha256 !== digest.checksumSha256
      ) throw new Error("export_multipart_receipt_invalid");
    },
    reconcile: async (_scope, uploadId, digest) =>
      multipartSnapshot(
        await multipartRpc("reconcile", {
          upload_id: uploadId,
          byte_length: digest.byteLength,
          checksum_sha256: digest.checksumSha256,
        }),
        uploadId,
      ),
  };
  const pageDigests = new Map<string, string>();
  const submissionsFactory = async function* (): AsyncIterable<
    XlsxSnapshotSubmission
  > {
    const seen = new Set<string>();
    const seenVersions = new Set<string>();
    let cursor: string | null = null;
    do {
      fresh();
      const after: number = cursor === null ? 0 : Number(cursor);
      if (!Number.isSafeInteger(after) || after < 0) {
        throw new Error("export_snapshot_invalid");
      }
      const value: unknown = structuredClone(
        await rpc("form_worker_xlsx_snapshot_r2_v1", {
          ...params,
          p_asset_id: scope.assetId,
          p_after_sequence: after,
          p_limit: PAGE_SIZE,
        }),
      );
      fresh();
      if (
        !jsonObject(value) || value.kind !== "xlsx" ||
        value.snapshot_format_version !== scope.snapshotFormatVersion ||
        value.snapshot_schema_sha256 !== schemaHash ||
        !Array.isArray(value.submissions) ||
        value.submissions.length > PAGE_SIZE
      ) throw new Error("export_snapshot_invalid");
      const next = after + value.submissions.length;
      if (
        next > scope.snapshotRowCount ||
        value.has_more !== (next < scope.snapshotRowCount) ||
        value.next_cursor !==
          (value.submissions.length ? String(next) : null) ||
        (value.has_more && value.submissions.length === 0)
      ) throw new Error("export_snapshot_invalid");
      const submissions = value.submissions.map((submission) =>
        parseXlsxSubmission(submission, schema)
      );
      for (const submission of submissions) {
        if (seen.has(submission.responseId)) {
          throw new Error("export_snapshot_invalid");
        }
        seen.add(submission.responseId);
        seenVersions.add(submission.versionId);
      }
      const digest = await sha256Hex(JSON.stringify(value));
      const previous = pageDigests.get(String(after));
      if (previous !== undefined && previous !== digest) {
        throw new Error("xlsx_snapshot_changed");
      }
      pageDigests.set(String(after), digest);
      for (const submission of submissions) yield submission;
      cursor = value.has_more ? String(next) : null;
    } while (cursor !== null);
    if (
      schema.versions.some((version) => !seenVersions.has(version.versionId))
    ) throw new Error("export_snapshot_invalid");
  };
  const config = validateR2Config({
    endpoint: environment.COELO_R2_ENDPOINT ?? "",
    region: environment.COELO_R2_REGION ?? "auto",
    accessKeyId: environment.COELO_R2_ACCESS_KEY_ID ?? "",
    secretAccessKey: environment.COELO_R2_SECRET_ACCESS_KEY ?? "",
    bucket: scope.bucket,
  });
  const r2 = dependencies.createR2?.(config) ?? new R2Client(config);
  const multipart = dependencies.createMultipart?.(config) ??
    new MultipartS3Client(config);
  const artifact = await uploadAdaptiveArtifact({
    ...scope,
    proposedPath: scope.objectPath,
    contentType: XLSX_MIME,
    source: streamXlsxWorkbook(
      createVersionedXlsxSheets(
        schema,
        submissionsFactory,
        environment.COELO_FORMS_WEB_ORIGIN,
        { maxRows: MAX_ROWS_PER_LEASE },
      ),
    ),
    ...artifactConfig,
    persistence,
    rpc: () => Promise.reject(new Error("legacy_multipart_not_allowed")),
    standardUpload: (path, bytes, mime) => r2.put(path, bytes, mime),
    s3: multipart,
  });
  if (
    !checksum(artifact.checksumSha256) ||
    artifact.artifactPath !== scope.objectPath || artifact.byteLength < 1
  ) throw new Error("export_measurement_invalid");
  const digest: ArtifactDigest = {
    byteLength: artifact.byteLength,
    checksumSha256: artifact.checksumSha256,
  };
  const validReceipt = (value: unknown, state: string) =>
    jsonObject(value) && value.state === state &&
    value.job_id === scope.fileJobId && value.asset_id === scope.assetId &&
    value.byte_length === digest.byteLength &&
    value.checksum_sha256 === digest.checksumSha256;
  try {
    fresh();
    const result = await rpc("form_worker_complete_xlsx_r2_v1", {
      ...params,
      p_asset_id: scope.assetId,
      p_actual_byte_length: digest.byteLength,
      p_actual_checksum_sha256: digest.checksumSha256,
    });
    if (
      !validReceipt(result, "succeeded") ||
      (result as Json).expires_at !== prepared.expires_at
    ) throw new Error("export_completion_unknown");
  } catch {
    const result = await rpc("form_worker_reconcile_xlsx_r2_v1", {
      p_job_id: scope.jobId,
      p_file_job_id: scope.fileJobId,
      p_asset_id: scope.assetId,
    });
    if (!validReceipt(result, "committed")) {
      throw new Error("export_completion_unknown");
    }
  }
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
      "export_xlsx_r2_v1",
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
  let completionAttempted = false;
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
    if (job.job_kind === "export_xlsx_r2_v1") {
      await writeR2Xlsx(client, job, workerId, environment, dependencies);
      return reply(200, { processed: true, job_id: job.id });
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
    completionAttempted = true;
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
    if (job.job_kind === "export_xlsx_r2_v1") {
      // R2 failures retain the lease and attempt for reconciliation. The legacy
      // failure RPC and Storage deletion cannot operate on the R2 catalog.
      return reply(503, {
        error: error instanceof Error && R2_SCHEMA_ERRORS.has(error.message)
          ? error.message
          : "export_completion_unknown",
      });
    }
    if (completionAttempted) {
      // A dropped response or SDK error does not prove SQL rollback. Preserve
      // the artifact and persisted state until a nominal reconciliation; the
      // worker must not delete a file that may already be the committed winner.
      return reply(503, { error: "export_completion_unknown" });
    }
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
