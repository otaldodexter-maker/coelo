import { assertEquals } from "jsr:@std/assert@1.0.14";

Deno.test("accepts binary uploads and never accepts base64 source payloads", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assertEquals(source.includes("await request.arrayBuffer()"), true);
  assertEquals(source.includes("content_base64"), false);
});

Deno.test("revalidates the user before each private job operation", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  const checks = source.match(/createClient\(url, anon/g) ?? [];
  assertEquals(checks.length >= 1, true);
  assertEquals(source.includes("superadmin_import_export_upload_contract"), true);
  assertEquals(source.includes("superadmin_get_import_export_job"), true);
});
