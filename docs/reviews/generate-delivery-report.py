"""Generate the current R16 delivery-reconciliation report from live sources.

This is a report generator, not a delivery command. It never fetches, commits,
pushes, deploys, changes trackers or changes product state.
"""
from __future__ import annotations

import json
import re
import subprocess
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "docs/reviews/entrega-atual.json"
INVENTORY = ROOT / "docs/reviews/inventario-etapa-2.json"
OWNER_LEDGER = ROOT / "docs/reviews/etapa-2-operacao/next-round/R12-owner-items.json"
OWNER_QUEUE = ROOT / "docs/reviews/etapa-2-operacao/next-round/R16-pendencias.md"
CHECKPOINT = "docs/reviews/etapa-2-operacao/next-round/R15-checkpoint-20260917.md"
# Last coordination base before the R14 action deltas. This keeps the gate
# audit anchored to the published cut instead of comparing HEAD with itself.
BASE_REFERENCE = "9d6636115a15d10f6c44b1ababa4f162fed0ae06"
CURRENT_STATE = "docs/reviews/etapa-2-operacao/ETAPA-2-estado-atual.md"
PENDENCIES = "docs/reviews/etapa-2-operacao/next-round/R16-pendencias.md"
ROUND_INDEX = "docs/reviews/etapa-2-operacao/next-round/RODADAS.md"
EXCLUDED_COMPLETED_OWNER_IDS = {
    "owner.r12-07",
    "owner.r12-41",
    "owner.r12-43",
}


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def read_json(path: Path) -> dict | list:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def path_exists(relative: str) -> bool:
    return (ROOT / relative).is_file()


def current_residual_branches(previous: dict) -> dict:
    result = {}
    current_branch = git("branch", "--show-current")
    rows = git(
        "for-each-ref",
        "--format=%(refname:short)|%(objectname)",
        "refs/heads",
        "refs/remotes/origin",
    ).splitlines()
    for row in rows:
        branch, sha = row.split("|", 1)
        if branch in {"origin/HEAD", current_branch, f"origin/{current_branch}"}:
            continue
        exclusive = git("rev-list", branch, "--not", "origin/dev").splitlines()
        if not exclusive:
            continue
        old = previous.get("residualBranches", {}).get(branch, {})
        evidence = old.get("evidence", CHECKPOINT)
        if not path_exists(evidence):
            evidence = CHECKPOINT
        entry = {
            "sha": sha,
            "exclusive": exclusive,
            "disposition": old.get("disposition", "retained-review"),
            "reason": old.get(
                "reason",
                "Branch preservada para revisão de conteúdo; não é fila operacional.",
            ),
            "evidence": evidence,
        }
        for key in ("owner", "nextGate", "successor"):
            if old.get(key):
                entry[key] = old[key]
        if entry["disposition"] == "retained-review":
            entry.setdefault("owner", "C0")
            entry.setdefault("nextGate", "Revisar conteúdo antes de qualquer integração ou remoção.")
        result[branch] = entry
    return result


def current_protected_worktrees() -> dict:
    result = {}
    for block in git("worktree", "list", "--porcelain").split("\n\n"):
        values = {}
        for line in block.splitlines():
            key, _, value = line.partition(" ")
            values[key] = value
        raw_path = values.get("worktree")
        branch = values.get("branch", "")
        if not raw_path or not (
            branch.startswith("refs/heads/r14/") or branch.startswith("refs/heads/r15/")
        ):
            continue
        path = str(Path(raw_path).resolve())
        if branch.startswith("refs/heads/r15/"):
            disposition = "retained-session"
            reason = (
                "Worktree de sessão executora da R15 (17/09; R15-execucao-paralela.md); "
                "a coordenadora integra por cherry-pick; remover só com manifesto no fechamento."
            )
        else:
            disposition = "retained-active-r14"
            reason = (
                "Worktree da segunda onda R14 (16/09), integrada em dev por cherry-pick; "
                "protegida até a disposição registrada no fechamento da R15."
            )
        result[path] = {
            "disposition": disposition,
            "reason": reason,
            "branch": branch.removeprefix("refs/heads/"),
            "sha": values.get("HEAD", ""),
        }
    return result


def normalize_gate(value: str) -> str:
    return (
        value.replace(
            "executar somente na R12 autorizada",
            "executar somente na cota R15 autorizada",
        )
        .replace(
            "na R12 autorizada",
            "na cota R15 autorizada",
        )
        .replace("após abertura explícita da R12", "após abertura explícita da R15")
        .replace("após abertura R12", "após abertura explícita da R15")
        .replace("reproduzir na R12", "reproduzir na R15")
    )


