import { type MultipartPart, sha256Hex } from "./multipart_s3.ts";
import { createHash } from "node:crypto";

export type MultipartPersistenceCall = Readonly<{
  name: string;
  params: Record<string, unknown>;
}>;

export type PersistedPart = Readonly<{
  part_number: number;
  etag: string;
  byte_length: number;
  checksum_sha256: string;
}>;

export type MultipartSnapshot = Readonly<{
  bucket_id: string;
  object_path: string;
  upload_id: string;
  state: "initiated" | "uploading" | "completed";
  next_part_number: number;
  uploaded_bytes: number;
  parts: PersistedPart[];
  scope?: MultipartAttemptScope;
  checksum_sha256?: string;
}>;

/** Server-issued identity; workerId + attempt fence the current queue lease. */
export type MultipartAttemptScope = Readonly<{
  jobId: string;
  workerId: string;
  fileJobId: string;
  attempt: number;
  assetId: string;
  bucket: string;
  objectPath: string;
  snapshotFormatVersion: number;
  snapshotRowCount: number;
}>;

export type ArtifactDigest = Readonly<
  { byteLength: number; checksumSha256: string }
>;

/** Every operation must reauthorize the actor, resource, snapshot and live lease
 * server-side. Reconcile may return a completed winner after lease release, but
 * must still reauthorize access. No automatic object deletion is permitted. */
export type MultipartPersistenceAdapter = Readonly<{
  scope: MultipartAttemptScope;
  authorize(scope: MultipartAttemptScope): Promise<void>;
  snapshot(scope: MultipartAttemptScope): Promise<MultipartSnapshot | null>;
  begin(scope: MultipartAttemptScope, uploadId: string): Promise<void>;
  recordPart(
    scope: MultipartAttemptScope,
    uploadId: string,
    part: PersistedPart,
  ): Promise<void>;
  complete(
    scope: MultipartAttemptScope,
    uploadId: string,
    digest: ArtifactDigest,
  ): Promise<void>;
  reconcile(
    scope: MultipartAttemptScope,
    uploadId: string,
    digest: ArtifactDigest,
  ): Promise<MultipartSnapshot | null>;
}>;

type MultipartClient = Readonly<{
  initiate(
    bucket: string,
    key: string,
    contentType: string,
  ): Promise<{ uploadId: string }>;
  uploadPart(
    bucket: string,
    key: string,
    uploadId: string,
    partNumber: number,
    body: Uint8Array,
  ): Promise<MultipartPart>;
  complete(
    bucket: string,
    key: string,
    uploadId: string,
    parts: readonly MultipartPart[],
  ): Promise<{ etag?: string }>;
  abort(bucket: string, key: string, uploadId: string): Promise<void>;
}>;

export type AdaptiveArtifactInput = Readonly<{
  jobId: string;
  workerId: string;
  fileJobId: string;
  bucket: string;
  proposedPath: string;
  contentType: string;
  source: AsyncIterable<Uint8Array>;
  thresholdBytes: number;
  partSizeBytes: number;
  rpc: (call: MultipartPersistenceCall) => Promise<unknown>;
  persistence?: MultipartPersistenceAdapter;
  standardUpload: (
    path: string,
    bytes: Uint8Array,
    contentType: string,
  ) => Promise<void>;
  s3: MultipartClient;
}>;

export type AdaptiveArtifactResult = Readonly<{
  mode: "standard" | "multipart";
  artifactPath: string;
  byteLength: number;
  /** Absent only on an already completed legacy snapshot without a digest. */
  checksumSha256?: string;
}>;

class ByteQueue {
  readonly #chunks: Uint8Array[] = [];
  length = 0;

  push(bytes: Uint8Array): void {
    if (!bytes.byteLength) return;
    this.#chunks.push(bytes);
    this.length += bytes.byteLength;
  }

  take(length: number): Uint8Array {
    if (length < 0 || length > this.length) {
      throw new Error("multipart_buffer_underflow");
    }
    const result = new Uint8Array(length);
    let offset = 0;
    while (offset < length) {
      const chunk = this.#chunks[0];
      const consumed = Math.min(chunk.byteLength, length - offset);
      result.set(chunk.subarray(0, consumed), offset);
      offset += consumed;
      this.length -= consumed;
      if (consumed === chunk.byteLength) this.#chunks.shift();
      else this.#chunks[0] = chunk.subarray(consumed);
    }
    return result;
  }
}

