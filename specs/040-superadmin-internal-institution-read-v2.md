---
title: "Leitura v2 de Instituições para o Superadmin interno"
source: "specs/039-superadmin-internal-auth-session-context.md; specs/011-superadmin-database-rls.md; apps/superadmin/lib/features/institutions/data/supabase_institution_directory_repository.dart; apps/superadmin/lib/features/institutions/domain/institution_directory_query.dart"
status: "approved-for-implementation"
approval: "Coordenação Coelo em 2026-08-27; derivada estritamente das specs 011 e 039"
generated_at: "2026-08-27"
---

# Leitura v2 de Instituições para o Superadmin interno

## Objetivo

Migrar somente listar, filtrar, detalhar e recarregar Instituições para a
identidade interna exclusiva definida na spec 039. O pacote é aditivo: não usa
`people`, `person_auth_links`, `platform_memberships` ou overrides legados
como autoridade e não remove os contratos atuais antes do cutover Flutter.

## Escopo

- listagem paginada e filtrada;
- opções dependentes de filtro;
- detalhe e reload pelo mesmo contrato;
- `auth.uid()`, `session_id`, `auth.sessions.not_after`, link, membership,
  role, capability, MFA e escopo revalidados em cada chamada;
- envelope estável, auditoria v2/v3, ACL mínima e isolamento institucional;
- saída equivalente aos campos que o repositório Flutter atual já consome.

## Fora de escopo

- criar, editar, status, plano, branding mutável, representantes e admins;
- arquivos, importação, exportação e mídia;
- alteração Flutter nesta etapa;
- revogar views, tabelas ou RPCs legadas antes do cutover integrado;
- ampliação da matriz de papéis. Somente `owner`, `operations` e `auditor`
  podem usar a leitura v2. `support` permanece fail-closed sem sessão de
  suporte física compatível, e `content` permanece fail-closed para
  Instituições mesmo que o catálogo compartilhado contenha `platform.read`.

## Interfaces públicas

Todas retornam o envelope da spec 039, são `VOLATILE SECURITY DEFINER`,
`search_path=''`, owner `postgres`, com `EXECUTE` somente para
`authenticated`.

### Diretório

```sql
public.superadmin_institution_directory_v2(
  p_filters jsonb default '{}'::jsonb,
  p_limit integer default 20,
  p_offset integer default 0,
  p_sort text default 'public_name',
  p_sort_ascending boolean default true
) returns jsonb
```

`data` contém:

```json
{
  "items": [],
  "total_count": 0,
  "limit": 20,
  "offset": 0
}
```

Cada item preserva somente os campos atuais da view
`public.institution_directory`: IDs e nomes da instituição, domínio, status,
tipo, endereço, plano, contadores de unidades/grupos e contatos institucionais.
Não inclui documento, pessoa, sessão, membership ou payload de auditoria.

`p_filters` aceita apenas:

- `search`: texto aparado, até 120 caracteres;
- `statuses`: array textual, no máximo 8 itens, valores do enum físico atual;
- `plan_id`: UUID ou nulo;
- `states`, `cities`, `districts`: arrays textuais, até 20 itens cada;
- `type_ids`: array de UUIDs, até 20 itens.

Chave extra, tipo inválido, item vazio ou cardinalidade excessiva retorna
`SAI_PERMISSION_DENIED` sem executar a consulta. `p_limit` fica entre 1 e
100; `p_offset` é não negativo. A ordenação aceita somente:
`public_name`, `type_name`, `units_count`, `groups_count`, `plan_name`,
`status`, `contact_email`, `contact_phone`, `contact_mobile_phone`,
`primary_domain`, `street`, `postal_code`, `number`, `complement`,
`district`, `city` e `state`. O desempate final é sempre `id`.

### Opções de filtro

```sql
public.superadmin_institution_filter_options_v2(
  p_states text[] default '{}'::text[],
  p_cities text[] default '{}'::text[]
) returns jsonb
```

`data` contém listas minimizadas de `plans`, `types`, `states`,
`cities` e `districts`. Estados limitam cidades; cidades limitam bairros.
Cada array de entrada aceita no máximo 20 valores não vazios. Somente opções
visíveis dentro do escopo institucional efetivo são retornadas. Catálogos
globais não ampliam o conjunto de Instituições.

### Detalhe e reload

```sql
public.superadmin_institution_detail_v2(
  p_institution_id uuid
) returns jsonb
```

`data` reutiliza o payload sanitizado já produzido por
`app_private.institution_management_payload(uuid)`. Reload é uma nova chamada
com o mesmo ID; nenhuma seleção institucional ou cache é persistido.

ID inexistente, adulterado ou fora do escopo retorna o mesmo
`SAI_PERMISSION_DENIED`, sem confirmar existência. Membership `platform` de
`owner`, `operations` ou `auditor` pode ler qualquer instituição existente
autorizada por `platform.read`; membership `institution` desses mesmos papéis
só lê sua FK.

## Autorização e transporte

Cada wrapper chama `app_private.require_superadmin_internal_context(
'platform.read')` dentro da própria chamada. Owner sempre exige AAL2; os demais
papéis seguem `platform_permissions.requires_mfa`. Qualquer papel fora de
`owner`, `operations` e `auditor` é negado nesta versão. Claims, filtros e
IDs são dados não confiáveis.

Falhas de negócio revertem a subtransação, gravam exatamente um evento negativo
na transação externa quando a sessão foi validada e retornam HTTP 200 do
PostgREST com `ok=false`. Falha do append aborta a RPC. Sessão ausente,
inválida ou expirada não fabrica audit.

## Auditoria

- lista: `action_code='institution.list'`;
- opções: `action_code='institution.filter_options'`;
- detalhe/reload: `action_code='institution.detail'`;
- capability: `platform.read`;
- sucesso com ator completo usa v2, resultado `success`;
- negativa sem ator completo após sessão válida usa v3;
- negativa com ator completo usa v2;
- filtros completos, termos de busca, contatos, documento e hash de sessão não
  entram no audit;
- eventos de lista/opções usam contexto global para membership `platform` e a
  FK autorizada para membership `institution`; detalhe usa a instituição
  somente após validar escopo.

## Compatibilidade e cutover

Os contratos legados `institution_directory`,
`institution_directory_locations`, `get_institution_for_superadmin`,
`plans` e `institution_types` permanecem inalterados nesta migration. O
Flutter futuro migra para as três RPCs v2 e interpreta `ok/error.code`.
Revogação do caminho legado exige regressão Flutter + Supabase, cross-app e
cross-tenant e será uma migration forward-only separada.

## Critérios de aceite

- conta Admin/Principal autenticada não recebe linhas;
- internal platform ativo lista/detalha A e B; internal institution só A;
- troca de ID, filtro, role, grant, sessão, link ou membership não amplia escopo;
- sessão ausente/divergente/expirada, link e membership suspensos/revogados,
  Support, Content e Owner AAL1 retornam envelope estável;
- ACL nega `PUBLIC`, `anon` e `service_role`; helpers privados não têm
  grants de cliente;
- listagem limita cardinalidade e ordenação no servidor;
- detalhe/reload retornam o mesmo dado persistido;
- auditoria correlacionada v2/v3 é verificável e não expõe PII/hash;
- fixtures são transacionais e o replay isolado termina sem resíduos;
- estado máximo sem deploy e E2E é `local-green`.
