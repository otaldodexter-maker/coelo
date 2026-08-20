const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const OPERATIONAL_JOB_KINDS = [
  "generate_occurrences",
  "reconcile_audience",
  "materialize_metrics",
  "enqueue_reminders",
] as const;

export type OperationalJobKind = typeof OPERATIONAL_JOB_KINDS[number];

export type OperationalCall = {
  rpc: string;
  params: Record<string, string | number>;
};

export function operationForJob(
  jobKind: unknown,
  aggregateId: unknown,
): OperationalCall | null {
  if (
    typeof jobKind !== "string" ||
    !OPERATIONAL_JOB_KINDS.includes(jobKind as OperationalJobKind)
  ) return null;
  if (typeof aggregateId !== "string" || !UUID.test(aggregateId)) {
    throw new Error("invalid_operational_aggregate");
  }
  switch (jobKind) {
    case "generate_occurrences":
      return {
        rpc: "form_worker_generate_occurrences",
        params: { p_schedule_id: aggregateId, p_horizon_days: 90 },
      };
    case "reconcile_audience":
      return {
        rpc: "form_worker_reconcile_audience",
        params: { p_occurrence_id: aggregateId },
      };
    case "materialize_metrics":
      return {
        rpc: "form_worker_rebuild_metrics",
        params: { p_occurrence_id: aggregateId },
      };
    case "enqueue_reminders":
      return {
        rpc: "form_worker_enqueue_reminders",
        params: { p_horizon_seconds: 86_400 },
      };
  }
  return null;
}
