import { assertEquals, assertNotEquals } from "jsr:@std/assert@1.0.14";
import { buildAuditArtifact, safeSpreadsheetCell } from "./artifact.ts";

Deno.test("neutralizes spreadsheet formulas in CSV cells", () => {
  assertEquals(safeSpreadsheetCell("=1+1"), "'=1+1");
  assertEquals(safeSpreadsheetCell("+SUM(A1:A2)"), "'+SUM(A1:A2)");
  assertEquals(safeSpreadsheetCell("\tcmd"), "'\tcmd");
  assertEquals(safeSpreadsheetCell("safe"), "safe");
});

Deno.test("builds a real XLSX archive instead of renamed CSV", () => {
  const artifact = buildAuditArtifact(
    [{ id: "1", actor_name: "=SYSTEM()" }],
    "xlsx",
  );
  assertEquals(artifact.extension, "xlsx");
  assertEquals(
    artifact.mime,
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  );
  assertEquals(artifact.bytes[0], 0x50);
  assertEquals(artifact.bytes[1], 0x4b);
  assertNotEquals(
    new TextDecoder().decode(artifact.bytes.slice(0, 20)).includes(
      "actor_name",
    ),
    true,
  );
});

Deno.test("centralizes every signed URL behind user-owned download authorization", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );
  const signedCalls = source.match(/\.createSignedUrl\(/g) ?? [];
  assertEquals(signedCalls.length, 1);
  const helperStart = source.indexOf("async function signedDownload");
  const authorizeCall = source.indexOf(
    "await authorizeDownload(user, jobId)",
    helperStart,
  );
  const signedCall = source.indexOf(".createSignedUrl(", helperStart);
  assertEquals(
    helperStart >= 0 && authorizeCall > helperStart &&
      signedCall > authorizeCall,
    true,
  );
});
