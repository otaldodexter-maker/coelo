---
title: "F-AUTHOR01 — pacote local de rascunhos internos"
source: "Reserva nominal do Coordenador; crosswalk38041740; matriz efetiva; revisões read-only e testes preparados E2E4"
status: "static-reviewed-prepared-unexecuted"
generated_at: "2026-09-07"
---

# Estado

SQL e pgTAP preparados localmente, **nenhum SQL executado**. Não há RED/GREEN de
banco comprovado, deploy, acesso remoto ou claim E2E. Eng1 é o executor exclusivo.
Root único writer; três recortes de revisão independentes somente leitura.

Arquivos:

- `packages/coelo_database/migrations/20260908030000_superadmin_internal_form_drafts_v2.sql`.
- `packages/coelo_database/supabase/tests/superadmin_internal_form_drafts_v2_test.sql`.
- Matriz `2026-09-07-authoring-coexistence-matrix.md` e crosswalk
  `2026-09-07-authoring-nominal-crosswalk.md`.

Git blobs atuais após review pós-lock (não SHA256 de arquivo CRLF): migration
`fe2f82f9a5901e35512a8c216c8e7e9c6f4fe04f`; teste principal
`6ae5bd0c21da4ea23988cb4f5d2ee8a65e755821`.
Os blobs anteriores 955cfc5/7b6dd8c do commit 1ccae045 foram substituídos antes
do replay. Arquivos adicionais `_repeatable_read_test.sql` e
`_serializable_test.sql` usam, respectivamente,
`fa4f6b16996e170507722696e06365e2502cadf7` e
`48e1404bbbeb396f6c44692776c8e1cbdc274f29`.

Delta e protocolo concorrente: `2026-09-07-authoring-lock-reauthorization.md`.
READ COMMITTED nominal obrigatório; reautorização após waits com âncoras/escopo
originais; instituição não excluída sob SHARE. Nenhum SQL executado.

# Dependências nominais para o executor

Usar base Auth nominal com contexto interno real, audit v2/v3, último Owner e
envelope. Exigir a política efetiva de
`20260901200206_defer_superadmin_internal_mfa_until_mvp_go_live.sql` (AAL1/AAL2)
e ampliação `20260827235500_superadmin_internal_institution_list_filter.sql`
(INVALID_ARGUMENT/400). CONCURRENT_CHANGE/409 também tem preflight semântico.
Não reaplicar cadeias históricas de Auth nem substituir helpers para passar.

Além da fundação Forms 55005/55116 já usada pelo reader, a autoria depende dos
corpos/tabelas efetivos; não se resume às duas migrations do diretório:

1. `20260813155005_forms_definition_and_capabilities.sql`.
2. `20260813155116_forms_distribution_and_occurrences.sql`.
3. `20260813155118_forms_responses_and_private_media.sql`.
4. `20260813155121_forms_commands_and_projections.sql`.
5. `20260813155124_forms_jobs_notifications_and_exports.sql`.
6. `20260813155126_forms_security_performance_closure.sql`.
7. `20260813170001_forms_monitor_hierarchy.sql`.
8. `20260820152528_forms_editor_application_capability_guard.sql`.
9. `20260820154638_forms_distribution_cardinality_limits.sql`.
10. `20260825193120_final_review_forms_runtime_hardening.sql`.
11. `20260901194209_forms_distribution_target_authorization.sql`.
12. `20260901194256_forms_distribution_rpc_grants_hardening.sql`.

Esta é a lista de fontes necessárias à revisão do manifesto do Eng1, não ordem
para executar toda cauda. Dependências transitivas/extensões e definições
efetivas precisam ser fechadas no runner antes do pacote. Nenhum worker deve
ser despachado nem recurso remoto alcançado durante o replay.

Achado baseline comunicado: o helper de distribuição de 194209 referencia
`form_record.deleted_at`; a coluna não foi encontrada na fundação Forms nem
nas evoluções nominais inspecionadas. Não foi inventada coluna ou corrigido o
helper fora da reserva. Wrappers G receberam guard anterior, mantendo as
checagens originais. Controle de distribuição legado pode herdar 42703; isso
deve ser distinguido da barreira nova, não chamado de teste verde.

# Contrato implementado localmente

Autoria e atualização com FKs internas verdadeiras e XOR por campo; nenhuma
pessoa artificial. Recibo em tabela privada com ENABLE/FORCE RLS, sem grants
cliente, snapshot de definição sem autoria/sessão/secret e reautorização antes
de replay. Request, identidade, instituição, hash e versão devem coincidir.
Um replay após edição posterior devolve o recibo original, não a versão nova.

