---
title: "Atividades — busca, hierarquia de filtros e negação"
source: "docs/superpowers/specs/2026-07-29-superadmin-activity-inspection-design.md; review Eng2 encaminhado pelo Coordenador; testes e review read-only E2E5"
status: "local-green; backend e E2E pendentes"
generated_at: "2026-09-07"
---

# Recorte

Tela Atividades, diretório/busca/filtros, `activities.list`, Superadmin somente.
Passo 3/6 cliente → 5/6 regressão → 6/6 review/commit desta fatia. Sem mudança
de layout, editor, contrato público, adapter ou SQL neste commit. BD: nenhum
acesso local ou remoto. Repository fake nos testes; não prova cross-tenant no
servidor. Writer root; review independente `activities_sql_review`.

## TDD e mudança

Três REDs confirmaram os achados encaminhados pelo Coordenador: resposta antiga
aceita entre mudança da busca e debounce, notificação após dispose e turmas de
outra instituição visíveis quando nenhuma unidade está selecionada.

O ViewModel agora invalida a requisição na mudança da busca, entra em loading
imediatamente, invalida continuations no disposal e cruza opções de turma com
unidades das instituições selecionadas. Quando não há filtro hierárquico,
preserva as opções retornadas pelo repository autorizado.

Review adicional encontrou precedência de erro incorreta: `Future.wait`
conservava a primeira indisponibilidade e escondia uma negação posterior da
outra RPC. Dois REDs reproduziram ambas as combinações de endpoint. O VM
reúne resultados/erros, prioriza a negativa e limpa página/opções anteriores.
O teste semeia instituição, unidade e turma antes da negativa, evitando
falso-verde da limpeza de opções originalmente vazias.

## Evidência e limites

- Cinco casos novos falharam antes das correções.
- Dez testes focados de VM/ordem passaram.
- Regressão domínio + VM + diretório final: 33/33 verdes após o reforço de sentinelas.
- Analyzer dos três arquivos: sem problemas.
- Review estático: sem regressão funcional encontrada; teste de sentinelas
  reforçado conforme recomendação.
- Não foi alterado golden ou componente visual. Estados e dimensões existentes
  foram exercitados pelos testes funcionais do diretório, não por navegador real.
- A agregação ainda aguarda ambas as RPCs; não comprova negação imediata enquanto
  outra chamada permanece pendente. Nenhuma autorização server-side foi alterada.
- Migration/adapter A01 continuam em outro pacote. Não promove Front-end
  `verified`, backend `done` ou integração `verified-e2e`.

Memória: no-op. Nenhuma nova regra aprovada de produto; os filtros relacionais
e ausência de exposição após negativa já são contratos existentes.
