import { assertEquals } from "jsr:@std/assert@1.0.14";
import { processNoticePublicationJobs } from "./worker.ts";

Deno.test("materializes a publication until completion", async () => {
  let pages = 0;
  const result = await processNoticePublicationJobs({
    claim: () => Promise.resolve([{ id: "job-1" }]),
    run: () => Promise.resolve({ state: ++pages === 1 ? "processing" : "completed" }),
  }, "worker-1");
  assertEquals(pages, 2);
  assertEquals(result, { claimed: 1, completed: 1, failed: 0 });
});

Deno.test("isolates a failed job and continues the claimed batch", async () => {
  const attempted: string[] = [];
  const result = await processNoticePublicationJobs({
    claim: () => Promise.resolve([{ id: "job-1" }, { id: "job-2" }]),
    run: (id) => {
      attempted.push(id);
      return id === "job-1" ? Promise.reject(new Error("transient")) : Promise.resolve({ state: "completed" });
    },
  }, "worker-1");
  assertEquals(attempted, ["job-1", "job-2"]);
  assertEquals(result, { claimed: 2, completed: 1, failed: 1 });
});
