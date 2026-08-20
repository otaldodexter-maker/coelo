export type PublicationState = "processing" | "completed" | "failed";

export interface NoticePublicationStore {
  claim(workerId: string, limit: number): Promise<Array<{ id: string }>>;
  run(jobId: string, limit: number): Promise<{ state: PublicationState }>;
}

export async function processNoticePublicationJobs(
  store: NoticePublicationStore,
  workerId: string,
): Promise<{ claimed: number; completed: number; failed: number }> {
  if (!workerId.trim()) throw new Error("worker_id_required");
  const jobs = await store.claim(workerId, 20);
  let completed = 0;
  let failed = 0;
  for (const job of jobs) {
    try {
      let state: PublicationState = "processing";
      for (let page = 0; state === "processing" && page < 1000; page++) {
        state = (await store.run(job.id, 1000)).state;
      }
      if (state === "completed") completed++;
      else failed++;
    } catch {
      failed++;
    }
  }
  return { claimed: jobs.length, completed, failed };
}
