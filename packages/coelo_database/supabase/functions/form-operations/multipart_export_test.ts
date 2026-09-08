// Async doubles intentionally model the transport/persistence Promise contract.
// deno-lint-ignore-file require-await
import { assertEquals, assertRejects } from "@std/assert";
import {
  multipartArtifactConfig,
  type MultipartPersistenceAdapter,
  type MultipartPersistenceCall,
  type MultipartSnapshot,
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
    checksumSha256: await sha256Hex(new Uint8Array([1, 2, 3])),
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

function engineFixture() {
  const uploaded: number[] = [];
  const events: string[] = [];
  const input = {
    ...base,
    source: chunks([1, 2, 3, 4, 5, 6]),
    thresholdBytes: 4,
    partSizeBytes: 3,
    rpc: async (call: MultipartPersistenceCall) => {
      events.push(call.name);
      return null;
    },
    standardUpload: async (_path: string, bytes: Uint8Array) => {
      uploaded.push(...bytes);
    },
    s3: {
      initiate: async () => ({ uploadId: "upload-id" }),
      uploadPart: async (
        _b: string,
        _k: string,
        _u: string,
        partNumber: number,
        bytes: Uint8Array,
      ) => {
        uploaded.push(...bytes);
        return { partNumber, etag: `etag-${partNumber}` };
      },
      complete: async () => ({}),
      abort: async () => {
        events.push("abort");
      },
    },
  };
  return { input, uploaded, events };
}

Deno.test("returns whole artifact SHA256 for standard and multipart paths", async () => {
  for (const thresholdBytes of [4, 20]) {
    const { input } = engineFixture();
    const result = await uploadAdaptiveArtifact({ ...input, thresholdBytes });
    assertEquals(
      "checksumSha256" in result ? result.checksumSha256 : undefined,
      await sha256Hex(new Uint8Array([1, 2, 3, 4, 5, 6])),
    );
  }
});

Deno.test("copies the entire yielded chunk before asynchronous persistence", async () => {
  const { input, uploaded } = engineFixture();
  const bytes = new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8, 9]);
  input.source = {
    async *[Symbol.asyncIterator]() {
      yield bytes;
    },
  };
  input.s3.initiate = async () => {
    bytes.fill(99);
    return { uploadId: "upload-id" };
  };
  await uploadAdaptiveArtifact(input);
  assertEquals(uploaded, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
});

Deno.test("rejects mismatched provider part number before persistence or completion", async () => {
  const { input, events } = engineFixture();
  input.s3.uploadPart = async () => ({ partNumber: 99, etag: "etag" });
  await assertRejects(
    () => uploadAdaptiveArtifact(input),
    Error,
    "multipart_part_invalid",
  );
  assertEquals(events.includes("form_worker_record_multipart_part"), false);
});

function adapterFixture() {
  const fixture = engineFixture();
  const scope = {
    jobId: base.jobId,
    workerId: base.workerId,
    fileJobId: base.fileJobId,
    attempt: 1,
    assetId: "asset-id",
    bucket: base.bucket,
    objectPath: base.proposedPath,
    snapshotFormatVersion: 1,
    snapshotRowCount: 2,
  };
  const events = fixture.events;
  let snapshot: MultipartSnapshot | null = null;
  const persistence: MultipartPersistenceAdapter = {
    scope,
    authorize: async (value) => {
      assertEquals(value, scope);
      events.push("authorize");
    },
    snapshot: async () => snapshot,
    begin: async (value, uploadId) => {
      snapshot = {
        scope: value,
        bucket_id: value.bucket,
        object_path: value.objectPath,
        upload_id: uploadId,
        state: "initiated",
        next_part_number: 1,
        uploaded_bytes: 0,
        parts: [],
      };
      events.push("begin");
    },
    recordPart: async (_value, _id, part) => {
      if (!snapshot) throw new Error("missing_snapshot");
      snapshot = {
        ...snapshot,
        state: "uploading",
        parts: [...snapshot.parts, part],
        uploaded_bytes: snapshot.uploaded_bytes + part.byte_length,
        next_part_number: part.part_number + 1,
      };
      events.push("record");
    },
    complete: async (_value, _id, digest) => {
      if (!snapshot) throw new Error("missing_snapshot");
      snapshot = {
        ...snapshot,
        state: "completed",
        checksum_sha256: digest.checksumSha256,
      };
      events.push("complete");
    },
    reconcile: async () => {
      events.push("reconcile");
      return snapshot;
    },
  };
  return {
    ...fixture,
    input: { ...fixture.input, persistence },
    persistence,
    scope,
    setSnapshot: (value: MultipartSnapshot) => {
      snapshot = value;
    },
  };
}

