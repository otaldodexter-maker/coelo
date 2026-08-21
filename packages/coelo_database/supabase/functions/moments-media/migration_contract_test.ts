import { assertEquals } from "jsr:@std/assert@1.0.14";

async function migration() {
  const directory = new URL("../../../migrations/", import.meta.url);
  for await (const entry of Deno.readDir(directory)) {
    if (entry.name.endsWith("_moments_publication_mvp.sql")) {
      return await Deno.readTextFile(new URL(entry.name, directory));
    }
  }
  throw new Error("moments_publication_migration_missing");
}

Deno.test("migration owns metadata, receipts, RLS and explicit grants", async () => {
  const sql = await migration();

  for (
    const table of [
      "moments_publications",
      "moments_publication_audiences",
      "moments_media_assets",
      "moments_media_links",
    ]
  ) {
    assertEquals(sql.includes(`create table public.${table}`), true);
    assertEquals(
      sql.includes(`alter table public.${table} enable row level security`),
      true,
    );
    assertEquals(
      sql.includes(`alter table public.${table} force row level security`),
      true,
    );
  }
  assertEquals(sql.includes("moments_command_receipts"), true);
  assertEquals(sql.includes("request_fingerprint"), true);
  assertEquals(sql.includes("cloudflare_r2"), true);
  assertEquals(sql.includes("insert into storage.buckets"), false);
  assertEquals(sql.includes("service_role"), true);
  assertEquals(sql.includes("revoke all on function"), true);
});

Deno.test("commands authorize context, replay idempotently and emit receipts", async () => {
  const sql = await migration();

  for (
    const command of [
      "save_moments_draft",
      "prepare_moments_media_upload",
      "finalize_moments_media_upload",
      "publish_moment",
    ]
  ) {
    assertEquals(sql.includes(`function public.${command}`), true);
  }
  assertEquals(sql.includes("app_private.has_institution_permission"), true);
  assertEquals(sql.includes("idempotency_key_reused"), true);
  assertEquals(sql.includes("expected_version_conflict"), true);
  assertEquals(sql.includes("receipt_id"), true);
  assertEquals(sql.includes("claim_stale_moments_media"), true);
  assertEquals(sql.includes("asset.status <> 'pending'"), true);
  assertEquals(sql.includes("status = 'orphaned'"), true);
});

Deno.test("media finalize is authorized by a one-time two-minute ticket", async () => {
  const sql = await migration();

  assertEquals(sql.includes("moments_media_finalize_tickets"), true);
  assertEquals(sql.includes("authorize_moments_media_finalize"), true);
  assertEquals(sql.includes("interval '2 minutes'"), true);
  assertEquals(
    sql.includes("delete from app_private.moments_media_finalize_tickets"),
    true,
  );
  assertEquals(sql.includes("p_finalize_ticket uuid"), true);
  assertEquals(sql.includes("p_actor_auth_user_id uuid"), false);
});

Deno.test("cleanup RPCs are public service-role-only PostgREST endpoints", async () => {
  const sql = await migration();

  assertEquals(sql.includes("function public.claim_stale_moments_media"), true);
  assertEquals(
    sql.includes("function public.mark_moments_media_deleted"),
    true,
  );
  assertEquals(
    sql.includes(
      "grant execute on function public.claim_stale_moments_media(integer)",
    ),
    true,
  );
  assertEquals(sql.includes("to service_role"), true);
});
