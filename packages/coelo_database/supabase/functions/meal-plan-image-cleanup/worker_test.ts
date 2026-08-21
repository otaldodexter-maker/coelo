import { assertEquals, assertRejects } from "jsr:@std/assert@1.0.14";
import { processMealPlanImageCleanup } from "./worker.ts";

Deno.test("removes each claimed private image before confirming", async () => {
  const events: string[] = [];
  const result = await processMealPlanImageCleanup({
    claim: () => Promise.resolve([{
      request_id: "request-1",
      asset_id: "asset-1",
      bucket: "coelo-meal-plans-private",
      path: "meal-plans/plan/asset.jpg",
      attempt: 1,
    }]),
    remove: (_bucket, path) => {
      events.push(`remove:${path}`);
      return Promise.resolve();
    },
    complete: (requestId, succeeded) => {
      events.push(`complete:${requestId}:${succeeded}`);
      return Promise.resolve();
    },
  });
  assertEquals(events, [
    "remove:meal-plans/plan/asset.jpg",
    "complete:request-1:true",
  ]);
  assertEquals(result, { claimed: 1, completed: 1, failed: 0 });
});

Deno.test("persists a failed attempt and continues the batch", async () => {
  const completions: Array<[string, boolean]> = [];
  const result = await processMealPlanImageCleanup({
    claim: () => Promise.resolve([
      { request_id: "bad", asset_id: "a", bucket: "coelo-meal-plans-private", path: "bad", attempt: 1 },
      { request_id: "good", asset_id: "b", bucket: "coelo-meal-plans-private", path: "good", attempt: 1 },
    ]),
    remove: (_bucket, path) => path === "bad"
      ? Promise.reject(new Error("transient"))
      : Promise.resolve(),
    complete: (requestId, succeeded) => {
      completions.push([requestId, succeeded]);
      return Promise.resolve();
    },
  });
  assertEquals(completions, [["bad", false], ["good", true]]);
  assertEquals(result, { claimed: 2, completed: 1, failed: 1 });
});

Deno.test("rejects an unsafe batch size", async () => {
  await assertRejects(
    () => processMealPlanImageCleanup({
      claim: () => Promise.resolve([]),
      remove: () => Promise.resolve(),
      complete: () => Promise.resolve(),
    }, 0),
    Error,
    "invalid_cleanup_limit",
  );
});
