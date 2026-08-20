import { assertEquals } from "@std/assert";
import { createSnapshotRows } from "./snapshot_paging.ts";

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
    const row of createSnapshotRows(async (cursor) => {
      cursors.push(cursor);
      return pages[cursors.length - 1];
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
  const rows = createSnapshotRows(async () => {
    page++;
    liveRows = 2;
    peakRows = Math.max(peakRows, liveRows);
    return {
      kind: "anonymous_participation",
      rows: [{ id: `${page}-1` }, { id: `${page}-2` }],
      has_more: page < 3,
      next_cursor: page < 3 ? String(page) : null,
    };
  }, { onPageReleased: () => liveRows = 0 });
  let count = 0;
  for await (const _row of rows) count++;
  assertEquals(count, 6);
  assertEquals(peakRows, 2);
  assertEquals(liveRows, 0);
});
