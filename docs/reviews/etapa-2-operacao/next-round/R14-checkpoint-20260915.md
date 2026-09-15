---
source: Owner em 2026-09-15; R14-handoff-sessao-1.md; R14-handoff-sessao-2.md; inventario-etapa-2.json; R14-pendencias.md
status: checkpoint
lifecycle: "current"
generated_at: 2026-09-15
updated_at: 2026-09-15
---

# R14 — checkpoint do corte de 15/09/2026

Este checkpoint registra o corte publicado em `dev` após o encerramento da
Sessão 1 (Blocos A e B) e as provas de Cardápios publicadas pela Sessão 2. Não
é uma fila alternativa: a fila viva continua sendo
[`R14-pendencias.md`](R14-pendencias.md). A R15 ainda não foi aberta.

## Quatro números certificados

| Indicador | Resultado | Leitura |
|---|---:|---|
| FE verificado | 184 / 231 (79,65%) | inventário validado |
| BE concluído | 166 / 224 (74,11%) | sete ações não aplicáveis ao BE |
| E2E verificado ativo | 157 / 192 (81,77%) | denominador 192 após o Bloco B |
| Owner items done | 15 / 53 (28,30%) | seis aceites novos da Sessão 1 sobre os nove anteriores |

## Delta desta coordenação

- Bloco A fechado em 10/10: Circulares, Agenda, Assiduidade, Rotina, Acontece,
  Shell, Atividades, Convites, Chat e Unidades.
- Bloco B aplicado: sete ações foram reclassificadas como
  `deferred-post-mvp`; o E2E ativo passou de 199 para 192 sem alterar os
  denominadores FE/BE.
- Cardápios tem prova FE/BE/E2E publicada em
  `r14-sessao-2/meal-plans-20260915.md`; `owner.r12-34/35/36/37` permanecem
  `partial` no contador Owner deste corte até o aceite central, sem repetir a
  prova técnica.
- Owner items movidos para concluídos nesta coordenação:
  `r12-03`, `r12-12`, `r12-14`, `r12-42`, `r12-44` e `r12-45`.
- Em Perfis de cuidado, `owner.r12-29/30` passa a exigir vários registros
  independentes de alergias e orientações, com adicionar/remover/reload e
  limite defensivo de 100 por coleção/entidade validado no backend.

## Sobra preparada para a R15

`owner.r12-05` (escopo de Atividade na RPC), `r12-06` (rotina/versão na
chamada), `r12-08` (massa com múltiplos alunos), `r12-13/15/16` (ciclo de vida
de Segurança infantil e timeout `child_safety_change_lifecycle`), os Perfis de
acesso `r12-19` a `r12-27`, upload em resposta de Formulários com ocorrência
aberta, contexto ativo após “Ver como”, e as imagens privadas R2 de Cardápios
(`r12-38`) e Conta (`r12-46`) ficam preparados para transferência. O contrato
de Auth recovery/reset e o reader de Planos comerciais permanecem fora da R14
por ADR 0039.

## Estado de execução

Sessão 1 está encerrada. Sessão 2 continua em `Coelo.worktrees/r14-cd`, branch
`r14/bloco-cd`; as worktrees/branches R14 devem ser preservadas até o fechamento
da rodada. Novas sessões C e E serão abertas em worktrees próprias, sem apagar
as existentes.
