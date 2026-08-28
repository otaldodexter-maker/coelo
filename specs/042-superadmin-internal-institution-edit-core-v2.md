---
title: "Edição cadastral core v2 de Instituições pelo Superadmin interno"
source: "specs/010-superadmin-completo-v1-technical-spec.md; specs/011-superadmin-database-rls.md; specs/039-superadmin-internal-auth-session-context.md; specs/040-superadmin-internal-institution-read-v2.md; packages/coelo_database/migrations/20260811125345_institution_management_commands.sql"
status: "approved-for-implementation"
approval: "Coordenação Coelo em 2026-08-27; continuidade explícita do lote EDIT CORE v2, sem CREATE/activation, plan, branding ou representantes/admin"
generated_at: "2026-08-27"
---

# Edição cadastral core v2 de Instituições pelo Superadmin interno

## Objetivo

Permitir que a tela de edição de Instituições persista e recarregue somente o
cadastro principal e endereço por meio da identidade interna exclusiva
da spec 039. O contrato substituto é aditivo e não usa `people`,
`person_auth_links`, `platform_memberships` ou recibos person-bound como
autoridade.

## Escopo

- edição parcial de uma instituição existente;
- campos cadastrais raiz e endereço já presentes no agregado físico;
- idempotência por `request_id`, concorrência otimista por
  `expected_version`, auditoria tipada e reload pelo detalhe v2;
- autorização, tenant/escopo, sessão, link, membership, capability e MFA
  revalidados no backend em cada chamada;
- erros estáveis no envelope semântico da spec 039.

## Fora de escopo

- criação ou ativação de instituição;
- alteração de status, plano/assinatura, branding, mídia ou arquivos;
- `slug`, porque sua alteração dispara a cascata física de activity handles e
  exige contrato e regressão próprios;
- `primary_domain`, até existir contrato aprovado de hostname, normalização e
  conflito;
- `document_ref` e `document_type`, cuja estratégia permanece pendente nas
  specs 010/011;
- `contact` e `institution_contacts` nesta primeira fatia, porque
  `public.save_profile_about` escreve a mesma linha sem bloquear nem incrementar
  `institutions.management_version`, permitindo bypass de versão e lost update;
- o follow-up de contato exige um protocolo comum e versionado entre os writers;
  esta spec não cria trigger, não usa `xmin` e não reescreve Profile About;
- responsáveis legais, administradores, owner institucional, convite ou Auth;
- `primary_contact_person_id`, `created_by` ou qualquer autoria baseada em
  pessoa;
- alteração Flutter, revogação do writer legado ou deploy remoto;
- importação e exportação.

## Interface pública

```sql
public.superadmin_institution_edit_core_v2(
  p_request_id uuid,
  p_institution_id uuid,
  p_expected_version bigint,
  p_payload jsonb
) returns jsonb
```

A função é `VOLATILE SECURITY DEFINER`, `search_path=''`, owner `postgres` e
tem `EXECUTE` somente para `authenticated`. `PUBLIC`, `anon` e `service_role`
não executam. Helpers e recibos privados não possuem grants de cliente.

Sucesso retorna somente um ack estável e sem PII:

```json
{
  "ok": true,
  "data": {
    "institution_id": "uuid",
    "management_version": 2,
    "correlation_id": "uuid",
    "replayed": false
  },
  "error": null
}
```

O cliente recarrega o agregado com
`superadmin_institution_detail_v2(p_institution_id)`. O writer não devolve o
snapshot completo.

## Payload permitido

`p_payload` deve ser um objeto JSON não vazio cujo texto canônico em UTF-8 tenha
no máximo 65.536 bytes. `address`, quando presente, também deve ser objeto JSON.
Chaves ausentes mantêm o valor atual. Chaves extras,
estruturas inválidas ou um payload que não altere nenhum campo falham fechados.

Os tipos JSON são exatos. Campos classificados como texto obrigatório aceitam
somente JSON string não vazia após `btrim`. Campos classificados como texto
opcional aceitam somente JSON string ou JSON null; string vazia após `btrim` é
normalizada para null. Number, boolean, array ou object em qualquer campo
escalar são rejeitados. Toda string que contenha caractere de controle C0
U+0000–U+001F ou U+007F é rejeitada. Todos os limites textuais abaixo são
medidos em bytes UTF-8 com `octet_length`, depois da normalização.

Campos raiz permitidos:

- `public_name`: texto obrigatório, até 240 bytes;
- `trade_name`, `legal_name`: texto opcional, até 240 bytes;
- `timezone`: texto obrigatório, até 64 bytes, e deve corresponder a um
  `name` existente em `pg_catalog.pg_timezone_names`;
- `locale`: texto obrigatório, até 35 bytes, com shape BCP-47 básica
  `^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$`;
