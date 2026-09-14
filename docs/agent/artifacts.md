---
title: "Artefatos e isolamento do harness Coelo"
source: "AGENTS.md; inspeção de diretórios em 2026-09-14"
status: "active"
generated_at: "2026-09-14"
updated_at: "2026-09-14"
audience: "team"
---

# Artefatos

## Regra

Artefato de execução não é fonte de produto. Patches, logs, screenshots,
snapshots, worktrees, sessões, caches, prompts e backups só entram numa tarefa
quando o pedido for especificamente sobre aquela evidência.

## Diretórios identificados

O inventário agregado desta rodada, com tamanho, classificação, risco e ação
preliminar por local, está em
[`artifact-inventory-20260914.json`](artifact-inventory-20260914.json). Ele é
somente metadado: a lista de exclusão detalhada ainda depende de revisão e
aprovação do Owner.

O backlog operacional da limpeza está em
[`artifact-cleanup-backlog-20260914.md`](artifact-cleanup-backlog-20260914.md).
Ele separa o que já foi removido com aprovação do que permanece retido por
WIP, recuperação, segurança ou proveniência.

O Lote L2 removeu somente três arquivos scratch e uma árvore sem arquivos,
registrados em `artifact-disposition-l2-20260914.json`.

- `.codex/`: runtime local; contém previews, patches, logs, validações e um
  `AGENTS.md` legado em `activity-patch-tree`.
- `.claude/`: configurações e junctions de skills do Claude; não é fonte de
  domínio. `settings.local.json` contém permissões históricas para copiar
  arquivos a uma worktree externa e para executar Cloudflare; isso não é
  requisito do projeto e deve ser revisado antes de reutilizar.
- `.superpowers/`: brainstorms, SDD, planos e diffs; histórico de processo.
- `.recovery-archives/`: retenção local de recuperação. O antigo `.preserved/`
  foi movido para `C:/Users/adrie/Documents/Coelo.preserved/workspace-preserved-20260914/`
  no Lote L1, com manifesto.
- `C:/Users/adrie/Documents/Coelo.artifacts`: scripts e resultados de rodadas.
- `C:/Users/adrie/Documents/Coelo.preserved`: evidências e worktrees retidos.
- `C:/Users/adrie/Documents/Coelo-backups`: backups, dumps e capturas.

Backups com `.env`, cookies, sessões, dumps ou bundles Git são potencialmente
sensíveis. Não abrir, copiar, indexar, anexar ou executar seu conteúdo durante
uma limpeza documental; antes de qualquer descarte, o Owner/ops deve avaliar
rotação de segredos e invalidação de sessões. O destino externo de preservação
fica fora do workspace para não entrar em buscas ou `git add` por acidente.

Esses diretórios permanecem preservados nesta fase. Nenhum arquivo será
excluído, movido ou reclassificado sem manifesto e aprovação do Owner. Antes
da próxima fase de exclusão, verificar também segredos, dados sintéticos,
dependências de scripts e possibilidade de recuperação.

## Isolamento aplicado nesta fase

Os `AGENTS.md` encontrados em snapshots gerados de `.codex` e
`.recovery-archives` foram substituídos por avisos de quarentena para não serem
herdados quando alguém abrir um artefato como diretório de trabalho. As versões
anteriores foram preservadas em
`C:/Users/adrie/Documents/Coelo.preserved/workspace-preserved-20260914/agent-context-audit-20260914/`.
Isso é isolamento de contexto, não exclusão de evidência.
