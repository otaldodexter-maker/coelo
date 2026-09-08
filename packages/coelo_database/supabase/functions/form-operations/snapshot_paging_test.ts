import { assertEquals, assertRejects } from "@std/assert";
import { createSnapshotRows } from "./snapshot_paging.ts";

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
