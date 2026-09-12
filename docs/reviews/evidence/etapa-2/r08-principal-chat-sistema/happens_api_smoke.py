"""Serial API smoke for an explicitly selected synthetic institution.

No browser, service role, raw response logs, token files or password changes.
The manifest records only synthetic resource IDs and bounded assertions.
Run once per manifest; a failed run must be inspected before any retry.
"""
import argparse
import hashlib
import json
import struct
import time
import urllib.error
import urllib.request
import uuid
import zlib
from datetime import datetime, timezone
from pathlib import Path


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def configuration(path):
    text = Path(path).read_text(encoding="utf-8-sig")
    if text.lstrip().startswith("{"):
        return json.loads(text)
    return dict(
        (key.strip(), value.strip().strip("\"'"))
        for line in text.splitlines()
        if line.strip() and not line.lstrip().startswith("#") and "=" in line
        for key, value in [line.split("=", 1)]
    )


def png():
    def chunk(kind, payload):
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))
    pixels = b"".join(b"\0" + bytes([214, 60, 0, 255]) * 16 for _ in range(16))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 16, 16, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(pixels)) + chunk(b"IEND", b"")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True)
    parser.add_argument("--qa-env", required=True)
    parser.add_argument("--institution", required=True)
    parser.add_argument("--unit")
    parser.add_argument("--group")
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--negative-qa-env")
    args = parser.parse_args()
    output = Path(args.manifest)
    if output.exists():
        raise SystemExit("Manifest already exists; inspect it before retrying.")
    cfg = configuration(args.config)
    base = cfg.get("SUPABASE_URL", cfg.get("COELO_SUPABASE_URL", "")).rstrip("/")
    key = cfg.get("SUPABASE_ANON_KEY", cfg.get("SUPABASE_PUBLISHABLE_KEY", cfg.get("COELO_SUPABASE_PUBLISHABLE_KEY", cfg.get("COELO_SUPABASE_ANON_KEY", ""))))
    if not base.startswith("https://") or not key:
        raise SystemExit("Client configuration is incomplete.")
    opener = urllib.request.build_opener(NoRedirect())
    data = png()
    manifest = {"source": "R08 G4 serial authenticated API smoke", "environment": "production", "ui_e2e": False, "started_at": datetime.now(timezone.utc).isoformat(), "institution_id": args.institution, "unit_id": args.unit, "group_id": args.group, "fixture": {"name": "R08-G4-synthetic.png", "width": 16, "height": 16, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}, "checks": [], "resources": {}, "status": "running"}

    def save():
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    def check(name, passed, status=None):
        manifest["checks"].append({"name": name, "passed": bool(passed), "http_status": status})
        save()
        if not passed:
            raise RuntimeError(name)

    def request(method, url, payload=None, headers=None):
        body = json.dumps(payload).encode() if isinstance(payload, dict) else payload
        try:
            with opener.open(urllib.request.Request(url, data=body, headers=headers or {}, method=method), timeout=30) as response:
                return response.status, response.read()
        except urllib.error.HTTPError as error:
            return error.code, error.read()

    def api(path, payload, token=None, method="POST"):
        headers = {"apikey": key, "Content-Type": "application/json", "Origin": "http://127.0.0.1:3014"}
        if token:
            headers["Authorization"] = "Bearer " + token
        status, body = request(method, base + path, payload, headers)
        try:
            return status, json.loads(body)
        except (ValueError, UnicodeDecodeError):
            return status, None

    def login(path, label):
        qa = configuration(path)
        status, result = api("/auth/v1/token?grant_type=password", {"email": qa["QA_EMAIL"], "password": qa["QA_PASSWORD"]})
        check(label, status == 200 and bool(result.get("access_token")), status)
        return result["access_token"]

    token = negative = None
    published = False
    post_id = asset_id = None
    version = None
    try:
        save()
        token = login(args.qa_env, "qa_login")
        if args.group:
            status, groups = api("/rest/v1/groups?select=id,institution_id,unit_id&id=eq." + args.group, None, token, "GET")
            check("current_group_hierarchy", status == 200 and isinstance(groups, list) and len(groups) == 1 and groups[0]["institution_id"] == args.institution and groups[0]["unit_id"] == args.unit, status)
        if args.negative_qa_env:
            negative = login(args.negative_qa_env, "other_actor_login")

        def rpc(name, payload):
            status, result = api("/rest/v1/rpc/" + name, payload, token)
            check(name, status == 200, status)
            return result

        def media(action, payload, actor=token):
            return api("/functions/v1/happens-media", {"action": action, **payload}, actor)

        scope = {"p_institution_id": args.institution, "p_unit_id": args.unit, "p_group_id": args.group, "p_limit": 50}
        # This read proves authorization before creating any resource.
        rpc("list_visible_happens_posts", scope)
        draft = rpc("save_happens_draft", {"p_request_id": str(uuid.uuid4()), "p_draft": {"institution_id": args.institution, "unit_id": args.unit, "group_id": args.group, "caption": "R08 G4 synthetic private PNG API proof", "audiences": ["school_staff"], "publish_at": None}, "p_post_id": None, "p_expected_version": 0})
        post_id, version = draft["id"], draft["version"]
        manifest["resources"]["post_id"] = post_id
        save()
        envelope = {"request_id": str(uuid.uuid4()), "institution_id": args.institution, "post_id": post_id, "name": manifest["fixture"]["name"], "mime_type": "image/png", "size_bytes": len(data)}
        status, prepared = media("prepare", envelope)
        check("prepare_r2", status == 200 and prepared.get("storage_provider") == "r2", status)
        asset_id = prepared["asset_id"]
        manifest["resources"]["asset_id"] = asset_id
        save()
        headers = {k.lower(): v for k, v in prepared["required_headers"].items()}
        check("signed_content_type", headers.get("content-type") == "image/png")
        status, _ = request("PUT", prepared["upload_url"], data, headers)
        check("private_put", 200 <= status < 300, status)
        status, finalized = media("finalize", {**envelope, "asset_id": asset_id, "display_order": 0})
        check("finalize_binding", status == 200 and finalized.get("asset_id") == asset_id, status)
        rpc("publish_happens_post", {"p_request_id": str(uuid.uuid4()), "p_post_id": post_id, "p_expected_version": version, "p_publish_at": None})
        published = True
        rows = rpc("list_visible_happens_posts", scope)
        row = next((r for r in rows if r.get("post_id") == post_id), None)
        check("published_readback", row is not None and len(row["media"]) == 1)
        version = row["management_version"]
        ticket = row["media"][0]["read_ticket"]
        status, _ = media("read", {"read_ticket": ticket}, actor=None)
        check("anonymous_denied", status in (401, 403), status)
        status, _ = media("read", {"read_ticket": str(uuid.uuid4())})
        check("invalid_ticket_denied", status == 403, status)
        if negative:
            status, _ = media("read", {"read_ticket": ticket}, actor=negative)
            check("other_actor_ticket_denied", status in (401, 403), status)
        status, resolved = media("read", {"read_ticket": ticket})
        check("authorized_read", status == 200 and resolved.get("mime_type") == "image/png", status)
        ttl = resolved["expires_in"]
        check("bounded_read_ttl", isinstance(ttl, int) and 0 < ttl <= 60)
        status, image = request("GET", resolved["signed_url"])
        check("private_bytes_match", status == 200 and hashlib.sha256(image).digest() == hashlib.sha256(data).digest(), status)
        rows = rpc("list_visible_happens_posts", scope)
        check("fresh_server_reload", any(r.get("post_id") == post_id for r in rows))
        print("API byte/read/reload checks recorded; waiting for signed URL expiry.", flush=True)
        time.sleep(ttl + 3)
        status, _ = request("GET", resolved["signed_url"])
        check("signed_url_expired", status in (401, 403), status)
        manifest["status"] = "passed"
    except Exception as error:
        manifest["status"] = "failed"
        # Exception text can contain signed URLs; persist only its type.
        manifest["failure_type"] = type(error).__name__
    finally:
        if token and post_id:
            try:
                if published:
                    rows = rpc("list_visible_happens_posts", scope)
                    row = next((r for r in rows if r.get("post_id") == post_id), None)
                    version = row["management_version"] if row else version
                    rpc("withdraw_happens_post", {"p_request_id": str(uuid.uuid4()), "p_post_id": post_id, "p_expected_version": version, "p_reason": "R08 G4 synthetic API proof cleanup"})
                    rows = rpc("list_visible_happens_posts", scope)
                    check("withdrawal_readback_absent", not any(r.get("post_id") == post_id for r in rows))
                    manifest["cleanup"] = "publication withdrawn; private master follows existing retention"
                elif asset_id:
                    status, _ = media("delete", {"asset_id": asset_id, "request_id": str(uuid.uuid4())})
                    check("draft_asset_cleanup", status == 200, status)
                    manifest["cleanup"] = "draft media removed; empty synthetic draft retained for inspection"
            except Exception as error:
                manifest["status"] = "failed"
                manifest["cleanup_failure_type"] = type(error).__name__
        for session in (token, negative):
            if session:
                status, _ = api("/auth/v1/logout?scope=local", {}, session)
                manifest.setdefault("logout_status", []).append(status)
        manifest["finished_at"] = datetime.now(timezone.utc).isoformat()
        save()
    print(json.dumps({"status": manifest["status"], "checks": len(manifest["checks"]), "manifest": str(output)}))
    return 0 if manifest["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
