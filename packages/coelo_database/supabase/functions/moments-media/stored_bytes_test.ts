import { assertEquals, assertRejects } from "jsr:@std/assert@1.0.14";

import {
  assertStoredBytesMatchDeclaredType,
  matchesDeclaredType,
} from "./stored_bytes.ts";

// A finalizacao de Momentos conferia so metadados, e o Content-Type de um
// objeto no R2 e o que o proprio cliente declarou no PUT assinado. Qualquer
// conteudo do tamanho certo anunciado como imagem era finalizado como imagem
// pronta. Estas provas fixam a conferencia dos bytes reais.

const png = new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13]);
const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0, 0, 0, 0]);
const webp = new Uint8Array([
  0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50,
]);
const mp4 = new Uint8Array([0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, 0, 0, 0, 0]);
const html = new TextEncoder().encode("<html>oi</html>");

function transport(bytes: Uint8Array | Error) {
  const deleted: string[] = [];
  const reads: Array<{ key: string; maxBytes: number }> = [];
  return {
    deleted,
    reads,
    get(key: string, maxBytes: number) {
      reads.push({ key, maxBytes });
      return bytes instanceof Error
        ? Promise.reject(bytes)
        : Promise.resolve(bytes);
    },
    delete(key: string) {
      deleted.push(key);
      return Promise.resolve();
    },
  };
}

Deno.test("aceita os quatro tipos que Momentos permite", () => {
  assertEquals(matchesDeclaredType(png, "image/png"), true);
  assertEquals(matchesDeclaredType(jpeg, "image/jpeg"), true);
  assertEquals(matchesDeclaredType(webp, "image/webp"), true);
  assertEquals(matchesDeclaredType(mp4, "video/mp4"), true);
});

Deno.test("recusa bytes que nao correspondem ao tipo declarado", () => {
  assertEquals(matchesDeclaredType(html, "image/png"), false);
  assertEquals(matchesDeclaredType(png, "image/jpeg"), false);
  assertEquals(matchesDeclaredType(png, "video/mp4"), false);
  assertEquals(matchesDeclaredType(png, "application/pdf"), false);
});

Deno.test("um objeto valido passa e devolve os bytes lidos", async () => {
  const r2 = transport(png);

  const bytes = await assertStoredBytesMatchDeclaredType(
    r2,
    "chave",
    png.length,
    "image/png",
  );

  assertEquals(bytes, png);
  assertEquals(r2.reads, [{ key: "chave", maxBytes: png.length }]);
  assertEquals(r2.deleted, []);
});

Deno.test("conteudo disfarcado de imagem e recusado E apagado do bucket", async () => {
  const disguised = new Uint8Array(png.length);
  disguised.set(html.slice(0, Math.min(html.length, png.length)));
  const r2 = transport(disguised);

  await assertRejects(
    () =>
      assertStoredBytesMatchDeclaredType(r2, "chave", png.length, "image/png"),
    Error,
    "uploaded_media_mismatch",
  );
  assertEquals(r2.deleted, ["chave"]);
});

Deno.test("tamanho divergente e recusado mesmo com assinatura correta", async () => {
  const r2 = transport(png);

  await assertRejects(
    () => assertStoredBytesMatchDeclaredType(r2, "chave", png.length + 1, "image/png"),
    Error,
    "uploaded_media_mismatch",
  );
  assertEquals(r2.deleted, ["chave"]);
});

Deno.test("objeto ilegivel e falha honesta, nao sucesso", async () => {
  const r2 = transport(new Error("transport"));

  await assertRejects(
    () =>
      assertStoredBytesMatchDeclaredType(r2, "chave", png.length, "image/png"),
    Error,
    "uploaded_media_unreadable",
  );
  assertEquals(r2.deleted, []);
});

Deno.test("descritor sem tamanho util nao alcanca o objeto", async () => {
  const r2 = transport(png);

  await assertRejects(
    () => assertStoredBytesMatchDeclaredType(r2, "chave", 0, "image/png"),
    Error,
    "media_descriptor_invalid",
  );
  assertEquals(r2.reads, []);
  assertEquals(r2.deleted, []);
});

Deno.test("a leitura e limitada ao tamanho ja esperado", async () => {
  const r2 = transport(mp4);

  await assertStoredBytesMatchDeclaredType(r2, "chave", mp4.length, "video/mp4");

  assertEquals(r2.reads[0].maxBytes, mp4.length);
});
