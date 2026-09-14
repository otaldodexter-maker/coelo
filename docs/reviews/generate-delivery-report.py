"""Generate the current R13 delivery-reconciliation report from live sources.

This is a report generator, not a delivery command. It never fetches, commits,
pushes, deploys, changes trackers or changes product state.
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "docs/reviews/entrega-atual.json"
INVENTORY = ROOT / "docs/reviews/inventario-etapa-2.json"
OWNER_LEDGER = ROOT / "docs/reviews/etapa-2-operacao/next-round/R12-owner-items.json"
OWNER_QUEUE = ROOT / "docs/reviews/etapa-2-operacao/next-round/R13-owner-items-atual.json"
CHECKPOINT = "docs/reviews/etapa-2-operacao/next-round/R13-checkpoint-20260914-1620.md"
CURRENT_STATE = "docs/reviews/etapa-2-operacao/ETAPA-2-estado-atual.md"
PENDENCIES = "docs/reviews/etapa-2-operacao/next-round/R13-pendencias.md"
ROUND_INDEX = "docs/reviews/etapa-2-operacao/next-round/RODADAS.md"


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def read_json(path: Path) -> dict | list:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def path_exists(relative: str) -> bool:
    return (ROOT / relative).is_file()


def current_residual_branches(previous: dict) -> dict:
    result = {}
    rows = git(
        "for-each-ref",
        "--format=%(refname:short)|%(objectname)",
        "refs/heads",
        "refs/remotes/origin",
    ).splitlines()
    for row in rows:
        branch, sha = row.split("|", 1)
        if branch == "origin/HEAD":
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


def normalize_gate(value: str) -> str:
    return (
        value.replace(
            "executar somente na R12 autorizada",
            "executar somente na cota R13 autorizada; se não couber, preparar transferência para R14",
        )
        .replace(
            "na R12 autorizada",
            "na cota R13 autorizada; se não couber, preparar transferência para R14",
        )
        .replace("após abertura explícita da R12", "após abertura explícita da R13")
        .replace("após abertura R12", "após abertura explícita da R13")
        .replace("reproduzir na R12", "reproduzir na R13")
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
                "owner": "C0 R13" if status != "done" else "registro histórico R12/R13",
                "nextGate": normalize_gate(item.get("nextGate", "")),
                "sourceRound": "R13",
            }
        )
    return result


def main() -> None:
    previous = read_json(REPORT) if REPORT.exists() else {}
    inventory = read_json(INVENTORY)
    ledger = read_json(OWNER_LEDGER)
    queue = read_json(OWNER_QUEUE)
    if len(ledger) != 53:
        raise SystemExit(f"Expected 53 Owner records, found {len(ledger)}")

    pending = set(queue["pendingOwnerIds"])
    completed = set(queue["excludedCompletedOwnerIds"]) | set(queue["completedInR13OwnerIds"])
    ids = {item["id"] for item in ledger}
    if pending | completed != ids or pending & completed:
        raise SystemExit("R13 Owner queue does not partition the 53 canonical IDs")

    owner_items = current_owner_items(ledger)
    branches = current_residual_branches(previous)
    evidence = {
        CURRENT_STATE,
        ROUND_INDEX,
        CHECKPOINT,
        PENDENCIES,
        "docs/agent/current-state.md",
        "docs/agent/source-of-truth.md",
        "docs/agent/artifact-inventory-20260914.json",
        "docs/reviews/inventario-etapa-2.json",
        "docs/reviews/etapa-2-operacao/next-round/R13-owner-items-atual.json",
        "docs/reviews/etapa-2-operacao/next-round/R13-prompt-execucao-20260914.md",
        "docs/reviews/etapa-2-operacao/next-round/R14-catalogo.md",
    }
    evidence.update(item["evidence"] for item in owner_items)
    evidence.update(entry["evidence"] for entry in branches.values())
    evidence = sorted(value for value in evidence if path_exists(value))

    metrics = {
        "frontendVerified": "157/231 (67.97%)",
        "frontendLocalGreen": "37/231 (16.02%)",
        "backendDone": "164/224 (73.21%)",
        "backendLocalGreen": "16/224 (7.14%)",
        "e2eVerified": "130/199 (65.33%)",
        "e2ePlusFlutterOnly": "137/231 (59.31%)",
        "ownerDone": "6/53 (11.32%)",
        "ownerNonTerminal": "47/53 (88.68%)",
    }
    report = {
        "schema": "r13-current-delivery-report-v1",
        "generatedAt": "2026-09-14",
        "reportType": "current-cut-reconciliation",
        "completion": "partial",
        "asOf": {
            "round": "R13",
            "roundStatus": "active-paused",
            "nextRound": "R14 prepared-not-started",
            "branch": git("branch", "--show-current"),
            "head": git("rev-parse", "HEAD"),
            "worktree": "dirty-until-this-documentation-commit",
        },
        "sources": {
            "currentState": CURRENT_STATE,
            "roundIndex": ROUND_INDEX,
            "latestCheckpoint": CHECKPOINT,
            "ownerQueue": "docs/reviews/etapa-2-operacao/next-round/R12-owner-items.json",
            "ownerQueueProjection": "docs/reviews/etapa-2-operacao/next-round/R13-owner-items-atual.json",
            "inventory": "docs/reviews/inventario-etapa-2.json",
            "artifactInventory": "docs/agent/artifact-inventory-20260914.json",
            "trackers": [
                "docs/reviews/coelo-flutter-pendencias.md",
                "docs/reviews/coelo-supabase-pendencias.md",
                "docs/reviews/coelo-flutter-integrado-supabase-pendencias.md",
            ],
        },
        "currentQueue": {
            "scope": "R13 vigente; R14 preparada sem execução",
            "ownerTotal": 53,
            "ownerPendingCount": len(pending),
            "ownerDoneCount": len(completed),
            "inheritedOriginIds": [f"H{i:02d}" for i in range(2, 29)],
            "inheritedOriginCount": 27,
            "inheritedStateSource": PENDENCIES,
            "activeNonTerminalActionUnion": 78,
            "nonTerminalByLayer": {"frontend": 64, "backend": 43, "integrated": 77},
            "deferredPostMvpActionCount": 22,
            "excludedCompletedOwnerIds": sorted(queue["excludedCompletedOwnerIds"]),
            "completedInR13OwnerIds": sorted(queue["completedInR13OwnerIds"]),
        },
        "metrics": metrics,
        "firstGate": "Saúde/Cuidado na rota real",
        "ownerItems": owner_items,
        "baseReference": git("rev-parse", "HEAD"),
        "target": str(ROOT.resolve()),
        "protectedWorktrees": {},
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
            "reason": "Os lotes SQL 63–69 e provas do executor permanecem registrados; esta rodada publicou documentação, sem novo deploy web, Edge ou Cloudflare.",
        },
        "r13Closure": {
            "round": "R13",
            "status": "active-paused",
            "source": CHECKPOINT,
            "completedOwnerItems": sorted(completed),
            "openOwnerItems": sorted(pending),
            "completedGates": ["H06", "H17", "OQ-028", "anexos com limite 10", "H21 backend"],
            "openFirstGate": "Saúde/Cuidado na rota real",
            "metrics": metrics,
            "deployment": "none for this documentation reconciliation",
            "memory": "no-op",
        },
        "history": {
            "priorRounds": "R01–R12 preserved as provenance; never use as current queue",
            "priorDeliveryReport": "previous content replaced by this current-cut report; Git history preserves the old snapshot",
            "residualBranches": "preserved and re-read from current refs; branch deletion is not authorized",
        },
    }
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {REPORT} with {len(owner_items)} Owner items, {len(branches)} residual branches and {len(evidence)} evidence files.")


if __name__ == "__main__":
    main()
