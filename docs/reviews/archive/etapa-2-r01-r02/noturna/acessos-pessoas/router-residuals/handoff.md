---
fonte: "NOTURNA-catalogo-falhas.md; commits 153b2dbfa, 2c0dbe84b e 3a96ca535; execucao focal sobre 6aa352c6a"
status: "local-green; publicacao pelo pai pendente"
data_geracao: "2026-09-09"
---

# Residuais funcionais de rotas de Pessoas e Safety

Base materializada: 6aa352c6a434086905444aaa5f128034ad8352e6, apps/superadmin. Recorte: Acessos -> Pessoas -> criar -> people.create; Seguranca infantil -> diretorio/criar/detalhe/editar -> child-safety.list/create/child/edit. Sem alteracao em produto, router compartilhado, composicao, SQL ou MFA.

O catalogo mediu uma falha em cada uma de tres suites sobre 414b82b29. people_routes_test.dart ja foi resolvido por 153b2dbfac2f9fa67750865a01fab57aa70a5a57: mensagem do commit registra 2P/1F -> 3P/0F, com allowDevelopmentPreview explicito. O commit esta integrado na base atual. Essa suite nao foi repetida e seus passes nao entram no lote novo.

Dois casos ainda falhavam na base atual, reproduzidos com --name focal: 0P/2F em red.txt.

- people_creation_requirements_red_test.dart: `create route requires identity lookup before exposing editable identity` exigia o dialogo na rota produtiva /people/new, apesar do bloqueio de mutacao introduzido em 2c0dbe84b. O contrato de isolamento ja esta em person_identity_fail_closed_routes_test.dart. O teste agora se chama `development create requires identity lookup while production stays blocked`: primeiro exige o painel production-mutation-capability-unavailable e ausencia de lookup/campos editaveis em producao; depois navega a /dev/people/new com preview explicitamente habilitado e exige lookup antes dos campos editaveis. Nao foi aberta escrita nem alterado o guard.
- safety_routes_test.dart: `development safety directory, create, detail and edit are locally navigable` passava pelo diretorio, criacao e detalhe, mas tentava editar dev-safety-0001-approved-1. O commit 3a96ca535 rejeita corretamente edicao de autorizacao nao pendente. O teste preserva essa tentativa e agora exige mensagem de contexto indisponivel e Continuar desabilitado; em seguida usa a fixture pendente dev-child-0127 / dev-safety-0127-pending-1 e verifica a justificativa `Solicitacao familiar aguardando revisao da unidade.` apos continuar. A fixture 0127 corresponde ao primeiro registro awaitingApproval do catalogo, sem dado real ou chamada remota.

Delta somente em dois arquivos de teste: 24 linhas acrescentadas, 2 substituidas; dart format 0 alteracoes e diff --check limpo. Sem teste novo, sem contagem duplicada de RED ou reruns. Nenhuma promocao FE/BE/E2E; o fluxo /dev nao qualifica persistencia produtiva. Nenhuma nova decisao de produto para memoria.

Resultado final: **2P/0F/0S**, green.txt, exit nativo 0; os dois casos RED foram resolvidos. people_routes 3P integrado e evidencia reaproveitada, nao soma a estes 2P. Todos os tres commits causais sao ancestrais do HEAD. Runner 53198 encerrado, Flutter livre.

Proximo passo: pai revisar evidencias e publicar os dois testes e esta pasta; manter todos os gates de contratos/persistencia do residual. Recursos proprios do filho: somente runner focal, encerrado antes da entrega; nenhum servidor ou recurso remoto criado. Git e JSON central nao foram escritos.
