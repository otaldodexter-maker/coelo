---
title: "CHILD-SQLVECTOR01 — vetor nominal e RED de catálogo"
source: "CHILD-READ01 a9a5974; fontes SQL canônicas; perfil Auth do Eng1 em 3c644398; revisões Mencius e Nash; direção da coordenação de 2026-09-08"
status: "proposal-audit13-reuse-awaiting-implementation-reservation-not-executed"
generated_at: "2026-09-08"
---

# Contrato e pendências

E2E 2, Superadmin: preparar a leitura mínima de contextos infantis, sem alterar
spec046, criar grants de negócio, conectar UI ou executar SQL/Docker/remoto.
Ordem: proveniência, precondições, fixture RED, reserva final da dependência,
implementação futura e replay serializado pelo Eng1. Este pacote termina na
proposta nominal; não prova catálogo real, autorização em runtime ou E2E.
Estimativa desta preparação: 30–60 minutos; execução depende da coordenação.
Os três rastreadores/ledger continuam sob escrita exclusiva da coordenação.

Pendências concretas: gateway inexistente nas fontes deste checkout;
envelope Auth original não distingue argumento inválido;
implementação SQL, testes comportamentais e wiring ainda não entregues.

## Vetor de replay proposto, sem duplicar Base

Reutilizar o perfil **auth** existente do Eng1, não copiar migrations para outro
Base. Identidade lida em seu `replay/profiles/LocationCatalogV2/profile.json`:
manifesto `packages/coelo_database/replay/foundation-migrations.sha256`, SHA-256
UTF-8 normalizado CRLF
`4279e67c9651f4049329591b6e8aad82e3a9052506c1a4e16ba8bbb693249d59`;
45 canônicas + 2 preflights, boundary `20260901200206`.
Essa é identidade de arquivo, não prova de aplicação/ledger.

Seleção exata herdada: entradas do manifesto com versão <= `20260812001975`,
mais `20260827214000`, `20260827233000`, `20260901124500`, `20260901200206`.
Herdar sem alterações os preflights `20260811151253_assert_function_execute_preflight.sql`
e `20260811215452_access_profile_labels_replay_bridge.sql`, com posições e hashes
do perfil existente. Não incluir bootstrap de Locais.

Única adição canônica proposta para o primeiro RED de catálogo:

| Arquivo | SHA-256 CRLF UTF-8 | Motivo |
| --- | --- | --- |
| `20260827235500_superadmin_internal_institution_list_filter.sql` | `c4496229e2d004907b1c878e9719cadfa60169307eeb92be67cd76c3ad5551aa` | Envelope039 com SAI_INVALID_ARGUMENT; dependência já nominal em LOC/FRead |

União ordenada por versão: adição na posição canônica44, entre Auth039 e
denial/AAL; total planejado 46 canônicas + 2 preflights = 48, sem gateway.
Não usar `AdditionalMigration` para forçar arquivo anterior ao boundary: o Eng1
deve reservar um perfil nominal que reutilize a seleção Auth existente.
Não editar o harness compartilhado por este pacote.

**RED esperado nesse vetor:** gateway ausente. As demais assertions
são expectativas a medir, não resultados já obtidos. O teste não instala esses
objetos e não converte ausência em verde.

## Fontes físicas e precondições mínimas

Todos os arquivos seguintes ficam em `packages/coelo_database/migrations/`.

| Fonte já herdada de Auth | Contrato físico utilizado |
| --- | --- |
| `20260623191021_superadmin_foundation_v1.sql:81/231` | `people(id uuid, person_type public.person_type, display_name text, deleted_at timestamptz)`; `institutions(id uuid, public_name text, deleted_at timestamptz)` |
| `20260720180000_people_context_foundation.sql:155` | `child_contexts(id uuid, child_person_id uuid, institution_id uuid, status public.record_status)`; FKs para pessoa/instituição e unique pessoa/instituição |
| `20260729141839_superadmin_people_directory.sql:14–55` | Capability people.read e grant histórico Owner; verificar catálogo efetivo, não reprovisionar |
| `20260827233000_superadmin_internal_auth_context.sql` | Tipo de contexto interno, helper039, auditoria13, envelope inicial |
| `20260901124500_harden_superadmin_auth_context_denial_audit.sql` | Negativa com instituição segura |
| `20260901200206_defer_superadmin_internal_mfa_until_mvp_go_live.sql` | Política atual aceita AAL1/AAL2; não restaurar exigência AAL2 histórica |

