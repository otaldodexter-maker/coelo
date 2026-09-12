---
source: G7 R08 worktree closing inventory
status: observed
generated_at: 2026-09-12T13:50:29-03:00
---

# Inventário somente leitura de worktrees R08

Escopo: as nove worktrees G0--G8 e a worktree C0. Nenhum arquivo, stash, branch ou worktree foi alterado/removido. O snapshot usou `git fetch origin`, `git status --short`, `git rev-list --left-right --count HEAD...origin/dev`, `git log origin/dev..branch -3`, `git stash list` e a lista de ignorados, excluindo `.dart_tool`, `build`, `node_modules` e `.git`.

## Estado Git

| frente | branch | HEAD | ahead/behind | WIP rastreado | recomendação agora |
| --- | --- | --- | ---: | --- | --- |
| G0 runtime | `work/etapa2-r08-ambiente-runtime` | `353689d85` | 17/0 | limpo | reter: 17 commits ainda não estão em `origin/dev` |
| G1 estrutura | `work/etapa2-r08-estrutura` | `5bee1edfb` | 14/0 | limpo | reter: correções idempotentes de avaliações aguardam revisão/integração |
| G2 acessos/pessoas | `work/etapa2-r08-acessos-pessoas` | `64dab33fa` | 3/0 | limpo | reter: pacote de Pessoas ainda não integrado |
| G3 formulários | `work/etapa2-r08-formularios-cuidado-rotina` | `0c92198a0` | 6/0 | teste de tabela modificado | reter: WIP rastreado |
| G4 principal/chat | `work/etapa2-r08-principal-chat-sistema` | `d5aa7e253` | 6/0 | teste de perfil modificado | reter: WIP rastreado |
| G5 realm interno | `work/etapa2-r08-realm-interno` | `5927718f2` | 4/0 | limpo | reter: correção de ticket R2 ainda não está em `origin/dev` |
| G6 publicações | `work/etapa2-r08-publicacoes-agenda` | `d9c6f0dad` | 7/0 | limpo | reter: evidências ainda não integradas |
| G7 operações | `work/etapa2-r08-operacoes` | `8ec701dc0` | 4/0 | limpo antes deste inventário | reter até C0 integrar/dispensar revisão H28 e este recibo |
| G8 suites | `work/etapa2-r08-suites` | `cfc710b13` | 11/0 | limpo | reter: parser/plano de censo ainda não integrado |
| C0 coordenação | `work/etapa2-r08-coordenacao` | `c729090f9` | 26/0 | JSON e quatro evidências não rastreadas | reter: escritora central ainda ativa |

Todos os dez HEADs retornaram não-ancestrais de `origin/dev`; portanto nenhuma worktree R08 está demonstravelmente encerrável por integração neste snapshot. `git stash list` não retornou entradas.

## Ignorados relevantes, por nome e tamanho

Não enumerei artefatos de build. PNGs em `test/**/failures/` são resíduos de golden falho: diagnóstico descartável, não prova nem WIP de produto.

- G0: `apps/superadmin/.env.local` (160 bytes), privado: reter localmente e nunca versionar/copiar; logs QA stdout/stderr (0 bytes); `supabase/.temp/*` é estado de CLI local.
- G1: `docs/reviews/evidence/etapa-2/r08-estrutura/png-a-20260912.log` (1.321 bytes), diagnóstico não rastreado; `__pycache__` descartável.
- G3: logs ignorados de análise sob `docs/reviews/evidence/etapa-2/r08-formularios-cuidado-rotina/`; versionar somente se a evidência final depender deles.
- G4: `principal-viewer-focal.tmp.log` (13.544 bytes) e `principal-viewer-test.tmp.log` (32.119 bytes): diagnóstico local, reter até o dono produzir evidência sanitizada; `__pycache__` descartável.
- C0: logs de análise/deploy, `packages/coelo_database/supabase/.temp/*` e `tmp/r08-p51-auth-config/supabase/config.toml`: privado/local, não versionar nem replicar.

## Decisão proposta

Não remover/mover worktrees agora. C0 deve integrar ou dispensar cada conjunto de commits e resolver os WIPs rastreados G3/G4; depois reexecutar este inventário contra o `origin/dev` final. Somente worktree limpa, sem commits não integrados, sem WIP e sem artefato privado a reter pode ser encerrada. Branches permanecem.
