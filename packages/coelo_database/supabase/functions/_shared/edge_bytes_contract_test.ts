import { assertEquals } from "jsr:@std/assert@1.0.14";

// Toda superficie de midia do MVP aceita upload binario e leitura inline pela Edge
// (o navegador nunca fala com o R2): o desenho do entity-media, replicado.
const gateways = ["moments-media", "now-media", "happens-media", "circular-media", "chat-media", "meal-plan-media", "child-safety-media"];

for (const gateway of gateways) {
  Deno.test(`${gateway}: upload binario e leitura inline pela Edge`, async () => {
    const source = await Deno.readTextFile(new URL(`../${gateway}/index.ts`, import.meta.url));
    assertEquals(source.includes("isBinaryUpload(request)"), true, "upload binario com envelope no cabecalho");
    assertEquals(source.includes('body.action === "upload"'), true, "acao upload grava os bytes no servidor");
    assertEquals(source.includes("body.inline === true"), true, "leitura inline devolve bytes");
    assertEquals(source.includes("bytesResponse("), true);
    assertEquals(source.includes("x-coelo-media-envelope"), true, "preflight aceita o envelope");
  });
}