def current_owner_items(ledger: list) -> list:
    result = []
    for item in sorted(ledger, key=lambda value: value["id"]):
        status = "open" if item["status"] == "partial" else item["status"]
        evidence = str(item.get("evidence", "")).split(";", 1)[0].strip()
        if not path_exists(evidence):
            evidence = PENDENCIES
        result.append(
            {
                "id": item["id"],
                "status": status,
                "actionIds": item.get("actionIds", []),
                "fe": item.get("fe", ""),
                "be": item.get("be", ""),
                "e2e": item.get("e2e", ""),
                "evidence": evidence,
                "owner": "C0 R16" if status != "done" else "registro histórico R12/R13",
                "nextGate": normalize_gate(item.get("nextGate", "")),
                "sourceRound": "R15",
            }
        )
    return result


def current_owner_queue(path: Path) -> tuple[set[str], set[str]]:
    """Read the single live R15 Owner table and return all IDs and done IDs."""
    text = path.read_text(encoding="utf-8")
    rows = re.findall(r"^\| (owner\.r12-\d+) \|", text, flags=re.MULTILINE)
    done = set(
        re.findall(
            r"^\| (owner\.r12-\d+) \|[^\n]*\| done /",
            text,
            flags=re.MULTILINE,
        )
    )
    return set(rows), done


