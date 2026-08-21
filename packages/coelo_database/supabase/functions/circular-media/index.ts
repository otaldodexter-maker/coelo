import { createClient } from "@supabase/supabase-js";

import { validateCircularMediaEnvelope } from "./media_contract.ts";

type Json = Record<string, unknown>;

function requiredSecret(name: string) {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error("server_secret_unavailable");
  return value;
}

function allowedOrigins() {
  return new Set(
    (Deno.env.get("CIRCULAR_MEDIA_ALLOWED_ORIGINS") ?? "")
      .split(",").map((value) => value.trim()).filter(Boolean),
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

function operationId(value: unknown) {
  if (
    typeof value !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(value)
  ) {
    throw new Error("invalid_request");
  }
  return value;
}

function validSignature(bytes: Uint8Array, mimeType: string) {
  if (mimeType === "image/jpeg") return bytes[0] === 0xff && bytes[1] === 0xd8;
  if (mimeType === "image/png") {
    return bytes.slice(0, 8).join(",") === "137,80,78,71,13,10,26,10";
  }
  const text = new TextDecoder();
  if (mimeType === "image/webp") {
    return text.decode(bytes.slice(0, 4)) === "RIFF" &&
      text.decode(bytes.slice(8, 12)) === "WEBP";
  }
  if (mimeType === "video/mp4") {
    return text.decode(bytes.slice(4, 8)) === "ftyp";
  }
  return mimeType === "application/pdf" &&
    text.decode(bytes.slice(0, 5)) === "%PDF-";
}

async function checksum(bytes: Uint8Array) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    Uint8Array.from(bytes).buffer,
  );
  return [...new Uint8Array(digest)]
    .map((value) => value.toString(16).padStart(2, "0")).join("");
}

