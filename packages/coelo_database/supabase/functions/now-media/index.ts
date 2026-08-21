import { createClient } from "@supabase/supabase-js";

const BUCKET = "coelo-now-mvp";
const DEFAULT_MAX_BYTES = 25 * 1024 * 1024;
const ALLOWED = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "video/mp4",
  "audio/mpeg",
  "audio/mp4",
  "audio/wav",
  "audio/aac",
]);
type Json = Record<string, unknown>;

function maxBytes() {
  const value = Number(
    Deno.env.get("NOW_MEDIA_MAX_BYTES") ?? DEFAULT_MAX_BYTES,
  );
  return Number.isSafeInteger(value) && value > 0 ? value : DEFAULT_MAX_BYTES;
}

function allowedOrigins() {
  return new Set(
    (Deno.env.get("NOW_MEDIA_ALLOWED_ORIGINS") ?? "")
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
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (origin !== null && allowedOrigins().has(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return new Response(JSON.stringify(body), {
    status,
    headers,
  });
}

function secret() {
  const value = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!value) throw new Error("server_secret_unavailable");
  return value;
}

function uploadEnvelope(body: Json) {
  if (
    typeof body.request_id !== "string" || body.request_id.length < 1 ||
    body.request_id.length > 240 ||
    typeof body.publication_id !== "string" ||
    typeof body.institution_id !== "string" ||
    typeof body.kind !== "string" ||
    !["media", "audio", "cover"].includes(body.kind) ||
    typeof body.name !== "string" || body.name.length < 1 ||
    typeof body.mime_type !== "string" || !ALLOWED.has(body.mime_type) ||
    typeof body.size_bytes !== "number" ||
    !Number.isSafeInteger(body.size_bytes) ||
    body.size_bytes < 1 || body.size_bytes > maxBytes()
  ) {
    throw new Error("invalid_request");
  }
  return {
    requestId: body.request_id,
    publicationId: body.publication_id,
    institutionId: body.institution_id,
    kind: body.kind,
    name: body.name,
    mimeType: body.mime_type,
    sizeBytes: body.size_bytes,
    durationSeconds: body.duration_seconds,
    rightsConfirmed: body.rights_confirmed === true,
  };
}

function text(bytes: Uint8Array, start: number, end: number) {
  return new TextDecoder().decode(bytes.slice(start, end));
}

function validSignature(bytes: Uint8Array, mime: string) {
  if (mime === "image/jpeg") return bytes[0] === 0xff && bytes[1] === 0xd8;
  if (mime === "image/png") {
    return bytes.slice(0, 8).join(",") === "137,80,78,71,13,10,26,10";
  }
  if (mime === "image/webp") {
    return text(bytes, 0, 4) === "RIFF" && text(bytes, 8, 12) === "WEBP";
  }
  if (mime === "video/mp4" || mime === "audio/mp4") {
    return text(bytes, 4, 8) === "ftyp";
  }
  if (mime === "audio/mpeg") {
    return text(bytes, 0, 3) === "ID3" ||
      (bytes[0] === 0xff && (bytes[1] & 0xe0) === 0xe0);
  }
  if (mime === "audio/wav") {
    return text(bytes, 0, 4) === "RIFF" && text(bytes, 8, 12) === "WAVE";
  }
  if (mime === "audio/aac") {
    return bytes[0] === 0xff && (bytes[1] & 0xf6) === 0xf0;
  }
  return false;
}

async function checksum(bytes: Uint8Array) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    Uint8Array.from(bytes).buffer,
  );
  return [...new Uint8Array(digest)].map((value) =>
    value.toString(16).padStart(2, "0")
  ).join("");
}

