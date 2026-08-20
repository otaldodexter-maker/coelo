import { assertEquals, assertThrows } from "@std/assert";
import {
  authorizedOperationsRequest,
  operationsBearerToken,
} from "./auth_contract.ts";

const dedicated = "forms-operations-" + "s".repeat(48);

Deno.test("requires a dedicated operations bearer secret", () => {
  assertThrows(() => operationsBearerToken({}));
  assertThrows(() =>
    operationsBearerToken({ FORMS_OPERATIONS_BEARER_TOKEN: "short" })
  );
  assertEquals(
    operationsBearerToken({ FORMS_OPERATIONS_BEARER_TOKEN: dedicated }),
    dedicated,
  );
});

Deno.test("never accepts the Supabase service key as inbound worker authentication", () => {
  const serviceKey = "service-role-" + "k".repeat(48);
  const token = operationsBearerToken({
    FORMS_OPERATIONS_BEARER_TOKEN: dedicated,
    SUPABASE_SERVICE_ROLE_KEY: serviceKey,
  });

  assertEquals(authorizedOperationsRequest(`Bearer ${dedicated}`, token), true);
  assertEquals(
    authorizedOperationsRequest(`Bearer ${serviceKey}`, token),
    false,
  );
  assertEquals(authorizedOperationsRequest(dedicated, token), false);
  assertEquals(authorizedOperationsRequest(null, token), false);
});