Deno.test("typed attempt adapter replaces legacy RPC and persists integral checksum", async () => {
  const { input, events } = adapterFixture();
  const result = await uploadAdaptiveArtifact(input);
  assertEquals(events.includes("form_worker_multipart_snapshot"), false);
  assertEquals(events.filter((event) => event === "record").length, 2);
  assertEquals(events.includes("complete"), true);
  assertEquals(
    result.checksumSha256,
    await sha256Hex(new Uint8Array([1, 2, 3, 4, 5, 6])),
  );
});

Deno.test("typed attempt scope rejects another asset snapshot before network I/O", async () => {
  const fixture = adapterFixture();
  fixture.setSnapshot({
    scope: { ...fixture.scope, assetId: "other-asset" },
    bucket_id: base.bucket,
    object_path: base.proposedPath,
    upload_id: "upload-id",
    state: "initiated",
    next_part_number: 1,
    uploaded_bytes: 0,
    parts: [],
  });
  await assertRejects(
    () => uploadAdaptiveArtifact(fixture.input),
    Error,
    "multipart_snapshot_scope_mismatch",
  );
  assertEquals(fixture.uploaded, []);
});

Deno.test("ambiguous persistence completion reconciles the exact completed winner", async () => {
  const { input, persistence, events } = adapterFixture();
  const complete = persistence.complete;
  input.persistence = {
    ...persistence,
    complete: async (...args) => {
      await complete(...args);
      throw new Error("connection_lost_after_commit");
    },
  };
  const result = await uploadAdaptiveArtifact(input);
  assertEquals(result.byteLength, 6);
  assertEquals(events.includes("reconcile"), true);
  assertEquals(events.includes("abort"), false);
});

Deno.test("ambiguous provider completion without a winner stays uncertain and never aborts", async () => {
  const { input, events } = adapterFixture();
  input.s3.complete = async () => {
    throw new Error("sensitive_remote_response");
  };
  await assertRejects(
    () => uploadAdaptiveArtifact(input),
    Error,
    "multipart_completion_uncertain",
  );
  assertEquals(events.includes("reconcile"), true);
  assertEquals(events.includes("abort"), false);
});

Deno.test("typed scope rejects each correlation field before reading persistence", async () => {
  for (
    const delta of [
      { jobId: "other" },
      { workerId: "other" },
      { fileJobId: "other" },
      { bucket: "other" },
      { objectPath: "other" },
      { assetId: "" },
      { attempt: 0 },
      { attempt: 1.5 },
      { snapshotFormatVersion: 0 },
      { snapshotRowCount: -1 },
    ]
  ) {
    const { input, scope } = adapterFixture();
    input.persistence = {
      ...input.persistence,
      scope: { ...scope, ...delta },
      snapshot: async () => {
        throw new Error("must_not_read");
      },
    };
    await assertRejects(
      () => uploadAdaptiveArtifact(input),
      Error,
      "multipart_attempt_scope_invalid",
    );
  }
});

Deno.test("typed snapshots reject all crossed attempt and snapshot fields", async () => {
  for (
    const delta of [
      { jobId: "other" },
      { workerId: "other" },
      { fileJobId: "other" },
      { bucket: "other" },
      { objectPath: "other" },
      { assetId: "other" },
      { attempt: 2 },
      { snapshotFormatVersion: 2 },
      { snapshotRowCount: 3 },
    ]
  ) {
    const { input, scope, setSnapshot, uploaded } = adapterFixture();
    setSnapshot({
      scope: { ...scope, ...delta },
      bucket_id: base.bucket,
      object_path: base.proposedPath,
      upload_id: "upload-id",
      state: "initiated",
      next_part_number: 1,
      uploaded_bytes: 0,
      parts: [],
    });
    await assertRejects(
      () => uploadAdaptiveArtifact(input),
      Error,
      "multipart_snapshot_scope_mismatch",
    );
    assertEquals(uploaded, []);
  }
});

