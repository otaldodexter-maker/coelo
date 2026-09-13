import { assertEquals, assertRejects } from "jsr:@std/assert@1.0.14";
import { matchesDeclaredType, readStoredBytes, sha256Hex } from "./stored_bytes.ts";

const png = new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10, 0, 0]);
const pdf = new TextEncoder().encode("%PDF-1.7 teste");
const encoder = new TextEncoder();
const box = (type: string, payload: number[] = []) => {
  const size = payload.length + 8;
  return new Uint8Array([(size >>> 24) & 255, (size >>> 16) & 255, (size >>> 8) & 255, size & 255, ...encoder.encode(type), ...payload]);
};
const mp4 = new Uint8Array([
  ...box("ftyp", [...encoder.encode("isom"), 0, 0, 0, 1, ...encoder.encode("isom")]),
  ...box("moov"),
  ...box("mdat", [0, 1, 2, 3]),
]);

Deno.test("assinaturas reais dos quatro tipos aceitos", () => {
  assertEquals(matchesDeclaredType(png, "image/png"), true);
  assertEquals(matchesDeclaredType(pdf, "application/pdf"), true);
  assertEquals(matchesDeclaredType(png, "application/pdf"), false);
  assertEquals(matchesDeclaredType(new Uint8Array([0xff, 0xd8, 0]), "image/jpeg"), true);
  assertEquals(matchesDeclaredType(png, "video/mp4"), false);
  assertEquals(matchesDeclaredType(mp4, "video/mp4"), true);
  assertEquals(matchesDeclaredType(new Uint8Array([0, 0, 0, 12, 0x66, 0x74, 0x79, 0x70, 0, 0, 0, 0]), "video/mp4"), false);
  assertEquals(matchesDeclaredType(new Uint8Array([...box("ftyp", [...encoder.encode("heic"), 0, 0, 0, 1]), ...box("moov"), ...box("mdat")]), "video/mp4"), false);
  assertEquals(matchesDeclaredType(mp4.slice(0, mp4.length - 1), "video/mp4"), false);
  assertEquals(matchesDeclaredType(new Uint8Array([0xff, 0xff, 0xff, 0xff, ...mp4.slice(4)]), "video/mp4"), false);
});

Deno.test("readStoredBytes devolve sha256 e apaga objeto divergente", async () => {
  const deleted: string[] = [];
  const transport = {
    get: (_key: string, _max: number) => Promise.resolve(png),
    delete: (key: string) => { deleted.push(key); return Promise.resolve(); },
  };
  const ok = await readStoredBytes(transport, "k", png.length, "image/png");
  assertEquals(ok.sha256, await sha256Hex(png));
  assertEquals(deleted.length, 0);
  await assertRejects(() => readStoredBytes(transport, "k", png.length, "application/pdf"), Error, "uploaded_attachment_mismatch");
  assertEquals(deleted, ["k"]);
  await assertRejects(() => readStoredBytes(transport, "k", png.length + 1, "image/png"), Error, "uploaded_attachment_mismatch");
});
