import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import { processNoticePublicationJobs } from "./worker.ts";

function reply(status: number, body: Record<string, unknown>) {
  return Response.json(body, { status, headers: { "Cache-Control": "no-store" } });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const expected = Deno.env.get("COELO_NOTICE_WORKER_SECRET");
  if (!expected || request.headers.get("x-coelo-worker-secret") !== expected) {
    return reply(401, { error: "unauthorized" });
  }
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return reply(503, { error: "worker_unavailable" });
  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  try {
    const result = await processNoticePublicationJobs({
      async claim(workerId, limit) {
        const response = await admin.rpc("claim_notice_publication_jobs_for_worker", {
          p_worker: workerId,
          p_limit: limit,
        });
        if (response.error || !Array.isArray(response.data)) throw new Error("claim_failed");
        return response.data.map((row) => ({ id: String(row.id) }));
      },
      async run(jobId, limit) {
        const response = await admin.rpc("run_notice_publication_job_for_worker", {
          p_job_id: jobId,
          p_limit: limit,
        });
        if (response.error || !response.data || typeof response.data !== "object") {
          throw new Error("materialization_failed");
        }
        return response.data as { state: "processing" | "completed" | "failed" };
      },
    }, crypto.randomUUID());
    return reply(200, result);
  } catch {
    return reply(503, { error: "worker_unavailable" });
  }
});
