const OPERATIONS_TOKEN = /^[\x21-\x7e]{32,256}$/;

export function operationsBearerToken(
  environment: Record<string, string | undefined>,
): string {
  const token = environment.FORMS_OPERATIONS_BEARER_TOKEN ?? "";
  if (!OPERATIONS_TOKEN.test(token)) {
    throw new Error("forms_operations_bearer_not_configured");
  }
  return token;
}

function constantTimeEqual(left: string, right: string): boolean {
  const length = Math.max(left.length, right.length);
  let difference = left.length ^ right.length;
  for (let index = 0; index < length; index++) {
    difference |= (left.charCodeAt(index) || 0) ^
      (right.charCodeAt(index) || 0);
  }
  return difference === 0;
}

export function authorizedOperationsRequest(
  authorization: string | null,
  expectedToken: string,
): boolean {
  if (!authorization?.startsWith("Bearer ")) return false;
  return constantTimeEqual(authorization.slice(7), expectedToken);
}
