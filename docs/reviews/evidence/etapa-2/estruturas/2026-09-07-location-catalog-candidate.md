---
title: "LOC-CATALOG01 — candidato local e gates pendentes"
source: "docs/superpowers/specs/2026-09-07-location-catalog-v2-local-contract.md"
status: "prepared-not-replayed-not-e2e"
generated_at: "2026-09-07"
---

## Recorte

Catálogo único de Locais no backend do Superadmin: criar, consultar detalhe e
listar por proprietário real. Não entrega ainda UI, edição, mapas, vínculos,
seleção de grupos ou os sete IDs completos. Nenhuma alteração em Admin,
Principal ou Site; nenhuma permissão para execução remota.

## Evidência obtida

- Gate estático sem candidato: RED observado; com candidato: 17 PASS.
- Revisão independente encontrou replay de receipt sem reautorizar proprietário
  atual e conflito classificado como argumento inválido. Ambos corrigidos e
  revisados estaticamente; teste preparado cobre fixture movida de A para B.
- Fixture de revogação corrigida para respeitar lifecycle e timestamps.
- Segunda revisão identificou instituição antiga na auditoria de replay por
  Owner de plataforma após mudança do proprietário. O ramo de receipt agora
  audita a instituição atual; sequência preparada exercita esse ator e cenário.
- Os dois gates de memória Coelo passaram. Nenhuma regra candidata foi
  promovida a conhecimento aprovado de produto.
- Consultas remotas foram somente metadados de estrutura e ACL; nenhum comando
  de negócio, DDL, DML, deploy ou concessão de capability em produção.

## Handoff obrigatório

Engineer1 seleciona e executa replay local serializado. Ordem: dependências,
bootstrap nominal de capabilities, migration candidata, duas suítes pgTAP.
Bootstrap é opt-in explícito, separado e anterior à migration; um seed posterior
ao reset não satisfaz o preflight. E2E5 valida fechamento dos caminhos legados.

Permanecem sem evidência executada: sintaxe PostgreSQL e regex de substituição,
preflight contra drift e catálogo não vazio, assertions pgTAP, RLS/ACL efetivas,
auditoria/rollback real, concorrência em duas sessões e regressão dos seis
caminhos de Atividades. Não houve uso de Docker nesta tarefa.

Preparação de testes, revisão estática e leitura de metadados não equivalem a
replay local aprovado, produção aplicada ou entrega E2E.
