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
  // Token unico de midia COELO_R2_* (ADR 0034, Decisao 11) com MOMENTS_R2_*
  // como sobrescrita local; bucket padrao coelo-media-prod (ADR 0032).
  return validate({
    endpoint: environment.MOMENTS_R2_ENDPOINT ?? environment.COELO_R2_ENDPOINT ?? "",
    region: environment.MOMENTS_R2_REGION ?? environment.COELO_R2_REGION ?? "",
    accessKeyId: environment.MOMENTS_R2_ACCESS_KEY_ID ?? environment.COELO_R2_ACCESS_KEY_ID ?? "",
    secretAccessKey: environment.MOMENTS_R2_SECRET_ACCESS_KEY ?? environment.COELO_R2_SECRET_ACCESS_KEY ?? "",
    bucket: environment.MOMENTS_R2_BUCKET ?? "coelo-media-prod",
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

  /// Le de volta os bytes ja armazenados, limitados por [maxBytes], para que a
  /// finalizacao possa conferir a assinatura MIME real em vez de confiar no
  /// Content-Type que o proprio cliente declarou no PUT.
  get(key: string, maxBytes: number) {
    return this.#client.get(key, maxBytes).catch(compatibleError);
  }

  delete(key: string) {
    return this.#client.delete(key).catch(compatibleError);
  }
}
