import { assertEquals, assertRejects } from "@std/assert";
import { cleanupExpiredItems } from "./cleanup_contract.ts";

const cleanupJob = "11111111-1111-4111-8111-111111111111";

Deno.test("aborts expired multipart uploads before deleting storage and completing cleanup", async () => {
  const events: string[] = [];
  const count = await cleanupExpiredItems({
    jobId: cleanupJob,
    workerId: "worker-a",
    snapshot: async () => ({
      kind: "cleanup_artifacts",
      items: [{
        id: "22222222-2222-4222-8222-222222222222",
        storage_path: null,
        multipart_bucket: "coelo-forms-private",
        multipart_path: "ab/33333333-3333-4333-8333-333333333333",
        multipart_upload_id: "opaque-upload-id",
      }],
    }),
    abortMultipart: async (bucket, path, uploadId) => {
      events.push(`abort:${bucket}:${path}:${uploadId}`);
    },
    removeStorage: async (paths) => {
      events.push(`remove:${paths.join(",")}`);
    },
    complete: async (ids) => {
      events.push(`complete:${ids.join(",")}`);
    },
  });

  assertEquals(count, 1);
  assertEquals(events, [
    "abort:coelo-forms-private:ab/33333333-3333-4333-8333-333333333333:opaque-upload-id",
    "complete:22222222-2222-4222-8222-222222222222",
  ]);
});

Deno.test("does not complete cleanup when an external deletion fails", async () => {
  let completed = false;
  await assertRejects(() =>
    cleanupExpiredItems({
      jobId: cleanupJob,
      workerId: "worker-a",
      snapshot: async () => ({
        kind: "cleanup_uploads",
        items: [{
          id: "22222222-2222-4222-8222-222222222222",
          storage_path: "ab/33333333-3333-4333-8333-333333333333",
        }],
      }),
      abortMultipart: async () => {},
      removeStorage: async () => {
        throw new Error("storage unavailable");
      },
      complete: async () => {
        completed = true;
      },
    })
  );
  assertEquals(completed, false);
});
