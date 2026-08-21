export type MomentsR2Config = Readonly<{
  endpoint: string;
  region: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucket: string;
}>;

const required = [
  "MOMENTS_R2_ENDPOINT",
  "MOMENTS_R2_REGION",
  "MOMENTS_R2_ACCESS_KEY_ID",
  "MOMENTS_R2_SECRET_ACCESS_KEY",
  "MOMENTS_R2_BUCKET",
] as const;

export function momentsR2Config(
  environment: Record<string, string | undefined>,
): MomentsR2Config {
  if (required.some((name) => !environment[name]?.trim())) {
    throw new Error("moments_r2_not_configured");
  }
  const endpoint = new URL(environment.MOMENTS_R2_ENDPOINT!);
  if (endpoint.protocol !== "https:") {
    throw new Error("moments_r2_invalid_endpoint");
  }
  const bucket = environment.MOMENTS_R2_BUCKET!;
  if (!/^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$/.test(bucket)) {
    throw new Error("moments_r2_invalid_bucket");
  }
  return {
    endpoint: endpoint.toString().replace(/\/+$/, ""),
    region: environment.MOMENTS_R2_REGION!,
    accessKeyId: environment.MOMENTS_R2_ACCESS_KEY_ID!,
    secretAccessKey: environment.MOMENTS_R2_SECRET_ACCESS_KEY!,
    bucket,
  };
}

type Options = Readonly<{
  fetch?: (request: Request) => Promise<Response>;
  now?: () => Date;
}>;

export type SignedR2Request = Readonly<{
  url: URL;
  requiredHeaders: Readonly<Record<string, string>>;
}>;

export type R2ObjectMetadata = Readonly<{
  byteSize: number;
  mimeType: string;
  etag?: string;
}>;

const encoder = new TextEncoder();
const awsEncode = (value: string) =>
  encodeURIComponent(value).replace(
    /[!'()*]/g,
    (character) => `%${character.charCodeAt(0).toString(16).toUpperCase()}`,
  );
const hex = (bytes: ArrayBuffer) =>
  [...new Uint8Array(bytes)].map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");

async function sha256(value: string | Uint8Array) {
  const bytes = typeof value === "string" ? encoder.encode(value) : value;
  return hex(
    await crypto.subtle.digest("SHA-256", Uint8Array.from(bytes).buffer),
  );
}

async function hmac(key: string | Uint8Array, value: string) {
  const bytes = typeof key === "string" ? encoder.encode(key) : key;
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    Uint8Array.from(bytes).buffer,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return new Uint8Array(
    await crypto.subtle.sign("HMAC", cryptoKey, encoder.encode(value)),
  );
}

function timestamp(date: Date) {
  return date.toISOString().replace(/[:-]|\.\d{3}/g, "");
}

function canonicalQuery(url: URL) {
  return [...url.searchParams.entries()]
    .map(([name, value]) => [awsEncode(name), awsEncode(value)] as const)
    .sort(([leftName, leftValue], [rightName, rightValue]) =>
      leftName.localeCompare(rightName) || leftValue.localeCompare(rightValue)
    )
    .map(([name, value]) => `${name}=${value}`)
    .join("&");
}

function objectUrl(config: MomentsR2Config, key: string) {
  const parts = key.split("/");
  if (
    !key || key.startsWith("/") ||
    parts.some((part) => !part || part === "." || part === "..")
  ) {
    throw new Error("moments_r2_invalid_key");
  }
  return new URL(
    `${config.endpoint}/${awsEncode(config.bucket)}/${
      parts.map(awsEncode).join("/")
    }`,
  );
}

export class MomentsR2Client {
  readonly #fetch: (request: Request) => Promise<Response>;
  readonly #now: () => Date;

  constructor(readonly config: MomentsR2Config, options: Options = {}) {
    this.#fetch = options.fetch ?? ((request) => fetch(request));
    this.#now = options.now ?? (() => new Date());
  }

  presignPut(key: string, mimeType: string, expiresSeconds = 300) {
    return this.#presign("PUT", key, expiresSeconds, mimeType);
  }

  presignGet(key: string, expiresSeconds = 120) {
    return this.#presign("GET", key, expiresSeconds);
  }

  async head(key: string): Promise<R2ObjectMetadata> {
    const signed = await this.#presign("HEAD", key, 120);
    const response = await this.#fetch(
      new Request(signed.url, { method: "HEAD" }),
    );
    if (!response.ok) throw new Error(`moments_r2_http_${response.status}`);
    const size = Number(response.headers.get("content-length"));
    const mimeType =
      response.headers.get("content-type")?.split(";", 1)[0]?.trim() ?? "";
    if (!Number.isSafeInteger(size) || size < 1 || !mimeType) {
      throw new Error("moments_r2_invalid_metadata");
    }
    return {
      byteSize: size,
      mimeType,
      etag: response.headers.get("etag") ?? undefined,
    };
  }

  async delete(key: string): Promise<void> {
    const signed = await this.#presign("DELETE", key, 120);
    const response = await this.#fetch(
      new Request(signed.url, { method: "DELETE" }),
    );
    if (!response.ok && response.status !== 404) {
      throw new Error(`moments_r2_http_${response.status}`);
    }
  }

  async #presign(
    method: string,
    key: string,
    expiresSeconds: number,
    contentType?: string,
  ): Promise<SignedR2Request> {
    if (
      !Number.isInteger(expiresSeconds) || expiresSeconds < 1 ||
      expiresSeconds > 900
    ) {
      throw new Error("moments_r2_invalid_expiry");
    }
    const url = objectUrl(this.config, key);
    const amzDate = timestamp(this.#now());
    const date = amzDate.slice(0, 8);
    const scope = `${date}/${this.config.region}/s3/aws4_request`;
    const signedHeaders = contentType ? "content-type;host" : "host";
    url.searchParams.set("X-Amz-Algorithm", "AWS4-HMAC-SHA256");
    url.searchParams.set(
      "X-Amz-Credential",
      `${this.config.accessKeyId}/${scope}`,
    );
    url.searchParams.set("X-Amz-Date", amzDate);
    url.searchParams.set("X-Amz-Expires", String(expiresSeconds));
    url.searchParams.set("X-Amz-SignedHeaders", signedHeaders);
    const canonicalHeaders = contentType
      ? `content-type:${contentType.trim()}\nhost:${url.host}\n`
      : `host:${url.host}\n`;
    const canonicalRequest = [
      method,
      url.pathname,
      canonicalQuery(url),
      canonicalHeaders,
      signedHeaders,
      "UNSIGNED-PAYLOAD",
    ].join("\n");
    const stringToSign = [
      "AWS4-HMAC-SHA256",
      amzDate,
      scope,
      await sha256(canonicalRequest),
    ].join("\n");
    const dateKey = await hmac(`AWS4${this.config.secretAccessKey}`, date);
    const regionKey = await hmac(dateKey, this.config.region);
    const serviceKey = await hmac(regionKey, "s3");
    const signingKey = await hmac(serviceKey, "aws4_request");
    url.searchParams.set(
      "X-Amz-Signature",
      hex((await hmac(signingKey, stringToSign)).buffer),
    );
    return {
      url,
      requiredHeaders: contentType ? { "content-type": contentType } : {},
    };
  }
}
