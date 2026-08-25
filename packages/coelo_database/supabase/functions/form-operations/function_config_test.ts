import { assertEquals, assertMatch } from "@std/assert";

const config = await Deno.readTextFile(
  new URL("../../config.toml", import.meta.url),
);

Deno.test("registers the authenticated media endpoint and service-only operations worker", () => {
  assertMatch(
    config,
    /\[functions\.form-media\]\s+verify_jwt\s*=\s*true/m,
  );
  assertMatch(
    config,
    /\[functions\.form-export-download\]\s+verify_jwt\s*=\s*true/m,
  );
  assertMatch(
    config,
    /\[functions\.form-operations\]\s+verify_jwt\s*=\s*false/m,
  );
});

Deno.test("registers circular media for handler-owned authorization", () => {
  assertMatch(
    config,
    /\[functions\.circular-media\]\s+verify_jwt\s*=\s*false/m,
  );
});

Deno.test("keeps circular media server credentials out of Flutter sources", async () => {
  const flutterApps = new URL("../../../../../apps/", import.meta.url);
  const forbidden = /SUPABASE_SERVICE_ROLE_KEY|CIRCULAR_MEDIA_WORKER_SECRET/;
  const leaks: string[] = [];

  async function inspect(directory: URL): Promise<void> {
    for await (const entry of Deno.readDir(directory)) {
      const path = new URL(
        `${entry.name}${entry.isDirectory ? "/" : ""}`,
        directory,
      );
      if (entry.isDirectory) {
        await inspect(path);
      } else if (entry.name.endsWith(".dart")) {
        const source = await Deno.readTextFile(path);
        if (forbidden.test(source)) leaks.push(path.pathname);
      }
    }
  }

  for await (const app of Deno.readDir(flutterApps)) {
    if (!app.isDirectory) continue;
    const library = new URL(`${app.name}/lib/`, flutterApps);
    try {
      await inspect(library);
    } catch (error) {
      if (!(error instanceof Deno.errors.NotFound)) throw error;
    }
  }

  assertEquals(leaks, []);
});
