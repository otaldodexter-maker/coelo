"""Read-only skill audit; synthetic knowledge fixtures stay in a checked temp root.

Run from the repository: rtk proxy python -X utf8 <this-file>
Requires the existing Python PyYAML and PowerShell 7 runtimes.
Outputs JSON observations, not a certification of agent behavior or production.
"""

import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

import yaml


ROOT = Path(__file__).resolve().parents[4]
FOLDERS = ["coelo-ui", "coelo-tutor", "coelo-supabase",
           "coelo-flutter-review", "coelo-knowledge"]


def read(path):
    return path.read_text(encoding="utf-8-sig")


def command(args):
    result = subprocess.run(["rtk", "proxy", *args], cwd=ROOT,
                            capture_output=True, encoding="utf-8",
                            errors="replace", timeout=60)
    return result.returncode, result.stdout.strip()


def inventory():
    result = []
    for folder in FOLDERS:
        base = ROOT / ".agents/skills" / folder
        entry = base / "SKILL.md"
        body = read(entry)
        metadata = yaml.safe_load(body.split("---", 2)[1])
        interface = yaml.safe_load(read(base / "agents/openai.yaml"))["interface"]
        broken = []
        links = 0
        for file in base.rglob("*.md"):
            for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", read(file)):
                if "://" in target or target.startswith("#"):
                    continue
                target = target.split("#")[0]
                links += 1
                if not (file.parent / target).exists():
                    broken.append({"file": str(file.relative_to(ROOT)), "target": target})
        result.append({
            "name": metadata["name"], "path": str(entry.relative_to(ROOT)),
            "sha256": hashlib.sha256(entry.read_bytes()).hexdigest(),
            "bytes": entry.stat().st_size, "lines": len(body.splitlines()),
            "words": len(body.split()), "bundle_files": len(list(base.rglob("*.*"))),
            "document_provenance_present": all(
                key in metadata.get("metadata", {}) for key in ("source", "status", "generated_at")),
            "default_prompt_mentions_skill": "$" + metadata["name"] in interface["default_prompt"],
            "short_description_length": len(interface["short_description"]),
            "markdown_local_links": links, "broken_markdown_local_links": broken,
        })
    return result


def index_references():
    entries = [json.loads(line) for line in read(
        ROOT / "apps/catalog/assets/coelo-ui.index.jsonl").splitlines() if line.strip()]
    ids = {entry["id"] for entry in entries}
    used = set()
    for file in (ROOT / ".agents/skills/coelo-ui").rglob("*.md"):
        used.update(re.findall(r"`(pattern\.[a-z0-9.-]+)`", read(file)))
    missing = []
    for entry in entries:
        for path in [entry.get("publicFile"), *entry.get("tests", [])]:
            if path and not (ROOT / path).exists():
                missing.append({"id": entry["id"], "path": path})
    return {"entry_count": len(entries), "duplicate_ids": len(entries) - len(ids),
            "referenced_pattern_count": len(used), "missing_patterns": sorted(used - ids),
            "missing_public_or_test_files": missing}


