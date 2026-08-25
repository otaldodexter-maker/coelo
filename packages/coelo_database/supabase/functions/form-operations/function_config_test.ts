import { assertMatch } from "@std/assert";

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
