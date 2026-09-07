import {
  R2Client,
  type R2Config,
  type R2Options,
  R2TransportError,
  validateR2Config,
} from "../_shared/r2_s3.ts";
export type { R2ObjectMetadata, SignedR2Request } from "../_shared/r2_s3.ts";

export type MomentsR2Config = R2Config;

// Keep the existing consumer's API and error codes while sharing transport.
function compatibleError(error: unknown): never {
  if (error instanceof R2TransportError) {
    throw new Error(`moments_r2_${error.code}`);
  }
  throw error;
}

function validate(config: MomentsR2Config): MomentsR2Config {
  try {
    return validateR2Config(config);
  } catch (error) {
    return compatibleError(error);
  }
}

export function momentsR2Config(
  environment: Record<string, string | undefined>,
): MomentsR2Config {
  return validate({
    endpoint: environment.MOMENTS_R2_ENDPOINT ?? "",
    region: environment.MOMENTS_R2_REGION ?? "",
    accessKeyId: environment.MOMENTS_R2_ACCESS_KEY_ID ?? "",
    secretAccessKey: environment.MOMENTS_R2_SECRET_ACCESS_KEY ?? "",
    bucket: environment.MOMENTS_R2_BUCKET ?? "",
  });
}

export class MomentsR2Client {
  readonly #client: R2Client;
  readonly config: MomentsR2Config;

  constructor(config: MomentsR2Config, options: R2Options = {}) {
    this.config = validate(config);
    this.#client = new R2Client(this.config, options);
  }

  presignPut(key: string, mimeType: string, expiresSeconds = 300) {
    return this.#client.presignPut(key, mimeType, expiresSeconds).catch(
      compatibleError,
    );
  }

  presignGet(key: string, expiresSeconds = 120) {
    return this.#client.presignGet(key, expiresSeconds).catch(compatibleError);
  }

  head(key: string) {
    return this.#client.head(key).catch(compatibleError);
  }

  delete(key: string) {
    return this.#client.delete(key).catch(compatibleError);
  }
}
