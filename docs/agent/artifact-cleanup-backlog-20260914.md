---
title: "Backlog de limpeza de artefatos Coelo"
source: "Owner em 2026-09-14; docs/agent/artifact-inventory-20260914.json; auditoria paralela de artefatos"
status: "active"
lifecycle: "current"
generated_at: "2026-09-14"
updated_at: "2026-09-15"
audience: "team"
---

# Backlog de limpeza de artefatos

Este arquivo é a fila da próxima sessão de saneamento. Artefatos não são
fonte de produto. Nenhum item abaixo autoriza exclusão fora do estado indicado.

## Concluído nesta sessão

- L1: `.preserved/` foi movido para
  `C:/Users/adrie/Documents/Coelo.preserved/workspace-preserved-20260914/`.
- L1b: `C:/Users/adrie/Documents/Coelo.worktrees/` foi removido após confirmação
  de que estava vazio; branches foram preservadas.
- Scratch seguro do Codex: os três arquivos temporários e o diretório vazio
  listados em L2 foram removidos após verificação de ausência de referência.

Manifestos: `artifact-disposition-l1-20260914.json`,
`artifact-disposition-l2-20260914.json` e este arquivo.

## Próxima ação segura

### L2 — `.codex` scratch/cache regenerável

Estado: concluído apenas para os quatro candidatos abaixo. Não ampliar o lote
sem nova verificação de processo e referência.

| Caminho | Tamanho anterior | Motivo |
|---|---:|---|
| `.codex/patch_probe.tmp` | 6 B | Arquivo de teste temporário |
| `.codex/temp.txt` | 5 B | Arquivo temporário |
| `.codex/stdin-write-test.txt` | 0 B | Teste vazio de escrita |
| `.codex/health-surface-validation/` | vazio | Diretório vazio |

Não remover `activity-patch-tree`, `staged-groups-validation`, `chrome-preview`,
`unit-db-push-214000`, `backups`, `deliverables`, `golden-review`,
`safety-final-review`, `patch-work` ou qualquer configuração ativa.

## Bloqueios e retenções

- Capturas WIP da R13/R14: manter como proveniência até a sessão executora
  classificar cada uma. Não fazer `git add -A`, stash, revert ou remoção.
- `.claude/settings*.json`, `launch.json` e junctions de skills: manter; revisar
  permissões depois do fechamento da R14.
- `.superpowers/brainstorm` e `.superpowers/sdd`: manter enquanto houver estado
  de trabalho ou referência ativa.
- `.recovery-archives`: somente deduplicar/comprimir após inventário de nomes,
  referências e risco de dados sensíveis.
- `C:/Users/adrie/Documents/Coelo.artifacts`: classificar referências e
  duplicatas antes de arquivar.
- `C:/Users/adrie/Documents/Coelo.preserved`: manter uma cópia recuperável;
  remover duplicatas somente após teste de recuperação e manifesto.
- `C:/Users/adrie/Documents/Coelo-backups`: retenção crítica; não abrir,
  copiar, executar, indexar ou apagar `.env`, tokens, cookies, sessões, dumps,
  bundles ou arquivos de produção sem decisão de segurança/Owner.
- 30 branches residuais: manter até reachability, WIP, sucessor e evidência
  serem revisados; este lote não autoriza apagar branches.
- R01–R12, planos, specs e evidências históricas: arquivar somente após
  substituir referências atuais e preservar proveniência, SHA e manifesto.

## Critério de encerramento

Encerrar a limpeza somente quando cada item tiver estado `keep`, `archive`,
`quarantine` ou `delete`, caminho de destino, evidência e aprovação. Depois
rodar os validadores de rastreadores, o gate de memória e o delivery gate.

## Próxima sessão

1. Reconciliar as capturas WIP com a sessão executora e fechar a R14 quando a
   execução de produto terminar.
2. Fazer inventário file-level de L3–L5 sem abrir dados sensíveis.
3. Substituir no relatório as evidências históricas que deixarem de ser
   necessárias antes de arquivar documentos R01–R12.
4. Apresentar novo lote itemizado ao Owner antes de qualquer exclusão.
