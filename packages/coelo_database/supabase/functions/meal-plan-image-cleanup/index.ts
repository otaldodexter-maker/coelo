import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import { processMealPlanImageCleanup } from "./worker.ts";

function reply(status: number, body: Record<string, unknown>) {
  return Response.json(body, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return reply(405, { error: "method_not_allowed" });
  const expected = Deno.env.get("COELO_MEAL_PLAN_CLEANUP_SECRET");
  if (!expected || request.headers.get("x-coelo-worker-secret") !== expected) {
    return reply(401, { error: "unauthorized" });
  }
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return reply(503, { error: "worker_unavailable" });

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  try {
    const result = await processMealPlanImageCleanup({
      async claim(limit) {
        const response = await admin.rpc("meal_plan_claim_image_cleanup", {
          p_limit: limit,
        });
        if (response.error || !Array.isArray(response.data)) {
          throw new Error("cleanup_claim_failed");
        }
        return response.data;
      },
      async remove(bucket, path) {
        if (bucket !== "coelo-meal-plans-private") {
          throw new Error("invalid_cleanup_bucket");
        }
        const response = await admin.storage.from(bucket).remove([path]);
        if (response.error) throw new Error("storage_deletion_failed");
      },
      async complete(requestId, succeeded, error) {
        const response = await admin.rpc("meal_plan_complete_image_cleanup", {
          p_request_id: requestId,
          p_succeeded: succeeded,
          p_error: error ?? null,
        });
        if (response.error) throw new Error("cleanup_completion_failed");
      },
    });
    return reply(200, result);
  } catch {
    return reply(503, { error: "worker_unavailable" });
  }
});
