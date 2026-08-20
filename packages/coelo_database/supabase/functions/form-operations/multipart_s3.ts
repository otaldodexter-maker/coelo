export type MultipartS3Config = {
  endpoint: string;
  region: string;
  accessKeyId: string;
  secretAccessKey: string;
};

const required = [
  "FORMS_S3_ENDPOINT",
  "FORMS_S3_REGION",
  "FORMS_S3_ACCESS_KEY_ID",
  "FORMS_S3_SECRET_ACCESS_KEY",
] as const;

export function multipartS3Config(
  environment: Record<string, string | undefined>,
): MultipartS3Config {
  if (required.some((name) => !environment[name]?.trim())) {
    throw new Error("multipart_s3_not_configured");
  }
  return {
    endpoint: environment.FORMS_S3_ENDPOINT!,
    region: environment.FORMS_S3_REGION!,
    accessKeyId: environment.FORMS_S3_ACCESS_KEY_ID!,
    secretAccessKey: environment.FORMS_S3_SECRET_ACCESS_KEY!,
  };
}

const encoder = new TextEncoder();
const hex = (bytes: ArrayBuffer) =>
  [...new Uint8Array(bytes)].map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");

export async function sha256Hex(value: string | Uint8Array): Promise<string> {
  const bytes = typeof value === "string" ? encoder.encode(value) : value;
  return hex(
    await crypto.subtle.digest("SHA-256", Uint8Array.from(bytes).buffer),
  );
}

export async function hmacHex(
  key: string | Uint8Array,
  value: string,
): Promise<string> {
  return hex((await hmacBytes(key, value)).buffer);
}

async function hmacBytes(
  key: string | Uint8Array,
  value: string,
): Promise<Uint8Array<ArrayBuffer>> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    Uint8Array.from(typeof key === "string" ? encoder.encode(key) : key).buffer,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return new Uint8Array(
    await crypto.subtle.sign("HMAC", cryptoKey, encoder.encode(value)),
  );
}

export type MultipartPart = Readonly<{
  partNumber: number;
  etag: string;
}>;

type MultipartS3ClientOptions = Readonly<{
  fetch?: (request: Request) => Promise<Response>;
  now?: () => Date;
}>;