Deno.test("malformed part snapshots are rejected before provider I/O", async () => {
  const part = {
    part_number: 1,
    etag: "etag-1",
    byte_length: 3,
    checksum_sha256: "0".repeat(64),
  };
  for (
    const delta of [
      { uploaded_bytes: -1 },
      { uploaded_bytes: 2 },
      { next_part_number: 3 },
      { upload_id: "" },
      { upload_id: "bad\nvalue" },
      { parts: [{ ...part, part_number: 2 }] },
      { parts: [{ ...part, etag: "" }] },
      { parts: [{ ...part, byte_length: 1.5 }] },
      { parts: [{ ...part, checksum_sha256: "invalid" }] },
      { state: "initiated" as const },
      { state: "completed" as const },
    ]
  ) {
    const { input, scope, setSnapshot, uploaded } = adapterFixture();
    setSnapshot({
      scope,
      bucket_id: base.bucket,
      object_path: base.proposedPath,
      upload_id: "upload-id",
      state: "uploading",
      next_part_number: 2,
      uploaded_bytes: 3,
      parts: [part],
      ...delta,
    });
    await assertRejects(
      () => uploadAdaptiveArtifact(input),
      Error,
      "multipart_snapshot_invalid",
    );
    assertEquals(uploaded, []);
  }
});

Deno.test("completed typed snapshot returns the persisted integral checksum without rereading", async () => {
  const { input, scope, setSnapshot } = adapterFixture();
  const checksum = await sha256Hex(new Uint8Array([1, 2, 3]));
  setSnapshot({
    scope,
    bucket_id: base.bucket,
    object_path: base.proposedPath,
    upload_id: "upload-id",
    state: "completed",
    next_part_number: 2,
    uploaded_bytes: 3,
    checksum_sha256: checksum,
    parts: [{
      part_number: 1,
      etag: "etag-1",
      byte_length: 3,
      checksum_sha256: checksum,
    }],
  });
  input.source = {
    [Symbol.asyncIterator]: () => ({
      next: () => Promise.reject(new Error("must_not_read")),
    }),
  };
  const result = await uploadAdaptiveArtifact(input);
  assertEquals(result.checksumSha256, checksum);
});

Deno.test("revoked lease before provider upload denies bytes and does not abort", async () => {
  const { input, persistence, events, uploaded } = adapterFixture();
  let revoked = false;
  input.persistence = {
    ...persistence,
    authorize: async () => {
      if (revoked) throw new Error("lease_revoked");
    },
    begin: async (...args) => {
      await persistence.begin(...args);
      revoked = true;
    },
  };
  await assertRejects(
    () => uploadAdaptiveArtifact(input),
    Error,
    "lease_revoked",
  );
  assertEquals(uploaded, []);
  assertEquals(events.includes("abort"), false);
});

Deno.test("typed resumed checksum includes verified existing parts and new bytes", async () => {
  const { input, scope, setSnapshot, uploaded } = adapterFixture();
  setSnapshot({
    scope,
    bucket_id: base.bucket,
    object_path: base.proposedPath,
    upload_id: "upload-id",
    state: "uploading",
    next_part_number: 2,
    uploaded_bytes: 3,
    parts: [{
      part_number: 1,
      etag: "etag-1",
      byte_length: 3,
      checksum_sha256: await sha256Hex(new Uint8Array([1, 2, 3])),
    }],
  });
  const result = await uploadAdaptiveArtifact(input);
  assertEquals(uploaded, [4, 5, 6]);
  assertEquals(
    result.checksumSha256,
    await sha256Hex(new Uint8Array([1, 2, 3, 4, 5, 6])),
  );
});

Deno.test("typed resume divergence and truncation never abort a possibly stale attempt", async () => {
  for (const source of [chunks([9, 9, 9]), chunks([1, 2])]) {
    const { input, scope, setSnapshot, events } = adapterFixture();
    setSnapshot({
      scope,
      bucket_id: base.bucket,
      object_path: base.proposedPath,
      upload_id: "upload-id",
      state: "uploading",
      next_part_number: 2,
      uploaded_bytes: 3,
      parts: [{
        part_number: 1,
        etag: "etag-1",
        byte_length: 3,
        checksum_sha256: await sha256Hex(new Uint8Array([1, 2, 3])),
      }],
    });
    await assertRejects(
      () => uploadAdaptiveArtifact({ ...input, source }),
      Error,
      "multipart_resume_",
    );
    assertEquals(events.includes("abort"), false);
  }
});

