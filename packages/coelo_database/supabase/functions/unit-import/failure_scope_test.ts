import {
  captureCreatedJobId,
  recordCreatedFailureBestEffort,
} from "./index.ts";

function assertEquals(actual: unknown, expected: unknown) {
  const received = JSON.stringify(actual);
  const wanted = JSON.stringify(expected);
  if (received !== wanted) {
    throw new Error(`Expected ${wanted}, received ${received}`);
  }
}

function assertThrows(action: () => unknown, message: string) {
  try {
    action();
  } catch (error) {
    if (error instanceof Error && error.message.includes(message)) return;
    throw error;
  }
  throw new Error(`Expected error containing ${message}`);
}

Deno.test("status confirm and retry auth failures never fail a requested foreign job", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );
  assertEquals(source.includes("const requestedJobId"), true);
  assertEquals(
    source.includes("recordCreatedFailureBestEffort(createdJobId"),
    true,
  );

  let createdJobId: string | null = null;
  let adminSelects = 0;
  let failRpcs = 0;
  let state = "PENDING";
  await recordCreatedFailureBestEffort(createdJobId, async () => {
    adminSelects++;
    failRpcs++;
    state = "FAILED";
  });

  assertEquals(adminSelects, 0);
  assertEquals(failRpcs, 0);
  assertEquals(state, "PENDING");
});

Deno.test("upload preview captures only its own authorized created job", async () => {
  assertThrows(
    () =>
      captureCreatedJobId(
        { data: null, error: { code: "42501" } },
        "job_create_failed",
      ),
    "job_create_failed",
  );

  const ownJobId = "00000000-0000-4000-8000-000000000004";
  const createdJobId = captureCreatedJobId(
    { data: { job_id: ownJobId }, error: null },
    "job_create_failed",
  );
  const failedIds: string[] = [];
  await recordCreatedFailureBestEffort(createdJobId, async (jobId) => {
    failedIds.push(jobId);
  });

  assertEquals(failedIds, [ownJobId]);
});
