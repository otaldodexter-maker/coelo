import { createClient } from "@supabase/supabase-js";

import { validateCircularMediaEnvelope } from "./media_contract.ts";

type Json = Record<string, unknown>;
const maximumRequestBytes = 32_768;

export type CircularMediaDependencies = Readonly<{
  envGet: (name: string) => string | undefined;
  createClient: typeof createClient;
}>;

const productionDependencies: CircularMediaDependencies = {
  envGet: (name) => Deno.env.get(name),
  createClient,
};

function requiredSecret(
  dependencies: CircularMediaDependencies,
  name: string,
) {
  const value = dependencies.envGet(name)?.trim();
  if (!value) throw new Error("server_secret_unavailable");
  return value;
}

function allowedOrigins(dependencies: CircularMediaDependencies) {
  return new Set(
    (dependencies.envGet("CIRCULAR_MEDIA_ALLOWED_ORIGINS") ?? "")
      .split(",").map((value) => value.trim()).filter(Boolean),
  );
}

function reply(
  origins: ReadonlySet<string>,
  origin: string | null,
  status: number,
  body: Json,
) {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
    "Vary": "Origin",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (origin !== null && origins.has(origin)) {
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

export async function handleCircularMediaRequest(
  request: Request,
  dependencies: CircularMediaDependencies = productionDependencies,
) {
  const origins = allowedOrigins(dependencies);
  const respond = (origin: string | null, status: number, body: Json) =>
    reply(origins, origin, status, body);
  const origin = request.headers.get("origin");
  if (origin !== null && !origins.has(origin)) {
    return respond(null, 403, { error: "origin_not_allowed" });
  }
  if (request.method === "OPTIONS") return respond(origin, 200, { ok: true });
  if (request.method !== "POST") {
    return respond(origin, 405, { error: "method_not_allowed" });
  }

  try {
    const declaredLength = request.headers.get("content-length");
    if (declaredLength !== null) {
      const parsedLength = Number(declaredLength);
      if (
        !Number.isSafeInteger(parsedLength) || parsedLength < 0 ||
        parsedLength > maximumRequestBytes
      ) {
        return respond(origin, 413, { error: "request_too_large" });
      }
    }
    const contentType = request.headers.get("content-type")
      ?.split(";", 1)[0].trim().toLowerCase();
    if (contentType !== "application/json") {
      return respond(origin, 415, { error: "unsupported_media_type" });
    }

    const workerSecret = request.headers.get("x-worker-secret");
    const workerAuthenticated = workerSecret !== null;
    const authorization = request.headers.get("authorization");
    if (workerAuthenticated) {
      if (
        workerSecret !==
          requiredSecret(dependencies, "CIRCULAR_MEDIA_WORKER_SECRET")
      ) return respond(origin, 401, { error: "authentication_required" });
    } else if (!authorization?.startsWith("Bearer ")) {
      return respond(origin, 401, { error: "authentication_required" });
    }

    const rawBody = await request.text();
    if (new TextEncoder().encode(rawBody).length > maximumRequestBytes) {
      return respond(origin, 413, { error: "request_too_large" });
    }

    const userSession = workerAuthenticated ? null : await (async () => {
      const authenticatedUrl = requiredSecret(dependencies, "SUPABASE_URL");
      const client = dependencies.createClient(
        authenticatedUrl,
        requiredSecret(dependencies, "SUPABASE_ANON_KEY"),
        {
          global: { headers: { Authorization: authorization! } },
          auth: { persistSession: false },
        },
      );
      return {
        client,
        identity: await client.auth.getUser(),
        url: authenticatedUrl,
      };
    })();
    if (
      userSession !== null &&
      (userSession.identity.error || !userSession.identity.data.user)
    ) {
      return respond(origin, 401, { error: "authentication_required" });
    }
    const user = userSession?.client ?? null;
    let url = userSession?.url ?? null;

    let body: Json;
    try {
      body = JSON.parse(rawBody) as Json;
    } catch {
      throw new Error("invalid_request");
    }

    if (body.action === "cleanup") {
      if (!workerAuthenticated) {
        return respond(origin, 401, { error: "authentication_required" });
      }
      url ??= requiredSecret(dependencies, "SUPABASE_URL");
      const admin = dependencies.createClient(
        url,
        requiredSecret(dependencies, "SUPABASE_SERVICE_ROLE_KEY"),
        { auth: { persistSession: false } },
      );
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
      return respond(origin, 200, { deleted });
    }

    if (workerAuthenticated || user === null || url === null) {
      return respond(origin, 400, { error: "invalid_request" });
    }
    const admin = dependencies.createClient(
      url,
      requiredSecret(dependencies, "SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false } },
    );

    if (body.action === "read") {
      if (typeof body.asset_id !== "string") throw new Error("invalid_request");
      const authorized = await user.rpc("authorize_circular_media_read", {
        p_asset_id: body.asset_id,
      });
      if (authorized.error) {
        return respond(origin, 403, { error: "media_read_denied" });
      }
      const descriptor = authorized.data as Json;
      const signed = await admin.storage.from(String(descriptor.bucket_id))
        .createSignedUrl(String(descriptor.object_key), 120);
      if (signed.error) throw new Error("media_sign_failed");
      return respond(origin, 200, {
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
        return respond(origin, 403, { error: "media_delete_denied" });
      }
      const descriptor = removed.data as Json;
      const deletion = await admin.storage.from(String(descriptor.bucket_id))
        .remove([String(descriptor.object_key)]);
      if (deletion.error) throw new Error("media_delete_failed");
      const marked = await admin.rpc("mark_circular_media_deleted", {
        p_asset_id: body.asset_id,
      });
      if (marked.error) throw new Error("media_delete_finalize_failed");
      return respond(origin, 200, { asset_id: body.asset_id, deleted: true });
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
      return respond(origin, 403, { error: "media_prepare_denied" });
    }
    const descriptor = prepared.data as Json;

    if (body.action === "prepare") {
      if (descriptor.status === "ready") {
        return respond(origin, 200, {
          asset_id: descriptor.asset_id,
          already_uploaded: true,
        });
      }
      const signed = await admin.storage.from(String(descriptor.bucket_id))
        .createSignedUploadUrl(String(descriptor.object_key), {
          upsert: false,
        });
      if (signed.error) throw new Error("media_sign_failed");
      return respond(origin, 200, {
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
        return respond(origin, 200, {
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
        return respond(origin, 403, { error: "media_finalize_denied" });
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
      return respond(origin, 200, finalized.data as Json);
    }
    return respond(origin, 400, { error: "invalid_request" });
  } catch (error) {
    return respond(origin, 422, {
      error: error instanceof Error ? error.message : "media_gateway_failure",
    });
  }
}

if (import.meta.main) {
  Deno.serve((request) => handleCircularMediaRequest(request));
}
