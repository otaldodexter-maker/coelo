import { assertEquals, assertRejects } from "@std/assert";
import {
  multipartArtifactConfig,
  type MultipartPersistenceCall,
  uploadAdaptiveArtifact,
} from "./multipart_export.ts";
import { sha256Hex } from "./multipart_s3.ts";

const chunks = (...values: number[][]): AsyncIterable<Uint8Array> => ({
  async *[Symbol.asyncIterator]() {
    for (const value of values) yield new Uint8Array(value);
  },
});

const base = {
  jobId: "job-id",
  workerId: "worker-id",
  fileJobId: "file-job-id",
  bucket: "coelo-forms-private",
  proposedPath: "ab/11111111-1111-4111-8111-111111111111",
  contentType: "application/zip",
};

Deno.test("validates bounded multipart threshold and S3 part size configuration", () => {
  assertEquals(multipartArtifactConfig({}), {
    thresholdBytes: 16 * 1024 * 1024,
    partSizeBytes: 8 * 1024 * 1024,
  });
  assertEquals(
    multipartArtifactConfig({
      FORMS_ZIP_MULTIPART_THRESHOLD_BYTES: String(10 * 1024 * 1024),
      FORMS_ZIP_MULTIPART_PART_BYTES: String(5 * 1024 * 1024),
    }),
    {
      thresholdBytes: 10 * 1024 * 1024,
      partSizeBytes: 5 * 1024 * 1024,
    },
  );
  for (
    const environment of [
      { FORMS_ZIP_MULTIPART_THRESHOLD_BYTES: "NaN" },
      { FORMS_ZIP_MULTIPART_PART_BYTES: "1024" },
      {
        FORMS_ZIP_MULTIPART_THRESHOLD_BYTES: String(5 * 1024 * 1024),
        FORMS_ZIP_MULTIPART_PART_BYTES: String(8 * 1024 * 1024),
      },
    ]
  ) {
    try {
      multipartArtifactConfig(environment);
      throw new Error("expected_invalid_config");
    } catch (error) {
      assertEquals(
        (error as Error).message,
        "multipart_artifact_config_invalid",
      );
    }
  }
});

Deno.test("keeps a ZIP below the threshold on the bounded standard upload path", async () => {
  const events: string[] = [];
  const result = await uploadAdaptiveArtifact({
    ...base,
    source: chunks([1, 2], [3]),
    thresholdBytes: 4,
    partSizeBytes: 3,
    rpc: async (call) => {
      events.push(call.name);
      return null;
    },
    standardUpload: (_path, bytes) => {
      events.push(`standard:${[...bytes].join(",")}`);
      return Promise.resolve();
    },
    s3: {
      initiate: () => Promise.reject(new Error("must_not_initiate")),
      uploadPart: () => Promise.reject(new Error("must_not_upload_part")),
      complete: () => Promise.reject(new Error("must_not_complete")),
      abort: () => Promise.reject(new Error("must_not_abort")),
    },
  });

  assertEquals(result, {
    mode: "standard",
    artifactPath: base.proposedPath,
    byteLength: 3,
  });
  assertEquals(events, ["form_worker_multipart_snapshot", "standard:1,2,3"]);
});

Deno.test("uploads bounded parts and persists each ETag before starting the next part", async () => {
  const events: string[] = [];
  const rpc = async (call: MultipartPersistenceCall) => {
    events.push(`rpc:${call.name}:${call.params.p_part_number ?? ""}`);
    if (call.name === "form_worker_multipart_snapshot") return null;
    return {};
  };
  const result = await uploadAdaptiveArtifact({
    ...base,
    source: chunks([1, 2, 3], [4, 5, 6], [7, 8, 9]),
    thresholdBytes: 5,
    partSizeBytes: 4,
    rpc,
    standardUpload: () => Promise.reject(new Error("must_not_standard_upload")),
    s3: {
      initiate: async () => {
        events.push("s3:initiate");
        return { uploadId: "upload-id" };
      },
      uploadPart: async (_bucket, _path, _uploadId, partNumber, bytes) => {
        events.push(`s3:part:${partNumber}:${bytes.byteLength}`);
        return { partNumber, etag: `etag-${partNumber}` };
      },
      complete: async (_bucket, _path, _uploadId, parts) => {
        events.push(`s3:complete:${parts.length}`);
        return {};
      },
      abort: () => Promise.reject(new Error("must_not_abort")),
    },
  });

  assertEquals(result.mode, "multipart");
  assertEquals(result.byteLength, 9);
  assertEquals(events, [
    "rpc:form_worker_multipart_snapshot:",
    "s3:initiate",
    "rpc:form_worker_begin_multipart:",
    "s3:part:1:4",
    "rpc:form_worker_record_multipart_part:1",
    "s3:part:2:4",
    "rpc:form_worker_record_multipart_part:2",
    "s3:part:3:1",
    "rpc:form_worker_record_multipart_part:3",
    "s3:complete:3",
    "rpc:form_worker_complete_multipart:",
  ]);
});

