---
title: "PLANS-READ01 — catálogo e vínculos, proposta de leitura interna"
source: "specs/051-superadmin-plans-production.md; specs/039-superadmin-internal-auth-session-context.md; ADRs 0019 e 0016; migration 20260901183154; SupabasePlanCatalogRepository; autorização de análise pela coordenação"
status: "proposta local; sem SQL executável, grants ou conexão"
generated_at: "2026-09-07"
---

# Objetivo e limites

Separar a leitura de Planos do realm People, preservando o catálogo manual e os vínculos de instituições somente leitura aprovados na spec 051. A spec 039 permite migração incremental por capability, começando por leitura. A capacidade continua `platform.read` e o alcance desta proposta é **somente membership interna `scope_kind=platform`**. Membership institucional não ganha acesso às contagens ou aos vínculos globais por possuir a mesma capacidade.

Fora: criar/editar/arquivar/restaurar, billing, alteração de assinatura, grants de produto, helper compartilhado, remoção do legado, SQL executável e implantação. Não substituir `superadmin_plan_get`, pois `superadmin_plan_save` o chama no replay e no retorno.

**Divergência documental e gate de aceite:** a seção de segurança da spec 051 exige explicitamente pessoa global ativa; a spec 039 e ADR0019 proíbem essa identidade como principal interno. A estratégia incremental de 039 fundamenta propor a transição, mas não torna a nova leitura conformidade já resolvida com o texto de 051. A coordenação deve registrar essa divergência no rastreador central/perguntas abertas e obter aceite nominal da transição antes de SQL. Não resolver por ponte People ou substituição silenciosa do helper legado.

## Inventário comprovado por leitura de arquivos

| Superfície atual | Fonte | Contrato e limite |
| --- | --- | --- |
| `superadmin_plans_list` | `20260901183154_superadmin_plans_production.sql:85` | Busca/status/feature/página; `items,total_items,page,page_size`; contagem de subscriptions active/draft; entitlements ativos. |
| `superadmin_plan_get` | mesma migration:161 | Detalhe, entitlements, contagem e linked_institutions de todos os status. `units_with_override` é constante zero, não contagem real. |
| `assert_plan_permission` | mesma migration:53 | Usa `current_person_id` e `has_platform_permission`; não autoriza o principal interno 039. |
| `superadmin_plan_save` | mesma migration:201 | Autor People, `plan.change`, AAL2; chama o get legado em dois caminhos. Permanece inalterado. |
| Reader institucional v2 de filtros | `20260827235500_superadmin_internal_institution_list_filter.sql` | Planos presentes nas instituições visíveis; não substitui catálogo global. |
| Reader de Unidade v2 | `20260828002000_superadmin_internal_unit_detail.sql` | Plano efetivo contextual; não substitui diretório de Planos. |
| Adapter Flutter | `apps/superadmin/lib/features/plans/data/supabase_plan_catalog_repository.dart` | Usa as três RPCs legadas, espera corpo sem envelope e exige todas as nove features e quatro limites. List/get ainda não são leitores internos. |

O aditivo MVP de 039/ADR0019 rege AAL do futuro reader interno. Isso não muda silenciosamente a política AAL2 do writer legado. A ADR0016 define herança e override, mas não transforma a constante zero do get em prova de contagem.

## Contrato proposto, não implementado

| RPC nominal proposta | Entradas preservadas | Dados permitidos |
| --- | --- | --- |
| `superadmin_plans_list_v2` | `p_search`, `p_status`, `p_feature`, `p_page`, `p_page_size` | `items,total_items,page,page_size,correlation_id` |
| `superadmin_plan_get_v2` | `p_plan_id uuid` | `item,correlation_id` |

Cada chamada revalida sessão/Auth/link/membership/capacidade através do helper 039 e exige scope platform antes de consultar o catálogo. IDs, metadados mutáveis e memberships People não autorizam. O envelope é `ok/data/error`, com data nulo nas negativas; códigos 039 preservados e códigos de input/not-found nominais a revisar, sem ampliar allowlists de helpers compartilhados por conveniência.

