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
  if (mimeType === "video/mp4") {
    return bytes.length >= 12 && text(bytes, 4, 8) === "ftyp";
  }
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
