---
title: "Dashboard responsivo de Assiduidade"
source: "aprovação explícita do usuário em 2026-08-25"
status: "approved"
generated_at: "2026-08-25"
---

# Dashboard responsivo de Assiduidade

## Objetivo e problema

Substituir a landing de Assiduidade limitada a `Nova chamada` por uma visão
analítica e operacional baseada exclusivamente em dados reais e no escopo
autorizado. A chamada existente permanece o fluxo canônico de operação.

Esta decisão substitui somente as cláusulas abaixo, sem reescrever o histórico:

- em `specs/024-superadmin-attendance-daily-routine-production.md`, `Landing de
  Assiduidade somente com Nova chamada` e a proibição de dashboard, histórico,
  métricas e filtros na landing;
- em `specs/033-superadmin-attendance-production-closure.md`, a conclusão de que
  dashboard e histórico permaneciam reprovados e a evidência de landing somente
  com `Nova chamada`.

As demais regras das specs 015, 024 e 033 continuam vigentes, especialmente o
registro oficial, a separação de avisos familiares, a autorização backend-first
e o fluxo canônico de chamada.

## Escopo e superfícies

- Dashboard no host produtivo existente do Superadmin, preservando shell e
  sidebar.
- Contratos puros compartilháveis com Admin, Professor e Principal.
- Consultas, métricas, rankings, série temporal, últimas chamadas e exportações
  autorizadas e agregadas no servidor.
- Admin, Professor e Principal recebem integração visual somente quando seus
  hosts produtivos existirem; não serão simulados com dados ou rotas fictícias.
- Wizard, detalhe, fechamento, reabertura e correção de chamada ficam fora de
  escopo, salvo a navegação a partir da landing.

## Dados, métricas e autorização

O backend resolve o escopo efetivo de plataforma, instituição, unidade,
atribuições profissionais ou vínculo familiar. Toda RPC revalida ator,
capability, tenant, instituição, unidade, turma, atividade e criança; filtros
enviados pelo cliente nunca ampliam o escopo.

Presença é calculada sobre registros ativos de sessões oficiais `closed` ou
`corrected`:

`(present + late_arrival + early_departure + late_and_early) / registros oficiais válidos`

Participantes ainda sem registro, sessões não iniciadas, sessões abertas ou
reabertas, sessões canceladas e avisos familiares não entram no denominador.
Denominador zero produz `Dados insuficientes`, sem meta ou percentual inventado.

`Chamadas pendentes` inclui somente sessões reais em `draft`, `open` ou
`reopened`; não presume agenda ou obrigatoriedade inexistente. `Em revisão`
contabiliza avisos familiares pendentes e permanece separado do registro
oficial. A tendência compara um período anterior de mesma duração somente
quando ambos têm base válida.

Exportações de visão e tabela exigem `attendance.export`, usam job e snapshot
server-side, respeitam os filtros atuais, minimizam dados pessoais, são
auditadas e armazenadas privadamente com download temporário.

## UX e responsividade

A hierarquia é cabeçalho e `Nova chamada`; período, granularidade e filtros;
calendário, KPIs e atenção; desempenho por contexto; presença no período; e
últimas chamadas. A página usa `colorScheme.surface` e apenas `Nova chamada` é
ação preenchida principal.

Instituições é a baseline de cards, filtros, tabela e paginação. Criar/Editar
Instituição é a baseline de geometria, gaps e separação entre superfícies. O
seletor canônico Coelo abre inline em desktop amplo e em diálogo seguro no
compacto. Layout é decidido por constraints: uma coluna abaixo de 840 px,
composição adaptativa entre 840 e 1199 px e faixa ampla a partir de 1200 px.

Rankings mostram resumo curto, seleção não dependente apenas de cor, breadcrumb
em cascata e listagem completa sob demanda. Professores são descritos por
vínculo, responsabilidade e conclusão operacional; presença observada pertence
ao contexto e não constitui avaliação docente.

O gráfico de linha apresenta período atual e anterior comparável, alternativa
textual acessível e reduced motion. A tabela usa linhas contínuas, busca,
filtros, ordenação e paginação reais no servidor.

## Estados, eventos e testes

Estados obrigatórios: loading, ready, empty, no-results, error/retry,
unauthorized e not-found quando aplicável. Controles preservam foco, teclado,
mouse, toque, Semantics, texto a 200%, light/dark e alvos mínimos de 48 × 48.

Registrar solicitações e conclusão/falha de exportação sem payload pessoal.
Testes cobrem cálculo, insuficiência, filtros, cascata, respostas obsoletas,
capabilities, responsividade 375/768/1024/1440, goldens focados, RLS e acesso
cruzado por todos os níveis. Nenhum dado fake participa de produção.

## Riscos e rollout

Migration e Edge Function são validadas localmente antes de qualquer aplicação
remota. A entrega é bloqueada por agregação no cliente, permissão inventada no
Flutter, exportação sem capability, vazamento cross-tenant, regressão visual não
explicada ou teste de segurança não executado.
