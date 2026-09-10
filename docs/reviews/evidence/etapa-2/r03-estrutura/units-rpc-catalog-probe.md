---
title: "Unidades — as cinco RPCs não versionadas e como conferi-las em pg_proc"
source: "apps/superadmin/lib/features/units/data/supabase_unit_directory_repository.dart; packages/coelo_database/migrations; inventario-etapa-2.json (units.list/create/edit em blocked-environment)"
status: "levantamento do executor; leitura de catálogo é do coordenador"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# Por que `units.list`, `units.create` e `units.edit` estão travadas

O repositório de diretório de Unidades chama cinco RPCs por PostgREST. Nenhum
arquivo de `packages/coelo_database/migrations` cria qualquer uma delas. A única
citação em migration é indireta: `20260825180500_repair_unit_import_export_runtime_contract.sql`
executa `app_private.create_unit_for_superadmin(...)` dentro do worker de importação
e se declara, no próprio cabeçalho, "repair locally installed Unit … functions".

Isso deixa exatamente duas hipóteses, e só a leitura do catálogo remoto decide:

1. **Produção tem as funções fora do versionamento.** Então não há pacote a
   escrever; há dívida de versionamento a registrar, e as três ações saem de
   `blocked-environment` assim que a leitura confirmar assinatura e grants.
2. **Produção não tem as funções.** Então o diretório de Unidades falha
   fail-closed no primeiro uso, e as três ações precisam de migration nova.

Detalhe que muda o resultado da conferência: o cliente chama pelo schema
exposto (`public`), enquanto a migration de reparo referencia `app_private`.
Conferir os dois schemas; achar só a versão `app_private` **não** resolve a
chamada do cliente.

## Contrato exato chamado pelo cliente

| RPC | Parâmetros enviados | Origem |
| --- | --- | --- |
| `create_unit_for_superadmin` | `p_request_id` uuid, `p_payload` jsonb | `supabase_unit_directory_repository.dart:47` |
| `update_unit_for_superadmin` | `p_request_id` uuid, `p_payload` jsonb, `p_unit_id` uuid, `p_expected_version` int | `supabase_unit_directory_repository.dart:51` |
| `get_unit_form_for_superadmin` | `p_unit_id` uuid (nulo em criação) | `supabase_unit_directory_repository.dart:83` |
| `list_units_for_superadmin` | `p_search` text, `p_institution_ids`, `p_institution_type_ids`, `p_unit_type_ids`, `p_unit_statuses`, `p_plan_ids`, `p_states`, `p_cities`, `p_districts` (arrays), `p_sort` text, `p_ascending` bool, `p_offset` int, `p_limit` int | `supabase_unit_directory_repository.dart:116` |
| `unit_directory_filter_options` | `p_states`, `p_cities` (arrays) | `supabase_unit_directory_repository.dart:161` |

`superadmin_unit_detail_v2` **é** versionada, em
`20260828002000_superadmin_internal_unit_detail.sql`; não entra nesta dúvida.

## Consulta de leitura para o coordenador

Somente leitura de catálogo, sem mutação:

```sql
select n.nspname as schema,
       p.proname as funcao,
       pg_get_function_identity_arguments(p.oid) as assinatura,
       p.prosecdef as security_definer,
       pg_get_userbyid(p.proowner) as dono,
       coalesce(array_to_string(p.proacl, ' | '), 'sem ACL explicita') as grants
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where p.proname in (
        'create_unit_for_superadmin',
        'update_unit_for_superadmin',
        'get_unit_form_for_superadmin',
        'list_units_for_superadmin',
        'unit_directory_filter_options')
order by p.proname, n.nspname;
```

Resultado esperado por hipótese: cinco linhas em `public` confirmam a hipótese 1;
zero linha, ou linhas só em `app_private`, confirmam a hipótese 2 do ponto de
vista do cliente. Registrar também `security_definer` e `grants`: função
`security definer` sem `revoke` de `public` é achado de segurança por si só.
