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

Deno.test("entity gateway: svg do icone e leitor do Principal", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assertEquals(source.includes("isAcceptableSvg"), true, "svg passa pelo contrato estreito");
  assertEquals(source.includes('"icon_vector"'), true);
  assertEquals(source.includes('"principal_entity_image_authorize_read_v1"'), true, "responsavel le pela regra do Postgres");
});

Deno.test("entity gateway: planta baixa (floor_plan) so para instituicao/unidade e so raster", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assertEquals(source.includes('"floor_plan"'), true);
  assertEquals(source.includes('floorPlanKinds = new Set(["institution", "unit"])'), true);
  assertEquals(
    source.includes('body.image_kind === "floor_plan" && (!floorPlanKinds.has(body.entity_kind) || body.content_type === "image/svg+xml")'),
    true,
    "svg e turma/atividade/pessoa sao recusados no gateway antes do Postgres",
  );
});
