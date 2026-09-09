// Chat attachment gateway, reserved locally by R01-C05-I007.
//
// The transport, the guards and the contract are real. The catalog branch is
// not: chat_attachment_metadata.message_id is NOT NULL, there is no staging
// table and the send RPC neither accepts attachments nor an empty body, and
// I007 keeps that SQL without reservation. So every operation that would need
// those RPCs answers `*_unavailable` with a named reason instead of pretending.
// A bridge is not a backend.
//
// Nothing here creates a parallel catalog, fabricates a message or a ready
// receipt, relaxes message_id, or invents a global person for internal
// authorship. R2 credentials never leave this function.

import { createClient } from "@supabase/supabase-js";

import { R2Client, validateR2Config } from "../_shared/r2_s3.ts";
import {
  measuredObjectMatches,
  validateChatMediaAssetRef,
  validateChatMediaAttempt,
  validateChatMediaBinding,
} from "./media_contract.ts";

type Json = Record<string, unknown>;

const maximumRequestBytes = 32_768;

export type ChatMediaDependencies = Readonly<{
  envGet: (name: string) => string | undefined;
  createClient: typeof createClient;
}>;

const productionDependencies: ChatMediaDependencies = {
  envGet: (name) => Deno.env.get(name),
  createClient,
};

function requiredSecret(dependencies: ChatMediaDependencies, name: string) {
  const value = dependencies.envGet(name)?.trim();
  if (!value) throw new Error("server_secret_unavailable");
  return value;
}

function allowedOrigins(dependencies: ChatMediaDependencies) {
  return new Set(
    (dependencies.envGet("CHAT_MEDIA_ALLOWED_ORIGINS") ?? "")
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
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  // Only a configured origin is ever reflected back.
  if (origin !== null && origins.has(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return new Response(JSON.stringify(body), { status, headers });
}

function r2Client(dependencies: ChatMediaDependencies) {
  return new R2Client(validateR2Config({
    endpoint: requiredSecret(dependencies, "COELO_R2_ENDPOINT"),
    region: dependencies.envGet("COELO_R2_REGION")?.trim() || "auto",
    accessKeyId: requiredSecret(dependencies, "COELO_R2_ACCESS_KEY_ID"),
    secretAccessKey: requiredSecret(dependencies, "COELO_R2_SECRET_ACCESS_KEY"),
    bucket: requiredSecret(dependencies, "COELO_R2_DOCUMENTS_BUCKET"),
  }));
}

/** Opaque, versioned key. It carries no file name and no person, so an operator
 * reading a bucket listing learns nothing about who wrote what. */
export function chatAttachmentObjectKey(
  conversationId: string,
  assetId: string,
): string {
  return `chat/${conversationId}/attachments/${assetId}/original`;
}

export async function handleChatMediaRequest(
  request: Request,
  dependencies: ChatMediaDependencies = productionDependencies,
): Promise<Response> {
  const origins = allowedOrigins(dependencies);
  const origin = request.headers.get("origin");
  if (origin !== null && !origins.has(origin)) {
    return reply(origins, null, 403, { error: "origin_not_allowed" });
  }
  if (request.method === "OPTIONS") return reply(origins, origin, 200, { ok: true });
  if (request.method !== "POST") {
    return reply(origins, origin, 405, { error: "method_not_allowed" });
  }
  const authorization = request.headers.get("authorization");
  // Shape only, and deliberately not more: this gateway reaches no data yet, so
  // there is nothing to authorise and no token to verify. The sibling
  // moments-media calls `auth.getUser()` right after this same check, because it
  // does reach data. Whoever wires the catalog branch here must add that
  // verification with it — passing this check is not being authenticated.
  if (!authorization?.startsWith("Bearer ")) {
    return reply(origins, origin, 401, { error: "authentication_required" });
  }

  let body: Json;
  try {
    const raw = await request.text();
    // Measured in bytes, which is what the limit is named for. `raw.length`
    // counts UTF-16 code units, so an accented or emoji-heavy payload would slip
    // through at up to three or four times the intended size.
    if (new TextEncoder().encode(raw).length > maximumRequestBytes) {
      return reply(origins, origin, 413, { error: "request_too_large" });
    }
    const parsed = JSON.parse(raw) as unknown;
    if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
      return reply(origins, origin, 400, { error: "invalid_request" });
    }
    body = parsed as Json;
  } catch {
    return reply(origins, origin, 400, { error: "invalid_request" });
  }

  try {
    switch (body.action) {
      case "prepare": {
        // Shape is validated before anything else so a malformed attempt never
        // reaches storage or the database.
        validateChatMediaAttempt(body);
        // Needs prepare_chat_media_upload, which does not exist: it would have
        // to reserve an asset row, and chat_attachment_metadata cannot hold one
        // without a message.
        return reply(origins, origin, 503, {
          error: "chat_media_prepare_unavailable",
          reason: "catalog_branch_missing",
        });
      }
      case "finalize": {
        validateChatMediaAssetRef(body);
        // Needs finalize_chat_media_upload. The measurement itself is ready:
        // measuredObjectMatches compares the stored object against what was
        // declared, and only the server may declare an asset ready.
        return reply(origins, origin, 503, {
          error: "chat_media_finalize_unavailable",
          reason: "catalog_branch_missing",
        });
      }
      case "bind": {
        validateChatMediaBinding(body);
        // Needs the send RPC to accept p_attachment_ids and an empty body when
        // an attachment is present, plus a staging branch for message_id.
        return reply(origins, origin, 503, {
          error: "chat_media_bind_unavailable",
          reason: "send_contract_missing",
        });
      }
      case "discard": {
        validateChatMediaAssetRef(body);
        // Discard marks the tombstone the table already models; it never
        // deletes metadata or audit. Needs its own RPC.
        return reply(origins, origin, 503, {
          error: "chat_media_discard_unavailable",
          reason: "catalog_branch_missing",
        });
      }
      case "read": {
        // Trimmed: a blank token is never an opaque ticket, and answering 503
        // for it would report a client bug as a server pendency.
        if (typeof body.read_ticket !== "string" || body.read_ticket.trim().length < 1) {
          return reply(origins, origin, 400, { error: "invalid_request" });
        }
        // Needs redeem_chat_media_read_ticket. Reading is deliberately ticket
        // based: an asset id from the client never addresses an object.
        return reply(origins, origin, 503, {
          error: "chat_media_read_unavailable",
          reason: "read_ticket_missing",
        });
      }
      default:
        return reply(origins, origin, 400, { error: "invalid_request" });
    }
  } catch (error) {
    if (error instanceof Error && error.message === "invalid_request") {
      return reply(origins, origin, 400, { error: "invalid_request" });
    }
    if (error instanceof Error && error.message === "server_secret_unavailable") {
      return reply(origins, origin, 500, { error: "server_secret_unavailable" });
    }
    return reply(origins, origin, 500, { error: "chat_media_failed" });
  }
}

// Exported so the reserved surface is exercisable without booting the runtime.
export const chatMediaInternals = { r2Client, allowedOrigins, measuredObjectMatches };

if (import.meta.main) Deno.serve((request) => handleChatMediaRequest(request));
