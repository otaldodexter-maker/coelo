---
title: "F-READ01 — pacote SQL nominal para replay local"
source: "Reserva do Coordenador; fundação Forms e contexto interno SAI canônicos; revisão estática E2E4"
status: "prepared-unexecuted"
generated_at: "2026-09-07"
---

# Estado e autoridade

Implementação SQL e pgTAP preparados, **não executados**. Não há RED/GREEN de
banco comprovado, aplicação remota, lease de produção ou declaração E2E.
Engenheiro 1 permanece o único executor do runner local/Docker. O Coordenador
controla fila, pacote nominal e ledger; este documento não os altera.

O cliente foi entregue separadamente em `17c92b5a961bd17bdf5c6a8939207b082133d053`
com 124 testes locais. Esses testes usam doubles, não este SQL.

# Arquivos nominais

- `packages/coelo_database/migrations/20260908000049_superadmin_forms_directory_internal_read.sql`
  — Git blob `a40bfb84a9e782a539d1a76d8e1c49a9ead00076` (wrapper auditado).
- `packages/coelo_database/supabase/tests/superadmin_forms_directory_internal_read_test.sql`
  — Git blob `abe0c8c2d835c9d9e577db965b33b301d0e79ad0` (AAL vigente, auditoria e separação RPC/TAP).

Timestamp criado pela CLI Supabase 2.116.0 `migration new`, sem iniciar serviço.
Arquivo movido para o diretório canônico por patch. Não aplicar toda a cauda de
migrations para satisfazer dependências.

# Contrato e dependências

Nova função pública e privada `superadmin_forms_directory_v2(p_query jsonb)`;
não modifica `form_list`, `require_forms_actor`, People, autoria, comandos,
RLS existente, grants de tabelas ou helper compartilhado.

Preflight exige executor postgres, objetos Forms/ocorrências, contexto e guard
internos, helpers de auditoria existentes, capability ativa `forms.read`, ausência do endpoint nominal e prova
semântica de `SAI_INVALID_ARGUMENT` com HTTP 400 no helper compartilhado.

Fontes canônicas consultadas:

- `20260827233000_superadmin_internal_auth_context.sql`: tipo, guard, lifecycle,
  proteção do último Owner, separação de realms e grants.
- ADR 0019 e spec 039, aditivos normativos de 2026-09-01, com
  `20260901200206_defer_superadmin_internal_mfa_until_mvp_go_live.sql`: AAL1/AAL2
  aceitos no realm interno durante validação do MVP, inclusive Owner. A regra
  histórica de MFA obrigatório não é expectativa válida desta entrega.
- `20260827235500_superadmin_internal_institution_list_filter.sql`: envelope
  ampliado com argumento inválido. O snapshot de Auth em
  `20260901190927_deploy_superadmin_internal_auth.sql` sozinho não o fornece.
- `20260828000500_superadmin_internal_institution_edit_core.sql`: precedente de
  preflight semântico do envelope.
- `20260813155005_forms_definition_and_capabilities.sql`,
  `20260813155116_forms_distribution_and_occurrences.sql` e
  `20260813155126_forms_security_performance_closure.sql`: schema, índices,
  capacidades e coerência de vínculos das fixtures.

O runner precisa comprovar a definição efetiva das dependências na base nominal.
Não criar uma ponte genérica, reordenar ledger ou substituir helper nesta fatia.

# Segurança e testes preparados

Guard interno antes de casts/filtros; escopo real imposto antes da paginação e
repetido nos vínculos de ocorrências. Busca literal limitada; allowlists, datas,
cursor completo e tamanho de payload validados. Keyset `(updated_at,id)`; cursor
nulo ao terminar. Oito campos permitidos por item, sem identidade de respondente
ou autor. Erros descartam dados e usam envelope sanitizado. Somente authenticated
executa a função pública; implementação privada não é concedida ao cliente.

