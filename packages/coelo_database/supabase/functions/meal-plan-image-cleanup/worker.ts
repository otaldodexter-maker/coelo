export interface MealPlanCleanupJob {
  request_id: string;
  asset_id: string;
  bucket: string;
  path: string;
  attempt: number;
}

export interface MealPlanCleanupStore {
  claim(limit: number): Promise<MealPlanCleanupJob[]>;
  remove(bucket: string, path: string): Promise<void>;
  complete(requestId: string, succeeded: boolean, error?: string): Promise<void>;
}

export async function processMealPlanImageCleanup(
  store: MealPlanCleanupStore,
  limit = 20,
): Promise<{ claimed: number; completed: number; failed: number }> {
  if (!Number.isInteger(limit) || limit < 1 || limit > 100) {
    throw new Error("invalid_cleanup_limit");
  }
  const jobs = await store.claim(limit);
  let completed = 0;
  let failed = 0;
  for (const job of jobs) {
    try {
      await store.remove(job.bucket, job.path);
      await store.complete(job.request_id, true);
      completed++;
    } catch (error) {
      failed++;
      const message = error instanceof Error ? error.message : "storage_deletion_failed";
      try {
        await store.complete(job.request_id, false, message);
      } catch {
        // The persisted claim will be recovered after its lease expires.
      }
    }
  }
  return { claimed: jobs.length, completed, failed };
}