function validateExtension(name: string, mimeType: string) {
  const extension = name.toLowerCase().split(".").pop() ?? "";
  const allowed = new Map<string, ReadonlySet<string>>([
    ["image/jpeg", new Set(["jpg", "jpeg"])],
    ["image/png", new Set(["png"])],
    ["image/webp", new Set(["webp"])],
    ["video/mp4", new Set(["mp4"])],
    ["application/pdf", new Set(["pdf"])],
  ]);
  if (!allowed.get(mimeType)?.has(extension)) {
    throw new Error("media_extension_mismatch");
  }
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

  try {
    const body = await request.json() as Json;
    const url = requiredSecret("SUPABASE_URL");
    const admin = createClient(
      url,
      requiredSecret("SUPABASE_SERVICE_ROLE_KEY"),
      {
        auth: { persistSession: false },
      },
    );

    if (body.action === "cleanup") {
      if (
        request.headers.get("x-worker-secret") !==
          requiredSecret("CIRCULAR_MEDIA_WORKER_SECRET")
      ) return reply(origin, 401, { error: "authentication_required" });
      const claimed = await admin.rpc("claim_stale_circular_media", {
        p_limit: 50,
      });
      if (claimed.error) throw new Error("cleanup_claim_failed");
      let deleted = 0;
      for (const raw of claimed.data as Json[]) {
        const removal = await admin.storage.from("coelo-circulars-private")
          .remove([String(raw.object_key)]);
        if (removal.error) throw new Error("cleanup_storage_failed");
        const marked = await admin.rpc("mark_circular_media_deleted", {
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
    const user = createClient(url, requiredSecret("SUPABASE_ANON_KEY"), {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    const identity = await user.auth.getUser();
    if (identity.error || !identity.data.user) {
      return reply(origin, 401, { error: "authentication_required" });
    }

    if (body.action === "read") {
      if (typeof body.asset_id !== "string") throw new Error("invalid_request");
      const authorized = await user.rpc("authorize_circular_media_read", {
        p_asset_id: body.asset_id,
      });
      if (authorized.error) {
        return reply(origin, 403, { error: "media_read_denied" });
      }
      const descriptor = authorized.data as Json;
      const signed = await admin.storage.from(String(descriptor.bucket_id))
        .createSignedUrl(String(descriptor.object_key), 120);
      if (signed.error) throw new Error("media_sign_failed");
      return reply(origin, 200, {
        signed_url: signed.data.signedUrl,
        mime_type: descriptor.mime_type,
        expires_in: 120,
      });
    }

    if (body.action === "delete") {
      if (typeof body.asset_id !== "string") throw new Error("invalid_request");
      const removed = await user.rpc("remove_circular_media", {
        p_asset_id: body.asset_id,
      });
      if (removed.error) {
        return reply(origin, 403, { error: "media_delete_denied" });
      }
      const descriptor = removed.data as Json;
      const deletion = await admin.storage.from(String(descriptor.bucket_id))
        .remove([String(descriptor.object_key)]);
      if (deletion.error) throw new Error("media_delete_failed");
      const marked = await admin.rpc("mark_circular_media_deleted", {
        p_asset_id: body.asset_id,
      });
      if (marked.error) throw new Error("media_delete_finalize_failed");
      return reply(origin, 200, { asset_id: body.asset_id, deleted: true });
    }

    const input = validateCircularMediaEnvelope(body);
    validateExtension(input.name, input.mimeType);
    const prepared = await user.rpc("prepare_circular_media_upload", {
      p_request_id: operationId(body.request_id),
      p_institution_id: input.institutionId,
      p_circular_id: input.circularId,
      p_name: input.name,
      p_mime_type: input.mimeType,
      p_byte_size: input.sizeBytes,
    });
    if (prepared.error) {
      return reply(origin, 403, { error: "media_prepare_denied" });
    }
    const descriptor = prepared.data as Json;

    if (body.action === "prepare") {
      if (descriptor.status === "ready") {
        return reply(origin, 200, {
          asset_id: descriptor.asset_id,
          already_uploaded: true,
        });
      }
      const signed = await admin.storage.from(String(descriptor.bucket_id))
        .createSignedUploadUrl(String(descriptor.object_key), {
          upsert: false,
        });
      if (signed.error) throw new Error("media_sign_failed");
      return reply(origin, 200, {
        asset_id: descriptor.asset_id,
        upload_url: signed.data.signedUrl,
        upload_token: signed.data.token,
        required_headers: { "content-type": input.mimeType },
        expires_at: new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString(),
      });
    }

    if (body.action === "finalize") {
      if (body.asset_id !== descriptor.asset_id) {
        throw new Error("media_receipt_mismatch");
      }
      if (descriptor.status === "ready") {
        return reply(origin, 200, {
          asset_id: descriptor.asset_id,
          status: "ready",
        });
      }
      const stored = await admin.storage.from(String(descriptor.bucket_id))
        .download(String(descriptor.object_key));
      if (stored.error) throw new Error("media_upload_incomplete");
      const bytes = new Uint8Array(await stored.data.arrayBuffer());
      if (
        bytes.length !== input.sizeBytes ||
        !validSignature(bytes, input.mimeType)
      ) {
        await admin.storage.from(String(descriptor.bucket_id))
          .remove([String(descriptor.object_key)]);
        throw new Error("invalid_media_signature");
      }
      const ticket = await user.rpc("authorize_circular_media_finalize", {
        p_asset_id: descriptor.asset_id,
      });
      if (ticket.error) {
        return reply(origin, 403, { error: "media_finalize_denied" });
      }
      const finalized = await admin.rpc("finalize_circular_media_upload", {
        p_asset_id: descriptor.asset_id,
        p_finalize_ticket: (ticket.data as Json).finalize_ticket,
        p_expected_byte_size: bytes.length,
        p_expected_mime_type: input.mimeType,
        p_checksum_sha256: await checksum(bytes),
        p_etag: null,
      });
      if (finalized.error) throw new Error("media_finalize_failed");
      return reply(origin, 200, finalized.data as Json);
    }
    return reply(origin, 400, { error: "invalid_request" });
  } catch (error) {
    return reply(origin, 422, {
      error: error instanceof Error ? error.message : "media_gateway_failure",
    });
  }
});
