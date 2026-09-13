/**
 * Conferencia do conteudo realmente armazenado de um anexo do chat.
 *
 * O Content-Type do objeto no R2 e o que o cliente declarou no PUT assinado;
 * so os bytes provam o tipo. A leitura e limitada ao tamanho anunciado no
 * prepare e o sha256 real e calculado aqui para o finalize (service_role)
 * comparar com o anunciado. Objeto que nao corresponde e apagado do bucket.
 */

export type StoredBytesTransport = {
  get(key: string, maxBytes: number): Promise<Uint8Array>;
  delete(key: string): Promise<void>;
};

function text(bytes: Uint8Array, start: number, end: number) {
  return new TextDecoder().decode(bytes.slice(start, end));
}

function uint32(bytes: Uint8Array, offset: number) {
  return ((bytes[offset] << 24) | (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) | bytes[offset + 3]) >>> 0;
}

const mp4Brands = new Set([
  "isom", "iso2", "iso3", "iso4", "iso5", "iso6", "mp41", "mp42", "avc1", "dash", "msdh", "msix", "M4V ",
]);

function isMp4(bytes: Uint8Array) {
  // A complete upload is at most 10 MiB, so inspect every top-level ISO-BMFF
  // box rather than accepting an ftyp prefix supplied by an arbitrary file.
  if (bytes.length < 32 || uint32(bytes, 0) < 16 || text(bytes, 4, 8) !== "ftyp") return false;
  const ftypSize = uint32(bytes, 0);
  if (ftypSize > bytes.length || !mp4Brands.has(text(bytes, 8, 12))) return false;
  let offset = 0;
  let hasMoov = false;
  let hasMdat = false;
  while (offset < bytes.length) {
    if (bytes.length - offset < 8) return false;
    const size = uint32(bytes, offset);
    if (size < 8 || size > bytes.length - offset) return false;
    const type = text(bytes, offset + 4, offset + 8);
    if (type === "moov") hasMoov = true;
    if (type === "mdat") hasMdat = true;
    offset += size;
  }
  return offset === bytes.length && hasMoov && hasMdat;
}

/** Assinatura real dos tipos aceitos pelo chat privado, sem Stream. */
export function matchesDeclaredType(bytes: Uint8Array, mimeType: string) {
  if (mimeType === "image/jpeg") return bytes[0] === 0xff && bytes[1] === 0xd8;
  if (mimeType === "image/png") {
    return bytes.slice(0, 8).join(",") === "137,80,78,71,13,10,26,10";
  }
  if (mimeType === "image/webp") {
    return text(bytes, 0, 4) === "RIFF" && text(bytes, 8, 12) === "WEBP";
  }
  if (mimeType === "application/pdf") return text(bytes, 0, 5) === "%PDF-";
  if (mimeType === "video/mp4") return isMp4(bytes);
  return false;
}

export async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes.slice().buffer as ArrayBuffer);
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

export async function readStoredBytes(
  transport: StoredBytesTransport,
  objectKey: string,
  expectedByteSize: number,
  expectedMimeType: string,
): Promise<{ bytes: Uint8Array; sha256: string }> {
  if (!Number.isSafeInteger(expectedByteSize) || expectedByteSize < 1) {
    throw new Error("attachment_descriptor_invalid");
  }
  let bytes: Uint8Array;
  try {
    bytes = await transport.get(objectKey, expectedByteSize);
  } catch {
    throw new Error("uploaded_attachment_unreadable");
  }
  if (bytes.length !== expectedByteSize || !matchesDeclaredType(bytes, expectedMimeType)) {
    await transport.delete(objectKey).catch(() => {});
    throw new Error("uploaded_attachment_mismatch");
  }
  return { bytes, sha256: await sha256Hex(bytes) };
}