Projeção de plano: ID, nome, código, descrição, status, revisão, entitlements comerciais allowlisted e contagem aprovada. Sem `to_jsonb(row)`, autores People ou recibos completos. Ordenação nome + ID e paginação precedem a projeção; total não depende da página. Busca literal, limite de comprimento nominal, validação de paginação nula/negativa e overflow de offset devem integrar o contrato final. Os nove nomes de feature e quatro limites continuam fechados conforme spec 051; ausência/inconsistência de entitlement não deve ser convertida silenciosamente em dado comercial inventado.

Vínculos: allowlist ID/nome institucional/status da assinatura/início. A semântica de múltiplas assinaturas por instituição, status históricos e contagem distinta exige inventário de constraints e dados sintéticos da base. `units_with_override=0` não será promovido a contagem real; antes do DTO final, escolher entre cálculo comprovado conforme ADR0016 ou indisponibilidade explícita com adaptação do cliente. Não há escolha implementada nesta proposta.

Auditoria: ações nominais `plans.list`/`plans.get`, capability `platform.read`, ator interno, correlação comum ao envelope e contagens minimizadas. Append fora do catch de negócio; falha de append não devolve sucesso. Não incluir busca, catálogo completo, nomes institucionais ou payload comercial nos logs. Confirmar o helper de audit efetivamente disponível na base; a sobrecarga de 14 argumentos usada por A01 não pode ser presumida na base de Planos nem justificar importar toda a cadeia de Atividades.

## Matriz RED proposta, ainda não executável

1. Sessão interna válida, membership platform e allow ativo de `platform.read`: list/get autorizados em AAL1/AAL2 conforme MVP.
2. Conta People com permissão de plataforma: negada no reader novo; legado permanece independente. Sem pessoa sintética para o ator interno.
3. Membership interna institucional com a mesma capability: negativa sem itens, totais, entitlements ou nomes globais; parâmetro/claim adulterado não amplia escopo.
4. Sessão inexistente/revogada, auth link ou membership suspensa/revogada, role/capability inativos e deny: nenhuma leitura antecipada, envelopes/audit conforme estágio de autenticação.
5. Dois planos com mesmo nome: desempate por ID, paginação estável, página vazia com total preservado. Filtros combinados e caracteres `%`, `_`, `\` literais.
6. Inputs nulos/inválidos/oversized: falha nominal, sem overflow de offset ou busca sem limite. UUID textual inválido pode ser recusado no cast antes do wrapper; não exigir seu envelope nesse caso.
7. Plano inexistente: not-found sem payload; detalhe retornado deve corresponder ao ID solicitado. Entitlements desconhecidos e campos novos não escapam da allowlist.
8. Assinaturas em estados distintos e overrides reais: comprovar cardinalidade e política final do DTO antes de escrever asserts de contagem; zero placeholder não conta como GREEN.
9. Wrapper somente authenticated; tabelas/helpers sem leitura direta de cliente; conferir ACL efetiva inclusive PUBLIC, anon e service_role conforme contrato nominal.
10. Audit de sucesso/negação, correlação, contagens, nenhuma informação bruta e propagação de falha obrigatória. Preservar regressão do writer/get legado.
11. Adapter futuro interpreta envelope antes de dados, valida shape/ID/status e não chama writer People como fallback. Runtime autorizado, reload e revogação reais continuam gates posteriores.

## Gates anteriores à fixture/SQL

- Revisão nominal de shape, código de erro, contagens/vínculos/override e auditoria.
- Inventário efetivo de grants, tabelas/constraints, helper de audit e closure das migrations. Não declarar um número de arquivos reproduzível sem manifesto revisado.
- Definir se a fixture usará role/grant sintéticos restritos à transação com rollback, ou grants nominais já verificados. Não conceder permissões a papéis reais por analogia.
- Operador serial Eng1 e autorização nominal para qualquer replay; root não executa SQL/Docker. RED funcional deve preceder a corretiva.

Memória de conhecimento: no-op. Esta proposta não altera fonte canônica nem estabelece regra nova aprovada. Não há promoção local-green de SQL, remote-green ou E2E.