Deno.serve(async (request) => {
  const origin = request.headers.get("origin");
  if (origin !== null && !allowedOrigins().has(origin)) {
    return reply(null, 403, { error: "origin_not_allowed" });
  }
  if (request.method === "OPTIONS") {
    return reply(origin, 200, { ok: true });
  }
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

    if (body.action === "read-draft") {
      if (
        typeof body.institution_id !== "string" ||
        typeof body.asset_id !== "string"
      ) return reply(origin, 400, { error: "invalid_request" });

      const authorized = await user.rpc("authorize_now_asset_read", {
        p_institution_id: body.institution_id,
        p_asset_id: body.asset_id,
      });
      if (authorized.error) throw new Error("asset_read_not_authorized");
      const descriptor = authorized.data as Json;
      if (
        descriptor.bucket_id !== BUCKET ||
        typeof descriptor.object_key !== "string"
      ) throw new Error("asset_read_not_authorized");

      const signed = await admin.storage.from(BUCKET).createSignedUrl(
        descriptor.object_key,
        60,
      );
      if (signed.error || !signed.data?.signedUrl) {
        throw new Error("asset_signing_failed");
      }
      return reply(origin, 200, {
        signed_url: signed.data.signedUrl,
        mime_type: descriptor.mime_type,
        expires_in: 60,
      });
    }

    if (body.action === "read") {
      if (typeof body.read_ticket !== "string") {
        return reply(origin, 400, { error: "invalid_request" });
      }
      const identity = await user.auth.getUser();
      if (identity.error || !identity.data.user) {
        return reply(origin, 401, { error: "authentication_required" });
      }
      const redeemed = await admin.rpc("redeem_now_media_read_ticket", {
        p_ticket: body.read_ticket,
        p_viewer_auth_user_id: identity.data.user.id,
      });
      if (redeemed.error) {
        return reply(origin, 403, { error: "media_read_denied" });
      }
      const descriptor = redeemed.data as Json;
      if (
        descriptor.bucket_id !== BUCKET ||
        typeof descriptor.object_key !== "string"
      ) throw new Error("media_read_denied");
      const signed = await admin.storage.from(BUCKET).createSignedUrl(
        descriptor.object_key,
        60,
      );
      if (signed.error || !signed.data?.signedUrl) {
        throw new Error("asset_signing_failed");
      }
      return reply(origin, 200, {
        signed_url: signed.data.signedUrl,
        mime_type: descriptor.mime_type,
        expires_in: 60,
      });
    }

    if (body.action === "prepare") {
      const input = uploadEnvelope(body);
      const prepared = await user.rpc("prepare_now_asset_upload", {
        p_institution_id: input.institutionId,
        p_publication_id: input.publicationId,
        p_kind: input.kind,
        p_name: input.name,
        p_mime_type: input.mimeType,
        p_byte_size: input.sizeBytes,
        p_duration_seconds: input.durationSeconds,
        p_rights_confirmed: input.rightsConfirmed,
      });
      if (prepared.error) throw new Error("asset_prepare_failed");
      const descriptor = prepared.data as Json;
      if (
        descriptor.bucket_id !== BUCKET ||
        typeof descriptor.asset_id !== "string" ||
        typeof descriptor.object_key !== "string"
      ) throw new Error("asset_prepare_failed");
      const signed = await admin.storage.from(BUCKET).createSignedUploadUrl(
        descriptor.object_key,
        { upsert: true },
      );
      if (signed.error) throw new Error("asset_signing_failed");
      return reply(origin, 200, {
        asset_id: descriptor.asset_id,
        object_key: descriptor.object_key,
        upload_token: signed.data.token,
      });
    }

    if (body.action === "finalize") {
      const input = uploadEnvelope(body);
      if (typeof body.asset_id !== "string") {
        return reply(origin, 400, { error: "invalid_request" });
      }
      const authorized = await user.rpc("prepare_now_asset_upload", {
        p_institution_id: input.institutionId,
        p_publication_id: input.publicationId,
        p_kind: input.kind,
        p_name: input.name,
        p_mime_type: input.mimeType,
        p_byte_size: input.sizeBytes,
        p_duration_seconds: input.durationSeconds,
        p_rights_confirmed: input.rightsConfirmed,
      });
      if (authorized.error) throw new Error("asset_finalize_denied");
      const descriptor = authorized.data as Json;
      if (
        descriptor.bucket_id !== BUCKET ||
        descriptor.asset_id !== body.asset_id ||
        typeof descriptor.object_key !== "string"
      ) {
        throw new Error("asset_receipt_mismatch");
      }
      const stored = await admin.storage.from(BUCKET).download(
        descriptor.object_key,
      );
      if (stored.error) throw new Error("asset_upload_incomplete");
      const bytes = new Uint8Array(await stored.data.arrayBuffer());
      if (
        bytes.length !== input.sizeBytes ||
        !validSignature(bytes, String(input.mimeType))
      ) {
        await admin.storage.from(BUCKET).remove([
          descriptor.object_key,
        ]);
        throw new Error("invalid_asset_signature");
      }
      const finalized = await user.rpc("finalize_now_asset_upload", {
        p_asset_id: body.asset_id,
        p_checksum_sha256: await checksum(bytes),
      });
      if (finalized.error) throw new Error("asset_finalize_failed");
      return reply(origin, 200, finalized.data as Json);
    }

    return reply(origin, 400, { error: "invalid_request" });
  } catch (error) {
    return reply(origin, 422, {
      error: error instanceof Error ? error.message : "worker_error",
    });
  }
});