Reader privado/público `superadmin_forms_editor_v2(uuid)`: manage OU read
explícitos, sem inferir grants; save `superadmin_forms_save_draft_v2(uuid,bigint,jsonb)`
exige manage. Só rascunhos internos nunca publicados, sem dependências
operacionais e no escopo real. Critérios rechecados sob lock Forms.

Grafo usa tabelas existentes e novos validadores nominais. Validador de
publicação legado fica intacto; somente completude quick poll deixa de ser
exigida no novo rascunho. IDs do cliente são mapeados para IDs novos do grafo,
não concedem acesso a outra versão. Tipos, allowlists, posições contíguas,
opções de origem, ciclos/profundidade e limites permanecem server-side.

Limites técnicos adicionais explícitos da entrada nominal: 32 MiB de JSON,
identificadores locais de grafo até 128 caracteres, até 200 condições agrupadas
por item. Limites de produto existentes (20 seções/200 itens/50 opções,
profundidade quatro e constraints de texto/configuração) são preservados.

Dezenove corpos efetivos são republicados com guard/exclusão localizada antes
de projeção, receipt e efeito. Wrappers de distribuição também são protegidos
antes de seu lookup. Sem rename de função/OID, revoke global ou mudança de
require_forms_actor/MFA. Responder, participação, mídia e workers não mudam.

Audit success/denial ocorre fora da subtransação de negócio; falha de append
aborta escrita e receipt, sem envelope de negócio não auditado.

# Revisão e testes preparados

O teste foi criado antes da migration, mas execução RED/GREEN está reservada
ao Eng1. Contém incompletudes quick poll, invalid inputs/grafo, read-only e
manage-only, People-only, AAL1, A/B por ID, versão/replay original/divergente,
revogações, dois Owners sintéticos preservando last-owner, e auditoria.

Recibos legados de sucesso são semeados para provar guard ANTES do replay;
controles legados não protegidos provam que esse replay continua válido.
Inclui exclusão física seguida de replay. Dependência inesperada sintética
comprova que application não remove a proteção da população. RPCs somente como
authenticated; TAP depois de RESET ROLE; nenhum grant de pgTAP ao cliente.

Revisão encontrou explosão de caminhos por opções no validador copiado.
Correção somente nominal: arestas DISTINCT e estados (origem,destino,profundidade)
com UNION, limitados a 200×200×5. Testes de 50 opções/elo e DAG denso de quatro
e cinco níveis foram preparados com timeout; nenhum tempo SQL foi medido ainda.

Revisão estática dos 19 corpos aprovada; novas definições revisadas, P1 corrigido.
Review final dos testes aprovado estaticamente, sem novos bloqueadores.
Verificação textual: 29 funções na migration; 18 blocos authenticated no teste,
nenhum TAP dentro deles e role restabelecida ao terminar. O manifesto e replay
do executor permanecem gates abertos; esses números não são testes SQL passados.

Revisão final também separou os DOs de DAG denso, dando timeout próprio a cada
statement, e acrescentou vínculo individual de correlation_id de sucesso por
operação em capture table temporária. Triggers exclusivamente de teste fazem
essa associação, sem executar RPC ou TAP sob privilégio elevado; são removidos
ou revertidos ao final. Igualdade de totais não substitui a asserção individual.

Concorrência real entre duas conexões ainda precisa ser exercitada pelo runner
isolado do Eng1: mesmo request/payload deve devolver um único efeito; versões
iguais concorrentes devem produzir um sucesso e um conflito; recurso bloqueado
entre guard/receipt deve ser rechecado. Os testes pgTAP aqui comprovam contratos
sequenciais quando executados, não são uma prova já obtida de corrida entre
conexões. Não usar destino remoto para esse ensaio.

# Limite da entrega e memória

Cliente nominal ainda não conectado. Publicar, distribuir, responder, XLSX/R2,
locais, imagens e cuidado continuam abertos no escopo original. Evolução futura
de publicação deve tratar autoria/updater XOR e audience sem transformar autoria
interna em veto permanente. Este pacote draft-only não implementa essa evolução.

Gate de memória: implementação de regra já aprovada; nenhuma nova regra de
produto ou projeção de conhecimento criada para registrar atividade. Delta
destinado ao Coordenador, sem editar trackers ou ledger oficiais.
