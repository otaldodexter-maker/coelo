// C01 I015: Windows CurrentUser DPAPI storage. No Auth or PostgreSQL operations.
import { win32 } from "node:path";
import { fileURLToPath } from "node:url";
import {
  PackageError,
  type Plan,
  type SecretReceipt,
  type SecretStore,
  validatePlan,
} from "./e2-r01-auth-personas.ts";

export interface SecretStoreRequest {
  readonly version: 1;
  readonly operation: "read" | "reserve" | "mark-created";
  readonly directory: string;
  readonly planId: string;
  readonly authUserId: string;
  readonly receipt?: SecretReceipt;
}
export type SecretStoreInvoker = (
  request: SecretStoreRequest,
) => Promise<unknown>;
export interface WindowsSecretStoreContext {
  readonly plan: Plan;
  readonly directory: string;
  readonly powerShellPath: string;
}

function requireValue(value: unknown): asserts value {
  if (!value) throw new PackageError("SECRET_STORE_INVALID_DATA");
}

function exactObject(
  value: unknown,
  keys: readonly string[],
): asserts value is Record<string, unknown> {
  requireValue(
    value !== null && typeof value === "object" && !Array.isArray(value) &&
      Object.keys(value).length === keys.length &&
      keys.every((key) => Object.hasOwn(value, key)),
  );
}

function hasControl(value: string): boolean {
  return Array.from(value).some((character) => {
    const code = character.codePointAt(0)!;
    return code < 32 || code === 127;
  });
}

function localPath(value: string): string {
  requireValue(
    typeof value === "string" && /^[a-z]:[\\/]/i.test(value) &&
      !hasControl(value) && !value.slice(2).includes(":"),
  );
  const path = win32.normalize(value);
  requireValue(path !== win32.parse(path).root);
  return path;
}

function receiptValue(
  value: unknown,
  planId: string,
  authUserId: string,
): SecretReceipt {
  exactObject(value, ["planId", "authUserId", "password", "state"]);
  requireValue(
    value.planId === planId && value.authUserId === authUserId &&
      typeof value.password === "string" && value.password.length >= 32 &&
      value.password.length <= 256 && !hasControl(value.password) &&
      (value.state === "reserved" || value.state === "created"),
  );
  return {
    planId,
    authUserId,
    password: value.password,
    state: value.state,
  };
}

function privatePipeInvoker(powerShellPath: string): SecretStoreInvoker {
  const helper = fileURLToPath(
    new URL("./Invoke-E2R01PersonaSecretStore.ps1", import.meta.url),
  );
  return async (request) => {
    let child: Deno.ChildProcess | undefined;
    let output: Promise<Deno.CommandOutput> | undefined;
    let timer: ReturnType<typeof setTimeout> | undefined;
    let encoded: Uint8Array | undefined;
    try {
      requireValue(Deno.build.os === "windows");
      encoded = new TextEncoder().encode(JSON.stringify(request));
      requireValue(encoded.length <= 65536);
      child = new Deno.Command(powerShellPath, {
        args: [
          "-NoLogo",
          "-NoProfile",
          "-NonInteractive",
          "-WindowStyle",
          "Hidden",
          "-File",
          helper,
        ],
        stdin: "piped",
        stdout: "piped",
        stderr: "piped",
        windowsRawArguments: false,
      }).spawn();
      // Drain both output pipes while writing stdin; never inherit a console or
      // place a receipt in a command argument, environment variable or temp file.
      output = child.output();
      const running = child;
      timer = setTimeout(() => {
        try {
          running.kill();
        } catch (_) { /* Already exited. */ }
      }, 30000);
      const writer = child.stdin.getWriter();
      try {
        await writer.write(encoded);
        await writer.close();
      } finally {
        writer.releaseLock();
      }
      const result = await output;
      try {
        requireValue(
          result.success && result.stderr.length === 0 &&
            result.stdout.length > 0 && result.stdout.length <= 65536,
        );
        return JSON.parse(
          new TextDecoder("utf-8", { fatal: true }).decode(result.stdout),
        );
      } finally {
        result.stdout.fill(0);
        result.stderr.fill(0);
      }
    } catch (_) {
      if (child) {
        try {
          child.kill();
        } catch (_) { /* Already exited. */ }
      }
      if (output) {
        const pending = await output.catch(() => null);
        pending?.stdout.fill(0);
        pending?.stderr.fill(0);
      }
      // No raw process output, request body, filesystem path or exception text.
      // An uncertain reservation remains on disk for an explicit later read.
      throw new PackageError("SECRET_STORE_UNAVAILABLE");
    } finally {
      if (timer !== undefined) clearTimeout(timer);
      encoded?.fill(0);
    }
  };
}

export function windowsPersonaSecretStore(
  context: WindowsSecretStoreContext,
  invoke?: SecretStoreInvoker,
): SecretStore {
  let nominal: Plan;
  let directory: string;
  let powerShellPath: string;
  try {
    nominal = structuredClone(context.plan);
    validatePlan(nominal);
    directory = localPath(context.directory);
    powerShellPath = localPath(context.powerShellPath);
  } catch (_) {
    throw new PackageError("SECRET_STORE_INVALID_CONTEXT");
  }
  const ids = new Set(nominal.personas.map((item) => item.authUserId));
  const transport = invoke ?? privatePipeInvoker(powerShellPath);

  function requireId(id: string) {
    requireValue(typeof id === "string" && ids.has(id));
  }

  async function request(
    operation: SecretStoreRequest["operation"],
    authUserId: string,
    receipt?: SecretReceipt,
  ) {
    requireId(authUserId);
    const input: SecretStoreRequest = Object.freeze({
      version: 1,
      operation,
      directory,
      planId: nominal.id,
      authUserId,
      ...(receipt ? { receipt: Object.freeze({ ...receipt }) } : {}),
    });
    let response: unknown;
    try {
      response = await transport(input);
    } catch (_) {
      throw new PackageError("SECRET_STORE_UNAVAILABLE");
    }
    exactObject(response, [
      "version",
      "ok",
      "operation",
      "planId",
      "authUserId",
      ...(operation === "read" ? ["receipt"] : []),
    ]);
    requireValue(
      response.version === 1 && response.ok === true &&
        response.operation === operation && response.planId === nominal.id &&
        response.authUserId === authUserId,
    );
    return response;
  }

  return {
    async read(id) {
      const response = await request("read", id);
      return response.receipt === null
        ? null
        : receiptValue(response.receipt, nominal.id, id);
    },
    async reserve(receipt) {
      exactObject(receipt, ["planId", "authUserId", "password", "state"]);
      requireId(receipt.authUserId);
      const original = receiptValue(receipt, nominal.id, receipt.authUserId);
      requireValue(original.state === "reserved");
      await request("reserve", original.authUserId, original);
      const current = receiptValue(receipt, nominal.id, original.authUserId);
      requireValue(
        current.state === original.state &&
          current.password === original.password,
      );
    },
    async markCreated(id) {
      await request("mark-created", id);
    },
  };
}
