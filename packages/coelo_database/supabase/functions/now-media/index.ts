import { createClient } from "@supabase/supabase-js";

const BUCKET = "coelo-now-mvp";
const MAX_BYTES = 25 * 1024 * 1024;
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
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(status: number, body: Json) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

function secret() {
  const value = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!value) throw new Error("server_secret_unavailable");
  return value;
}

function decode(value: unknown) {
  if (
    typeof value !== "string" ||
    value.length > Math.ceil(MAX_BYTES * 4 / 3) + 16
  ) {
    throw new Error("invalid_asset_payload");
  }
  const binary = atob(value);
  if (!binary.length || binary.length > MAX_BYTES) {
    throw new Error("invalid_asset_size");
  }
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
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
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS });
  }
  if (request.method !== "POST") {
    return reply(405, { error: "method_not_allowed" });
  }
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return reply(401, { error: "authentication_required" });
  }
  let uploaded: string | null = null;
  let preparedAssetId: string | null = null;
  try {
    const body = await request.json() as Json;
    if (body.action !== "upload") {
      return reply(400, { error: "invalid_request" });
    }
    if (
      typeof body.publication_id !== "string" ||
      typeof body.institution_id !== "string" ||
      typeof body.kind !== "string" ||
      !["media", "audio", "cover"].includes(body.kind) ||
      typeof body.name !== "string" || typeof body.mime_type !== "string" ||
      !ALLOWED.has(body.mime_type)
    ) return reply(400, { error: "invalid_request" });

    const bytes = decode(body.content_base64);
    if (
      body.size_bytes !== bytes.length || !validSignature(bytes, body.mime_type)
    ) {
      throw new Error("invalid_asset_signature");
    }

    const url = Deno.env.get("SUPABASE_URL")!;
    const user = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authorization } },
    });
    const admin = createClient(url, secret(), {
      auth: { persistSession: false },
    });
    const prepared = await user.rpc("prepare_now_asset_upload", {
      p_institution_id: body.institution_id,
      p_publication_id: body.publication_id,
      p_kind: body.kind,
      p_name: body.name,
      p_mime_type: body.mime_type,
      p_byte_size: bytes.length,
      p_duration_seconds: body.duration_seconds,
      p_rights_confirmed: body.rights_confirmed === true,
    });
    if (prepared.error) throw new Error("asset_prepare_failed");
    const descriptor = prepared.data as Json;
    preparedAssetId = String(descriptor.asset_id);
    uploaded = String(descriptor.object_key);
    const upload = await admin.storage.from(BUCKET).upload(uploaded, bytes, {
      contentType: body.mime_type,
      cacheControl: "no-store",
      upsert: true,
    });
    if (upload.error) throw new Error("asset_upload_failed");
    const finalized = await user.rpc("finalize_now_asset_upload", {
      p_asset_id: descriptor.asset_id,
      p_checksum_sha256: await checksum(bytes),
    });
    if (finalized.error) throw new Error("asset_finalize_failed");
    uploaded = null;
    preparedAssetId = null;
    return reply(200, finalized.data as Json);
  } catch (error) {
    if (uploaded) {
      const admin = createClient(Deno.env.get("SUPABASE_URL")!, secret(), {
        auth: { persistSession: false },
      });
      await admin.storage.from(BUCKET).remove([uploaded]);
      if (preparedAssetId) {
        await admin.from("now_media_assets").delete().eq("id", preparedAssetId);
      }
    }
    return reply(422, {
      error: error instanceof Error ? error.message : "worker_error",
    });
  }
});