def main() -> None:
    previous = read_json(REPORT) if REPORT.exists() else {}
    inventory = read_json(INVENTORY)
    ledger = read_json(OWNER_LEDGER)
    if len(ledger) != 53:
        raise SystemExit(f"Expected 53 Owner records, found {len(ledger)}")

    ids = {item["id"] for item in ledger}
    queue_ids, queue_completed = current_owner_queue(OWNER_QUEUE)
    if queue_ids != ids:
        raise SystemExit("R16 Owner queue does not enumerate the 53 canonical IDs")
    completed = {item["id"] for item in ledger if item["status"] == "done"}
    if completed != queue_completed:
        raise SystemExit("R16 Owner queue and canonical Owner ledger disagree on done IDs")
    pending = ids - completed

    owner_items = current_owner_items(ledger)
    branches = current_residual_branches(previous)
    evidence = {
        CURRENT_STATE,
        ROUND_INDEX,
        CHECKPOINT,
        PENDENCIES,
        "docs/agent/current-state.md",
        "docs/agent/source-of-truth.md",
        "decisions/0040-agora-immediate-removal.md",
        "docs/agent/artifact-inventory-20260914.json",
        "docs/reviews/inventario-etapa-2.json",
        "docs/reviews/etapa-2-operacao/next-round/R13-owner-items-atual.json",
        "docs/reviews/etapa-2-operacao/next-round/R13-prompt-execucao-20260914.md",
        "docs/reviews/etapa-2-operacao/next-round/R14-catalogo.md",
        "docs/reviews/etapa-2-operacao/next-round/R16-pendencias.md",
    }
    evidence.update(item["evidence"] for item in owner_items)
    evidence.update(entry["evidence"] for entry in branches.values())

    actions = inventory["actions"]
    layers = inventory["layerCounts"]
    formal_actions = [
        {"id": action["id"], **action["formalCommitment"]}
        for action in actions
        if action.get("formalCommitment")
    ]
    # Compromissos registrados à mão no relatório anterior (ações mudadas fora
    # de Owner items, ex.: decisões A4/A5/E9) são preservados entre regenerações.
    known = {entry["id"] for entry in formal_actions}
    for entry in previous.get("formalActions", []):
        if entry.get("id") and entry["id"] not in known:
            formal_actions.append(entry)
            known.add(entry["id"])
    formal_actions.sort(key=lambda entry: entry["id"])
    evidence.update(entry["evidence"] for entry in formal_actions if entry.get("evidence"))
    evidence = sorted(value for value in evidence if path_exists(value))

    def count(field: str, value: str) -> int:
        return sum(1 for action in actions if action.get(field) == value)

    def metric(done: int, total: int) -> str:
        return f"{done}/{total} ({done / total * 100:.2f}%)"

    def status_counts(field: str) -> dict[str, int]:
        counts: dict[str, int] = {}
        for action in actions:
            value = action.get(field, "missing")
            counts[value] = counts.get(value, 0) + 1
        return dict(sorted(counts.items()))

    frontend_total = layers["frontendApplicable"]
    backend_total = layers["backendApplicable"]
    integrated_total = layers["integratedActiveApplicable"]
    flutter_only = count("integratedStatus", "flutter-only")
    metrics = {
        "frontendVerified": metric(count("frontendStatus", "verified"), frontend_total),
        "frontendLocalGreen": metric(count("frontendStatus", "local-green"), frontend_total),
        "backendDone": metric(count("backendStatus", "done"), backend_total),
        "backendLocalGreen": metric(count("backendStatus", "local-green"), backend_total),
        "e2eVerified": metric(count("integratedStatus", "verified-e2e"), integrated_total),
        "e2ePlusFlutterOnly": metric(
            count("integratedStatus", "verified-e2e") + flutter_only,
            frontend_total,
        ),
        "ownerDone": metric(len(completed), len(ids)),
        "ownerNonTerminal": metric(len(pending), len(ids)),
    }
    generated_at = date.today().isoformat()
    report = {
        "schema": "r14-current-delivery-report-v1",
        "generatedAt": generated_at,
        "reportType": "current-cut-reconciliation",
        "completion": "partial",
        "asOf": {
            "round": "R16",
            "roundStatus": "active",
            "nextRound": "R17 not opened",
            "branch": git("branch", "--show-current"),
            "head": git("rev-parse", "HEAD"),
            "worktree": "source checkout at report generation; report commit follows",
        },
        "sources": {
            "currentState": CURRENT_STATE,
            "roundIndex": ROUND_INDEX,
            "latestCheckpoint": CHECKPOINT,
            "ownerQueue": PENDENCIES,
            "ownerQueueProjection": None,
            "inventory": "docs/reviews/inventario-etapa-2.json",
            "artifactInventory": "docs/agent/artifact-inventory-20260914.json",
            "trackers": [
                "docs/reviews/coelo-flutter-pendencias.md",
                "docs/reviews/coelo-supabase-pendencias.md",
                "docs/reviews/coelo-flutter-integrado-supabase-pendencias.md",
            ],
        },
        "currentQueue": {
            "scope": "R16 vigente (ADR 0043); R17 não aberta",
            "ownerTotal": 53,
            "ownerPendingCount": len(pending),
            "ownerDoneCount": len(completed),
            "inheritedOriginIds": [f"H{i:02d}" for i in range(2, 29)],
            "inheritedOriginCount": 27,
            "inheritedStateSource": PENDENCIES,
            "actionStatusCounts": {
                "frontend": status_counts("frontendStatus"),
                "backend": status_counts("backendStatus"),
                "integrated": status_counts("integratedStatus"),
            },
            "deferredPostMvpActionCount": sum(
                1 for action in actions if action.get("scope") == "deferred-post-mvp"
            ),
            "excludedCompletedOwnerIds": sorted(EXCLUDED_COMPLETED_OWNER_IDS),
            "completedInR14OrPriorOwnerIds": sorted(completed - EXCLUDED_COMPLETED_OWNER_IDS),
        },
        "metrics": metrics,
        "firstGate": "Avaliações › Fechar/Reabrir (assessments.close/reopen)",
        "ownerItems": owner_items,
        "formalActions": formal_actions,
        "baseReference": BASE_REFERENCE,
        "target": str(ROOT.resolve()),
        "protectedWorktrees": current_protected_worktrees(),
        "preservedStash": {},
        "residualBranches": branches,
        "evidenceFiles": evidence,
        "trackerActionIds": [item["id"] for item in inventory["actions"]],
        "memory": {
            "status": "no-op",
            "reason": "Reconciliacao documental e de harness; regras de produto continuam nas ADRs. Nenhum conhecimento novo de produto foi inventado.",
        },
        "deployment": {
            "status": "pending",
            "evidence": CHECKPOINT,
            "reason": "Lote 74 aplicado em produção pelo rito em 16/09 (seis migrations R14; incidente do PostgREST encerrado). Sessões R15 aplicam lotes seguintes pelo rito e registram no ledger. O relatório não autoriza novo deploy por si só.",
        },
        "r14Status": {
            "round": "R16",
            "status": "active",
            "source": CHECKPOINT,
            "completedOwnerItems": sorted(completed),
            "openOwnerItems": sorted(pending),
            "completedGates": [
                "H06",
                "H17",
                "OQ-028",
                "anexos com limite 10",
                "H21 backend",
                "D produção: coleções de cuidado (pgTAP 6/6)",
                "D produção: OQ-031 (pgTAP 11/11)",
                "D produção: Account self (pgTAP 6/6)",
            ],
            "openFirstGate": "Avaliações › Fechar/Reabrir (assessments.close/reopen)",
            "metrics": metrics,
            "deployment": "none for this documentation reconciliation",
            "memory": "no-op",
        },
        "history": {
            "priorRounds": "R01–R13 preserved as provenance; never use as current queue",
            "priorDeliveryReport": "previous content replaced by this current-cut report; Git history preserves the old snapshot",
            "residualBranches": "preserved and re-read from current refs; branch deletion is not authorized",
        },
    }
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {REPORT} with {len(owner_items)} Owner items, {len(branches)} residual branches and {len(evidence)} evidence files.")


if __name__ == "__main__":
    main()
