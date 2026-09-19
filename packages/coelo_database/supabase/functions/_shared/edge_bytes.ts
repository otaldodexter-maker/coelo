// Bytes de mídia pela Edge (mesmo desenho do entity-media): o navegador nunca fala com o R2,
// então o CORS do bucket não entra na conta. Upload binário = POST application/octet-stream com
// o envelope JSON (os mesmos campos do "prepare"/"finalize") em base64url no cabeçalho
// `x-coelo-media-envelope`; leitura inline = resposta application/octet-stream com o MIME real
// em `X-Coelo-Content-Type`.
export const envelopeHeader = "x-coelo-media-envelope";
export const contentTypeHeader = "X-Coelo-Content-Type";
export const maximumEnvelopeBytes = 8 * 1024;

type Json = Record<string, unknown>;

export function isBinaryUpload(request: Request) {
  return (request.headers.get("content-type") ?? "").toLowerCase().startsWith("application/octet-stream");
}

/** Envelope do upload binário; `action` vira "upload" sempre. */
export function decodeEnvelope(request: Request): Json {
  const raw = request.headers.get(envelopeHeader);
  if (!raw || raw.length > maximumEnvelopeBytes) throw new Error("invalid_request");
  let text: string;
  try {
    const base64 = raw.replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64 + "=".repeat((4 - (base64.length % 4)) % 4);
    text = new TextDecoder("utf-8", { fatal: true }).decode(Uint8Array.from(atob(padded), (c) => c.charCodeAt(0)));
  } catch {
    throw new Error("invalid_request");
  }
  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    throw new Error("invalid_request");
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) throw new Error("invalid_request");
  return { ...(body as Json), action: "upload" };
}

export function encodeEnvelope(body: Json) {
  const bytes = new TextEncoder().encode(JSON.stringify(body));
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** Lê o corpo binário respeitando o tamanho declarado (+1 para detectar excesso). */
export async function readUploadBytes(request: Request, declaredBytes: number): Promise<Uint8Array> {
  const bytes = new Uint8Array(await request.arrayBuffer());
  if (bytes.byteLength !== declaredBytes) throw new Error("uploaded_media_mismatch");
  return bytes;
}

export function bytesResponse(headers: Record<string, string>, bytes: Uint8Array, contentType: string) {
  return new Response(bytes.slice().buffer as ArrayBuffer, {
    status: 200,
    headers: {
      ...headers,
      "Content-Type": "application/octet-stream",
      [contentTypeHeader]: contentType,
      "Access-Control-Expose-Headers": contentTypeHeader,
    },
  });
}
