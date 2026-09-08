import { assertEquals, assertRejects } from "@std/assert";
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
import { createSnapshotRows } from "./snapshot_paging.ts";

for (const changed of ["B", "a longer changed response"]) {
  Deno.test(`XLSX rejects changed worksheet bytes between measurement and write: ${changed.length}`, async () => {
    let pass = 0;
    const rows = () => ({
      async *[Symbol.asyncIterator]() {
        pass++;
        yield { answer: pass >= 5 ? changed : "A" };
      },
    });
    await assertRejects(
      async () => {
        for await (const _chunk of streamXlsx(rows)) {
          /* consume actual archive */
        }
      },
      Error,
      "xlsx_snapshot_changed",
    );
  });
}

Deno.test("paged duplicate titles survive both XLSX encoders with sparse rows and safe cells", async () => {
  const rowsFactory = () =>
    createSnapshotRows((cursor) =>
      Promise.resolve({
        kind: "xlsx",
        submissions: [{
          responseId: cursor ? "r2" : "r1",
          occurrenceId: "o1",
          versionId: "v1",
          metadata: { response_id: "metadata" },
          answers: cursor
            ? [
              {
                itemId: "b",
                question: "Nome",
                values: ["Bia"],
                multiValued: false,
              },
            ]
            : [
              {
                itemId: "a",
                question: "Nome",
                values: ["Ana"],
                multiValued: false,
              },
              {
                itemId: "b",
                question: "Nome",
                values: ["=1+1"],
                multiValued: false,
              },
              {
                itemId: "c",
                question: "response_id",
                values: ["answer"],
                multiValued: false,
              },
              {
                itemId: "d",
                question: "=1+1",
                values: ["/forms/media/asset-1"],
                multiValued: false,
              },
            ],
        }],
        has_more: !cursor,
        next_cursor: cursor ? null : "r1",
      })
    );
  const rows = [];
  for await (const row of rowsFactory()) rows.push(row);
  const chunks = [];
  for await (const chunk of streamXlsx(rowsFactory, 1024)) chunks.push(chunk);
  for (const bytes of [encodeXlsx(rows), concatenate(chunks)]) {
    const workbook = XLSX.read(bytes, { type: "array" });
    const sheet = workbook.Sheets[workbook.SheetNames[0]];
    const matrix = XLSX.utils.sheet_to_json<string[]>(sheet, {
      header: 1,
      defval: "",
    });
    const headers = matrix[0];
    const cell = (key: string, row: number) =>
      matrix[row][headers.indexOf(key)];
    assertEquals(new Set(headers).size, headers.length);
    assertEquals(cell("response_id", 1), "r1");
    assertEquals(cell("response_id", 2), "r2");
    assertEquals(cell("Metadado [response_id]", 1), "metadata");
    assertEquals(cell("Resposta [a] Nome", 1), "Ana");
    assertEquals(cell("Resposta [a] Nome", 2), "");
    assertEquals(cell("Resposta [b] Nome", 1), "'=1+1");
    assertEquals(cell("Resposta [b] Nome", 2), "Bia");
    assertEquals(cell("Resposta [c] response_id", 1), "answer");
    const mediaAddress = XLSX.utils.encode_cell({
      r: 1,
      c: headers.indexOf("Resposta [d] =1+1"),
    });
    assertEquals(sheet[mediaAddress].l?.Target, "/forms/media/asset-1");
    for (const [address, value] of Object.entries(sheet)) {
      if (!address.startsWith("!")) {
        assertEquals((value as XLSX.CellObject).f, undefined);
      }
    }
  }
});

Deno.test("keeps duplicate question titles in stable item columns across sparse rows", () => {
  const submission = {
    responseId: "r1",
    occurrenceId: "o1",
    versionId: "v1",
    metadata: {},
    answers: [
      {
        itemId: "first",
        question: "Nome",
        values: ["Ana"],
        multiValued: false,
      },
      {
        itemId: "second",
        question: "Nome",
        values: ["Bia"],
        multiValued: false,
      },
    ],
  };
  const [full] = expandSubmission(submission);
  const [sparse] = expandSubmission({
    ...submission,
    answers: [submission.answers[1]],
  });
  assertEquals(full["Resposta [first] Nome"], "Ana");
  assertEquals(full["Resposta [second] Nome"], "Bia");
  assertEquals(sparse["Resposta [second] Nome"], "Bia");
  assertEquals(
    Object.keys(sparse).filter((key) => key.startsWith("Resposta ")),
    ["Resposta [second] Nome"],
  );
});

Deno.test("keeps system, metadata, simple and expanded values in disjoint columns", () => {
  const hostile = [
    "response_id",
    "occurrence_id",
    "version_id",
    "item_id",
    "valor_expandido",
    "Pergunta expandida",
    "__proto__",
    "constructor",
  ];
  const [row] = expandSubmission({
    responseId: "r1",
    occurrenceId: "o1",
    versionId: "v1",
    metadata: Object.fromEntries(
      hostile.map((key) => [key, `metadata:${key}`]),
    ),
    answers: [
      ...hostile.map((question, index) => ({
        itemId: `q${index}`,
        question,
        values: [`answer:${question}`],
        multiValued: false,
      })),
      {
        itemId: "multi",
        question: "Fotos",
        values: ["photo"],
        multiValued: true,
      },
    ],
  });
  assertEquals(row.response_id, "r1");
  assertEquals(row.occurrence_id, "o1");
  assertEquals(row.version_id, "v1");
  assertEquals(row.item_id, "multi");
  assertEquals(row.valor_expandido, "photo");
  assertEquals(row["Pergunta expandida"], "Fotos");
  hostile.forEach((key, index) => {
    assertEquals(
      row[`Metadado [${encodeURIComponent(key)}]`],
      `metadata:${key}`,
    );
    assertEquals(row[`Resposta [q${index}] ${key}`], `answer:${key}`);
  });
});

Deno.test("escapes item identifiers so delimiters cannot alias another question column", () => {
  const [row] = expandSubmission({
    responseId: "r",
    occurrenceId: "o",
    versionId: "v",
    metadata: {},
    answers: [
      { itemId: "a] b", question: "c", values: ["first"], multiValued: false },
      { itemId: "a", question: "b] c", values: ["second"], multiValued: false },
      {
        itemId: "a%5D%20b",
        question: "c",
        values: ["third"],
        multiValued: false,
      },
    ],
  });
  assertEquals(row["Resposta [a%5D%20b] c"], "first");
  assertEquals(row["Resposta [a] b] c"], "second");
  assertEquals(row["Resposta [a%255D%2520b] c"], "third");
});

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
  assertEquals(
    rows.every((row) => row["Resposta [name] Nome"] === "Ana"),
    true,
  );
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
