/**
 * Dimensoes em pixels lidas do cabecalho dos tres formatos normalizados do
 * Coelo (JPEG, PNG, WebP), sem decodificar a imagem. Serve para o finalize
 * dos catalogos R2 (question-image, answer-image, anexos) preencher
 * pixel_width/pixel_height a partir dos bytes reais, nunca do cliente.
 * Devolve null quando o cabecalho nao corresponde ao tipo declarado.
 */

export type ImageDimensions = Readonly<{ width: number; height: number }>;

function u16be(b: Uint8Array, i: number) {
  return (b[i] << 8) | b[i + 1];
}
function u32be(b: Uint8Array, i: number) {
  return ((b[i] << 24) >>> 0) + (b[i + 1] << 16) + (b[i + 2] << 8) + b[i + 3];
}
function u24le(b: Uint8Array, i: number) {
  return b[i] | (b[i + 1] << 8) | (b[i + 2] << 16);
}
function ascii(b: Uint8Array, start: number, end: number) {
  return new TextDecoder().decode(b.slice(start, end));
}

function png(b: Uint8Array): ImageDimensions | null {
  if (b.length < 24 || b.slice(0, 8).join(",") !== "137,80,78,71,13,10,26,10") return null;
  if (ascii(b, 12, 16) !== "IHDR") return null;
  return { width: u32be(b, 16), height: u32be(b, 20) };
}

function jpeg(b: Uint8Array): ImageDimensions | null {
  if (b.length < 4 || b[0] !== 0xff || b[1] !== 0xd8) return null;
  let i = 2;
  while (i + 9 < b.length) {
    if (b[i] !== 0xff) return null;
    const marker = b[i + 1];
    if (marker === 0xd8 || (marker >= 0xd0 && marker <= 0xd7) || marker === 0x01) { i += 2; continue; }
    const length = u16be(b, i + 2);
    if (length < 2) return null;
    // SOF0..SOF15 exceto DHT (C4), JPG (C8) e DAC (CC)
    if (marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc) {
      return { height: u16be(b, i + 5), width: u16be(b, i + 7) };
    }
    if (marker === 0xda) return null; // SOS antes de SOF: cabecalho invalido
    i += 2 + length;
  }
  return null;
}

function webp(b: Uint8Array): ImageDimensions | null {
  if (b.length < 30 || ascii(b, 0, 4) !== "RIFF" || ascii(b, 8, 12) !== "WEBP") return null;
  const chunk = ascii(b, 12, 16);
  if (chunk === "VP8 ") {
    // frame tag (3) + start code 9d 01 2a + width/height 14 bits
    if (b[23] !== 0x9d || b[24] !== 0x01 || b[25] !== 0x2a) return null;
    return { width: (b[26] | (b[27] << 8)) & 0x3fff, height: (b[28] | (b[29] << 8)) & 0x3fff };
  }
  if (chunk === "VP8L") {
    if (b[20] !== 0x2f) return null;
    const bits = b[21] | (b[22] << 8) | (b[23] << 16) | (b[24] << 24);
    return { width: (bits & 0x3fff) + 1, height: ((bits >>> 14) & 0x3fff) + 1 };
  }
  if (chunk === "VP8X") {
    return { width: u24le(b, 24) + 1, height: u24le(b, 27) + 1 };
  }
  return null;
}

export function imageDimensions(bytes: Uint8Array, mimeType: string): ImageDimensions | null {
  let result: ImageDimensions | null = null;
  if (mimeType === "image/png") result = png(bytes);
  else if (mimeType === "image/jpeg") result = jpeg(bytes);
  else if (mimeType === "image/webp") result = webp(bytes);
  if (!result || result.width < 1 || result.height < 1) return null;
  return result;
}
