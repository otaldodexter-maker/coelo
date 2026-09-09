import { createClient } from "@supabase/supabase-js";

import { MomentsR2Client, momentsR2Config } from "./r2_s3.ts";

/// Injected so the gateway is exercisable without booting the runtime or
/// reaching Supabase. Production keeps the real environment and client.
export type MomentsMediaDependencies = Readonly<{
  envGet: (name: string) => string | undefined;
  createClient: typeof createClient;
}>;

const productionDependencies: MomentsMediaDependencies = {
  envGet: (name) => Deno.env.get(name),
  createClient,
};

let dependencies: MomentsMediaDependencies = productionDependencies;

/// Matches the chat-media envelope. Nothing here needs a large body: the
/// requests carry ids and tickets, not content.
const maximumRequestBytes = 32_768;

type Json = Record<string, unknown>;
const allowedMimeTypes = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "video/mp4",
]);
const maximumBytes = 25 * 1024 * 1024;

function allowedOrigins() {
  return new Set(
    (dependencies.envGet("MOMENTS_MEDIA_ALLOWED_ORIGINS") ?? "")
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
  );
}

function reply(origin: string | null, status: number, body: Json) {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
    "Vary": "Origin",
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-worker-secret",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (origin !== null && allowedOrigins().has(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return new Response(JSON.stringify(body), { status, headers });
}

function environment() {
  return Object.fromEntries([
    "MOMENTS_R2_ENDPOINT",
    "MOMENTS_R2_REGION",
    "MOMENTS_R2_ACCESS_KEY_ID",
    "MOMENTS_R2_SECRET_ACCESS_KEY",
    "MOMENTS_R2_BUCKET",
  ].map((name) => [name, dependencies.envGet(name)]));
}

function requiredSecret(name: string) {
  const value = dependencies.envGet(name);
  if (!value) throw new Error("server_secret_unavailable");
  return value;
}

function requestId(value: unknown) {
  if (typeof value !== "string" || !/^[0-9a-f-]{36}$/i.test(value)) {
    throw new Error("invalid_request");
  }
  return value;
}

function mediaEnvelope(body: Json) {
  if (
    typeof body.institution_id !== "string" ||
    typeof body.publication_id !== "string" ||
    typeof body.name !== "string" || body.name.length < 1 ||
    body.name.length > 240 ||
    typeof body.mime_type !== "string" ||
    !allowedMimeTypes.has(body.mime_type) ||
    typeof body.size_bytes !== "number" ||
    !Number.isSafeInteger(body.size_bytes) ||
    body.size_bytes < 1 || body.size_bytes > maximumBytes ||
    typeof body.display_order !== "number" ||
    !Number.isInteger(body.display_order) ||
    body.display_order < 0 || body.display_order > 4
  ) throw new Error("invalid_request");
  const duration = body.duration_milliseconds;
  if (
    body.mime_type === "video/mp4" &&
    (typeof duration !== "number" || !Number.isSafeInteger(duration) ||
      duration < 1 || duration > 300000)
  ) throw new Error("invalid_request");
  if (body.mime_type !== "video/mp4" && duration != null) {
    throw new Error("invalid_request");
  }
  return {
    institutionId: body.institution_id,
    publicationId: body.publication_id,
    name: body.name,
    mimeType: body.mime_type,
    sizeBytes: body.size_bytes,
    displayOrder: body.display_order,
    durationMilliseconds: duration ?? null,
  };
}