function validSnapshot(value: unknown): value is MultipartSnapshot {
  if (!value || typeof value !== "object") return false;
  const snapshot = value as Record<string, unknown>;
  return validIdentifier(snapshot.bucket_id) &&
    validIdentifier(snapshot.object_path) &&
    validIdentifier(snapshot.upload_id) &&
    (snapshot.state === "initiated" || snapshot.state === "uploading" ||
      snapshot.state === "completed") &&
    Number.isSafeInteger(snapshot.next_part_number) &&
    Number(snapshot.next_part_number) > 0 &&
    Number(snapshot.next_part_number) <= 10001 &&
    Number.isSafeInteger(snapshot.uploaded_bytes) &&
    Number(snapshot.uploaded_bytes) >= 0 &&
    (snapshot.checksum_sha256 === undefined ||
      validChecksum(snapshot.checksum_sha256)) &&
    Array.isArray(snapshot.parts) && snapshot.parts.length <= 10000 &&
    snapshot.parts.every((part) => {
      if (!part || typeof part !== "object") return false;
      const row = part as Record<string, unknown>;
      return Number.isSafeInteger(row.part_number) &&
        Number(row.part_number) > 0 && Number(row.part_number) <= 10000 &&
        validIdentifier(row.etag) &&
        Number.isSafeInteger(row.byte_length) && Number(row.byte_length) > 0 &&
        validChecksum(row.checksum_sha256);
    });
}

function validIdentifier(value: unknown): value is string {
  return typeof value === "string" && value.length > 0 &&
    value.length <= 4096 &&
    Array.from(value).every((char) =>
      char.charCodeAt(0) >= 32 && char.charCodeAt(0) !== 127
    );
}

function validChecksum(value: unknown): value is string {
  return typeof value === "string" && /^[0-9a-f]{64}$/.test(value);
}

function sameScope(value: unknown, expected: MultipartAttemptScope): boolean {
  return !!value && typeof value === "object" &&
    Object.entries(expected).every(([key, field]) =>
      (value as Record<string, unknown>)[key] === field
    );
}

function checkedSnapshot(
  value: unknown,
  input: AdaptiveArtifactInput,
  scope?: MultipartAttemptScope,
): MultipartSnapshot | null {
  if (value === null) return null;
  if (!validSnapshot(value)) throw new Error("multipart_snapshot_invalid");
  const snapshot = structuredClone(value);
  if (snapshot.bucket_id !== input.bucket) {
    throw new Error("multipart_snapshot_bucket_mismatch");
  }
  if (
    scope &&
    (!sameScope(snapshot.scope, scope) ||
      snapshot.object_path !== scope.objectPath)
  ) {
    throw new Error("multipart_snapshot_scope_mismatch");
  }
  if (
    snapshot.parts.some((part, index) =>
      part.part_number !== index + 1 ||
      part.byte_length > input.partSizeBytes ||
      (index < snapshot.parts.length - 1 &&
        part.byte_length !== input.partSizeBytes)
    ) ||
    snapshot.next_part_number !== snapshot.parts.length + 1 ||
    snapshot.uploaded_bytes !==
      snapshot.parts.reduce((sum, part) => sum + part.byte_length, 0) ||
    (snapshot.state === "initiated" && snapshot.parts.length !== 0) ||
    (snapshot.state === "completed" &&
      (snapshot.parts.length === 0 ||
        (scope && !validChecksum(snapshot.checksum_sha256))))
  ) {
    throw new Error("multipart_snapshot_invalid");
  }
  return snapshot;
}

export function multipartArtifactConfig(
  environment: Record<string, string | undefined>,
): {
  thresholdBytes: number;
  partSizeBytes: number;
} {
  const thresholdBytes = Number(
    environment.FORMS_ZIP_MULTIPART_THRESHOLD_BYTES ?? 16 * 1024 * 1024,
  );
  const partSizeBytes = Number(
    environment.FORMS_ZIP_MULTIPART_PART_BYTES ?? 8 * 1024 * 1024,
  );
  if (
    !Number.isSafeInteger(thresholdBytes) ||
    !Number.isSafeInteger(partSizeBytes) ||
    thresholdBytes < 5 * 1024 * 1024 || thresholdBytes > 128 * 1024 * 1024 ||
    partSizeBytes < 5 * 1024 * 1024 || partSizeBytes > 64 * 1024 * 1024 ||
    thresholdBytes < partSizeBytes
  ) throw new Error("multipart_artifact_config_invalid");
  return { thresholdBytes, partSizeBytes };
}