const awsEncode = (value: string) =>
  encodeURIComponent(value).replace(
    /[!'()*]/g,
    (character) => `%${character.charCodeAt(0).toString(16).toUpperCase()}`,
  );

function objectUrl(
  config: MultipartS3Config,
  bucket: string,
  key: string,
): URL {
  if (!/^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$/.test(bucket)) {
    throw new Error("multipart_s3_invalid_bucket");
  }
  const segments = key.split("/");
  if (
    !key || key.startsWith("/") ||
    segments.some((part) => !part || part === "." || part === "..")
  ) {
    throw new Error("multipart_s3_invalid_key");
  }
  return new URL(
    `${config.endpoint.replace(/\/+$/, "")}/${awsEncode(bucket)}/${
      segments.map(awsEncode).join("/")
    }`,
  );
}

function amzTimestamp(date: Date): string {
  return date.toISOString().replace(/[:-]|\.\d{3}/g, "");
}

function canonicalQuery(url: URL): string {
  return [...url.searchParams.entries()]
    .map(([name, value]) => [awsEncode(name), awsEncode(value)] as const)
    .sort(([leftName, leftValue], [rightName, rightValue]) =>
      leftName.localeCompare(rightName) || leftValue.localeCompare(rightValue)
    )
    .map(([name, value]) => `${name}=${value}`)
    .join("&");
}

async function signedHeaders(
  config: MultipartS3Config,
  method: string,
  url: URL,
  payload: string | Uint8Array,
  date: Date,
  contentType?: string,
): Promise<Headers> {
  const payloadHash = await sha256Hex(payload);
  const timestamp = amzTimestamp(date);
  const dateStamp = timestamp.slice(0, 8);
  const headers = new Headers({
    "x-amz-content-sha256": payloadHash,
    "x-amz-date": timestamp,
  });
  if (contentType) headers.set("content-type", contentType);

  const signedHeaderNames = contentType
    ? "content-type;host;x-amz-content-sha256;x-amz-date"
    : "host;x-amz-content-sha256;x-amz-date";
  const canonicalHeaders = contentType
    ? `content-type:${contentType.trim()}\nhost:${url.host}\nx-amz-content-sha256:${payloadHash}\nx-amz-date:${timestamp}\n`
    : `host:${url.host}\nx-amz-content-sha256:${payloadHash}\nx-amz-date:${timestamp}\n`;
  const canonicalRequest = [
    method,
    url.pathname,
    canonicalQuery(url),
    canonicalHeaders,
    signedHeaderNames,
    payloadHash,
  ].join("\n");
  const scope = `${dateStamp}/${config.region}/s3/aws4_request`;
  const stringToSign = [
    "AWS4-HMAC-SHA256",
    timestamp,
    scope,
    await sha256Hex(canonicalRequest),
  ].join("\n");
  const dateKey = await hmacBytes(`AWS4${config.secretAccessKey}`, dateStamp);
  const regionKey = await hmacBytes(dateKey, config.region);
  const serviceKey = await hmacBytes(regionKey, "s3");
  const signingKey = await hmacBytes(serviceKey, "aws4_request");
  const signature = await hmacHex(signingKey, stringToSign);
  headers.set(
    "authorization",
    `AWS4-HMAC-SHA256 Credential=${config.accessKeyId}/${scope}, SignedHeaders=${signedHeaderNames}, Signature=${signature}`,
  );
  return headers;
}

function xmlEscape(value: string): string {
  return value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(
    ">",
    "&gt;",
  )
    .replaceAll('"', "&quot;").replaceAll("'", "&apos;");
}

function xmlValue(xml: string, element: string): string | undefined {
  const match = xml.match(
    new RegExp(`<${element}[^>]*>([\\s\\S]*?)<\\/${element}>`, "i"),
  );
  return match?.[1]?.replaceAll("&quot;", '"').replaceAll("&apos;", "'")
    .replaceAll("&lt;", "<").replaceAll("&gt;", ">").replaceAll("&amp;", "&");
}

export class MultipartS3Client {
  readonly #fetch: (request: Request) => Promise<Response>;
  readonly #now: () => Date;

  constructor(
    readonly config: MultipartS3Config,
    options: MultipartS3ClientOptions = {},
  ) {
    this.#fetch = options.fetch ?? ((request) => fetch(request));
    this.#now = options.now ?? (() => new Date());
  }

  async initiate(
    bucket: string,
    key: string,
    contentType: string,
  ): Promise<{ uploadId: string }> {
    const response = await this.#request(
      "POST",
      bucket,
      key,
      { uploads: "" },
      "",
      contentType,
    );
    const uploadId = xmlValue(await response.text(), "UploadId")?.trim();
    if (!uploadId) throw new Error("multipart_s3_missing_upload_id");
    return { uploadId };
  }

  async uploadPart(
    bucket: string,
    key: string,
    uploadId: string,
    partNumber: number,
    body: Uint8Array,
  ): Promise<MultipartPart> {
    this.#validateUpload(uploadId);
    if (!Number.isInteger(partNumber) || partNumber < 1 || partNumber > 10000) {
      throw new Error("multipart_s3_invalid_part_number");
    }
    const response = await this.#request(
      "PUT",
      bucket,
      key,
      { partNumber: String(partNumber), uploadId },
      body,
    );
    const etag = response.headers.get("etag")?.trim();
    if (!etag) throw new Error("multipart_s3_missing_etag");
    return { partNumber, etag };
  }

  async complete(
    bucket: string,
    key: string,
    uploadId: string,
    parts: readonly MultipartPart[],
  ): Promise<{ etag?: string }> {
    this.#validateUpload(uploadId);
    if (!parts.length) throw new Error("multipart_s3_missing_parts");
    const ordered = [...parts].sort((left, right) =>
      left.partNumber - right.partNumber
    );
    if (
      ordered.some((part, index) =>
        !Number.isInteger(part.partNumber) || part.partNumber < 1 ||
        part.partNumber > 10000 ||
        !part.etag.trim() ||
        (index > 0 && part.partNumber === ordered[index - 1].partNumber)
      )
    ) {
      throw new Error("multipart_s3_invalid_parts");
    }
    const body = `<CompleteMultipartUpload>${
      ordered.map((part) =>
        `<Part><PartNumber>${part.partNumber}</PartNumber><ETag>${
          xmlEscape(part.etag)
        }</ETag></Part>`
      ).join("")
    }</CompleteMultipartUpload>`;
    const response = await this.#request(
      "POST",
      bucket,
      key,
      { uploadId },
      body,
      "application/xml",
    );
    const responseXml = await response.text();
    const errorCode = xmlValue(responseXml, "Code")?.trim();
    if (/<Error(?:\s|>)/i.test(responseXml) && errorCode) {
      throw new Error(`multipart_s3_complete_${errorCode}`);
    }
    return { etag: xmlValue(responseXml, "ETag")?.trim() || undefined };
  }

  async abort(bucket: string, key: string, uploadId: string): Promise<void> {
    this.#validateUpload(uploadId);
    try {
      await this.#request("DELETE", bucket, key, { uploadId }, "");
    } catch (error) {
      // Supabase may already have applied its 24-hour multipart expiration.
      // A missing upload is the desired terminal state for cleanup.
      if (
        error instanceof Error && error.message === "multipart_s3_http_404"
      ) return;
      throw error;
    }
  }

  #validateUpload(uploadId: string): void {
    if (!uploadId.trim()) throw new Error("multipart_s3_invalid_upload_id");
  }

  async #request(
    method: string,
    bucket: string,
    key: string,
    query: Readonly<Record<string, string>>,
    body: string | Uint8Array,
    contentType?: string,
  ): Promise<Response> {
    const url = objectUrl(this.config, bucket, key);
    for (const [name, value] of Object.entries(query)) {
      url.searchParams.set(name, value);
    }
    const headers = await signedHeaders(
      this.config,
      method,
      url,
      body,
      this.#now(),
      contentType,
    );
    const request = new Request(url, {
      method,
      headers,
      body: method === "DELETE"
        ? undefined
        : typeof body === "string"
        ? body
        : Uint8Array.from(body),
    });
    const response = await this.#fetch(request);
    if (!response.ok) throw new Error(`multipart_s3_http_${response.status}`);
    return response;
  }
}