- `institution_type_id`: JSON string com UUID válido de um tipo de instituição
  existente e ativo;
- `address`: objeto parcial com somente `country`, `state`, `city`, `district`,
  `street`, `number`, `complement`, `postal_code`.

Este slice é brasileiro porque a tela vigente mantém país desabilitado como
Brasil e o formulário aprovado exige CEP nacional. No endereço, `country`,
quando enviado, deve ser exatamente a JSON string `Brasil`; quando omitido,
preserva o endereço existente. `state`, `city`, `district`, `street` e
`complement` são textos opcionais de até 240 bytes; `number` é texto opcional de
até 64 bytes. `postal_code`, quando não nulo, deve conter exatamente oito
dígitos conforme `^[0-9]{8}$`. Se ainda não existir linha em
`institution_addresses`, qualquer patch de `address` deve trazer
`country="Brasil"`; o backend não inventa `BR`, `Brasil` nem outro default.

`contact`, `slug`, `primary_domain`, `document_ref`, `document_type`, `status`,
`subscription`, `branding`, representantes, administradores e qualquer outra
chave são rejeitados. Todas as strings aceitas são aparadas. O payload
normalizado é JSONB com chaves canônicas. Conflitos de unicidade ou shape
retornam validação segura sem revelar qual tenant ou registro conflitou.

## Autorização e isolamento

O wrapper chama
`app_private.require_superadmin_internal_context('institution.update')` antes
de validar IDs ou payloads. Somente `owner` e `operations` são permitidos. A
capability física exige MFA; Owner permanece sempre AAL2 pela spec 039.

Membership `platform` pode editar uma instituição existente. Membership
`institution` somente pode editar a sua própria FK. ID inexistente,
cross-tenant ou adulterado produz o mesmo `SAI_PERMISSION_DENIED`, sem oracle
de existência. Conta Auth de Admin/Principal, Support, Content e Auditor,
sessão ausente/expirada/divergente, link ou membership suspenso/revogado e
grant/role inativos são negados no backend.

## Idempotência e concorrência

Um recibo privado novo e tipado armazena somente:

- `request_id` como PK;
- `actor_internal_identity_id`;
- `institution_id`;
- hash SHA-256 do comando canônico;
- versão resultante;
- correlação original e instante de criação.

Fisicamente, a tabela de receipts usa `ENABLE ROW LEVEL SECURITY` e
`FORCE ROW LEVEL SECURITY`, não possui policies e revoga todos os grants de
`PUBLIC`, `anon`, `authenticated` e `service_role`. Seus campos obrigatórios são
`NOT NULL`; ator e instituição usam FKs sem cascade; o hash exige exatamente 32
bytes; e versões esperada/resultante devem ser positivas, com a resultante igual
à esperada mais um.

O recibo não referencia pessoa, auth link ou membership e não guarda payload,
documento ou endereço. O hash é dado derivado/pseudônimo, permanece em
`app_private` e não possui reader, export, policy permissiva ou grant para
`PUBLIC`, `anon`, `authenticated` ou `service_role`.

Antes de consultar qualquer receipt, inclusive em replay, a chamada revalida o
contexto atual completo, a allowlist de papel, capability, MFA e o escopo atual
sobre `p_institution_id`. Somente depois dessa reautorização, `request_id`
repetido pela mesma identidade e mesmo hash canônico retorna os mesmos
`institution_id` e versão do ack original, com a correlação da nova chamada e
`replayed=true`, mesmo que a instituição tenha avançado desde então. Reuso com
outra identidade ou hash retorna `SAI_INVALID_ARGUMENT`.

Depois de revalidar papel, capability, MFA e escopo atuais, um replay histórico
idêntico pode devolver o ack mesmo que o alvo tenha sido soft-deleted após a
mutação original. O replay não lê snapshot, não confirma existência ou estado
atual e não exige lookup do alvo antes do receipt; o reload por detail v2
continua fail-closed. Essa exceção preserva somente a idempotência estável do
ack e nunca autoriza nova mutação.

O hash do comando é exatamente SHA-256 sobre os bytes UTF-8 do texto canônico
do JSONB abaixo. `request_id` fica fora do manifesto e
`actor_internal_identity_id` é comparado separadamente pelo receipt:

```json
{
  "command_kind": "institution.edit_core",
  "institution_id": "uuid",
  "expected_version": 1,
  "payload": {}
}
```

O `payload` do manifesto é o payload normalizado: strings aparadas, opcionais
vazias convertidas em null e chaves na ordem canônica de JSONB. A implementação
usa `convert_to(manifest::text, 'UTF8')` e SHA-256 sem concatenar texto livre.