export async function uploadAdaptiveArtifact(
  requested: AdaptiveArtifactInput,
): Promise<AdaptiveArtifactResult> {
  const input = Object.freeze({ ...requested });
  const persistence = input.persistence;
  const scope = persistence
    ? Object.freeze({ ...persistence.scope })
    : undefined;
  if (
    scope && (
      !Number.isSafeInteger(scope.attempt) || scope.attempt < 1 ||
      !Number.isSafeInteger(scope.snapshotFormatVersion) ||
      scope.snapshotFormatVersion < 1 ||
      !Number.isSafeInteger(scope.snapshotRowCount) ||
      scope.snapshotRowCount < 0 ||
      ![
        scope.jobId,
        scope.workerId,
        scope.fileJobId,
        scope.assetId,
        scope.bucket,
        scope.objectPath,
      ].every(validIdentifier) ||
      scope.jobId !== input.jobId || scope.workerId !== input.workerId ||
      scope.fileJobId !== input.fileJobId ||
      scope.bucket !== input.bucket || scope.objectPath !== input.proposedPath
    )
  ) throw new Error("multipart_attempt_scope_invalid");
  const authorize = async () => {
    if (persistence && scope) await persistence.authorize(scope);
  };
  if (
    !Number.isSafeInteger(input.thresholdBytes) || input.thresholdBytes < 1 ||
    !Number.isSafeInteger(input.partSizeBytes) || input.partSizeBytes < 1 ||
    input.thresholdBytes < input.partSizeBytes
  ) throw new Error("multipart_artifact_config_invalid");

  const persistenceParams = {
    p_job_id: input.jobId,
    p_worker_id: input.workerId,
    p_file_job_id: input.fileJobId,
  };
  const stored = persistence && scope
    ? await persistence.snapshot(scope)
    : await input.rpc({
      name: "form_worker_multipart_snapshot",
      params: persistenceParams,
    });
  const snapshot = checkedSnapshot(stored, input, scope);

  let multipart = snapshot !== null;
  let uploadId = snapshot?.upload_id ?? "";
  const artifactPath = snapshot?.object_path ?? input.proposedPath;
  let nextPartNumber = snapshot?.next_part_number ?? 1;
  const completedParts: MultipartPart[] = (snapshot?.parts ?? []).map((
    part,
  ) => ({
    partNumber: part.part_number,
    etag: part.etag,
  }));
  const persistedParts = snapshot?.parts ?? [];
  if (snapshot?.state === "completed") {
    return {
      mode: "multipart",
      artifactPath,
      byteLength: snapshot.uploaded_bytes,
      ...(snapshot.checksum_sha256
        ? { checksumSha256: snapshot.checksum_sha256 }
        : {}),
    };
  }

  const queue = new ByteQueue();
  const artifactHash = createHash("sha256");
  let totalBytes = 0;
  let persistedIndex = 0;

  const abortDivergedUpload = async () => {
    if (!multipart) return;
    // A typed attempt may have lost its lease. Its reconciler/cleanup owns
    // disposal; regenerated bytes alone never authorize aborting a winner.
    if (persistence) return;
    await input.s3.abort(input.bucket, artifactPath, uploadId);
    await input.rpc({
      name: "form_worker_abort_multipart",
      params: { ...persistenceParams, p_upload_id: uploadId },
    });
  };

  const verifyPersistedParts = async () => {
    while (
      persistedIndex < persistedParts.length &&
      queue.length >= persistedParts[persistedIndex].byte_length
    ) {
      const expected = persistedParts[persistedIndex];
      const bytes = queue.take(expected.byte_length);
      if (await sha256Hex(bytes) !== expected.checksum_sha256) {
        await abortDivergedUpload();
        throw new Error("multipart_resume_checksum_mismatch");
      }
      persistedIndex++;
    }
  };

  const beginMultipart = async () => {
    await authorize();
    const initiated = await input.s3.initiate(
      input.bucket,
      artifactPath,
      input.contentType,
    );
    uploadId = initiated.uploadId;
    if (!validIdentifier(uploadId)) {
      throw new Error("multipart_upload_id_invalid");
    }
    if (persistence && scope) {
      await persistence.begin(scope, uploadId);
    } else {
      await input.rpc({
        name: "form_worker_begin_multipart",
        params: {
          ...persistenceParams,
          p_bucket_id: input.bucket,
          p_object_path: artifactPath,
          p_upload_id: uploadId,
        },
      });
    }
    multipart = true;
  };

  const uploadReadyParts = async (final: boolean) => {
    await verifyPersistedParts();
    if (persistedIndex < persistedParts.length) return;
    if (
      queue.length > 0 && persistedParts.length > 0 &&
      persistedParts[persistedParts.length - 1].byte_length <
        input.partSizeBytes
    ) {
      await abortDivergedUpload();
      throw new Error("multipart_resume_length_mismatch");
    }
    while (
      multipart &&
      (queue.length >= input.partSizeBytes || (final && queue.length > 0))
    ) {
      const bytes = queue.take(
        final && queue.length < input.partSizeBytes
          ? queue.length
          : input.partSizeBytes,
      );
      const checksum = await sha256Hex(bytes);
      if (nextPartNumber > 10000) {
        throw new Error("multipart_part_limit_exceeded");
      }
      await authorize();
      const part = await input.s3.uploadPart(
        input.bucket,
        artifactPath,
        uploadId,
        nextPartNumber,
        bytes,
      );
      if (part.partNumber !== nextPartNumber || !validIdentifier(part.etag)) {
        throw new Error("multipart_part_invalid");
      }
      if (persistence && scope) {
        await persistence.recordPart(
          scope,
          uploadId,
          Object.freeze({
            part_number: nextPartNumber,
            etag: part.etag,
            byte_length: bytes.byteLength,
            checksum_sha256: checksum,
          }),
        );
      } else {
        await input.rpc({
          name: "form_worker_record_multipart_part",
          params: {
            ...persistenceParams,
            p_upload_id: uploadId,
            p_part_number: nextPartNumber,
            p_etag: part.etag,
            p_byte_length: bytes.byteLength,
            p_checksum_sha256: checksum,
          },
        });
      }
      completedParts.push(part);
      nextPartNumber++;
    }
  };

  for await (const yieldedChunk of input.source) {
    if (!(yieldedChunk instanceof Uint8Array)) {
      throw new Error("multipart_source_invalid");
    }
    const sourceChunk = new Uint8Array(yieldedChunk);
    artifactHash.update(sourceChunk);
    await authorize();
    let offset = 0;
    while (offset < sourceChunk.byteLength) {
      const sliceLength = Math.min(
        input.partSizeBytes,
        sourceChunk.byteLength - offset,
      );
      const slice = sourceChunk.slice(offset, offset + sliceLength);
      offset += sliceLength;
      queue.push(slice);
      totalBytes += slice.byteLength;
      if (!Number.isSafeInteger(totalBytes)) {
        throw new Error("multipart_source_length_invalid");
      }
      await verifyPersistedParts();
      if (!multipart && queue.length > input.thresholdBytes) {
        await beginMultipart();
      }
      await uploadReadyParts(false);
    }
  }

  if (persistedIndex !== persistedParts.length) {
    await abortDivergedUpload();
    throw new Error("multipart_resume_length_mismatch");
  }
  if (!multipart) {
    const bytes = queue.take(queue.length);
    await authorize();
    await input.standardUpload(artifactPath, bytes, input.contentType);
    await authorize();
    return {
      mode: "standard",
      artifactPath,
      byteLength: totalBytes,
      checksumSha256: artifactHash.digest("hex"),
    };
  }
  await uploadReadyParts(true);
  const digest = Object.freeze({
    byteLength: totalBytes,
    checksumSha256: artifactHash.digest("hex"),
  });
  await authorize();
  try {
    await input.s3.complete(
      input.bucket,
      artifactPath,
      uploadId,
      completedParts,
    );
    if (persistence && scope) {
      await persistence.complete(scope, uploadId, digest);
    } else {
      await input.rpc({
        name: "form_worker_complete_multipart",
        params: { ...persistenceParams, p_upload_id: uploadId },
      });
    }
  } catch (error) {
    if (!persistence || !scope) throw error;
    try {
      const winner = checkedSnapshot(
        await persistence.reconcile(scope, uploadId, digest),
        input,
        scope,
      );
      if (
        winner?.state === "completed" && winner.upload_id === uploadId &&
        winner.uploaded_bytes === digest.byteLength &&
        winner.checksum_sha256 === digest.checksumSha256
      ) {
        return { mode: "multipart", artifactPath, ...digest };
      }
    } catch {
      /* Leave the possible committed winner for later reconciliation. */
    }
    throw new Error("multipart_completion_uncertain");
  }
  return { mode: "multipart", artifactPath, ...digest };
}
