import { createClient } from "@supabase/supabase-js";
import {
  allowedOrigin,
  corsHeaders,
  FORMS_BUCKET,
  handleCorsPreflight,
  MAX_IMAGE_BYTES,
  opaqueStoragePath,
  parseAssetAccess,
  parsePrepareAsset,
  sha256,
  shouldVerifyFinalization,
  sniffImageMime,
  workerFinalizationSucceeded,
} from "./media_contract.ts";

type Json = Record<string, unknown>;

function response(origin: string | null, status: number, body: Json): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
      "referrer-policy": "no-referrer",
      ...corsHeaders(origin),
    },
  });
}

function serviceKey(): string {
  const configured = Deno.env.get("SUPABASE_SECRET_KEYS") ?? "";
  if (configured.startsWith("{")) {
    try {
      const values = JSON.parse(configured) as Record<string, string>;
      if (values.default) return values.default;
    } catch {
      return "";
    }
  }
  return configured.split(",").map((value) => value.trim()).find(Boolean) ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
}

Deno.serve(async (request) => {
  const origin = allowedOrigin(
    request,
    Deno.env.get("COELO_ALLOWED_ORIGINS") ?? "",
  );
  const preflight = handleCorsPreflight(request, origin);
  if (preflight) return preflight;
  if (request.headers.has("origin") && !origin) {
    return response(origin, 403, { error: "request_denied" });
  }
  if (request.method !== "POST") {
    return response(origin, 405, { error: "method_not_allowed" });
  }
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const service = serviceKey();
  const authorization = request.headers.get("authorization") ?? "";
  if (!url || !anon || !service || !authorization.startsWith("Bearer ")) {
    return response(origin, 401, { error: "unauthorized" });
  }
  const userClient = createClient(url, anon, {
    global: { headers: { Authorization: authorization } },
  });
  const serviceClient = createClient(url, service, {
    auth: { persistSession: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return response(origin, 401, { error: "unauthorized" });
  }
  const actorLookup = await serviceClient.from("person_auth_links").select(
    "person_id",
  )
    .eq("auth_user_id", userData.user.id).eq("status", "active").maybeSingle();
  const actorPersonId = actorLookup.data?.person_id;
  if (actorLookup.error || typeof actorPersonId !== "string") {
    return response(origin, 401, { error: "unauthorized" });
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return response(origin, 400, { error: "invalid_json" });
  }
  const action = body.action;
  const requestId = body.request_id;
  const expectedVersion = body.expected_version;
  if (
    typeof action !== "string" || typeof requestId !== "string" ||
    typeof expectedVersion !== "number"
  ) {
    return response(origin, 400, { error: "invalid_envelope" });
  }

  try {
    if (action === "prepare") {
      const payload = parsePrepareAsset(body.payload);
      const { data, error } = await userClient.rpc(
        "form_prepare_asset_upload",
        {
          p_request_id: requestId,
          p_expected_version: expectedVersion,
          p_payload: payload,
        },
      );
      if (error || !data || !opaqueStoragePath(data.storage_path)) {
        throw new Error("prepare_failed");
      }
      const signed = await serviceClient.storage.from(FORMS_BUCKET)
        .createSignedUploadUrl(data.storage_path);
      if (signed.error || !signed.data) throw new Error("sign_failed");
      return response(origin, 200, {
        asset_id: data.asset_id,
        signed_upload_url: signed.data.signedUrl,
        upload_token: signed.data.token,
        expires_at: data.expires_at,
      });
    }
    if (action === "finalize") {
      const payload = parseAssetAccess(body.payload);
      const queued = await userClient.rpc("form_finalize_asset_upload", {
        p_request_id: requestId,
        p_expected_version: expectedVersion,
        p_payload: payload,
      });
      if (queued.error) throw new Error("finalize_failed");
      const { data: metadata, error: authError } = await serviceClient.rpc(
        "form_media_authorize_for_worker",
        {
          p_asset_id: payload.asset_id,
          p_actor_person_id: actorPersonId,
          p_edit_secret: payload.edit_secret,
        },
      );
      if (authError || !metadata || !opaqueStoragePath(metadata.storage_path)) {
        throw new Error("asset_unavailable");
      }
      if (!shouldVerifyFinalization(metadata.state)) {
        return response(origin, 200, {
          asset_id: payload.asset_id,
          state: "finalized",
        });
      }
      const downloaded = await serviceClient.storage.from(FORMS_BUCKET)
        .download(metadata.storage_path);
      if (
        downloaded.error || !downloaded.data ||
        downloaded.data.size > MAX_IMAGE_BYTES
      ) {
        throw new Error("asset_unavailable");
      }
      const bytes = new Uint8Array(await downloaded.data.arrayBuffer());
      const actualMimeType = sniffImageMime(bytes) ??
        "application/octet-stream";
      const finalized = await serviceClient.rpc("form_worker_finalize_asset", {
        p_asset_id: payload.asset_id,
        p_actual_byte_length: bytes.byteLength,
        p_actual_mime_type: actualMimeType,
        p_actual_checksum_sha256: await sha256(bytes),
      });
      if (finalized.error) throw new Error("verification_failed");
      if (!workerFinalizationSucceeded(finalized.data)) {
        throw new Error("verification_failed");
      }
      return response(origin, 200, finalized.data as Json);
    }
    if (action === "download") {
      const payload = parseAssetAccess(body.payload);
      const authorized = await serviceClient.rpc(
        "form_media_authorize_for_worker",
        {
          p_asset_id: payload.asset_id,
          p_actor_person_id: actorPersonId,
          p_edit_secret: payload.edit_secret,
        },
      );
      if (
        authorized.error || !authorized.data ||
        !opaqueStoragePath(authorized.data.storage_path)
      ) {
        throw new Error("asset_unavailable");
      }
      if (authorized.data.state !== "finalized") {
        throw new Error("asset_unavailable");
      }
      const signed = await serviceClient.storage.from(FORMS_BUCKET)
        .createSignedUrl(
          authorized.data.storage_path,
          60,
        );
      if (signed.error || !signed.data) throw new Error("sign_failed");
      return response(origin, 200, {
        signed_url: signed.data.signedUrl,
        expires_in: 60,
      });
    }
    if (action === "discard") {
      const payload = parseAssetAccess(body.payload);
      const discarded = await userClient.rpc("form_discard_asset", {
        p_request_id: requestId,
        p_expected_version: expectedVersion,
        p_payload: payload,
      });
      if (discarded.error) throw new Error("discard_failed");
      return response(origin, 200, discarded.data as Json);
    }
    return response(origin, 400, { error: "unknown_action" });
  } catch (error) {
    return response(origin, 400, {
      error: error instanceof Error ? error.message : "unknown",
    });
  }
});
