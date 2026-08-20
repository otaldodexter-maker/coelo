import { assertEquals } from "@std/assert";
import {
  encodeCsv,
  encodeXlsx,
  encodeZip,
  expandSubmission,
  neutralizeSpreadsheetFormula,
  opaqueArtifactPath,
  streamCsv,
  streamXlsx,
  streamZip,
} from "./export_contract.ts";
import * as XLSX from "xlsx";
import { unzipSync } from "fflate";

Deno.test("expands multivalued questions independently without a cartesian product", () => {
  const rows = expandSubmission({
    responseId: "response-1",
    occurrenceId: "occurrence-1",
    versionId: "version-1",
    metadata: { institution: "Coelo" },
    answers: [
      { itemId: "name", question: "Nome", values: ["Ana"], multiValued: false },
      {
        itemId: "foods",
        question: "Alimentos",
        values: ["Maçã", "Pera"],
        multiValued: true,
      },
      {
        itemId: "photos",
        question: "Fotos",
        values: ["Ver foto 1", "Ver foto 2"],
        multiValued: true,
      },
    ],
  });
  assertEquals(rows.length, 4);
  assertEquals(rows.map((row) => row["Pergunta expandida"]), [
    "Alimentos",
    "Alimentos",
    "Fotos",
    "Fotos",
  ]);
  assertEquals(rows.every((row) => row.Nome === "Ana"), true);
});

Deno.test("neutralizes spreadsheet formulas in CSV values", () => {
  for (
    const value of [
      "=1+1",
      "+SUM(A1)",
      "-2+3",
      "@cmd",
      "\t=1+1",
      " =1+1",
      "\r-2+3",
    ]
  ) {
    assertEquals(neutralizeSpreadsheetFormula(value), `'${value}`);
  }
  const csv = new TextDecoder().decode(encodeCsv([{ answer: "=1+1" }]));
  assertEquals(csv.includes('"\'=1+1"'), true);
});

Deno.test("streams CSV from repeatable row pages without retaining all rows", async () => {
  let calls = 0;
  const rows = () => ({
    async *[Symbol.asyncIterator]() {
      calls++;
      yield { id: "1", answer: "=1+1" };
      yield { id: "2", answer: "ok" };
    },
  });
  const chunks: Uint8Array[] = [];
  for await (const chunk of streamCsv(rows)) chunks.push(chunk);
  assertEquals(calls, 2);
  assertEquals(
    new TextDecoder("utf-8", { ignoreBOM: true }).decode(concatenate(chunks)),
    '\uFEFF"id","answer"\r\n"1","\'=1+1"\r\n"2","ok"\r\n',
  );
});

Deno.test("XLSX reopens with neutralized values and protected media hyperlinks", () => {
  const bytes = encodeXlsx([{
    response_id: "response-1",
    "Foto": "/forms/media/asset-1",
    "Texto": '=HYPERLINK("https://invalid")',
  }]);
  const workbook = XLSX.read(bytes, { type: "array" });
  const sheet = workbook.Sheets[workbook.SheetNames[0]];
  if (sheet.C2.v !== '\'=HYPERLINK("https://invalid")') {
    throw new Error("formula was not neutralized");
  }
  if (sheet.B2.l?.Target !== "/forms/media/asset-1") {
    throw new Error("media route is not a real hyperlink");
  }
});

Deno.test("streams inline-string OOXML from repeatable bounded row passes", async () => {
  let consumed = 0;
  let factoryCalls = 0;
  const rows = () => ({
    async *[Symbol.asyncIterator]() {
      factoryCalls++;
      for (let index = 0; index < 40; index++) {
        consumed++;
        yield {
          response_id: `response-${index}`,
          Foto: `/forms/media/asset-${index}`,
          Texto: index === 0 ? "=1+1" : `Resposta ${index}`,
        };
      }
    },
  });
  const chunks: Uint8Array[] = [];
  for await (const chunk of streamXlsx(rows, 1024)) {
    chunks.push(chunk);
  }
  assertEquals(factoryCalls >= 5, true);
  assertEquals(consumed, factoryCalls * 40);
  assertEquals(chunks.every((chunk) => chunk.byteLength <= 1024), true);
  const bytes = concatenate(chunks);
  const workbook = XLSX.read(bytes, { type: "array" });
  const sheet = workbook.Sheets[workbook.SheetNames[0]];
  assertEquals(sheet.C2.v, "'=1+1");
  assertEquals(sheet.B2.l?.Target, "/forms/media/asset-0");
});

Deno.test("ZIP contains the workbook, manifest and opaque media names", () => {
  const bytes = encodeZip({
    workbook: new Uint8Array([1, 2, 3]),
    manifest: { response_count: 1 },
    media: [{ name: "asset-1.webp", bytes: new Uint8Array([4, 5]) }],
  });
  const files = unzipSync(bytes);
  if (
    !files["respostas.xlsx"] || !files["manifesto.json"] ||
    !files["midias/asset-1.webp"]
  ) {
    throw new Error("ZIP contract is incomplete");
  }
});

Deno.test("streams ZIP output in bounded chunks without materializing the archive", async () => {
  const chunks: Uint8Array[] = [];
  for await (
    const chunk of streamZip({
      workbook: new Uint8Array(32 * 1024).fill(1),
      manifest: { rows: 1 },
      media: [{
        name: "11111111-1111-4111-8111-111111111111.jpg",
        bytes: new Uint8Array(32 * 1024).fill(2),
      }],
      outputChunkBytes: 4096,
    })
  ) chunks.push(chunk);

  assertEquals(chunks.length > 1, true);
  assertEquals(chunks.every((chunk) => chunk.byteLength <= 4096), true);
  const archive = new Uint8Array(
    chunks.reduce((sum, chunk) => sum + chunk.byteLength, 0),
  );
  let offset = 0;
  for (const chunk of chunks) {
    archive.set(chunk, offset);
    offset += chunk.byteLength;
  }
  const files = unzipSync(archive);
  assertEquals(files["respostas.xlsx"].byteLength, 32 * 1024);
  assertEquals(
    files["midias/11111111-1111-4111-8111-111111111111.jpg"].byteLength,
    32 * 1024,
  );
});

function concatenate(chunks: Uint8Array[]): Uint8Array {
  const result = new Uint8Array(
    chunks.reduce((sum, chunk) => sum + chunk.byteLength, 0),
  );
  let offset = 0;
  for (const chunk of chunks) {
    result.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return result;
}

Deno.test("stores export artifacts at the opaque path required by the job schema", () => {
  assertEquals(
    opaqueArtifactPath("11111111-1111-4111-8111-111111111111"),
    "11/11111111-1111-4111-8111-111111111111",
  );
});
