import { type MultipartPart, sha256Hex } from "./multipart_s3.ts";

export type MultipartPersistenceCall = Readonly<{
  name: string;
  params: Record<string, unknown>;
}>;

type PersistedPart = Readonly<{
  part_number: number;
  etag: string;
  byte_length: number;
  checksum_sha256: string;
}>;

type MultipartSnapshot = Readonly<{
  bucket_id: string;
  object_path: string;
  upload_id: string;
  state: "initiated" | "uploading" | "completed";
  next_part_number: number;
  uploaded_bytes: number;
  parts: PersistedPart[];
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
  return typeof snapshot.bucket_id === "string" &&
    typeof snapshot.object_path === "string" &&
    typeof snapshot.upload_id === "string" &&
    (snapshot.state === "initiated" || snapshot.state === "uploading" ||
      snapshot.state === "completed") &&
    Number.isInteger(snapshot.next_part_number) &&
    typeof snapshot.uploaded_bytes === "number" &&
    Array.isArray(snapshot.parts) && snapshot.parts.every((part) => {
      if (!part || typeof part !== "object") return false;
      const row = part as Record<string, unknown>;
      return Number.isInteger(row.part_number) &&
        typeof row.etag === "string" &&
        Number.isInteger(row.byte_length) && Number(row.byte_length) > 0 &&
        typeof row.checksum_sha256 === "string" &&
        /^[0-9a-f]{64}$/.test(row.checksum_sha256);
    });
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
  input: AdaptiveArtifactInput,
): Promise<AdaptiveArtifactResult> {
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
  const stored = await input.rpc({
    name: "form_worker_multipart_snapshot",
    params: persistenceParams,
  });
  if (stored !== null && !validSnapshot(stored)) {
    throw new Error("multipart_snapshot_invalid");
  }
  const snapshot = stored as MultipartSnapshot | null;
  if (snapshot && snapshot.bucket_id !== input.bucket) {
    throw new Error("multipart_snapshot_bucket_mismatch");
  }

  let multipart = snapshot !== null;
  let uploadId = snapshot?.upload_id ?? "";
  let artifactPath = snapshot?.object_path ?? input.proposedPath;
  let nextPartNumber = snapshot?.next_part_number ?? 1;
  const completedParts: MultipartPart[] = (snapshot?.parts ?? []).map((
    part,
  ) => ({
    partNumber: part.part_number,
    etag: part.etag,
  }));
  const persistedParts = snapshot?.parts ?? [];
  if (
    persistedParts.some((part, index) => part.part_number !== index + 1) ||
    nextPartNumber !== persistedParts.length + 1 ||
    (snapshot?.uploaded_bytes ?? 0) !==
      persistedParts.reduce((sum, part) => sum + part.byte_length, 0)
  ) throw new Error("multipart_snapshot_invalid");
  if (snapshot?.state === "completed") {
    return {
      mode: "multipart",
      artifactPath,
      byteLength: snapshot.uploaded_bytes,
    };
  }

  const queue = new ByteQueue();
  let totalBytes = 0;
  let persistedIndex = 0;

  const abortDivergedUpload = async () => {
    if (!multipart) return;
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
    const initiated = await input.s3.initiate(
      input.bucket,
      artifactPath,
      input.contentType,
    );
    uploadId = initiated.uploadId;
    await input.rpc({
      name: "form_worker_begin_multipart",
      params: {
        ...persistenceParams,
        p_bucket_id: input.bucket,
        p_object_path: artifactPath,
        p_upload_id: uploadId,
      },
    });
    multipart = true;
  };

  const uploadReadyParts = async (final: boolean) => {
    await verifyPersistedParts();
    if (persistedIndex < persistedParts.length) return;
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
      const part = await input.s3.uploadPart(
        input.bucket,
        artifactPath,
        uploadId,
        nextPartNumber,
        bytes,
      );
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
      completedParts.push(part);
      nextPartNumber++;
    }
  };

  for await (const sourceChunk of input.source) {
    if (!(sourceChunk instanceof Uint8Array)) {
      throw new Error("multipart_source_invalid");
    }
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
    await input.standardUpload(artifactPath, bytes, input.contentType);
    return { mode: "standard", artifactPath, byteLength: totalBytes };
  }
  await uploadReadyParts(true);
  await input.s3.complete(input.bucket, artifactPath, uploadId, completedParts);
  await input.rpc({
    name: "form_worker_complete_multipart",
    params: { ...persistenceParams, p_upload_id: uploadId },
  });
  return { mode: "multipart", artifactPath, byteLength: totalBytes };
}
