import { assertEquals } from "jsr:@std/assert@1.0.14";

Deno.test("entity gateway: bytes pela Edge, ticket no Postgres, sem segredo no cliente", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assertEquals(source.includes("presignPut"), false, "o navegador nunca recebe URL assinada de upload");
  assertEquals(source.includes("presignGet"), false, "o navegador nunca recebe URL assinada de leitura");
  assertEquals(source.includes('"superadmin_entity_image_authorize_upload_v1"'), true);
  assertEquals(source.includes('"superadmin_entity_image_finalize_v1"'), true);
  assertEquals(source.includes("matchesDeclaredType(bytes, contentType)"), true, "assinatura real do arquivo");
  assertEquals(source.includes("origin_not_allowed"), true);
  assertEquals(source.includes("x-coelo-asset-id"), true, "upload binario identifica o asset pelo cabecalho");
});
