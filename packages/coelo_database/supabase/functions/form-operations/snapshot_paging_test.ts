import { assertEquals, assertRejects, assertThrows } from "@std/assert";
import {
  createSnapshotRows,
  createVersionedXlsxSheets,
  parseXlsxSnapshotSchema,
  parseXlsxSubmission,
} from "./snapshot_paging.ts";
import { encodeXlsxWorkbook, streamXlsxWorkbook } from "./export_contract.ts";
import * as XLSX from "xlsx";

const v2id = (n: number) =>
  `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;
function v2schema() {
  return {
    formId: v2id(1),
    formTitle: "Form",
    versions: [1, 2].map((n) => ({
      versionId: v2id(n + 1),
      versionNumber: n,
      state: "published",
      sections: [{
        sectionId: v2id(n + 10),
        title: "Section",
        description: null,
        position: 0,
        items: (n === 1 ? [20, 21, 22, 23] : [21, 20, 22, 23]).map((
          item,
          index,
        ) => ({
          itemId: v2id(item + n * 100),
          kind: item === 22
            ? "multiple_choice"
            : item === 23
            ? "gallery"
            : "decimal",
          label: "Repeated",
          helpText: null,
          position: index,
          required: false,
          config: {},
          options: item === 22
            ? [{ optionId: v2id(n + 40), label: "Choice", position: 0 }, {
              optionId: v2id(n + 50),
              label: "Other",
              position: 1,
            }]
            : [],
        })),
      }],
      conditions: [],
    })),
  };
}
function v2submission() {
  return {
    responseId: v2id(70),
    occurrenceId: v2id(71),
    versionId: v2id(2),
    metadata: { form_id: v2id(1), identity_mode: "anonymous" },
    answers: [{
      itemId: v2id(120),
      values: [{ kind: "decimal", value: "12.50" }],
    }, {
      itemId: v2id(122),
      values: [{ kind: "choice", optionId: v2id(41) }, {
        kind: "choice",
        optionId: v2id(51),
      }],
    }, {
      itemId: v2id(123),
      values: [{ kind: "media", assetId: v2id(80) }, {
        kind: "media",
        assetId: v2id(81),
      }],
    }],
  };
}

Deno.test("sealed graph preserves unanswered questions, version order and independent auxiliary rows", async () => {
  const raw = v2schema();
  raw.versions[0].state = "working";
  const schema = parseXlsxSnapshotSchema(raw, v2id(1));
  assertEquals(schema.versions[0].state, "working");
  raw.versions[0].sections[0].items[0].label = "Changed after seal";
  const submission = parseXlsxSubmission(v2submission(), schema);
  const sheets = createVersionedXlsxSheets(schema, async function* () {
    yield submission;
  }, "https://superadmin.example.test");
  assertEquals(sheets.map((sheet) => sheet.name), [
    "Respostas v1",
    "Valores v1",
    "Mídias v1",
    "Respostas v2",
    "Valores v2",
    "Mídias v2",
  ]);
  const main = [];
  for await (const row of sheets[0].rows()) main.push(row);
  assertEquals(main.length, 1);
  assertEquals(main[0][v2id(120)], 12.5);
  assertEquals(
    sheets[0].columns.slice(-4).map((column) => column.key),
    [120, 121, 122, 123].map(v2id),
  );
  assertEquals(
    sheets[3].columns.slice(-4).map((column) => column.key),
    [221, 220, 222, 223].map(v2id),
  );
  assertEquals(
    sheets[0].columns.some((column) => column.label.includes("Changed")),
    false,
  );
  for (const index of [1, 2]) {
    const rows = [];
    for await (const row of sheets[index].rows()) rows.push(row);
    assertEquals(rows.length, 2);
    assertEquals(rows[0].response_id, v2id(70));
  }
  assertEquals(main[0].respondent, undefined);
  assertEquals(main[0].submitted_at, undefined);
});

Deno.test("sealed snapshot rejects unfaithful numbers, unknown graph references and anonymous identity", () => {
  const schema = parseXlsxSnapshotSchema(v2schema(), v2id(1));
  for (
    const value of [
      "9007199254740993",
      "0.12345678901234567",
      "NaN",
      "Infinity",
      "1e400",
    ]
  ) {
    const row = v2submission();
    row.answers = [{ itemId: v2id(120), values: [{ kind: "decimal", value }] }];
    assertThrows(() => parseXlsxSubmission(row, schema));
  }
  const identity = {
    ...v2submission(),
    metadata: {
      form_id: v2id(1),
      identity_mode: "anonymous",
      respondent: "Leak",
    },
  };
  assertThrows(() => parseXlsxSubmission(identity, schema));
  assertThrows(() =>
    parseXlsxSubmission({ ...v2submission(), versionId: v2id(999) }, schema)
  );
  assertThrows(() =>
    parseXlsxSubmission({
      ...v2submission(),
      answers: [{
        itemId: v2id(122),
        values: [{ kind: "choice", optionId: v2id(999) }],
      }],
    }, schema)
  );
});

Deno.test("typed snapshot numbers dates boolean and explicit BRL coexist in both workbook encoders", async () => {
  const raw = v2schema();
  raw.versions = raw.versions.slice(0, 1);
  const template = raw.versions[0].sections[0].items[0];
  raw.versions[0].sections[0].items = [
    "short_text",
    "integer",
    "decimal",
    "money",
    "date",
    "yes_no",
    "scale",
    "information",
  ].map((kind, index) => ({
    ...template,
    itemId: v2id(200 + index),
    kind,
    position: index,
    config: kind === "money" ? { currency: "BRL" } : {},
  }));
  const schema = parseXlsxSnapshotSchema(raw, v2id(1));
  const values = [
    { kind: "text", value: "=unsafe" },
    { kind: "integer", value: "42" },
    { kind: "decimal", value: "0.125" },
    { kind: "money", minorUnits: "12345", currency: "BRL" },
    { kind: "date", value: "2026-09-08" },
    { kind: "boolean", value: false },
    { kind: "integer", value: "5" },
  ];
  const input = {
    ...v2submission(),
    answers: values.map((value, index) => ({
      itemId: v2id(200 + index),
      values: [value],
    })),
  };
  const submission = parseXlsxSubmission(input, schema);
  const sheets = createVersionedXlsxSheets(schema, async function* () {
    yield submission;
  });
  const buffered = [];
  for (const sheet of sheets) {
    const rows = [];
    for await (const row of sheet.rows()) rows.push(row);
    buffered.push({ ...sheet, rows });
  }
  const chunks = [];
  for await (const chunk of streamXlsxWorkbook(sheets)) chunks.push(chunk);
  const bytes = new Uint8Array(
    chunks.reduce((sum, chunk) => sum + chunk.length, 0),
  );
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  for (const encoded of [bytes, encodeXlsxWorkbook(buffered)]) {
    const sheet = XLSX.read(encoded, { type: "array", cellNF: true })
      .Sheets["Respostas v1"];
    assertEquals(sheet.I2.v, "'=unsafe");
    assertEquals(sheet.J2.v, 42);
    assertEquals(sheet.K2.v, 0.125);
    assertEquals(sheet.L2.v, 123.45);
    assertEquals(sheet.M2.t, "n");
    assertEquals(sheet.M2.z, "yyyy-mm-dd");
    assertEquals(sheet.N2.t, "b");
    assertEquals(sheet.N2.v, false);
    assertEquals(sheet.O2.v, 5);
    assertEquals(sheet.P1, undefined);
    assertEquals(sheet.L1.v.includes("(BRL)"), true);
  }
  const unsupported = {
    ...input,
    answers: [{
      itemId: v2id(203),
      values: [{ kind: "money", minorUnits: "12345", currency: "USD" }],
    }],
  };
  assertThrows(() => parseXlsxSubmission(unsupported, schema));
  const absentCurrency = structuredClone(raw);
  absentCurrency.versions[0].sections[0].items[3].config = {};
  assertThrows(() =>
    parseXlsxSubmission(input, parseXlsxSnapshotSchema(absentCurrency, v2id(1)))
  );
});

Deno.test("versioned streaming counts main and auxiliary rows across versions under one lease budget", async () => {
  const schema = parseXlsxSnapshotSchema(v2schema(), v2id(1));
  const first = parseXlsxSubmission(v2submission(), schema);
  const second = parseXlsxSubmission({
    ...v2submission(),
    versionId: v2id(3),
    responseId: v2id(72),
    answers: [],
  }, schema);
  let live = 0;
  let maxLive = 0;
  const factory = async function* () {
    for (const row of [first, second]) {
      live++;
      maxLive = Math.max(maxLive, live);
      try {
        yield row;
      } finally {
        live--;
      }
    }
  };
  const sheets = createVersionedXlsxSheets(
    schema,
    factory,
    "https://superadmin.example.test",
    { maxRows: 5 },
  );
  await assertRejects(
    () => drain(sheets[0].rows()),
    Error,
    "export_lease_row_limit",
  );
  await assertRejects(
    () => drain(sheets[3].rows()),
    Error,
    "export_lease_row_limit",
  );
  assertEquals(maxLive, 1);
  assertEquals(live, 0);
  const bounded = createVersionedXlsxSheets(
    schema,
    factory,
    "https://superadmin.example.test",
    { maxRows: 6 },
  );
  await drain(streamXlsxWorkbook(bounded, 1024));
  assertEquals(maxLive, 1);
  assertEquals(live, 0);
});

async function drain(rows: AsyncIterable<unknown>) {
  for await (const _row of rows) { /* consume the actual iterator */ }
}

Deno.test("rejects a repeated snapshot cursor without requesting another page", async () => {
  let calls = 0;
  await assertRejects(
    () =>
      drain(createSnapshotRows(() => {
        if (++calls > 2) throw new Error("unexpected_third_page");
        return Promise.resolve({
          kind: "xlsx",
          submissions: [{
            responseId: `r${calls}`,
            occurrenceId: "o",
            versionId: "v",
            metadata: {},
            answers: [],
          }],
          has_more: true,
          next_cursor: "same-cursor",
        });
      })),
    Error,
    "export_cursor_repeated",
  );
  assertEquals(calls, 2);
});

Deno.test("rejects an empty page advertising more rows before another request", async () => {
  let calls = 0;
  await assertRejects(
    () =>
      drain(createSnapshotRows(() => {
        if (++calls > 1) throw new Error("unexpected_second_page");
        return Promise.resolve({
          kind: "xlsx",
          submissions: [],
          has_more: true,
          next_cursor: "next",
        });
      })),
    Error,
    "export_page_empty",
  );
  assertEquals(calls, 1);
});

Deno.test("rejects a snapshot kind change across cursor pages", async () => {
  let calls = 0;
  await assertRejects(
    () =>
      drain(createSnapshotRows(() => {
        calls++;
        return Promise.resolve(
          calls === 1
            ? {
              kind: "xlsx",
              submissions: [{
                responseId: "r",
                occurrenceId: "o",
                versionId: "v",
                metadata: {},
                answers: [],
              }],
              has_more: true,
              next_cursor: "next",
            }
            : {
              kind: "anonymous_participation",
              rows: [{ Pessoa: "Synthetic person" }],
              has_more: false,
            },
        );
      })),
    Error,
    "export_snapshot_kind_changed",
  );
});

Deno.test("streams multiple cursor pages and expands multivalued answers independently", async () => {
  const cursors: Array<string | null> = [];
  const pages = [
    {
      kind: "xlsx",
      submissions: [{
        responseId: "r1",
        occurrenceId: "o1",
        versionId: "v1",
        metadata: {},
        answers: [
          { itemId: "a", question: "A", values: ["1", "2"], multiValued: true },
          { itemId: "b", question: "B", values: ["3", "4"], multiValued: true },
        ],
      }],
      has_more: true,
      next_cursor: "r1",
    },
    {
      kind: "xlsx",
      submissions: [{
        responseId: "r2",
        occurrenceId: "o1",
        versionId: "v1",
        metadata: {},
        answers: [],
      }],
      has_more: false,
    },
  ];
  const output = [];
  for await (
    const row of createSnapshotRows((cursor) => {
      cursors.push(cursor);
      return Promise.resolve(pages[cursors.length - 1]);
    })
  ) output.push(row);

  assertEquals(cursors, [null, "r1"]);
  assertEquals(output.length, 5);
  assertEquals(output.slice(0, 4).map((row) => row["Pergunta expandida"]), [
    "A",
    "A",
    "B",
    "B",
  ]);
});

Deno.test("keeps only one backend page live while the consumer is paused", async () => {
  let page = 0;
  let liveRows = 0;
  let peakRows = 0;
  const rows = createSnapshotRows(() => {
    page++;
    liveRows = 2;
    peakRows = Math.max(peakRows, liveRows);
    return Promise.resolve({
      kind: "anonymous_participation",
      rows: [{ id: `${page}-1` }, { id: `${page}-2` }],
      has_more: page < 3,
      next_cursor: page < 3 ? String(page) : null,
    });
  }, { onPageReleased: () => liveRows = 0 });
  let count = 0;
  for await (const _row of rows) count++;
  assertEquals(count, 6);
  assertEquals(peakRows, 2);
  assertEquals(liveRows, 0);
});
