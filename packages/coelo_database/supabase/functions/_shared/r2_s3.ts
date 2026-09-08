export type R2Config = Readonly<{
  endpoint: string;
  region: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucket: string;
}>;

export class R2TransportError extends Error {
  constructor(readonly code: string) {
    super(`r2_${code}`);
    this.name = "R2TransportError";
  }
}

export function validateR2Config(config: R2Config): R2Config {
  if (
    Object.values(config).some((value) => !value?.trim()) ||
    !config.endpoint || !config.region || !config.accessKeyId ||
    !config.secretAccessKey || !config.bucket
  ) {
    throw new R2TransportError("not_configured");
  }
  let endpoint: URL;
  try {
    endpoint = new URL(config.endpoint);
  } catch {
    throw new R2TransportError("invalid_endpoint");
  }
  if (
    endpoint.protocol !== "https:" || endpoint.username || endpoint.password ||
    endpoint.search || endpoint.hash || config.endpoint.includes("?") ||
    config.endpoint.includes("#")
  ) {
    throw new R2TransportError("invalid_endpoint");
  }
  if (!/^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$/.test(config.bucket)) {
    throw new R2TransportError("invalid_bucket");
  }
  return Object.freeze({
    ...config,
    endpoint: endpoint.toString().replace(/\/+$/, ""),
  });
}

export type R2Options = Readonly<{
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
      (leftName < rightName ? -1 : leftName > rightName ? 1 : 0) ||
      (leftValue < rightValue ? -1 : leftValue > rightValue ? 1 : 0)
    )
    .map(([name, value]) => `${name}=${value}`)
    .join("&");
}

function objectUrl(config: R2Config, key: string) {
  const parts = key.split("/");
  if (
    !key || key.startsWith("/") ||
    parts.some((part) => !part || part === "." || part === "..")
  ) {
    throw new R2TransportError("invalid_key");
  }
  return new URL(
    `${config.endpoint}/${awsEncode(config.bucket)}/${
      parts.map(awsEncode).join("/")
    }`,
  );
}

export class R2Client {
  readonly #fetch: (request: Request) => Promise<Response>;
  readonly #now: () => Date;

  readonly config: R2Config;

  constructor(config: R2Config, options: R2Options = {}) {
    this.config = validateR2Config(config);
    this.#fetch = options.fetch ?? ((request) => fetch(request));
    this.#now = options.now ?? (() => new Date());
  }

  presignPut(key: string, mimeType: string, expiresSeconds = 300) {
    return this.#presign("PUT", key, expiresSeconds, mimeType);
  }

  presignGet(key: string, expiresSeconds = 120) {
    return this.#presign("GET", key, expiresSeconds);
  }

  /** Reads bytes for server-side verification, never trusting object MIME or
   * Content-Length as proof. The caller selects the authorized purpose's limit
   * and must still decode, normalize, check checksum and reauthorize finalize.
   * No cache or retry: a failed read returns no partial bytes.
   */
  async get(key: string, maxBytes: number): Promise<Uint8Array> {
    if (!Number.isSafeInteger(maxBytes) || maxBytes < 1) {
      throw new R2TransportError("invalid_limit");
    }
    const signed = await this.presignGet(key);
    let response: Response | undefined;
    let reader: ReadableStreamDefaultReader<Uint8Array> | undefined;
    try {
      response = await this.#fetch(
        new Request(signed.url, {
          redirect: "error",
          signal: AbortSignal.timeout(30_000),
        }),
      );
      if (response.status !== 200) {
        throw new R2TransportError(`http_${response.status}`);
      }
      const rawLength = response.headers.get("content-length");
      const length = rawLength === null ? undefined : Number(rawLength);
      if (
        rawLength !== null &&
        (!/^[0-9]+$/.test(rawLength) || !Number.isSafeInteger(length) ||
          length! < 1)
      ) {
        throw new R2TransportError("invalid_metadata");
      }
      if (length !== undefined && length > maxBytes) {
        throw new R2TransportError("size_limit");
      }
      if (!response.body) throw new R2TransportError("invalid_body");
      reader = response.body.getReader();
      const chunks: Uint8Array[] = [];
      let size = 0;
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        if (value.byteLength > maxBytes - size) {
          throw new R2TransportError("size_limit");
        }
        size += value.byteLength;
        if (value.byteLength) chunks.push(value.slice());
      }
      if (size === 0 || (length !== undefined && size !== length)) {
        throw new R2TransportError("invalid_body");
      }
      const bytes = new Uint8Array(size);
      let offset = 0;
      for (const chunk of chunks) {
        bytes.set(chunk, offset);
        offset += chunk.byteLength;
      }
      return bytes;
    } catch (error) {
      if (error instanceof R2TransportError) throw error;
      throw new R2TransportError("transport_failed");
    } finally {
      // Release/cancel even on a rejected header, overflow or broken stream.
      if (reader) {
        await reader.cancel().catch(() => {});
        reader.releaseLock();
      } else {
        await response?.body?.cancel().catch(() => {});
      }
    }
  }

  /** Writes already-validated/generated bytes. Authorization, immutable key,
   * catalog commit and orphan cleanup remain responsibilities of the gateway.
   * An ambiguous failure is not retried here or reported as a persisted asset.
   */
  async put(key: string, bytes: Uint8Array, mimeType: string): Promise<void> {
    if (!(bytes instanceof Uint8Array) || bytes.byteLength === 0) {
      throw new R2TransportError("invalid_body");
    }
    if (
      !/^[a-z0-9][a-z0-9!#$&^_.+-]*\/[a-z0-9][a-z0-9!#$&^_.+-]*$/i.test(
        mimeType,
      )
    ) {
      throw new R2TransportError("invalid_mime");
    }
    const body = Uint8Array.from(bytes);
    const signed = await this.presignPut(key, mimeType);
    let response: Response | undefined;
    try {
      response = await this.#fetch(
        new Request(signed.url, {
          method: "PUT",
          headers: signed.requiredHeaders,
          body,
          redirect: "error",
          signal: AbortSignal.timeout(30_000),
        }),
      );
      if (!response.ok) throw new R2TransportError(`http_${response.status}`);
    } catch (error) {
      if (error instanceof R2TransportError) throw error;
      throw new R2TransportError("transport_failed");
    } finally {
      await response?.body?.cancel().catch(() => {});
    }
  }

  async head(key: string): Promise<R2ObjectMetadata> {
    const signed = await this.#presign("HEAD", key, 120);
    const response = await this.#fetch(
      new Request(signed.url, { method: "HEAD" }),
    );
    if (!response.ok) throw new R2TransportError(`http_${response.status}`);
    const size = Number(response.headers.get("content-length"));
    const mimeType =
      response.headers.get("content-type")?.split(";", 1)[0]?.trim() ?? "";
    if (!Number.isSafeInteger(size) || size < 1 || !mimeType) {
      throw new R2TransportError("invalid_metadata");
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
      throw new R2TransportError(`http_${response.status}`);
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
      throw new R2TransportError("invalid_expiry");
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
