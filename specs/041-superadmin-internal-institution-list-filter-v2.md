---
title: "Listagem e filtros v2 de Instituições para o Superadmin interno"
source: "specs/011-superadmin-database-rls.md; specs/039-superadmin-internal-auth-session-context.md; specs/040-superadmin-internal-institution-read-v2.md; autorização técnica da Coordenação Coelo em 2026-08-27"
status: "approved-for-implementation"
generated_at: "2026-08-27"
---

# Listagem e filtros v2 de Instituições para o Superadmin interno

## Objetivo

Fechar somente listagem paginada e opções de filtro de Instituições sobre a
identidade interna exclusiva. O contrato é aditivo, não altera Flutter, não
mistura autoridade legada e não revoga views, tabelas ou RPCs existentes.

## Supersessão limitada da spec 040

Esta spec substitui somente as seções `Diretório` e `Opções de filtro` da spec
040. Permanecem inalterados o detalhe/reload, a autorização, a auditoria e a
compatibilidade aprovados naquela spec. O refinamento técnico fixa: default 50,
busca até 200 caracteres, seis status físicos, offset máximo 10.000,
`SAI_INVALID_ARGUMENT` e rejeição de `NULL` explícito nos parâmetros públicos.

## Interfaces

```sql
public.superadmin_institution_directory_v2(
  p_filters jsonb default '{}'::jsonb,
  p_limit integer default 50,
  p_offset integer default 0,
  p_sort text default 'public_name',
  p_sort_ascending boolean default true
) returns jsonb

public.superadmin_institution_filter_options_v2(
  p_states text[] default '{}'::text[],
  p_cities text[] default '{}'::text[]
) returns jsonb
```

Os wrappers são `VOLATILE SECURITY DEFINER`, owner `postgres`, com
`search_path=''` e `EXECUTE` somente para `authenticated`. Implementações e
helpers privados não recebem grants de cliente nem de `service_role`.

## Autorização

Cada chamada resolve `app_private.require_superadmin_internal_context(
'platform.read')` antes de validar filtros. Somente `owner`, `operations` e
`auditor` são aceitos. Owner exige AAL2. `support`, `content` e qualquer papel
fora da allowlist permanecem fail-closed.

Membership `platform` vê todas as Instituições existentes. Membership
`institution` vê somente `scope_institution_id`. IDs, filtros, sort, limit e
offset enviados pelo cliente nunca são autoridade.

## Envelope da listagem

Sucesso usa chaves raiz exatas `ok`, `data`, `error`. `data` contém:

```json
{
  "items": [],
  "total_count": 0,
  "limit": 50,
  "offset": 0
}
```

Cada item contém somente estas chaves:

- `id`, `public_name`, `trade_name`, `legal_name`, `primary_domain`, `status`;
- `institution_type_id`, `type_name`;
- `district`, `street`, `number`, `complement`, `postal_code`, `city`, `state`;
- `contact_email`, `contact_phone`, `contact_mobile_phone`;
- `plan_id`, `plan_name`, `units_count`, `groups_count`.

Não retornar `document_ref`, `document_type`, `search_name`, `type_code`,
`subscription_status`, `country`, dados de ator, sessão ou auditoria.

## Filtros e limites

`p_filters` aceita somente:

- `search`: texto até 200 caracteres; `%`, `_` e barra invertida são literais;
- `statuses`: array de até 6 valores entre `draft`, `onboarding`, `active`,
  `inactive`, `suspended`, `archived`;
- `plan_id`: UUID textual;
- `states`, `cities`, `districts`: arrays de até 20 textos não vazios;
- `type_ids`: array de até 20 UUIDs textuais.

Chave extra, tipo incorreto, valor vazio onde proibido, duplicidade após
normalização ou cardinalidade excedida retorna `SAI_INVALID_ARGUMENT`.
O JSON serializado de filtros aceita no máximo 8.192 bytes e cada texto de
localização aceita no máximo 240 bytes, além dos limites de cardinalidade.
`plan_id` ou `type_id` inexistente/fora do escopo produz sucesso vazio, sem
confirmar existência.

`p_limit` aceita 1 a 100. `p_offset` aceita 0 a 10.000. `NULL` explícito para
qualquer parâmetro público é inválido; defaults valem somente quando o argumento
é omitido. A opção Flutter de page size 500 deve ser removida ou desabilitada
pela futura integração; esta frente não altera Flutter.

## Ordenação

`p_sort` aceita apenas `public_name`, `type_name`, `units_count`,
`groups_count`, `plan_name`, `status`, `contact_email`, `contact_phone`,
`contact_mobile_phone`, `primary_domain`, `street`, `postal_code`, `number`,
`complement`, `district`, `city` e `state`.

Todos os sorts usam `NULLS LAST`; o desempate final é sempre `id ASC`, inclusive
quando a direção primária é descendente. Nenhum fragmento enviado pelo cliente
é interpolado em SQL.

## Opções de filtro

`data` contém chaves exatas `plans`, `types`, `states`, `cities`, `districts`.
Cada valor é um array de objetos com chaves exatas `id`, `label`, ordenado por
label e depois id. Estados/cidades/bairros usam o próprio texto como id e label.

Planos, tipos e localizações derivam somente das Instituições visíveis ao ator;
catálogo global sem uso visível não aparece. Estados visíveis são sempre
retornados; `p_states` limita cidades e `p_cities` limita bairros. Arrays nulos,
acima de 20 itens, vazios internamente ou duplicados após normalização falham.
Cada item textual de `p_states` e `p_cities` aceita no máximo 240 bytes.

## Erros e auditoria

Falhas usam o envelope da spec 039. Apenas códigos `SAI_*` allowlisted são
preservados; exceção desconhecida vira `SAI_INTERNAL_ERROR`. Sessão ausente ou
inválida é tratada antes dos filtros e não fabrica audit. Após sessão válida,
negativas geram exatamente um evento v2/v3 correlacionado; falha do append
aborta a RPC.

Sucessos geram um evento minimizado por chamada:

- lista: `permission_code='platform.read'`, `action_code='institution.list'`;
- opções: `permission_code='platform.read'`,
  `action_code='institution.filter_options'`.

Não registrar termos de busca, arrays, UUIDs de filtro ou resultados.

## Compatibilidade e fora de escopo

`institution_directory`, `institution_directory_locations`, `plans`,
`institution_types` e os RPCs legados permanecem inalterados até cutover
Flutter, testes cross-app e regressão integrada. Criar, editar, status, mídia,
arquivos, importação/exportação e escrita de relações permanecem fora.

## Critérios de aceite

- Auth, sessão, membership, capability, MFA, papel e escopo são revalidados;
- Owner/Operations/Auditor positivos e Support/Content negativos são provados;
- platform vê A/B e institution vê somente A, inclusive nas opções;
- filtros inválidos, sort adulterado, limite 101, offset 10.001 e NULL explícito
  falham com envelope estável;
- busca trata `%`, `_` e barra como literais;
- paginação, contagem, `NULLS LAST` e desempate são determinísticos;
- outputs usam apenas as allowlists desta spec;
- ACL, audit v2/v3, append fail-closed e cleanup são comprovados;
- estado máximo sem Flutter/deploy/E2E é `local-green`.
