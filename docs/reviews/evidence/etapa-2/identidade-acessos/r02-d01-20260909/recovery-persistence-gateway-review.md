---
source: "D01 bounded review; installed gotrue 2.26.0 and supabase_flutter 2.16.0; recovery_persistence_gateway_test.dart"
status: "local-green-sdk-loopback; production-e2e-open"
generated_at: "2026-09-09"
---

# Recovery persistence gateway review

Scope: apps/superadmin -> Autenticacao -> Redefinir senha -> SDK recovery,
replay and cleanup failure -> auth.reset. Shared production delta reviewed only
in `supabase_coelo_auth_gateway.dart` and
`conditional_supabase_local_storage.dart`; the parent owns these changes.

The installed Supabase Flutter SDK persists every non-null session, including
passwordRecovery and initialSession, through an earlier asynchronous listener.
The serialized storage mutation queue orders removal after earlier writes and
recovers its internal tail after errors. The adapter disables persistence for a
matching recovery session, handles synchronous and asynchronous persistence
failures through a sanitized stream error, and preserves the recovery state.
A seed for A does not erase the distinct normal session B.

## Five unique test IDs

| ID: recovery persistence: ... | Result |
| --- | --- |
| gateway created after SDK callback purges on replay | PASS, initial execution |
| matching seed purges when latest SDK replay is refresh | PASS, initial execution |
| seed A preserves normal SDK session B | PASS, initial execution |
| cleanup failure remains confined; sync=false | PASS, focused rerun |
| cleanup failure remains confined; sync=true | PASS, focused rerun |

Initial command: from apps/superadmin,
`flutter test --no-pub ../../packages/coelo_auth/test/recovery_persistence_gateway_test.dart`.
The tool transcript returned 3 PASS / 2 FAIL. Both failures were in the new test
predicate: `CoeloAuthSessionState.isAuthenticated` includes passwordRecovery.
The intended assertion now checks `kind == CoeloAuthSessionKind.authenticated`.
No production change was made to resolve these fixture failures.

Only the two affected cases were rerun with
`--plain-name 'recovery persistence: cleanup failure'`; both passed. The raw
output is in `recovery-persistence-gateway-cleanup-green.txt`. PowerShell/RTK
reports its missing-hook warning as stderr; the Flutter transcript ends with
`00:00 +2: All tests passed!`. Unique current result: 5/5, not seven tests.

Tests use the real SDK and an ephemeral loopback HTTP server with synthetic
GoTrue responses and recording memory persistence. Each fixture disposes its
gateways, client and server. No production endpoint, browser or remote resource
is exercised. Failure cases deliberately retain serialized data and therefore
do not claim successful cleanup or cold-reload safety after a storage failure.

## Static validation

Initial analysis lacked the coelo_auth package configuration. Authorized
`flutter pub get --offline` restored it without changing tracked pubspec/lock
files. Both app and package resolve gotrue 2.26.0 and supabase_flutter 2.16.0.
The first configured analysis found one unnecessary dart:async import in the
new test; removing it was the only further change. Final command from the
package:

`dart analyze test/recovery_persistence_gateway_test.dart lib/src/supabase_coelo_auth_gateway.dart lib/src/conditional_supabase_local_storage.dart`

Result: `No issues found!`, exit 0. No test runner remains active.

Knowledge: no-op; no new approved product rule was introduced. This evidence
does not certify backend authorization, cold browser reload, or production E2E.

## Follow-up: initialize storage in SDK/composition fixtures

Parent regression `recovery-persistence-regression.txt` demonstrated three
fixture failures: one SDK scope disposal case and both composition cases used
fake Supabase initializers that returned their client without initializing
LocalStorage. The new recovery cleanup correctly exposed the missing setup.
Three SDK initializer callbacks and the composition initializer now await
`localStorage.initialize()`. SDK tests initialize the Flutter test binding and
reset SharedPreferences mock data in setUp; composition cases reset it per
test. No production file changed during this follow-up.

One targeted serial runner executed six unique existing cases, all PASS, exit 0:

- failed scope initialization releases the gateway without closing the shared SDK;
- scope synchronizes preexisting SDK session before bootstrap: recovery=false;
- scope synchronizes preexisting SDK session before bootstrap: recovery=true;
- scope disposal closes only gateway events and leaves the shared SDK usable;
- SDK recovery callback through reset form waits for logout: success=true;
- SDK recovery callback through reset form waits for logout: success=false.

