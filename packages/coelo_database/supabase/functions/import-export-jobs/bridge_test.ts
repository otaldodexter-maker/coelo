import { assertEquals, assertThrows } from "@std/assert";
import {
  authorizeUploadFailureJob,
  cleanupNewUploadBestEffort,
  recordAuthorizedFailureBestEffort,
} from "./index.ts";

Deno.test("accepts binary uploads and never accepts base64 source payloads", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );
  assertEquals(source.includes("await request.arrayBuffer()"), true);
  assertEquals(source.includes("content_base64"), false);
});

Deno.test("revalidates the user before each private job operation", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );
  const checks = source.match(/createClient\(url, anon/g) ?? [];
  assertEquals(checks.length >= 1, true);
  assertEquals(
    source.includes("superadmin_import_export_upload_contract"),
    true,
  );
  assertEquals(source.includes("superadmin_get_import_export_job"), true);
});

Deno.test("validates the service storage path before upload", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );
  assertEquals(
    source.includes("`imports/units/${uploadJobId}/source.${format}`"),
    true,
  );
  assertEquals(source.includes("invalid_storage_contract"), true);
});

Deno.test("foreign upload job rejected with 42501 cannot be failed by service role", async () => {
  const foreignJobId = "00000000-0000-4000-8000-000000000001";
  let authorizedFailureJobId: string | null = null;
  let adminSelects = 0;
  let failRpcs = 0;
  let state = "PENDING";

  assertThrows(
    () => {
      const authorized = authorizeUploadFailureJob(foreignJobId, {
        data: null,
        error: { code: "42501" },
      });
      authorizedFailureJobId = authorized.jobId;
    },
    Error,
    "upload_unauthorized",
  );
  await recordAuthorizedFailureBestEffort(authorizedFailureJobId, () => {
    adminSelects++;
    failRpcs++;
    state = "FAILED";
    return Promise.resolve();
  });

  assertEquals(adminSelects, 0);
  assertEquals(failRpcs, 0);
  assertEquals(state, "PENDING");
});

Deno.test("authorized upload can fail only its own job after a downstream error", async () => {
  const ownJobId = "00000000-0000-4000-8000-000000000002";
  const authorized = authorizeUploadFailureJob(ownJobId, {
    data: { mime_type: "text/csv" },
    error: null,
  });
  const failedIds: string[] = [];

  await recordAuthorizedFailureBestEffort(authorized.jobId, (jobId) => {
    failedIds.push(jobId);
    return Promise.resolve();
  });

  assertEquals(failedIds, [ownJobId]);
});

Deno.test("removes only a newly-created object after downstream failure", async () => {
  const removed: string[] = [];
  assertEquals(
    await cleanupNewUploadBestEffort(null, (path) => {
      removed.push(path);
      return Promise.resolve({ error: null });
    }),
    true,
  );
  assertEquals(removed, []);

  assertEquals(
    await cleanupNewUploadBestEffort(
      "imports/units/job/source.csv",
      (path) => {
        removed.push(path);
        return Promise.resolve({ error: null });
      },
    ),
    true,
  );
  assertEquals(removed, ["imports/units/job/source.csv"]);
});

Deno.test("cleanup failure remains observable to the job failure recorder", async () => {
  assertEquals(
    await cleanupNewUploadBestEffort(
      "imports/units/job/source.csv",
      () => Promise.resolve({ error: new Error("storage unavailable") }),
    ),
    false,
  );
  assertEquals(
    await cleanupNewUploadBestEffort(
      "imports/units/job/source.csv",
      () => Promise.reject(new Error("storage unavailable")),
    ),
    false,
  );

  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );
  assertEquals(source.includes("_cleanup_failed"), true);
  assertEquals(source.includes("superadmin_fail_unit_file_job"), true);
});
