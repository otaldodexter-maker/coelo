import { createClient } from "@supabase/supabase-js";

const DEFAULT_MAX_BYTES = 10 * 1024 * 1024;
const ALLOWED = new Set(["image/jpeg", "image/png", "image/webp", "video/mp4"]);
type Json = Record<string, unknown>;

function maxBytes() {
  const value = Number(
    Deno.env.get("HAPPENS_MEDIA_MAX_BYTES") ?? DEFAULT_MAX_BYTES,
  );
  return Number.isSafeInteger(value) && value > 0 ? value : DEFAULT_MAX_BYTES;
}

function allowedOrigins() {
  return new Set(
    (Deno.env.get("HAPPENS_MEDIA_ALLOWED_ORIGINS") ?? "")
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
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (origin !== null && allowedOrigins().has(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return new Response(JSON.stringify(body), { status, headers });
}

function secret() {
  const value = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!value) throw new Error("server_secret_unavailable");
  return value;
}

function validSignature(bytes: Uint8Array, mime: string) {
  if (mime === "image/jpeg") return bytes[0] === 0xff && bytes[1] === 0xd8;
  if (mime === "image/png") {
    return bytes.slice(0, 8).join(",") === "137,80,78,71,13,10,26,10";
  }
  if (mime === "image/webp") {
    return new TextDecoder().decode(bytes.slice(0, 4)) === "RIFF" &&
      new TextDecoder().decode(bytes.slice(8, 12)) === "WEBP";
  }
  return mime === "video/mp4" &&
    new TextDecoder().decode(bytes.slice(4, 8)) === "ftyp";
}

async function checksum(bytes: Uint8Array) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    Uint8Array.from(bytes).buffer,
  );
  return [...new Uint8Array(digest)]
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("");
}

function uploadEnvelope(body: Json) {
  if (
    typeof body.request_id !== "string" || body.request_id.length < 1 ||
    body.request_id.length > 240 ||
    typeof body.institution_id !== "string" ||
    typeof body.post_id !== "string" ||
    typeof body.name !== "string" || body.name.length < 1 ||
    typeof body.mime_type !== "string" || !ALLOWED.has(body.mime_type) ||
    typeof body.size_bytes !== "number" ||
    !Number.isSafeInteger(body.size_bytes) ||
    body.size_bytes < 1 || body.size_bytes > maxBytes()
  ) throw new Error("invalid_request");
  return {
    requestId: body.request_id,
    institutionId: body.institution_id,
    postId: body.post_id,
    name: body.name,
    mimeType: body.mime_type,
    sizeBytes: body.size_bytes,
  };
}

Deno.serve(async (request) => {
  const origin = request.headers.get("origin");
  if (origin !== null && !allowedOrigins().has(origin)) {
    return reply(null, 403, { error: "origin_not_allowed" });
  }
  if (request.method === "OPTIONS") return reply(origin, 200, { ok: true });
  if (request.method !== "POST") {
    return reply(origin, 405, { error: "method_not_allowed" });
  }
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return reply(origin, 401, { error: "authentication_required" });
  }

  try {
    const body = await request.json() as Json;
    const url = Deno.env.get("SUPABASE_URL")!;
    const user = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authorization } },
    });
    const admin = createClient(url, secret(), {
      auth: { persistSession: false },
    });

    if (body.action === "read") {
      if (typeof body.read_ticket !== "string") {
        return reply(origin, 400, { error: "invalid_request" });
      }
      const identity = await user.auth.getUser();
      if (identity.error || !identity.data.user) {
        return reply(origin, 401, { error: "authentication_required" });
      }
      const redeemed = await admin.rpc("redeem_happens_media_read_ticket", {
        p_ticket: body.read_ticket,
        p_viewer_auth_user_id: identity.data.user.id,
      });
      if (redeemed.error) {
        return reply(origin, 403, { error: "media_read_denied" });
      }
      const descriptor = redeemed.data as Json;
      const signed = await admin.storage
        .from(String(descriptor.bucket_id))
        .createSignedUrl(String(descriptor.object_key), 60);
      if (signed.error) throw new Error("media_sign_failed");
      return reply(origin, 200, {
        signed_url: signed.data.signedUrl,
        mime_type: descriptor.mime_type,
        expires_in: 60,
      });
    }

    if (body.action === "prepare") {
      const input = uploadEnvelope(body);
      const prepared = await user.rpc("prepare_happens_media_upload", {
        p_request_id: input.requestId,
        p_institution_id: input.institutionId,
        p_post_id: input.postId,
        p_name: input.name,
        p_mime_type: input.mimeType,
        p_byte_size: input.sizeBytes,
      });
      if (prepared.error) throw new Error("media_prepare_failed");
      const descriptor = prepared.data as Json;
      const signed = await admin.storage
        .from(String(descriptor.bucket_id))
        .createSignedUploadUrl(String(descriptor.object_key), { upsert: true });
      if (signed.error) throw new Error("media_sign_failed");
      return reply(origin, 200, {
        asset_id: descriptor.asset_id,
        object_key: descriptor.object_key,
        upload_token: signed.data.token,
      });
    }

    if (body.action === "finalize") {
      const input = uploadEnvelope(body);
      if (
        typeof body.asset_id !== "string" ||
        typeof body.display_order !== "number" ||
        !Number.isInteger(body.display_order) || body.display_order < 0 ||
        body.display_order > 5
      ) return reply(origin, 400, { error: "invalid_request" });
      const authorized = await user.rpc("prepare_happens_media_upload", {
        p_request_id: input.requestId,
        p_institution_id: input.institutionId,
        p_post_id: input.postId,
        p_name: input.name,
        p_mime_type: input.mimeType,
        p_byte_size: input.sizeBytes,
      });
      if (authorized.error) throw new Error("media_finalize_denied");
      const descriptor = authorized.data as Json;
      if (descriptor.asset_id !== body.asset_id) {
        throw new Error("media_receipt_mismatch");
      }
      const stored = await admin.storage
        .from(String(descriptor.bucket_id))
        .download(String(descriptor.object_key));
      if (stored.error) throw new Error("media_upload_incomplete");
      const bytes = new Uint8Array(await stored.data.arrayBuffer());
      if (
        bytes.length !== input.sizeBytes ||
        !validSignature(bytes, input.mimeType)
      ) {
        await admin.storage
          .from(String(descriptor.bucket_id))
          .remove([String(descriptor.object_key)]);
        throw new Error("invalid_media_signature");
      }
      const finalized = await user.rpc("finalize_happens_media_upload", {
        p_asset_id: body.asset_id,
        p_post_id: input.postId,
        p_checksum_sha256: await checksum(bytes),
        p_display_order: body.display_order,
      });
      if (finalized.error) throw new Error("media_finalize_failed");
      return reply(origin, 200, finalized.data as Json);
    }

    if (body.action === "delete") {
      if (typeof body.asset_id !== "string") {
        return reply(origin, 400, { error: "invalid_request" });
      }
      const removed = await user.rpc("remove_happens_media", {
        p_asset_id: body.asset_id,
      });
      if (removed.error) throw new Error("media_delete_denied");
      const descriptor = removed.data as Json;
      const deletion = await admin.storage
        .from(String(descriptor.bucket_id))
        .remove([String(descriptor.object_key)]);
      if (deletion.error) throw new Error("media_delete_failed");
      return reply(origin, 200, { deleted: true });
    }
    return reply(origin, 400, { error: "invalid_request" });
  } catch (error) {
    return reply(origin, 422, {
      error: error instanceof Error ? error.message : "worker_error",
    });
  }
});
