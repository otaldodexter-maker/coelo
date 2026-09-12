"""One nominal R08-G4 private QA group and PNG binding via normal APIs."""
import argparse
import hashlib
import json
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

from happens_api_smoke import configuration, NoRedirect, png


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("config", "qa-env", "preflight", "manifest"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--resume", help="Existing manifest; never creates a group or repeats PUT/finalize")
    args = parser.parse_args()
    preflight = json.loads(Path(args.preflight).read_text(encoding="utf-8"))
    actors = preflight["actors"]
    if {actor["alias"] for actor in actors} != {"qa-r06-principal", "qa-r06-realm"} or len(actors) != 2:
        raise SystemExit("The nominal two-actor QA preflight is required.")
    output = Path(args.manifest)
    if output.exists():
        raise SystemExit("Manifest exists; inspect it instead of creating another group.")
    cfg, qa = configuration(args.config), configuration(args.qa_env)
    base = cfg["COELO_SUPABASE_URL"].rstrip("/")
    key = cfg["COELO_SUPABASE_PUBLISHABLE_KEY"]
    opener = urllib.request.build_opener(NoRedirect())
    data = png()
    manifest = {"source": "R08 G4 chat API group and attachment, normal RPC/gateway contracts", "environment": "production", "ui_e2e": False, "started_at": datetime.now(timezone.utc).isoformat(), "institution_id": preflight["institution_id"], "participant_person_ids": [actor["person_id"] for actor in actors], "group_title": "R08-G4 PNG privado QA", "group_request_id": str(uuid.uuid4()), "upload_request_id": str(uuid.uuid4()), "fixture": {"name": "R08-G4-synthetic.png", "bytes": len(data), "width": 16, "height": 16, "sha256": hashlib.sha256(data).hexdigest()}, "checks": [], "resources": {}, "status": "running", "cross_tenant": "not executed; both QA actors are Owner/platform"}
    if args.resume:
        prior = json.loads(Path(args.resume).read_text(encoding="utf-8"))
        if prior["participant_person_ids"] != manifest["participant_person_ids"] or prior["fixture"] != manifest["fixture"]:
            raise SystemExit("Resume fixture differs from the nominal QA preflight.")
        manifest.update(group_request_id=prior["group_request_id"], upload_request_id=prior["upload_request_id"], resources=prior["resources"], continuation_of=args.resume)
    token = None

    def save():
        output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    def check(name, passed, status=None):
        manifest["checks"].append({"name": name, "passed": bool(passed), "http_status": status})
        save()
        if not passed:
            raise RuntimeError(name)

    def request(method, url, payload=None, headers=None):
        raw = json.dumps(payload).encode() if isinstance(payload, dict) else payload
        try:
            with opener.open(urllib.request.Request(url, headers=headers or {}, data=raw, method=method), timeout=30) as response:
                return response.status, response.read()
        except urllib.error.HTTPError as error:
            return error.code, error.read()

    def api(path, payload, authenticated=True):
        headers = {"apikey": key, "Content-Type": "application/json", "Origin": "http://127.0.0.1:3014"}
        if authenticated and token:
            headers["Authorization"] = "Bearer " + token
        status, body = request("POST", base + path, payload, headers)
        try:
            return status, json.loads(body)
        except (ValueError, UnicodeDecodeError):
            return status, None

    def rpc(name, payload):
        status, result = api("/rest/v1/rpc/" + name, payload)
        check(name + "_http", status == 200, status)
        if isinstance(result, dict) and "ok" in result:
            if result.get("ok") is not True:
                error_code = (result.get("error") or {}).get("code")
                if isinstance(error_code, str) and len(error_code) < 80 and error_code.replace("_", "").isalnum():
                    manifest["backend_error_code"] = error_code
            check(name + "_envelope", result.get("ok") is True)
            return result["data"]
        return result

    def media(action, payload, authenticated=True):
        return api("/functions/v1/chat-media", {"action": action, **payload}, authenticated)

    try:
        save()
        status, login = api("/auth/v1/token?grant_type=password", {"email": qa["QA_EMAIL"], "password": qa["QA_PASSWORD"]}, False)
        check("qa_login", status == 200, status)
        token = login["access_token"]
        for actor in actors:
            detail = rpc("superadmin_internal_user_detail", {"p_internal_identity_id": actor["internal_identity_id"]})
            check(actor["alias"] + "_identity_matches", detail["identity"]["id"] == actor["internal_identity_id"])
            service = rpc("superadmin_internal_user_service_person_v1", {"p_internal_identity_id": actor["internal_identity_id"]})
            check(actor["alias"] + "_service_person_matches", service["person_id"] == actor["person_id"])
        if args.resume:
            conversation = manifest["resources"]["conversation_id"]
            attachment = manifest["resources"]["attachment_id"]
            message = manifest["resources"]["message_id"]
            members = rpc("superadmin_chat_group_members_v2", {"p_conversation_id": conversation})
            check("same_nominal_qa_members", {member["person_id"] for member in members["items"]} == set(manifest["participant_person_ids"]))
            thread_query = {"p_conversation_id": conversation, "p_cursor_created_at": None, "p_cursor_message_id": None, "p_limit": 50}
            envelope = {"request_id": manifest["upload_request_id"], "conversation_id": conversation, "file_name": manifest["fixture"]["name"], "content_type": "image/png", "byte_size": len(data), "sha256": manifest["fixture"]["sha256"]}
        else:
            group = rpc("superadmin_chat_create_group_v2", {"p_request_id": manifest["group_request_id"], "p_institution_id": preflight["institution_id"], "p_title": manifest["group_title"], "p_person_ids": manifest["participant_person_ids"], "p_unit_id": None, "p_group_id": None, "p_activity_id": None})
            conversation = group["conversation_id"]
            manifest["resources"]["conversation_id"] = conversation
            save()
            check("nominal_group_created_once", group["title"] == manifest["group_title"] and group["member_count"] == 2 and group.get("replayed") is False)
            members = rpc("superadmin_chat_group_members_v2", {"p_conversation_id": conversation})
            check("only_nominal_qa_members", {member["person_id"] for member in members["items"]} == set(manifest["participant_person_ids"]))
            thread_query = {"p_conversation_id": conversation, "p_cursor_created_at": None, "p_cursor_message_id": None, "p_limit": 50}
            before = rpc("superadmin_chat_thread_v2", thread_query)
            check("new_group_thread_empty", not before["items"])
            envelope = {"request_id": manifest["upload_request_id"], "conversation_id": conversation, "file_name": manifest["fixture"]["name"], "content_type": "image/png", "byte_size": len(data), "sha256": manifest["fixture"]["sha256"]}
            status, prepared = media("prepare", envelope)
            if status != 200 and isinstance(prepared, dict):
                code = prepared.get("error")
                if isinstance(code, str) and len(code) < 80 and code.replace("_", "").isalnum():
                    manifest["gateway_error_code"] = code
            check("prepare", status == 200, status)
            attachment, message = prepared["attachment_id"], prepared["message_id"]
            manifest["resources"].update(attachment_id=attachment, message_id=message)
            save()
            signed_headers = {k.lower(): v for k, v in prepared["required_headers"].items()}
            check("signed_headers_exact_and_isolated", signed_headers.get("content-type") == "image/png" and not {"authorization", "apikey", "cookie"}.intersection(signed_headers))
            status, _ = request("PUT", prepared["upload_url"], data, signed_headers)
            check("private_put_without_redirect", 200 <= status < 300, status)
            status, finalized = media("finalize", {"attachment_id": attachment})
            if status != 200 and isinstance(finalized, dict):
                code = finalized.get("error")
                if isinstance(code, str) and len(code) < 80 and code.replace("_", "").isalnum():
                    manifest["gateway_error_code"] = code
            check("finalize_correlated_binding", status == 200 and finalized.get("attachment_id") == attachment and finalized.get("message_id") == message, status)
        status, resolved = media("read", {"attachment_id": attachment})
        check("authorized_binding_read", status == 200 and resolved.get("attachment_id") == attachment, status)
        ttl = resolved["expires_in"]
        manifest["read_ttl_seconds"] = ttl
        check("bounded_read_ttl", isinstance(ttl, int) and 0 < ttl <= 300)
        status, received = request("GET", resolved["signed_url"])
        check("private_png_bytes_match", status == 200 and hashlib.sha256(received).hexdigest() == manifest["fixture"]["sha256"], status)
        parsed = urllib.parse.urlsplit(resolved["signed_url"])
        status, unsigned = request("GET", urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, parsed.path, "", "")))
        try:
            error_code = ET.fromstring(unsigned).findtext("Code")
            if error_code and error_code.isalnum() and len(error_code) < 80:
                manifest["unsigned_r2_error_code"] = error_code
        except ET.ParseError:
            pass
        check("unsigned_object_denied", status in (400, 401, 403) and not unsigned.startswith(b"\x89PNG\r\n\x1a\n"), status)
        status, _ = media("read", {"attachment_id": attachment}, False)
        check("anonymous_binding_read_denied", status in (401, 403), status)
        status, rejected = media("read", {"attachment_id": str(uuid.uuid4())})
        check("unknown_binding_denied", status == 422 and rejected.get("error") in ("chat_attachment_not_found", "chat_not_found"), status)
        thread = rpc("superadmin_chat_thread_v2", thread_query)
        matching = [item for item in thread["items"] if item["message_id"] == message]
        check("thread_reload_contains_one_bound_attachment", len(matching) == 1 and [item["id"] for item in matching[0]["attachments"]] == [attachment])
        status, replayed = media("prepare", envelope)
        check("prepare_replay_same_ids_no_second_put", status == 200 and replayed.get("replayed") is True and replayed.get("attachment_id") == attachment and replayed.get("message_id") == message, status)
        status, _ = media("read", {"attachment_id": attachment})
        check("replayed_ready_binding_reauthorized", status == 200, status)
        print("Chat group, PNG binding, reload and replay recorded; waiting for URL TTL.", flush=True)
        time.sleep(ttl + 3)
        status, _ = request("GET", resolved["signed_url"])
        check("old_signed_url_expired", status in (401, 403), status)
        manifest["status"] = "passed"
    except Exception as error:
        manifest["status"] = "failed"
        manifest["failure_type"] = type(error).__name__
    finally:
        if token:
            status, _ = api("/auth/v1/logout?scope=local", {})
            manifest["logout_status"] = status
        manifest["retention"] = "nominal QA group, message, attachment and private master preserved; no DELETE or revoke"
        manifest["finished_at"] = datetime.now(timezone.utc).isoformat()
        save()
    print(json.dumps({"status": manifest["status"], "checks": len(manifest["checks"]), "manifest": str(output)}))
    return 0 if manifest["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