pgTAP sintético e rollback-only: instituição A/B, Owner sem PersonAuthLink,
People-only negado, permissão negada/revogada entre páginas, sessão expirada ou
de outro usuário, AAL ausente negado, Owner AAL1/AAL2 com a mesma projeção autorizada,
membership suspensa/revogada e AuthLink
revogado com membership/grant ativos. Inclui filtros, busca literal, datas,
offset equivalente, empate de cursor, página final, inputs inválidos, grants e
minimização do envelope. Não desabilita triggers nem inventa links People.

# Revisão e próximo gate

Correção da revisão central: o teste inicialmente seguia a cláusula histórica
de Owner AAL2. Foi corrigido para o aditivo vigente, sem mudar o endpoint ou
inserir gate MFA. A base Auth45+Forms2 sozinha não contém o helper de argumento
inválido/400. O Coordenador confirmou base nominal 50 com o helper 235500;
preservar o preflight. A expectativa AAL1 exige a política vigente efetiva na base.

O Coordenador confirmou o enquadramento pela spec 039, linhas 252 e 289, sem
nova decisão de produto, e liberou somente o wrapper nominal do reader.
Ambas as funções agora são `volatile`. Guard e projeção ficam na subtransação;
após seu encerramento, sucesso e negativas identificadas usam os helpers de
audit existentes. Falha de append escapa da RPC, sem conversão em envelope de
negócio. Erros desconhecidos são normalizados antes de entrar no audit.
O evento `superadmin.forms.directory` usa `forms.read`, ator v2 completo ou
v3 `auth_session` conforme helper; não recebe busca, títulos, cursor ou respostas.
Escopo de sucesso vem do contexto interno, nunca do filtro cliente.

Os testes foram escritos antes do ajuste do wrapper, mas **não houve execução
RED/GREEN nesta frente**. Acrescentam contagem por sucesso, correlações de
negativas, v2 real, v3 sem link ou sem membership, minimização, ausência de sessão
crua, digest e falha injetada de audit nos caminhos sucesso/negativa v2/v3.
O trigger de teste é temporário ao ensaio transacional, removido ao terminar;
nenhum helper é substituído. O ensaio anterior sem essas assertions não comprova
auditoria. Eng1 continua responsável pelo perfil serial 50/51 e provas reais.

Limitação explicitamente comunicada ao Coordenador: o dispatcher existente usa
`jwt_aal NOT IN (...)` sem `IS NULL`; AAL ausente com sessão válida segue até a
constraint do audit, que rejeita com `23514`. O teste exige esse abort fail-closed,
não uma negativa de negócio sem evento. Não foi fabricado AAL nem alterado helper.
Essa limitação não é declarada corrigida por esta fatia.

Duas revisões read-only iniciais: SQL sem bloqueante estático; fixture corrigida para
preencher `suspended_at` conforme constraint. Root também conferiu a proteção do
último Owner e usou papel content no caso de revogação do AuthLink.
Revisão adicional do wrapper auditado aprovada estaticamente, incluindo a
limitação AAL ausente. `git diff --check` limpo; isso não executa SQL.

Correção da revisão central da fixture: pgTAP não é chamado sob `authenticated`.
Os quatro ensaios de exceção executam a RPC em blocos protegidos nesse papel,
capturam SQLSTATE/mensagem em tabela temporária ou sentinela `NO_EXCEPTION`,
e só emitem TAP após `RESET ROLE`. A fixture também confere o papel capturado.
Não foram concedidos privilégios de pgTAP nem executadas RPCs como postgres.
Varredura de todos os blocos `SET LOCAL ROLE` confirmou TAP fora desses blocos.

Solicitado ao Coordenador o encaixe de RED em base sem endpoint e GREEN com o
pacote nominal, somente após aprovação da cadeia local. Registrar saídas reais,
assertions, versões, identidade, rollback/cleanup e regressão antes de promover
estado. Revisão estática não é parser nem execução SQL.

Gate de memória: nenhuma nova decisão de produto; implementação de contrato
aprovado. Não criar projeção de conhecimento operacional para registrar atividade.

Continuam fora da prova deste pacote: mutações/editor, respostas, XLSX/R2,
imagens/locais, saúde/medicação, validação visual pendente e integração remota.
Esses itens permanecem no escopo original da vertical, não foram descartados.
