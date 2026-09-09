"""Materialize the exact local Models candidate; never connects to a database."""
from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p / "AGENTS.md").is_file())
NAMES = [
    "20260901170731_access_profile_models_crud_and_catalog.sql",
    "20260901193000_name_access_profile_model_rpc_arguments.sql",
    "20260908021821_access_profile_models_read_prelookup_authorization.sql",
    "20260908182839_access_profile_models_aal1_phase_policy.sql",
    "20260909174500_d04_access_models_scope_filter.sql",
]

def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

parts = []
sources = []
for name in NAMES:
    path = ROOT / "packages/coelo_database/migrations" / name
    text = path.read_text(encoding="utf-8-sig")
    # Remove only the reviewed files' outer transaction, keeping every body.
    assert len(re.findall(r"(?mi)^begin;\s*$", text)) == 1, name
    assert len(re.findall(r"(?mi)^commit;\s*$", text)) == 1, name
    body = re.sub(r"(?mi)^(begin|commit);[ \t]*\n?", "", text)
    sources.append({"path": str(path.relative_to(ROOT)).replace("\\", "/"),
                    "sha256_lf_utf8": sha(text)})
    parts.append("-- SOURCE: " + name + "\n" + body)

preflight = (HERE / "preflight.sql").read_text(encoding="utf-8")
postflight = (HERE / "postflight.sql").read_text(encoding="utf-8")
payload = ("-- AP-MODELS-NOMINAL-20260909-v1: candidate; no remote authorization.\n"
           "begin;\nset local lock_timeout='5s';\nset local statement_timeout='90s';\n"
           "select pg_advisory_xact_lock(hashtextextended('coelo.models.nominal.v1',0));\n"
           + preflight + "\n" + "\n".join(parts) + "\n" + postflight + "\ncommit;\n")
(HERE / "package.sql").write_text(payload, encoding="utf-8", newline="\n")
fixture = "-- LOCAL ONLY: exercise package over Auth45 with production label constraints.\n"
for table in ("platform_permissions", "institution_permissions"):
    for label in ("module_label", "screen_label", "action_label"):
        fixture += f"alter table public.{table} alter column {label} drop default;\n"
checks = (HERE / "package_checks.sql").read_text(encoding="utf-8")
test_path = ROOT / "packages/coelo_database/supabase/tests/ap_models_nominal_package_test.sql"
test_path.write_text(fixture + payload + checks, encoding="utf-8", newline="\n")
manifest = {"package": "AP-MODELS-NOMINAL-20260909-v1", "status": "local-candidate",
            "sources": sources, "preflight_sha256": sha(preflight),
            "postflight_sha256": sha(postflight), "package_sha256": sha(payload),
            "local_test_sha256": sha(fixture + payload + checks), "remote_authorized": False}
(HERE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print(json.dumps(manifest))
