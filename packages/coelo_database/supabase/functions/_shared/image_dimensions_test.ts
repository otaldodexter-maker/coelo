import { assertEquals } from "jsr:@std/assert@1.0.14";
import { imageDimensions } from "./image_dimensions.ts";

function pngHeader(width: number, height: number) {
  const b = new Uint8Array(33);
  b.set([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82], 0);
  new DataView(b.buffer).setUint32(16, width);
  new DataView(b.buffer).setUint32(20, height);
  return b;
}
function jpegHeader(width: number, height: number) {
  // SOI, APP0 (length 16), SOF0 (length 17)
  const b = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, ...new Array(14).fill(0),
    0xff, 0xc0, 0x00, 0x11, 0x08, (height >> 8) & 0xff, height & 0xff, (width >> 8) & 0xff, width & 0xff, 0x03, ...new Array(9).fill(0),
    0xff, 0xda]);
  return b;
}
function webpVp8x(width: number, height: number) {
  const b = new Uint8Array(40);
  b.set(new TextEncoder().encode("RIFF"), 0);
  b.set(new TextEncoder().encode("WEBP"), 8);
  b.set(new TextEncoder().encode("VP8X"), 12);
  const w = width - 1, h = height - 1;
  b[24] = w & 0xff; b[25] = (w >> 8) & 0xff; b[26] = (w >> 16) & 0xff;
  b[27] = h & 0xff; b[28] = (h >> 8) & 0xff; b[29] = (h >> 16) & 0xff;
  return b;
}

Deno.test("PNG, JPEG e WebP devolvem largura e altura do cabecalho", () => {
  assertEquals(imageDimensions(pngHeader(640, 480), "image/png"), { width: 640, height: 480 });
  assertEquals(imageDimensions(jpegHeader(1024, 768), "image/jpeg"), { width: 1024, height: 768 });
  assertEquals(imageDimensions(webpVp8x(300, 200), "image/webp"), { width: 300, height: 200 });
});

Deno.test("tipo declarado diferente do cabecalho devolve null", () => {
  assertEquals(imageDimensions(pngHeader(10, 10), "image/jpeg"), null);
  assertEquals(imageDimensions(jpegHeader(10, 10), "image/png"), null);
  assertEquals(imageDimensions(new Uint8Array(5), "image/webp"), null);
  assertEquals(imageDimensions(pngHeader(0, 10), "image/png"), null);
});
