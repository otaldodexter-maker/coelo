---
name: coelo-knowledge
description: Use when a Coelo task changes or explains product behavior, UX, domain rules, permissions, documentation, or other observable system knowledge that may be reusable by the team, administrators, or end users.
metadata:
  source: "AGENTS.md; docs/knowledge/README.md"
  status: "active"
  generated_at: "2026-09-08"
---

# Memória de conhecimento Coelo

## Fonte operacional vigente — R12 consolidada, execução parcial

Retomadas conferem a subtela exata do pedido: o seletor de recorrência do
cardápio não cobre automaticamente Modelo > Aplicar por. Usar o
[checkpoint vigente](../../../docs/reviews/etapa-2-operacao/next-round/R12-checkpoint.md)
e sincronizar os 53 registros Owner a partir de R12-pendencias.md com
sync-r12-owner-records.cjs; a validação estrutural não confirma implementação.

Consultar [R12 consolidada](../../../docs/reviews/etapa-2-operacao/next-round/R12-consolidacao.md), [pendências por camada](../../../docs/reviews/etapa-2-operacao/next-round/R12-pendencias.md) e [prompt Luna médio](../../../docs/reviews/etapa-2-operacao/next-round/R12-prompt-unico.md). R12/R13 foram reunidas pelo Owner: 53 compromissos. O conhecimento durável desta execução inclui identificador técnico oculto no formulário de perfis, múltiplos registros de cuidado, remoção de campos de cardápio dispensados e renomeação de seções de formulários; as regras server-side e provas E2E permanecem pendentes quando não comprovadas. Preservar R01–R13, fontes e provas. A antiga divisão e o supervisor são históricos; não disparar outro processo.

Atualizar estado/referências desta skill e as fontes operacionais conforme aceites comprovados; manter detalhes nas matrizes/catálogos, sem transformar skill em log. Os gates remotos, conhecimento por audiência e distinção FE/BE/E2E permanecem. Preparação R14 Claude Opus médio ocorre no corte futuro, sem execução automática.

## Decisões do Owner de 14/09/2026 (ADR 0038)

As 37 respostas do artefato de decisões viraram a ADR 0038, refletidas em
`AGENTS.md`, `docs/open-questions.md` e na projeção
`supabase-production-environment`. Specs a revisar por ela: 018, 020, 028,
037, 039/051, notices-mvp-design, locais-mapas-agendamentos e
forms-end-to-end. O adendo de 14/09 já fechou lembrete (30/15 min), Circular
4.000 total, catálogos de tipo, SMTP (fim do MVP) e os seis visuais; nada
aguarda o Owner nessa ADR.

## Entrega: gate bloqueante obrigatório

Aplicar o [gate de compromissos, rastreadores, Git e destino](../coelo-flutter-supabase-review/references/delivery-gate.md)
(ADR 0036). Enumerar todos os pedidos do Owner, incluindo anexos, e conferir
avanços/pendências por tela/subtela nas três camadas. Antes do fechamento,
reconciliar commits exclusivos, worktrees, stash, ignorados e skills no
checkout final. Rodar `docs/reviews/delivery_gate.py` após commit/push.
`PASS DOCUMENTED_PARTIAL` não autoriza dizer que tudo foi concluído; `FAIL`
bloqueia a declaração de conclusão. Não omitir pendência no corte nem integrar
histórico indiscriminadamente para zerar ahead/behind.

## Escopo futuro não é comportamento disponível

A Etapa 3 ainda faz parte do MVP, mas seu registro não inicia implementação.
Consultar `decisions/0035-etapa3-mvp-contextual-access-and-app-delivery.md` e a
projeção `docs/knowledge/team/etapa3-mvp-planned-scope.md`. Quando o Owner abrir
a etapa, revisar todas as fontes/pendências previstas para entregar o app e
propor escopo antes de executar. Manter requisitos planejados na audiência
team com limite explícito; não oferecê-los como ajuda de recurso disponível
na home IA. Restrição temporal/afastamento pertence ao vínculo profissional,
preservando os demais contextos da identidade global. Mudanças de estado só
ocorrem quando implementação e provas sustentarem a nova afirmação.

## Overview

Tratar `docs/knowledge` como projeção pesquisável, nunca como fonte canônica ou depósito de conversas.

## Gate de memória

Buscar primeiro com `scripts/Search-CoeloKnowledge.ps1`, ler as fontes e respeitar
`AGENTS.md`. Atualizar fonte canônica antes da projeção. Criar projeção somente
para conhecimento aprovado, durável e reutilizável; usar `no-op` quando nada
durável mudou. Separar `team`, `admin` e `users` em arquivos relacionados pelo
mesmo `knowledge_id`. Conflitos vão para `docs/open-questions.md`.

Recusar PII, CPF, dados de crianças, tenants reconhecíveis, mensagens, mídias,
logs integrais, segredos, tokens e conversas brutas. A base nunca concede
autorização por tenant, papel, vínculo ou contexto.

Validar com `scripts/Test-CoeloKnowledge.ps1` e
`tests/Test-CoeloKnowledge.ps1`, e relatar a captura ou o `no-op`.

Decisões do Owner sobre autorização remota, régua de aceite e processo são
conhecimento durável: registrar em ADR em `decisions/` no mesmo turno, refletir
em `AGENTS.md` e nas skills afetadas, e atualizar a projeção `team`
correspondente (por exemplo `supabase-production-environment`). Não deixar a
decisão só em relatório de rodada ou em conversa.


## Consulta e limites da automação

Scripts exigem Python 3.10+ no PATH e PyYAML de `scripts/requirements.txt`.
Não instalar dependências silenciosamente nem interpretar runtime ausente como
base válida. Executar os wrappers PowerShell a partir de qualquer diretório;
`-Root` permite validar um checkout ou fixture isolada.

`Search-CoeloKnowledge.ps1 -Query "termo" -Audience team -Detailed` retorna
metadados e fonte. A consulta é literal, sem busca semântica: tente termos
curtos/sinônimos antes de concluir que não existe artigo. Por padrão retorna
somente `validated`; `-Status draft`, `deprecated` ou `all` é inspeção explícita,
nunca aprovação do conteúdo. `user` e `users` selecionam a pasta `users`, cujo
frontmatter usa `audience: user`. `all` serve à descoberta interna; entregar
conteúdo apenas da audiência adequada, sem expor orientação interna ao usuário.

O validador exige YAML tipado, data real, surfaces não vazias, ID único por
audiência e source apontando a arquivo canônico dentro do repo, fora da própria
projeção. Não prova que a fonte está aprovada ou atual: abrir a fonte e comparar.
Detectores de dados sensíveis são heurísticos; menção educativa a `service_role`
é permitida, valor de credencial não. PASS não é certificação de ausência de PII.

Consulta somente leitura não escreve. Auditoria das skills não é uma aula e
não modifica `docs/learning/progress.md`. Não criar artigo para registrar tarefa;
projetar somente uma regra durável que tenha sido aprovada na fonte canônica.