Command from apps/superadmin:

`flutter test --no-pub --concurrency=1 test/features/auth/domain/coelo_auth_recovery_sdk_test.dart test/features/auth/domain/coelo_auth_recovery_composition_test.dart --name 'failed scope initialization|scope synchronizes preexisting|scope disposal closes only|SDK recovery callback through reset form'`

Full output is UTF-8 in `recovery-persistence-fixtures-green.txt`. These are
existing regression IDs, not six newly added tests. Targeted dart analyze of
both changed test files returned `No issues found!`, exit 0. Diff check passed
without trailing whitespace. No runner or analyzer remains active; no commit
was created.

## Follow-up: transient retry and cold restart after failed disk removal

D00's later gate keeps auth.reset FE pending until cold restart with failing
storage is protected by backend authorization. Two new logical acceptance IDs
are tracked: transient purge retry and cold restart with retained recovery.
Diagnostic variants/reruns are not additional acceptance IDs.

The new retry test demonstrated RED: after one failed removal, refresh of the
same SDK session left `purgeAttempts=1` and `persisted=true`, instead of two
attempts and cleared storage. Parent's four-line production correction clears
the matching cached SID on failure, allowing the next SDK event to retry.
Only the new retry and two existing synchronous/asynchronous cleanup negatives
were run after that change: **3/3 PASS, exit 0**, recorded in
`recovery-persistence-retry-green.txt`. Earlier green cases were not rerun.

Cold restart diagnostic uses actual Supabase initialization and gateway/scope,
ConditionalSupabaseLocalStorage and SharedPreferences; only the first delegate
removal fails. Callback is consumed by the SDK before gateway creation, which
then handles recovery through replay. The failed purge retains the actual
serialized credential. Cold initialization restores it and the deliberately
permissive HTTP backend returns context: bootstrap 1, authenticated true,
context present, route `/`. This is a valid client RED, recorded in
`recovery-persistence-cold-failure-red.txt`; it is not remote/backend proof.

An earlier attempt mishandled FlutterError.onError around a failing assertion
and timed out. That fixture failure and the valid retry RED remain in
`recovery-persistence-retry-red-cold-fixture.txt`; the invalid cold result is
not counted as a product failure. Restoring the handler before assertions
allowed the single diagnostic rerun to expose the actual cold-restart result.

The permissive diagnostic is now outside default execution and requires
`COELO_D01_RUN_STORAGE_FAILURE_DIAGNOSTIC=true`. It is not relabeled green or
replaced by a hardcoded denial. A separate mode of the same logical cold gate,
`cold reload storage failure: backend denies retained recovery after restart`,
requires four process-only variables: `COELO_D01_LOCAL_SUPABASE_URL`,
`COELO_D01_LOCAL_PUBLISHABLE_KEY`, `COELO_D01_RECOVERY_ACCESS_TOKEN` and
`COELO_D01_RECOVERY_REFRESH_TOKEN`. Without them it is skipped, not passed.

The real mode pins HTTP to a loopback origin and forwards GET user, POST
bootstrap and POST logout to the actual local server. It retains the real
scope, route and automatic sign-out after bootstrap denial. Disk removal fails
permanently across initializations; the key must still exist. Acceptance
requires exact real RPC denial (`ok=false`, `data=null`,
`SAI_SESSION_INVALID`), one confirmed logout, SDK session cleared, no UI auth
context and `/reset-password`. The fixed sentinel
`D01_COLD_STORAGE_REAL_BE_PASS` is emitted only after those assertions; runner
exit 0 is also required. Assertion diagnostics do not print session objects
or credentials. No refresh is initiated by the test.

The backend hook must use a fresh dedicated recovery after its nine earlier
HTTP gates, because the production scope legitimately revokes that session.
This variant is prepared but **not executed/green in this receipt**; it awaits
the coordinated real backend campaign. No production E2E completion follows
from the retry fix or synthetic RED.

Static validation of this increment: retry test file analyzed separately,
`No issues found!`, exit 0. Cold variant initially used an unsupported nullable
HttpOverrides argument; its direct IOClient construction was corrected to use
the standard HttpOverrides.createHttpClient implementation, bypassing only the
Flutter test binding's synthetic HTTP 400 client. The local transport still
restricts every request to the configured loopback origin and allowed paths.
Final targeted analysis of the cold test file: `No issues found!`, exit 0.
Diff check passed. No runner/analyzer remains active.
