import {
  R2Client,
  type R2Config,
  type R2Options,
  R2TransportError,
  validateR2Config,
} from "../_shared/r2_s3.ts";

function compatibleError(error: unknown): never {
  if (error instanceof R2TransportError) throw new Error(`entity_r2_${error.code}`);
  throw error;
}

export function entityR2Config(environment: Record<string, string | undefined>): R2Config {
  try {
    return validateR2Config({
      endpoint: environment.COELO_R2_ENDPOINT ?? "",
      region: environment.COELO_R2_REGION ?? "auto",
      accessKeyId: environment.COELO_R2_ACCESS_KEY_ID ?? "",
      secretAccessKey: environment.COELO_R2_SECRET_ACCESS_KEY ?? "",
      bucket: "coelo-media-prod",
    });
  } catch (error) {
    return compatibleError(error);
  }
}

export class EntityR2Client {
  readonly #client: R2Client;

  constructor(config: R2Config, options: R2Options = {}) {
    this.#client = new R2Client(validateR2Config(config), options);
  }

  presignPut(key: string, mimeType: string, expiresSeconds = 300) {
    return this.#client.presignPut(key, mimeType, expiresSeconds).catch(compatibleError);
  }

  presignGet(key: string, expiresSeconds = 120) {
    return this.#client.presignGet(key, expiresSeconds).catch(compatibleError);
  }

  put(key: string, bytes: Uint8Array, mimeType: string) {
    return this.#client.put(key, bytes, mimeType).catch(compatibleError);
  }

  head(key: string) {
    return this.#client.head(key).catch(compatibleError);
  }

  get(key: string, maxBytes: number) {
    return this.#client.get(key, maxBytes).catch(compatibleError);
  }

  delete(key: string) {
    return this.#client.delete(key).catch(compatibleError);
  }
}