Conferir owner postgres, assinatura, retorno, volatilidade, SECURITY DEFINER
quando aplicável, search_path vazio e ACL privada dos helpers:

```text
app_private.require_superadmin_internal_context(text)
app_private.superadmin_internal_error_envelope(text,uuid)
app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)
app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)
```

Catálogo de negócio: exatamente uma people.read ativa, módulo people/tela
directory/ação read, risco high; grants allow ativos/não revogados ligados a
roles ativos resultam exatamente em owner. `requires_mfa=true` é metadado
histórico, não condição para exigir AAL2: pin do helper atual governa a política.
Inspecionar o valor e registrar drift; não modificá-lo nem inferir a política
runtime só dele. Ator Owner deve também ser conferido na chamada, não apenas
pela matriz no preflight. Scope somente platform/institution.

### Escolha mínima: reutilizar audit13 vigente, sem dependência nova

A comparação dos corpos e consumidores mostra que CHILD não precisa audit14.
`20260827233000_superadmin_internal_auth_context.sql:613–649` fornece audit13:
recebe identidade/link/membership/sessão, capability/AAL/ação/outcome/reason,
correlação, instituição opcional, object_type/object_id opcionais; retorna uuid.
Valida coerência do ator, grava hash de sessão e atribuição interna em audit_logs,
resultado/correlação/escopo e occurred_at. Não recebe nem grava payload de nomes.
É volatile, SECURITY DEFINER, search_path vazio, ACL privada. Fonte SHA-256 CRLF
`87d03cd1e75d9859438c82abbf3c59424680bdd64b57741f10740a5ac7007a33`.

O reader046 (`20260828005000_superadmin_internal_person_detail.sql:448–462`)
usa exatamente audit13 para sucesso com people.read/person.detail. O diretório
LOC (`20260908031000_superadmin_location_catalog_v2.sql:398–400`) também usa
audit13 com correlação/instituição/objeto de catálogo. Ambos usam o helper de
negativa com instituição NULL nas falhas. Isso atende ao contrato mínimo CHILD,
que não exige after_json. Não importar nenhum desses readers como dependência.

Chamada futura: audit13 com people.read/child_context.directory/success,
reason NULL, correlação da operação, instituição efetivamente autorizada ou
NULL no catálogo platform geral, object_type child_context_catalog e object_id
NULL (não fabricar criança representativa da página). Auditar antes de retornar;
falha de auditoria propaga falha segura. Sem cursor/nome/itens em audit.

Negativa: helper vigente de `20260901124500` com instituição NULL, mesma ação e
correlação. Seu corpo retorna sem gravar quando sessão não é válida; usa
audit_append_auth_session_denial(uuid,text,text,text,text,uuid) quando há sessão
mas não identidade/membership interna; nos demais casos usa audit13. Seu guard
de instituição verifica existência, **não autorização de tenant**: por isso o
wrapper CHILD não deve passar filtro não confiável. Não alterar helper comum.

Audit14 foi considerado inicialmente, mas descartado após orientação da
coordenação e comparação de corpos: não é requisito transversal da Etapa2.
As notas de proveniência abaixo explicam por que não importar sua superfície.

A fonte exata é `20260831211945_activities_v2_internal_gateways.sql:49–63`,
SHA-256 CRLF `443be75040ca103a7a6723aa90037359c11c1681afdc6a6361c2d81f667a6dfa`.
Owner/revokes aparecem no bloco final, linhas737/751. Retorna uuid, volatile,
SECURITY DEFINER, search_path vazio, sem EXECUTE para clientes/service_role.
O corpo usa links/memberships internos, `audit.audit_logs`, `extensions.digest`
e geração de UUID, já fornecidos pela fundação/Auth, mas cuja compatibilidade
física não é necessária a CHILD quando audit13 atende ao contrato sem payload.

