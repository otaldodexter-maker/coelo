import { assertEquals, assertThrows } from "@std/assert";
import { operationForJob } from "./operational_contract.ts";

const aggregateId = "11111111-1111-4111-8111-111111111111";

Deno.test("maps every short database operation to its service-only RPC", () => {
  assertEquals(operationForJob("generate_occurrences", aggregateId), {
    rpc: "form_worker_generate_occurrences",
    params: { p_schedule_id: aggregateId, p_horizon_days: 90 },
  });
  assertEquals(
    operationForJob("reconcile_audience", aggregateId)?.rpc,
    "form_worker_reconcile_audience",
  );
  assertEquals(
    operationForJob("materialize_metrics", aggregateId)?.rpc,
    "form_worker_rebuild_metrics",
  );
  assertEquals(operationForJob("enqueue_reminders", aggregateId)?.params, {
    p_horizon_seconds: 86_400,
  });
});

Deno.test("rejects forged aggregates and leaves export jobs to the exporter", () => {
  assertThrows(() => operationForJob("reconcile_audience", "not-an-id"));
  assertEquals(operationForJob("export_csv", aggregateId), null);
  assertEquals(operationForJob("unknown", aggregateId), null);
});
