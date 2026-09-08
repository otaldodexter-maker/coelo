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
  — Git blob `48ae0c2bf5793188741ec5ad2af4e31e25e763a0`.
- `packages/coelo_database/supabase/tests/superadmin_forms_directory_internal_read_test.sql`
  — Git blob `0f1ef585f67100fc7f253e1eba25a55719b1e3b0` (corrigido para a política AAL vigente).

Timestamp criado pela CLI Supabase 2.116.0 `migration new`, sem iniciar serviço.
Arquivo movido para o diretório canônico por patch. Não aplicar toda a cauda de
migrations para satisfazer dependências.

# Contrato e dependências

Nova função pública e privada `superadmin_forms_directory_v2(p_query jsonb)`;
não modifica `form_list`, `require_forms_actor`, People, autoria, comandos,
RLS existente, grants de tabelas ou helper compartilhado.

Preflight exige executor postgres, objetos Forms/ocorrências, contexto e guard
internos, capability ativa `forms.read`, ausência do endpoint nominal e prova
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
inválido/400; preservar o preflight e aguardar adição nominal separada pelo
Coordenador/Eng1. A expectativa AAL1 exige a política vigente efetiva na base.

Questão enviada ao Coordenador: confirmar o enquadramento de auditoria desta
leitura nominal frente à redação de comandos da spec 039. O endpoint preparado
é stable/read-only e ainda não registra audit; não declarar esse gate concluído.

Duas revisões read-only: SQL sem bloqueante estático; fixture corrigida para
preencher `suspended_at` conforme constraint. Root também conferiu a proteção do
último Owner e usou papel content no caso de revogação do AuthLink.

Solicitado ao Coordenador o encaixe de RED em base sem endpoint e GREEN com o
pacote nominal, somente após aprovação da cadeia local. Registrar saídas reais,
assertions, versões, identidade, rollback/cleanup e regressão antes de promover
estado. Revisão estática não é parser nem execução SQL.

Gate de memória: nenhuma nova decisão de produto; implementação de contrato
aprovado. Não criar projeção de conhecimento operacional para registrar atividade.

Continuam fora da prova deste pacote: mutações/editor, respostas, XLSX/R2,
imagens/locais, saúde/medicação, validação visual pendente e integração remota.
Esses itens permanecem no escopo original da vertical, não foram descartados.
