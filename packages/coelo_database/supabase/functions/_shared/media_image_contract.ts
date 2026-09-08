type ImageMetrics = Readonly<{
  mimeType: string;
  byteSize: number;
  width: number;
  height: number;
  sha256: string;
}>;

const MiB = 1024 * 1024;
const policies = new Map([
  ["avatar", {
    sourceBytes: 8 * MiB,
    pixels: 25_000_000,
    minWidth: 256,
    minHeight: 256,
    masterBytes: 2 * MiB,
    maxWidth: 1024,
    maxHeight: 1024,
    ratio: 1,
  }],
  ["logo", {
    sourceBytes: 8 * MiB,
    pixels: 25_000_000,
    minWidth: 256,
    minHeight: 256,
    masterBytes: 2 * MiB,
    maxWidth: 1024,
    maxHeight: 1024,
    ratio: 0,
  }],
  ["cover", {
    sourceBytes: 12 * MiB,
    pixels: 36_000_000,
    minWidth: 1200,
    minHeight: 400,
    masterBytes: 3 * MiB,
    maxWidth: 2400,
    maxHeight: 800,
    ratio: 3,
  }],
  ["photo", {
    sourceBytes: 10 * MiB,
    pixels: 36_000_000,
    minWidth: 1,
    minHeight: 1,
    masterBytes: 4 * MiB,
    maxWidth: 2560,
    maxHeight: 2560,
    ratio: 0,
  }],
  ["map", {
    sourceBytes: 20 * MiB,
    pixels: 64_000_000,
    minWidth: 1,
    minHeight: 1,
    masterBytes: 8 * MiB,
    maxWidth: 6000,
    maxHeight: 6000,
    ratio: 0,
  }],
]);
const fields = new Set(["mimeType", "byteSize", "width", "height", "sha256"]);

/**
 * ADR 0032 policy checks on measured decoder output, NOT a decoder or verifier.
 * The server selects purpose/stage and supplies metrics computed from actual
 * bytes. Passing this function proves no authorization, checksum calculation,
 * EXIF removal, animation policy, malware scan, or successful full decoding.
 * HEIC/HEIF must be converted before this normalized-format boundary.
 * The gateway must still limit bytes/pixels of the received HEIC/HEIF source;
 * measurements of a converted file do not replace those source limits.
 * Renditions need their own reserved profiles; this validates source/master only.
 */
export function validateImageMetrics(
  purpose: unknown,
  stage: unknown,
  metrics: unknown,
): ImageMetrics {
  const invalid = (): never => {
    throw new Error("media_image_metrics_invalid");
  };
  const policy = typeof purpose === "string"
    ? policies.get(purpose)
    : undefined;
  if (!policy || (stage !== "source" && stage !== "master")) return invalid();
  if (!metrics || typeof metrics !== "object" || Array.isArray(metrics)) {
    return invalid();
  }
  if (Object.keys(metrics).some((key) => !fields.has(key))) return invalid();
  const { mimeType, byteSize, width, height, sha256 } = metrics as Record<
    string,
    unknown
  >;
  if (
    mimeType !== "image/jpeg" && mimeType !== "image/png" &&
    mimeType !== "image/webp"
  ) return invalid();
  if (
    typeof byteSize !== "number" || !Number.isSafeInteger(byteSize) ||
    byteSize < 1 ||
    typeof width !== "number" || !Number.isSafeInteger(width) || width < 1 ||
    typeof height !== "number" || !Number.isSafeInteger(height) || height < 1 ||
    typeof sha256 !== "string" || !/^[a-f0-9]{64}$/.test(sha256)
  ) return invalid();
  if (stage === "source") {
    if (
      byteSize > policy.sourceBytes || width < policy.minWidth ||
      height < policy.minHeight ||
      width > Math.floor(policy.pixels / height)
    ) return invalid();
  } else if (
    byteSize > policy.masterBytes || width > policy.maxWidth ||
    height > policy.maxHeight ||
    (policy.ratio !== 0 && width !== height * policy.ratio)
  ) return invalid();
  return Object.freeze({ mimeType, byteSize, width, height, sha256 });
}
