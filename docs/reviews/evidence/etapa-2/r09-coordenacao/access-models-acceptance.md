---
source: C0 normal UI; production RPCs; coordinated SQL mirror
status: verified
generated_at: 2026-09-12
---

# Modelos de acesso: editar e duplicar

apps/superadmin -> Acessos -> Perfis e permissoes -> Modelos ->
access-models.edit/access-models.duplicate. C0 executou na base36ef3a43e,
Chrome22592, localhost3014, Auth normal, flags QA de emulacao desativadas.

Modelo sintetico R04 cc322488-bb7d-4490-9418-ac941db7e6ae preservado:
somente descricao alterada para "Modelo sintetico da Rodada 4; descricao
revisada pela UI na R09 1542.". Assistente passou pelas permissoes e vinculos
sem alteracoes; revisao mostrou zero permissoes/vinculos impactados. Motivo
auditavel informado, salvar retornou ao diretorio. Reload do diretorio e
nova abertura mostraram a descricao persistida (access-model-edit-reload.png).
SQL confirmou version3, active, codigo e nome preservados.

Botao Duplicar do proprio card abriu a rota normal. Nova copia
5e1b5e75-814a-43cf-8031-d38ee3d4f830, QA R09 Copia modelo1542 (nome real
com espaco antes de1542), codigo qa-r09-copia-modelo-1542-dfe5ff08,
inactive/version1, sem atribuicoes. Motivo explicito no formulario.
Diretorio retornou a copia; abrir, reload completo e nova leitura mantiveram
nome, codigo e Inativo (access-model-copy-reload.png). Nao ativada nem excluida.

Sonda access-model-consumer.json:6 checks PASS (anon401, Auth200, descricao
editada, copia inativa independente, capacidades iguais a origem, logout204).
Sem tokens ou URLs privadas no resultado. Consulta inicial tentou tabela
access_profile_models inexistente; corrigida para access_profile_templates,
somente leitura. Primeira extracao do resultado de paridade falhou no parser;
consulta repetida e parser corrigido, sem alteracao de dados.

Base conjunta SQL:11/11 access_profile_models_read_authorization_test e
32/32 access_profile_models_crud_catalog_test PASS. Leitura por pessoa global
negada, capacidades por dominio exigidas, auditoria e CRUD com ator interno.
26 corpos de funcoes, incluindo require_superadmin_internal_context, iguais
entre producao e espelho. Dominio platform global: nao inventar tenant_id ou
vinculo institucional para este modelo. Sem segunda sessao real tenantB;
negativas comportamentais locais na mesma implementacao, conforme regua MVP.

BE ja done pela prova R04; nao contar crescimento BE. Dois novos aceites
FE/E2E pela UI produtiva e persistencia. Nenhuma mudanca de codigo, SQL,
segredo ou deploy nesta fatia; testes Flutter verdes anteriores reutilizados.
Memoria: contrato existente copia inativa/sem vinculos preservado; sem novo
conhecimento duravel a acrescentar.