Deno.test("reconciliation refuses mismatched winners and preserves ambiguous errors", async () => {
  for (
    const delta of [
      { upload_id: "other" },
      { checksum_sha256: "0".repeat(64) },
      { uploaded_bytes: 99 },
      { object_path: "other" },
      { state: "uploading" as const },
      { scope: undefined },
    ]
  ) {
    const { input, persistence, events } = adapterFixture();
    input.persistence = {
      ...persistence,
      complete: async (...args) => {
        await persistence.complete(...args);
        throw new Error("lost_ack");
      },
      reconcile: async (...args) => {
        const snapshot = await persistence.reconcile(...args);
        return snapshot ? { ...snapshot, ...delta } : null;
      },
    };
    await assertRejects(
      () => uploadAdaptiveArtifact(input),
      Error,
      "multipart_completion_uncertain",
    );
    assertEquals(events.includes("abort"), false);
  }
});

Deno.test("attempt identity is copied before snapshot await", async () => {
  const { input, persistence, scope } = adapterFixture();
  const initial = { ...scope };
  input.persistence = {
    ...persistence,
    snapshot: async (received) => {
      scope.assetId = "mutated";
      scope.attempt = 2;
      assertEquals(received, initial);
      return null;
    },
    authorize: async (received) => {
      assertEquals(received, initial);
    },
  };
  await uploadAdaptiveArtifact(input);
});

Deno.test("preserves client methods on class prototypes", async () => {
  const { input } = engineFixture();
  class Client {
    #parts = 0;
    async initiate() {
      return { uploadId: "class-upload" };
    }
    async uploadPart(
      _b: string,
      _k: string,
      _u: string,
      partNumber: number,
      _bytes: Uint8Array,
    ) {
      this.#parts++;
      return { partNumber, etag: `etag-${partNumber}` };
    }
    async complete() {
      assertEquals(this.#parts, 2);
      return {};
    }
    async abort() {
      throw new Error("must_not_abort");
    }
  }
  assertEquals(
    (await uploadAdaptiveArtifact({ ...input, s3: new Client() })).byteLength,
    6,
  );
});

Deno.test("resume rejects oversized and short nonfinal persisted parts", async () => {
  for (const sizes of [[4], [2, 1]]) {
    const { input, scope, setSnapshot, uploaded } = adapterFixture();
    setSnapshot({
      scope,
      bucket_id: base.bucket,
      object_path: base.proposedPath,
      upload_id: "upload-id",
      state: "uploading",
      next_part_number: sizes.length + 1,
      uploaded_bytes: sizes.reduce((a, b) => a + b, 0),
      parts: sizes.map((size, index) => ({
        part_number: index + 1,
        etag: `etag-${index + 1}`,
        byte_length: size,
        checksum_sha256: "0".repeat(64),
      })),
    });
    await assertRejects(
      () => uploadAdaptiveArtifact(input),
      Error,
      "multipart_snapshot_invalid",
    );
    assertEquals(uploaded, []);
  }
});

Deno.test("resume cannot append new bytes after a previously short final part", async () => {
  const { input, scope, setSnapshot, events } = adapterFixture();
  setSnapshot({
    scope,
    bucket_id: base.bucket,
    object_path: base.proposedPath,
    upload_id: "upload-id",
    state: "uploading",
    next_part_number: 2,
    uploaded_bytes: 2,
    parts: [{
      part_number: 1,
      etag: "etag-1",
      byte_length: 2,
      checksum_sha256: await sha256Hex(new Uint8Array([1, 2])),
    }],
  });
  await assertRejects(
    () => uploadAdaptiveArtifact(input),
    Error,
    "multipart_resume_length_mismatch",
  );
  assertEquals(events.includes("abort"), false);
});

Deno.test("native incremental SHA256 agrees with WebCrypto across one MiB and chunk boundaries", async () => {
  const { input, uploaded } = engineFixture();
  const bytes = Uint8Array.from(
    { length: 1024 * 1024 + 17 },
    (_, index) => index % 251,
  );
  const source = {
    async *[Symbol.asyncIterator]() {
      for (let offset = 0; offset < bytes.length; offset += 65537) {
        yield bytes.subarray(offset, offset + 65537);
      }
    },
  };
  // Avoid a large argument list in the synthetic provider while retaining bytes.
  input.s3.uploadPart = async (_bucket, _key, _id, partNumber, part) => {
    for (const byte of part) uploaded.push(byte);
    return { partNumber, etag: `etag-${partNumber}` };
  };
  const result = await uploadAdaptiveArtifact({
    ...input,
    source,
    thresholdBytes: 262144,
    partSizeBytes: 262144,
  });
  assertEquals(result.checksumSha256, await sha256Hex(bytes));
  assertEquals(new Uint8Array(uploaded), bytes);
});