def knowledge_probes():
    temp_parent = Path(tempfile.gettempdir()).resolve()
    sandbox = Path(tempfile.mkdtemp(prefix="coelo-skill-audit-", dir=temp_parent)).resolve()
    assert sandbox.parent == temp_parent and sandbox.name.startswith("coelo-skill-audit-")
    observations = []
    validator = ROOT / ".agents/skills/coelo-knowledge/scripts/Test-CoeloKnowledge.ps1"
    searcher = ROOT / ".agents/skills/coelo-knowledge/scripts/Search-CoeloKnowledge.ps1"
    try:
        fixture = sandbox / "repo"
        team = fixture / "docs/knowledge/team"
        team.mkdir(parents=True)
        (fixture / "AGENTS.md").write_text("# Synthetic canonical source\n", encoding="utf-8")
        (sandbox / "external.md").write_text("# Synthetic external source\n", encoding="utf-8")
        base_metadata = {
            "title": "Synthetic audit article", "knowledge_id": "audit-probe",
            "source": "AGENTS.md", "status": "validated", "generated_at": "2026-09-08",
            "audience": "team", "surfaces": ["documentation"], "visibility": "internal",
            "review_owner": "Synthetic reviewer",
        }
        article = team / "probe.md"

        def run_probe(name, expected_valid, updates=None, body="Synthetic auditneedle.", transform=None):
            metadata = {**base_metadata, **(updates or {})}
            # Existing articles use inline lists; exercise that baseline first.
            text = "---\n" + yaml.safe_dump(metadata, allow_unicode=True, sort_keys=False,
                                           default_flow_style=None) + "---\n\n" + body + "\n"
            if transform:
                text = transform(text)
            article.write_text(text, encoding="utf-8")
            code, _ = command(["pwsh", "-NoProfile", "-File", str(validator),
                               "-Root", str(fixture), "-Quiet"])
            observations.append({"case": name, "expected_valid": expected_valid,
                                 "accepted": code == 0, "exit_code": code,
                                 "matches_expected": (code == 0) == expected_valid})

        run_probe("valid_control", True)
        run_probe("nonexistent_source_control", False, {"source": "docs/missing.md"})
        run_probe("source_outside_repository", False, {"source": "../external.md"})
        run_probe("projection_as_own_source", False, {"source": "docs/knowledge/team/probe.md"})
        run_probe("directory_as_source", False, {"source": "docs"})
        run_probe("impossible_date", False, {"generated_at": "2026-99-99"})
        run_probe("empty_surfaces", False, {"surfaces": []})
        run_probe("valid_yaml_block_list", True, transform=lambda s: s.replace(
            "surfaces: [documentation]", "surfaces:\n  - documentation"))
        run_probe("benign_security_guidance", True,
                  body="Nunca colocar a chave service_role no cliente. Nenhuma chave está presente.")
        run_probe("synthetic_unformatted_cpf", False,
                  body="CPF sintético para o teste: 12345678909.")
        run_probe("duplicate_id_control_baseline", True)
        duplicate = team / "duplicate.md"
        duplicate.write_text(read(article), encoding="utf-8")
        code, _ = command(["pwsh", "-NoProfile", "-File", str(validator), "-Root", str(fixture), "-Quiet"])
        observations.append({"case": "duplicate_id_same_audience", "expected_valid": False,
                             "accepted": code == 0, "exit_code": code,
                             "matches_expected": code != 0,
                             "expectation_basis": "audit proposal: unique id per audience; not an existing explicit rule"})
        duplicate.unlink()
        for status in ("draft", "deprecated", "validated"):
            run_probe("search_fixture_" + status, True, {"status": status})
            code, out = command(["pwsh", "-NoProfile", "-File", str(searcher),
                                  "-Root", str(fixture), "-Audience", "team", "-Query", "auditneedle"])
            observations.append({"case": "search_returns_" + status,
                                 "exit_code": code, "returned_article": "probe.md" in out})
        code, _ = command(["pwsh", "-NoProfile", "-File", str(searcher),
                           "-Root", str(fixture), "-Audience", "users", "-Query", "auditneedle"])
        observations.append({"case": "audience_users_argument", "exit_code": code})
        return observations
    finally:
        resolved = sandbox.resolve()
        if resolved.parent != temp_parent or not resolved.name.startswith("coelo-skill-audit-"):
            raise RuntimeError("Refusing cleanup outside this audit's temporary directory")
        shutil.rmtree(resolved)


def main():
    tutor = ROOT / ".agents/skills/coelo-tutor/SKILL.md"
    duplicate = ROOT / ".codex/skills/coelo-tutor/SKILL.md"
    trackers = [ROOT / "docs/reviews" / name for name in (
        "coelo-flutter-pendencias.md", "coelo-supabase-pendencias.md",
        "coelo-flutter-integrado-supabase-pendencias.md")]
    print(json.dumps({
        "audit_date": "2026-09-08", "scope": "skills and local synthetic probes only",
        "git_head": command(["git", "rev-parse", "HEAD"])[1],
        "skills": inventory(), "ui_index": index_references(),
        "tutor_copies_identical": duplicate.exists() and tutor.read_bytes() == duplicate.read_bytes(),
        "trackers": [{"path": str(path.relative_to(ROOT)), "bytes": path.stat().st_size,
                      "lines": len(read(path).splitlines())} for path in trackers],
        "knowledge_probes": knowledge_probes(), "temporary_fixtures_removed": True,
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
