---
source: Owner 2026-09-13 — consolidar R12/R13 como R12, Luna médio, commits e pendências
status: histórico; substituído pela fila vigente R14
generated_at: 2026-09-13
updated_at: 2026-09-14
---

> Documento histórico. A R12 não é a fila atual e seu prompt não deve ser
> reexecutado. Use `docs/agent/current-state.md` e `R14-pendencias.md`.

# R12 — Base única consolidada

## Execução C0 em 13/09/2026

O início manual foi executado até o item 53. Foram publicados commits de
produto e documentação para chat.attach, convites, atividades, chamada,
segurança infantil, perfis, saúde/medicação, cardápios e editor de formulários.
Os aceites locais novos estão registrados nas evidências R12 correspondentes;
qualquer superfície alterada permanece `pending-verification` no integrado até
rota normal, persistência/reload e negativa cross-tenant. Itens externos que
dependem de SMTP, PITR/backup, contrato server-side de notificação ou gateway R2
foram mantidos como pendência explícita, sem simulação.

Pedido vigente: reunir R12 e R13 sob o nome **R12**, preparar um prompt para
**Luna médio**, publicar todos os ajustes de consolidação e deixar somente o
checkout principal. Não iniciar execução de produto nem outro supervisor aqui.

## O que está entregue e o que falta

- R12-07: margem do erro da chamada24px e responsividade/teclado/200%; entregue no recorte visual.
- R12-41: filtros Situação/Período canônicos, multisseleção/limpeza e resultado real3→2→1→3; entregue no recorte visual.
- R12-43: contorno de Conversas, clipping e dois temas/compacto/vazio; entregue no recorte visual.
- R12-52: avanço local de anexos visuais em f8c209a17; **aberto**, faltam provas e aceites. São29 testes únicos (20 tile +9 goldens), não29+9.
- Catálogo único:53 compromissos,3 ajustes completos,50 abertos. Sem renumeração, duplicação ou exclusão de pendências. Quatro itens de mapeamento específico permanecem explícitos.

R13-owner-items.json e partes dos registros anteriores não refletiam o delta
local de chat.attach. O catálogo/entrega vigentes foram corrigidos com base no
código f8c209a17 e R13-fechamento.md, sem transformar avanço parcial em E2E.
As tentativas posteriores de supervisão não trouxeram produto;387b9bdf monitorou
seus próprios eventos e terminou sem commit/WIP/checkpoint. PID/eventos não
comprovam trabalho. Último disparo36113ccf cancelado pelo pedido de consolidação.

## Fontes operacionais

Usar R12-prompt-unico.md, R12-plano-de-rodada.md, R12-pendencias.md e
R12-owner-items.json. R12-fechamento.md e R13-fechamento.md registram fases
históricas, não encerramento da R12 consolidada. Versões anteriores de prompt,
plano, pendências e checkpoint foram preservadas em *.historico-pre-consolidacao.md.
R13-* permanece histórico. Nenhum script de arm/release deve ser executado pelo
novo prompt. O início será manual no chat escolhido pelo Owner.

## Git e preservação R01–R13

Destino C:/Users/adrie/Documents/Coelo, dev. Os commits de produto ba5cfd2d e
f8c209a17 são ancestrais da base conjunta; não há cherry-pick/merge de produto
pendente entre R12 e R13. Commit/push desta consolidação integra os MDs/skills.
Uma única worktree principal; zero worktrees extras, zero stash, sem WIP retido
ao terminar. Nenhuma branch/ref foi apagada. R12-consolidacao-git.json enumera
refs e SHAs:30 referências residuais,20 superadas e10 equivalentes por patch,
zero retained-review, conforme revisão de conteúdo preservada em R10-consolidacao.md.
Não reintroduzir código/SQL histórico para zerar contagens do grafo Git.
Backups/ignorados e evidências privadas existentes preservados fora do Git.

## Métricas e limitações

Censo preservado:231 ações/39 famílias; FE175/231 (75,76%), BE159/224 (70,98%),
E2E148/199 (74,37%). FE local12/56 pendentes (21,43%), BE local21/65 (32,31%),
visual A54/231 (23,38%) e cobertura SQL181/224 (80,80%) são estados herdados,
não novas provas desta consolidação. Zero ganho funcional inventado.

Quatro goldens de Circulares e20 ocorrências do validador visual já falhavam
na base; continuam com destino explícito. PITR/backup/ordem, SMTP e permissões
remotas reais continuam gates dos respectivos dependentes. Nenhum deploy,
SQL/Edge/Cloudflare executado na consolidação. Runtime QA preservado serve o
build R12 ba5cfd2d, não o delta posterior f8c209a17: construir antes da prova
desse delta. Usar o PID/porta realmente existentes na próxima abertura.

Quatro skills atualizadas para a fonte única. Memória no-op: não mudou regra
de produto/permissão. Validação documental/checkout limpo não certifica o app.
Delivery gate pós-push deve passar; PASS DOCUMENTED_PARTIAL se refere às
pendências funcionais, não a commits/worktrees deixados por consolidar.