export async function handleMomentsMediaRequest(
  request: Request,
  injected: MomentsMediaDependencies = productionDependencies,
): Promise<Response> {
  dependencies = injected;
  const origin = request.headers.get("origin");
  if (origin !== null && !allowedOrigins().has(origin)) {
    return reply(null, 403, { error: "origin_not_allowed" });
  }
  if (request.method === "OPTIONS") return reply(origin, 200, { ok: true });
  if (request.method !== "POST") {
    return reply(origin, 405, { error: "method_not_allowed" });
  }

  let body: Json;
  try {
    const raw = await request.text();
    // Same envelope the sibling chat-media enforces, and measured in bytes for
    // the same reason: `raw.length` counts UTF-16 code units, so accented or
    // emoji-heavy content would slip through at several times the cap.
    if (new TextEncoder().encode(raw).length > maximumRequestBytes) {
      return reply(origin, 413, { error: "request_too_large" });
    }
    const parsed = JSON.parse(raw) as unknown;
    // A list, a bare string or null is not a request. Without this the first
    // property read throws and the caller gets a generic gateway failure
    // instead of being told the request itself was malformed.
    if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
      return reply(origin, 400, { error: "invalid_request" });
    }
    body = parsed as Json;
  } catch {
    return reply(origin, 400, { error: "invalid_request" });
  }

  try {
    const url = requiredSecret("SUPABASE_URL");
    const admin = dependencies.createClient(
      url,
      requiredSecret("SUPABASE_SERVICE_ROLE_KEY"),
      {
        auth: { persistSession: false },
      },
    );
    const r2 = new MomentsR2Client(momentsR2Config(environment()));

    if (body.action === "cleanup") {
      if (
        request.headers.get("x-worker-secret") !==
          requiredSecret("MOMENTS_MEDIA_WORKER_SECRET")
      ) {
        return reply(origin, 401, { error: "authentication_required" });
      }
      const claimed = await admin.rpc("claim_stale_moments_media", {
        p_limit: 50,
      });
      if (claimed.error) throw new Error("cleanup_claim_failed");
      let deleted = 0;
      for (const raw of claimed.data as Json[]) {
        await r2.delete(String(raw.object_key));
        const marked = await admin.rpc("mark_moments_media_deleted", {
          p_asset_id: raw.asset_id,
        });
        if (marked.error) throw new Error("cleanup_finalize_failed");
        deleted++;
      }
      return reply(origin, 200, { deleted });
    }

    const authorization = request.headers.get("authorization");
    if (!authorization?.startsWith("Bearer ")) {
      return reply(origin, 401, { error: "authentication_required" });
    }
    const user = dependencies.createClient(url, requiredSecret("SUPABASE_ANON_KEY"), {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    const identity = await user.auth.getUser();
    if (identity.error || !identity.data.user) {
      return reply(origin, 401, { error: "authentication_required" });
    }

    if (body.action === "read") {
      // Two distinct readers, never interchangeable. A viewer redeems an opaque
      // single-use ticket that the feed issued for them; an author addresses
      // their own draft asset. Sending both is a malformed request, not a
      // choice, so neither path can be used to probe the other.
      const hasTicket = typeof body.read_ticket === "string" &&
        body.read_ticket.length > 0;
      const hasAsset = typeof body.asset_id === "string" && body.asset_id.length > 0;
      if (hasTicket === hasAsset) throw new Error("invalid_request");

      if (hasTicket) {
        // Redeeming is service_role only and consumes the ticket, so a replay
        // of the same token finds nothing.
        const redeemed = await admin.rpc("redeem_moments_media_read_ticket", {
          p_ticket: body.read_ticket,
          p_viewer_auth_user_id: identity.data.user.id,
        });
        if (redeemed.error) {
          return reply(origin, 403, { error: "media_read_denied" });
        }
        const descriptor = redeemed.data as Json;
        if (typeof descriptor?.object_key !== "string") {
          return reply(origin, 403, { error: "media_read_denied" });
        }
        const signed = await r2.presignGet(String(descriptor.object_key), 120);
        return reply(origin, 200, {
          signed_url: signed.url.toString(),
          mime_type: descriptor.mime_type,
          expires_in: 120,
        });
      }

      const authorized = await user.rpc("authorize_moments_media_read", {
        p_asset_id: body.asset_id,
      });
      if (authorized.error) {
        return reply(origin, 403, { error: "media_read_denied" });
      }
      const descriptor = authorized.data as Json;
      const signed = await r2.presignGet(String(descriptor.object_key), 120);
      return reply(origin, 200, {
        signed_url: signed.url.toString(),
        mime_type: descriptor.mime_type,
        expires_in: 120,
      });
    }

    const input = mediaEnvelope(body);
    const operationId = requestId(body.request_id);
    const prepared = await user.rpc("prepare_moments_media_upload", {
      p_request_id: operationId,
      p_institution_id: input.institutionId,
      p_publication_id: input.publicationId,
      p_name: input.name,
      p_mime_type: input.mimeType,
      p_byte_size: input.sizeBytes,
      p_duration_milliseconds: input.durationMilliseconds,
    });
    if (prepared.error) {
      return reply(origin, 403, { error: "media_prepare_denied" });
    }
    const descriptor = prepared.data as Json;

    if (body.action === "prepare") {
      const signed = await r2.presignPut(
        String(descriptor.object_key),
        input.mimeType,
        300,
      );
      return reply(origin, 200, {
        asset_id: descriptor.asset_id,
        object_key: descriptor.object_key,
        upload_url: signed.url.toString(),
        required_headers: signed.requiredHeaders,
        expires_at: new Date(Date.now() + 300_000).toISOString(),
        receipt_id: descriptor.receipt_id,
      });
    }

    if (body.action === "finalize") {
      if (body.asset_id !== descriptor.asset_id) {
        throw new Error("media_receipt_mismatch");
      }
      const stored = await r2.head(String(descriptor.object_key));
      if (
        stored.byteSize !== descriptor.expected_byte_size ||
        stored.mimeType !== descriptor.expected_mime_type
      ) {
        throw new Error("uploaded_media_mismatch");
      }
      const authorizationTicket = await user.rpc(
        "authorize_moments_media_finalize",
        { p_asset_id: descriptor.asset_id },
      );
      if (authorizationTicket.error) {
        return reply(origin, 403, { error: "media_finalize_denied" });
      }
      const finalizeAuthorization = authorizationTicket.data as Json;
      const finalized = await admin.rpc("finalize_moments_media_upload", {
        p_request_id: requestId(body.finalize_request_id),
        p_asset_id: descriptor.asset_id,
        p_finalize_ticket: finalizeAuthorization.finalize_ticket,
        p_expected_byte_size: stored.byteSize,
        p_expected_mime_type: stored.mimeType,
        p_checksum_sha256: typeof body.checksum_sha256 === "string"
          ? body.checksum_sha256
          : null,
        p_etag: stored.etag ?? null,
        p_display_order: input.displayOrder,
      });
      if (finalized.error) throw new Error("media_finalize_failed");
      return reply(origin, 200, finalized.data as Json);
    }
    return reply(origin, 400, { error: "invalid_request" });
  } catch (error) {
    return reply(origin, 422, {
      error: error instanceof Error ? error.message : "media_gateway_failure",
    });
  } finally {
    dependencies = productionDependencies;
  }
}

if (import.meta.main) {
  Deno.serve((request) => handleMomentsMediaRequest(request));
}
