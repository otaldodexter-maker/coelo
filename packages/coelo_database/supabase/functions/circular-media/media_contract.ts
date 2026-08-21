export type CircularMediaEnvelope = Readonly<{
  institutionId: string;
  circularId: string;
  name: string;
  mimeType: string;
  sizeBytes: number;
  displayOrder: number;
}>;

const maximumBytesByMime = new Map<string, number>([
  ["image/jpeg", 10 * 1024 * 1024],
  ["image/png", 10 * 1024 * 1024],
  ["image/webp", 10 * 1024 * 1024],
  ["video/mp4", 25 * 1024 * 1024],
  ["application/pdf", 5 * 1024 * 1024],
]);

export function validateCircularMediaEnvelope(
  body: Record<string, unknown>,
): CircularMediaEnvelope {
  const maximumBytes = typeof body.mime_type === "string"
    ? maximumBytesByMime.get(body.mime_type)
    : undefined;
  if (
    typeof body.institution_id !== "string" || !body.institution_id ||
    typeof body.circular_id !== "string" || !body.circular_id ||
    typeof body.name !== "string" || body.name.trim().length < 1 ||
    body.name.length > 240 ||
    maximumBytes === undefined ||
    typeof body.size_bytes !== "number" ||
    !Number.isSafeInteger(body.size_bytes) || body.size_bytes < 1 ||
    body.size_bytes > maximumBytes ||
    typeof body.display_order !== "number" ||
    !Number.isInteger(body.display_order) || body.display_order < 0 ||
    body.display_order > 3
  ) {
    throw new Error("invalid_request");
  }
  return {
    institutionId: body.institution_id,
    circularId: body.circular_id,
    name: body.name.trim(),
    mimeType: body.mime_type as string,
    sizeBytes: body.size_bytes,
    displayOrder: body.display_order,
  };
}
