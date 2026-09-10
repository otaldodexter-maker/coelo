/**
 * Conferencia do conteudo realmente armazenado de um Momento.
 *
 * A finalizacao conferia apenas metadados: tamanho e Content-Type devolvidos
 * por um HEAD no objeto. O Content-Type de um objeto no R2 e o que o proprio
 * cliente declarou no PUT assinado, entao esse par nao diz nada sobre os bytes:
 * bastava enviar qualquer conteudo anunciando `image/png` do tamanho declarado
 * para o ativo ser finalizado como imagem pronta. A ADR 0032 exige MIME real
 * conferido nos bytes, e as outras superficies de midia do Coelo ja faziam
 * isso.
 *
 * A leitura e limitada ao tamanho ja esperado, e um objeto que nao corresponde
 * ao tipo declarado e APAGADO antes de a funcao falhar, para nao deixar lixo
 * nao identificado no bucket privado.
 */

export type StoredBytesTransport = {
  get(key: string, maxBytes: number): Promise<Uint8Array>;
  delete(key: string): Promise<void>;
};

function text(bytes: Uint8Array, start: number, end: number) {
  return new TextDecoder().decode(bytes.slice(start, end));
}

/** Assinatura real dos quatro tipos que Momentos aceita. */
export function matchesDeclaredType(bytes: Uint8Array, mimeType: string) {
  if (mimeType === "image/jpeg") return bytes[0] === 0xff && bytes[1] === 0xd8;
  if (mimeType === "image/png") {
    return bytes.slice(0, 8).join(",") === "137,80,78,71,13,10,26,10";
  }
  if (mimeType === "image/webp") {
    return text(bytes, 0, 4) === "RIFF" && text(bytes, 8, 12) === "WEBP";
  }
  if (mimeType === "video/mp4") return text(bytes, 4, 8) === "ftyp";
  return false;
}

export async function assertStoredBytesMatchDeclaredType(
  transport: StoredBytesTransport,
  objectKey: string,
  expectedByteSize: number,
  expectedMimeType: string,
): Promise<Uint8Array> {
  if (!Number.isSafeInteger(expectedByteSize) || expectedByteSize < 1) {
    throw new Error("media_descriptor_invalid");
  }
  let bytes: Uint8Array;
  try {
    bytes = await transport.get(objectKey, expectedByteSize);
  } catch {
    throw new Error("uploaded_media_unreadable");
  }
  if (
    bytes.length !== expectedByteSize ||
    !matchesDeclaredType(bytes, expectedMimeType)
  ) {
    // O objeto nao corresponde ao que foi autorizado: sai do bucket antes de a
    // finalizacao falhar. A falha da remocao nao pode mascarar a recusa.
    await transport.delete(objectKey).catch(() => {});
    throw new Error("uploaded_media_mismatch");
  }
  return bytes;
}