Não importar esse arquivo inteiro por conveniência: ele instala gateways e
altera helpers/trigger de Atividades. O perfil A01DirectoryAuditRed do Eng1
inclui sete migrations E5 (actor attribution, provenance hardening/semantics,
permissions receipts, internal gateways, RLS grants e final review), mais seu
próprio alvo; isso não é dependência mínima aprovada de CHILD.

Proposta para reserva final: **Auth + envelope, sem audit14, sem derivação nova**.
Ausência de audit14 não é falha de CHILD e não participa do gate obrigatório.
Nenhuma bridge/derivação foi criada aqui.
Também não somar `20260901190927_deploy_superadmin_internal_auth.sql` ao Auth
histórico: é outra rota de implantação, não uma adição intercambiável.

## Assinatura, projeção e segurança

`public.superadmin_child_context_directory_v2(uuid,text,uuid,integer) returns jsonb`:
nomes `p_institution_id,p_after_name,p_after_context_id,p_limit`, defaults
NULL/NULL/NULL/20; limite1–50; cursor pareado. Contrato DTO canônico desta fatia:
`docs/superpowers/specs/2026-09-08-child-directory-read-contract.md` e
`packages/coelo_api/lib/src/children/child_directory_dto.dart`.

Usar `person_type`, não coluna imaginada `type`; `public_name`, não `name`.
Somente contexto active, pessoa child sem deleted_at, instituição sem deleted_at.
Instituição vem do contexto e é restringida por escopo antes de ordenar/limitar.
Sem join obrigatório de unidade/grupo. Não adicionar pessoa.status como novo
critério de negócio silenciosamente. Uma pessoa pode aparecer em dois contextos.

Item tem exatamente context_id/person_id/person_name/institution_id/institution_name.
Envelope039; data items/next_cursor, sem total. Keyset
`lower(display_name) COLLATE "C", context_id`, estritamente maior, limit+1;
cursor do último retornado, calculado no servidor, orçamento8192 bytes conforme
contrato candidato. IDs/cursor não concedem escopo nem permitem enumeração.
Não projetar matrícula, vínculos, responsáveis, Auth, datas, assiduidade ou PII
adicional. Auditar child_context.directory/people.read sem nomes/cursor/payload;
falha de auditoria não libera dados, negativa não confia no filtro alheio.

## Fixture RED e verificações futuras

Fixture nominal separada do autodiscovery:
`packages/coelo_database/replay/fixtures/child_directory_catalog_red.sql`.
Pré-requisito operacional: perfil local isolado com pgTAP já instalado em
extensions pelo Eng1; rodar como postgres, nunca authenticated. A fixture não
instala extensão, não cria usuário/dado/helper, não chama gateway ou auditoria.
Define search_path local extensions/pg_catalog para os helpers internos do pgTAP;
isso é apenas configuração da sessão de teste, não do gateway futuro.
Consulta somente catálogo e matriz de capability/roles, sem ler linhas infantis.

14 assertions de catálogo; `to_regprocedure` e coalesce impedem aborto por
gateway ausente e sucesso vazio. Há gates positivos para audit13/gateway;
nenhum `hasnt_function` disfarça a falta de implementação. Metadados adicionais
de preflight (FKs, tipos compostos, fingerprints exatos, defaults, funções e ACLs
herdadas) ainda precisam integrar o pacote de implementação, não são cobertos
integralmente por esta fixture inicial.

Após reserva/implementação: TAP comportamental cross-tenant, sessão inválida,
Owner/non-Owner, revogação, escopo restritivo, keyset/empates/Unicode, criança
sem unidade, exclusões/tipo/contexto inativo, limites/cursor forjado, audit failure,
concorrência e ACL. Depois transporte real e UI autorizada. Catálogo verde sozinho
não fecha CHILD nem E2E 2.

Revisões independentes: Mencius validou hierarquia/PII e fontes físicas; Nash
validou a matriz TAP/ausência segura e os arquivos finais, sem P1/P2 identificado.
Verificação estática: 14 assertions, sem DDL/DML/grants e sem cast abortivo de
regprocedure. Os dois gates de memória passaram. Nenhum SQL foi executado.
Gate de memória:
sem novo conhecimento aprovado de produto; não gerar projeção por atividade.