Deno.test("resumes after verified persisted parts without uploading them again", async () => {
  const first = new Uint8Array([1, 2, 3, 4]);
  const events: string[] = [];
  const result = await uploadAdaptiveArtifact({
    ...base,
    source: chunks([...first], [5, 6]),
    thresholdBytes: 5,
    partSizeBytes: 4,
    rpc: async (call) => {
      if (call.name === "form_worker_multipart_snapshot") {
        return {
          bucket_id: base.bucket,
          object_path: base.proposedPath,
          upload_id: "upload-id",
          state: "uploading",
          next_part_number: 2,
          uploaded_bytes: 4,
          parts: [{
            part_number: 1,
            etag: "etag-1",
            byte_length: 4,
            checksum_sha256: await sha256Hex(first),
          }],
        };
      }
      events.push(`rpc:${call.name}`);
      return {};
    },
    standardUpload: () => Promise.reject(new Error("must_not_standard_upload")),
    s3: {
      initiate: () => Promise.reject(new Error("must_not_initiate")),
      uploadPart: async (_bucket, _path, _uploadId, partNumber) => {
        events.push(`s3:part:${partNumber}`);
        return { partNumber, etag: "etag-2" };
      },
      complete: async (_bucket, _path, _uploadId, parts) => {
        events.push(
          `s3:complete:${parts.map((part) => part.partNumber).join(",")}`,
        );
        return {};
      },
      abort: () => Promise.reject(new Error("must_not_abort")),
    },
  });

  assertEquals(result.byteLength, 6);
  assertEquals(events, [
    "s3:part:2",
    "rpc:form_worker_record_multipart_part",
    "s3:complete:1,2",
    "rpc:form_worker_complete_multipart",
  ]);
});

Deno.test("returns an already completed multipart artifact without regenerating bytes", async () => {
  let sourceRead = false;
  const result = await uploadAdaptiveArtifact({
    ...base,
    source: {
      async *[Symbol.asyncIterator]() {
        sourceRead = true;
        yield new Uint8Array([9]);
      },
    },
    thresholdBytes: 5,
    partSizeBytes: 4,
    rpc: (call) =>
      Promise.resolve(
        call.name === "form_worker_multipart_snapshot"
          ? {
            bucket_id: base.bucket,
            object_path: base.proposedPath,
            upload_id: "upload-id",
            state: "completed",
            next_part_number: 2,
            uploaded_bytes: 4,
            parts: [{
              part_number: 1,
              etag: "etag-1",
              byte_length: 4,
              checksum_sha256: "0".repeat(64),
            }],
          }
          : {},
      ),
    standardUpload: () => Promise.reject(new Error("must_not_standard_upload")),
    s3: {
      initiate: () => Promise.reject(new Error("must_not_initiate")),
      uploadPart: () => Promise.reject(new Error("must_not_upload_part")),
      complete: () => Promise.reject(new Error("must_not_complete")),
      abort: () => Promise.reject(new Error("must_not_abort")),
    },
  });

  assertEquals(sourceRead, false);
  assertEquals(result, {
    mode: "multipart",
    artifactPath: base.proposedPath,
    byteLength: 4,
  });
});

Deno.test("aborts a multipart upload when regenerated persisted bytes diverge", async () => {
  const events: string[] = [];
  await assertRejects(
    () =>
      uploadAdaptiveArtifact({
        ...base,
        source: chunks([9, 9, 9, 9], [5]),
        thresholdBytes: 5,
        partSizeBytes: 4,
        rpc: async (call) => {
          if (call.name === "form_worker_multipart_snapshot") {
            return {
              bucket_id: base.bucket,
              object_path: base.proposedPath,
              upload_id: "upload-id",
              state: "uploading",
              next_part_number: 2,
              uploaded_bytes: 4,
              parts: [{
                part_number: 1,
                etag: "etag-1",
                byte_length: 4,
                checksum_sha256: await sha256Hex(new Uint8Array([1, 2, 3, 4])),
              }],
            };
          }
          events.push(`rpc:${call.name}`);
          return {};
        },
        standardUpload: () =>
          Promise.reject(new Error("must_not_standard_upload")),
        s3: {
          initiate: () => Promise.reject(new Error("must_not_initiate")),
          uploadPart: () => Promise.reject(new Error("must_not_upload_part")),
          complete: () => Promise.reject(new Error("must_not_complete")),
          abort: async () => {
            events.push("s3:abort");
          },
        },
      }),
    Error,
    "multipart_resume_checksum_mismatch",
  );
  assertEquals(events, ["s3:abort", "rpc:form_worker_abort_multipart"]);
});