Receipts não possuem cleanup, retenção, purge ou índice temporal nesta versão.
A retenção jurídica permanece decisão aberta. Qualquer política de expiração e
o índice que a suporte dependem de decisão canônica posterior; até lá, nenhum
job remove recibos e nenhuma rotina de purge é criada.

O comando adquire advisory transaction lock por `request_id`, depois bloqueia
a instituição com `FOR UPDATE`. `expected_version` deve ser positivo e igual a
`management_version`; divergência retorna `SAI_CONCURRENT_CHANGE`. A atualização
de raiz, endereço, incremento de versão, recibo e audit de sucesso é atômica.

## Erros

- `SAI_AUTH_REQUIRED`: ausência de autenticação/sessão válida;
- `SAI_SESSION_INVALID`: sessão divergente ou expirada;
- `SAI_INTERNAL_CONTEXT_DENIED`, `SAI_MEMBERSHIP_SUSPENDED` ou
  `SAI_MEMBERSHIP_REVOKED`: lifecycle interno inválido;
- `SAI_PERMISSION_DENIED`: role/capability/escopo, ID inexistente ou adulterado;
- `SAI_MFA_REQUIRED`: AAL insuficiente;
- `SAI_INVALID_ARGUMENT`: request, versão ou payload inválidos e request reuse;
- `SAI_CONCURRENT_CHANGE`: versão obsoleta;
- `SAI_INTERNAL_ERROR`: falha não allowlisted.

Os status no envelope são semânticos; o PostgREST continua respondendo HTTP
200. Nenhum SQLSTATE, constraint, ID de outro tenant ou payload é exposto.

## Auditoria

- permission: `institution.update`;
- mutation action: `institution.edit_core`;
- replay action: `institution.edit_core.replay`;
- toda chamada aceita gera exatamente um evento próprio com ator completo em
  audit v2 e a correlação daquela chamada;
- replay não cria outro receipt e não grava payload no receipt ou no audit;
- negativa após sessão válida usa audit v2 ou v3;
- ausência de sessão validada não fabrica audit;
- falha do append aborta a RPC;
- audit contém somente ator tipado, ação, resultado/reason e instituição já
  autorizada; não contém valores alterados, documento, endereço,
  request hash ou session hash legível.

## Persistência e reload

Após sucesso, uma chamada de detalhe v2 deve observar a nova
`management_version` e os valores normalizados. Replay idempotente não altera
timestamps, versão ou linhas filhas. Falha de validação, autorização,
concorrência ou audit não persiste nenhuma mudança nem recibo.

## Compatibilidade e cutover

O writer legado `update_institution_for_superadmin` permanece inalterado até o
cutover Flutter e regressão cross-app/cross-tenant. O Flutter futuro deve enviar
somente o subset desta spec; status, plano, branding, representantes e admins
seguem fail-closed ou em contratos próprios. Revogar o legado exige migration
forward-only posterior.

## Critérios de aceite

- Owner e Operations AAL2 editam e recarregam dados permitidos;
- Auditor, Support, Content, Owner AAL1 e contas de outro realm são negados;
- cross-tenant, ID inexistente/adulterado e membership/link revogados são
  indistinguíveis e não persistem;
- payload/keys/tipos/limites inválidos e status/plan/branding são rejeitados;
- `slug`, `primary_domain`, `document_ref` e `document_type` são rejeitados
  como fora de escopo;
- tipos JSON escalares, controles, limites por campo, timezone existente,
  locale BCP-47 básica e UUID ativo de `institution_type_id` são provados;
- o slice brasileiro exige `country="Brasil"` quando enviado, preserva o país
  existente quando omitido e exige país explícito Brasil ao criar endereço;
- CEP não nulo tem exatamente oito dígitos;
- duas requests na mesma versão resultam em um sucesso e um conflito;
- request repetida igual retorna o resultado original sem segunda mutação nem
  novo receipt e registra `institution.edit_core.replay` em evento próprio;
- request repetida diferente é negada;
- o manifesto/hash é reproduzível byte a byte, exclui `request_id` e compara a
  identidade interna separadamente;
- replay revalida papel, capability, MFA e escopo atual antes de ler o receipt;
- o hash permanece privado e não existe reader, export, grant, cleanup, índice
  temporal ou purge enquanto a retenção jurídica estiver aberta;
- o receipt prova RLS habilitada e forçada, zero policies/grants, campos
  obrigatórios, FKs sem cascade, hash de 32 bytes e invariantes de versão;
- audit success/denial é correlacionado, minimizado e fail-closed;
- wrapper, helpers, recibo, owner, `search_path`, RLS e grants são testados;
- fixtures usam dados sintéticos e rollback/teardown deixa zero resíduos;
- sem deploy/E2E, o estado máximo é `local-green`, nunca `done`.
