import {
  expandSubmission,
  type ExportRow,
  type ExportSubmission,
} from "./export_contract.ts";

export type SnapshotPage = Readonly<{
  kind: string;
  submissions?: ExportSubmission[];
  rows?: ExportRow[];
  media?: Array<{ asset_id: string; storage_path: string; mime_type: string }>;
  has_more: boolean;
  next_cursor?: string | null;
}>;

export type SnapshotPageLoader = (
  cursor: string | null,
) => Promise<SnapshotPage>;

export async function* createSnapshotRows(
  loadPage: SnapshotPageLoader,
  options: Readonly<{
    maxRows?: number;
    onPageReleased?: () => void;
  }> = {},
): AsyncIterable<ExportRow> {
  const maxRows = options.maxRows ?? 50_000;
  let cursor: string | null = null;
  let emitted = 0;
  let kind: string | undefined;
  const cursors = new Set<string>();
  do {
    const snapshot = await loadPage(cursor);
    if (
      !snapshot || typeof snapshot.kind !== "string" ||
      typeof snapshot.has_more !== "boolean"
    ) {
      throw new Error("export_snapshot_invalid");
    }
    if (kind !== undefined && snapshot.kind !== kind) {
      throw new Error("export_snapshot_kind_changed");
    }
    kind = snapshot.kind;
    const nextCursor = snapshot.has_more ? snapshot.next_cursor : null;
    if (snapshot.has_more) {
      if (typeof nextCursor !== "string" || !nextCursor) {
        throw new Error("export_cursor_missing");
      }
      if (cursors.has(nextCursor)) throw new Error("export_cursor_repeated");
      cursors.add(nextCursor);
    }
    const pageRows = snapshot.kind === "anonymous_participation"
      ? snapshot.rows ?? []
      : (snapshot.submissions ?? []).flatMap(expandSubmission);
    if (snapshot.has_more && pageRows.length === 0) {
      throw new Error("export_page_empty");
    }
    for (const row of pageRows) {
      emitted++;
      if (emitted > maxRows) throw new Error("export_lease_row_limit");
      yield row;
    }
    options.onPageReleased?.();
    cursor = nextCursor ?? null;
  } while (cursor);
  if (emitted === 0) throw new Error("empty_export");
}

export async function* createSnapshotMedia(
  loadPage: SnapshotPageLoader,
): AsyncIterable<
  { asset_id: string; storage_path: string; mime_type: string }
> {
  let cursor: string | null = null;
  do {
    const snapshot = await loadPage(cursor);
    for (const asset of snapshot.media ?? []) yield asset;
    cursor = snapshot.has_more ? snapshot.next_cursor ?? null : null;
    if (snapshot.has_more && !cursor) throw new Error("export_cursor_missing");
  } while (cursor);
}
