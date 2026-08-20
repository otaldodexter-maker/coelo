const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const OPAQUE_PATH = /^[0-9a-f]{2}\/[0-9a-f-]{36}$/;

type CleanupKind = "cleanup_uploads" | "cleanup_artifacts";

type CleanupItem = Readonly<{
  id: string;
  storage_path: string | null;
  multipart_bucket?: string | null;
  multipart_path?: string | null;
  multipart_upload_id?: string | null;
}>;

type CleanupSnapshot = Readonly<{
  kind: CleanupKind;
  items: CleanupItem[];
}>;

export type CleanupInput = Readonly<{
  jobId: string;
  workerId: string;
  snapshot: () => Promise<unknown>;
  abortMultipart: (
    bucket: string,
    path: string,
    uploadId: string,
  ) => Promise<void>;
  removeStorage: (paths: string[]) => Promise<void>;
  complete: (ids: string[]) => Promise<void>;
}>;

function parseSnapshot(value: unknown): CleanupSnapshot {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("cleanup_snapshot_invalid");
  }
  const snapshot = value as Record<string, unknown>;
  if (
    (snapshot.kind !== "cleanup_uploads" &&
      snapshot.kind !== "cleanup_artifacts") ||
    !Array.isArray(snapshot.items) || snapshot.items.length > 200
  ) throw new Error("cleanup_snapshot_invalid");
  for (const value of snapshot.items) {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      throw new Error("cleanup_snapshot_invalid");
    }
    const item = value as Record<string, unknown>;
    if (
      typeof item.id !== "string" || !UUID.test(item.id) ||
      !(item.storage_path === null ||
        (typeof item.storage_path === "string" &&
          OPAQUE_PATH.test(item.storage_path)))
    ) throw new Error("cleanup_snapshot_invalid");
    const multipart = [
      item.multipart_bucket,
      item.multipart_path,
      item.multipart_upload_id,
    ];
    const present = multipart.filter((part) => part != null).length;
    if (
      present !== 0 &&
      !(present === 3 && item.multipart_bucket === "coelo-forms-private" &&
        typeof item.multipart_path === "string" &&
        OPAQUE_PATH.test(item.multipart_path) &&
        typeof item.multipart_upload_id === "string" &&
        item.multipart_upload_id.length >= 1 &&
        item.multipart_upload_id.length <= 1024 &&
        !/[\u0000-\u001f\u007f]/.test(item.multipart_upload_id))
    ) throw new Error("cleanup_snapshot_invalid");
  }
  return snapshot as unknown as CleanupSnapshot;
}

export async function cleanupExpiredItems(
  input: CleanupInput,
): Promise<number> {
  const snapshot = parseSnapshot(await input.snapshot());
  for (const item of snapshot.items) {
    if (
      item.multipart_bucket && item.multipart_path &&
      item.multipart_upload_id
    ) {
      await input.abortMultipart(
        item.multipart_bucket,
        item.multipart_path,
        item.multipart_upload_id,
      );
    }
  }
  const paths = snapshot.items.flatMap((item) =>
    item.storage_path == null ? [] : [item.storage_path]
  );
  if (paths.length > 0) await input.removeStorage(paths);
  await input.complete(snapshot.items.map((item) => item.id));
  return snapshot.items.length;
}
