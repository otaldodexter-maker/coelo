"""Typed, read-only validation and search of the Coelo knowledge projection."""

import argparse
import datetime
import json
from pathlib import Path, PureWindowsPath
import re
import sys

try:
    import yaml
except ImportError:
    sys.exit("PyYAML ausente. Prepare Python com scripts/requirements.txt; nada foi instalado.")


class MetadataLoader(yaml.SafeLoader):
    pass


# Keep ISO dates as strings, then check their calendar validity explicitly.
MetadataLoader.yaml_implicit_resolvers = {
    key: [(tag, regex) for tag, regex in values if tag != "tag:yaml.org,2002:timestamp"]
    for key, values in yaml.SafeLoader.yaml_implicit_resolvers.items()
}


def unique_mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if not isinstance(key, str) or key in result:
            raise ValueError("chave YAML inválida ou duplicada")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


MetadataLoader.add_constructor("tag:yaml.org,2002:map", unique_mapping)
AUDIENCES = {"team": "team", "admin": "admin", "users": "user"}
REQUIRED = ("title", "knowledge_id", "source", "status", "generated_at",
            "audience", "surfaces", "visibility", "review_owner")
STATUSES = ("draft", "validated", "deprecated")
SENSITIVE = {
    "possível CPF": r"\b(?:\d{11}|\d{3}\.\d{3}\.\d{3}-\d{2})\b",
    "atribuição de segredo": r"(?i)\b(?:service_role|secret|token|api[_-]?key)\s*[:=]\s*\S+",
    "chave OpenAI": r"\bsk-(?:proj-)?[A-Za-z0-9_-]{12,}\b",
    "JWT": r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b",
    "conversa bruta": r"(?im)^\s*(?:usuário|usuario|assistente|user|assistant)\s*:",
}


def read_article(path):
    content = path.read_text(encoding="utf-8-sig")
    match = re.match(r"\A---\s*\r?\n(.*?)\r?\n---(?:\r?\n|\Z)", content, re.S)
    if not match:
        raise ValueError("frontmatter YAML ausente ou inválido")
    try:
        metadata = yaml.load(match[1], Loader=MetadataLoader)
    except (yaml.YAMLError, ValueError, TypeError, RecursionError) as error:
        # Parser diagnostics may contain sensitive values; never print them.
        raise ValueError("frontmatter YAML inválido ou com chave duplicada") from error
    if not isinstance(metadata, dict):
        raise ValueError("frontmatter deve ser um mapa YAML")
    return metadata, content


def source_error(root, source):
    candidate = Path(source)
    if candidate.is_absolute() or PureWindowsPath(source).drive or "\\" in source:
        return "source deve ser caminho relativo ao repositório com /"
    resolved = (root / candidate).resolve()
    if not resolved.is_relative_to(root):
        return "source sai da raiz do repositório"
    if resolved.is_relative_to((root / "docs/knowledge").resolve()):
        return "source deve ser canônica, fora de docs/knowledge"
    if not resolved.is_file():
        return "source deve apontar para arquivo existente"
    return None


def article_errors(root, path, folder, metadata, content):
    errors = []
    for field in REQUIRED:
        value = metadata.get(field)
        if field == "surfaces":
            if not isinstance(value, list) or not value or any(
                not isinstance(item, str) or not item.strip() for item in value
            ):
                errors.append("surfaces deve ser lista não vazia de strings")
        elif not isinstance(value, str) or not value.strip():
            errors.append(f"campo obrigatório deve ser string não vazia: {field}")
    if metadata.get("status") not in STATUSES:
        errors.append("status inválido")
    if metadata.get("audience") != AUDIENCES[folder]:
        errors.append("audience diverge da pasta")
    for field in ("generated_at", "updated_at"):
        if field not in metadata:
            continue
        value = metadata[field]
        try:
            if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
                raise ValueError()
            datetime.date.fromisoformat(value)
        except ValueError:
            errors.append(f"{field} deve ser data válida YYYY-MM-DD")
    kid = metadata.get("knowledge_id")
    if not isinstance(kid, str) or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", kid):
        errors.append("knowledge_id deve usar kebab-case")
    source = metadata.get("source")
    if isinstance(source, str) and source.strip():
        try:
            problem = source_error(root, source)
        except (OSError, ValueError, RuntimeError):
            problem = "source inválida"
        if problem:
            errors.append(problem)
    for label, pattern in SENSITIVE.items():
        if re.search(pattern, content):
            errors.append(f"conteúdo proibido detectado: {label}")
    return errors


def scan(root):
    root = Path(root).resolve()
    base = root / "docs/knowledge"
    errors, records, identities = [], [], set()
    if not base.is_dir() or not base.resolve().is_relative_to(root):
        return [], ["docs/knowledge: diretório ausente ou fora da raiz"]
    for folder in AUDIENCES:
        audience_root = base / folder
        if not audience_root.exists():
            continue
        if not audience_root.resolve().is_relative_to(base.resolve()):
            errors.append(f"docs/knowledge/{folder}: audiência fora da projeção")
            continue
        for path in sorted(audience_root.rglob("*.md")):
            label = path.relative_to(root).as_posix()
            if not path.resolve().is_relative_to(audience_root.resolve()):
                errors.append(f"{label}: artigo fora da audiência")
                continue
            try:
                metadata, content = read_article(path)
                problems = article_errors(root, path, folder, metadata, content)
            except (ValueError, OSError, UnicodeError, RuntimeError):
                errors.append(f"{label}: arquivo ou YAML inválido")
                continue
            kid = metadata.get("knowledge_id")
            identity = (folder, kid) if isinstance(kid, str) else None
            if identity in identities:
                problems.append("knowledge_id duplicado na mesma audiência")
            if identity:
                identities.add(identity)
            errors.extend(f"{label}: {problem}" for problem in problems)
            if not problems:
                records.append({"path": label, "metadata": metadata, "content": content})
    return records, errors


def search(records, query, audience="all", status="validated"):
    audience = "user" if audience == "users" else audience
    return [record for record in records
            if (audience == "all" or record["metadata"]["audience"] == audience)
            and (status == "all" or record["metadata"]["status"] == status)
            and query.casefold() in record["content"].casefold()]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("validate", "search"))
    parser.add_argument("--root", required=True)
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("--query")
    parser.add_argument("--audience", choices=("all", "team", "admin", "user", "users"), default="all")
    parser.add_argument("--status", choices=(*STATUSES, "all"), default="validated")
    parser.add_argument("--detailed", action="store_true")
    args = parser.parse_args()
    if args.mode == "search" and not (args.query and args.query.strip()):
        parser.error("search exige --query não vazia")
    records, errors = scan(args.root)
    if errors:
        if not args.quiet:
            print("\n".join(errors), file=sys.stderr)
            print(f"FAIL: {len(errors)} erro(s) na base de conhecimento.", file=sys.stderr)
        return 1
    if args.mode == "validate":
        if not args.quiet:
            print(f"PASS: {len(records)} artigo(s) validado(s). Revisão humana de conteúdo continua necessária.")
    else:
        matches = search(records, args.query, args.audience, args.status)
        if args.detailed:
            print(json.dumps([{"path": r["path"], **r["metadata"]} for r in matches], ensure_ascii=False))
        else:
            for record in matches:
                print(record["path"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
