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

## Ampliação: a lacuna é de treze RPCs, não de cinco, e é só de Unidades

Varri as seis famílias do recorte procurando toda RPC chamada pelo cliente sem
`create function` correspondente em `packages/coelo_database/migrations`. São 58
RPCs distintas chamadas; 13 não têm criação versionada, e **todas as 13 são de
Unidades**. Instituições, Turmas, Atividades, Locais e Avaliações têm cobertura
versionada completa — a única razão de Turmas aparecer abaixo é que o diretório
de Turmas reaproveita duas RPCs de Unidades.

| RPC sem migration | Chamada em |
| --- | --- |
| `change_unit_handle_for_superadmin` | `supabase_unit_backend_commands_gateway.dart:29` |
| `create_unit_for_superadmin` | `supabase_unit_directory_repository.dart:48` |
| `get_unit_form_for_superadmin` | `supabase_unit_directory_repository.dart:83` |
| `list_units_for_superadmin` | `supabase_unit_directory_repository.dart:117`; **`supabase_group_directory_repository.dart:127`** |
| `preview_unit_institution_transfer_for_superadmin` | `supabase_unit_backend_commands_gateway.dart:38` |
| `request_unit_type_for_superadmin` | `supabase_unit_backend_commands_gateway.dart:20` |
| `superadmin_prepare_unit_identity_upload` | `supabase_unit_backend_commands_gateway.dart:65` |
| `superadmin_request_unit_identity_delete` | `supabase_unit_backend_commands_gateway.dart:86` |
| `superadmin_unit_identity_download_descriptor` | `supabase_unit_backend_commands_gateway.dart:102` |
| `superadmin_unit_import_template` | `supabase_unit_backend_commands_gateway.dart:158` |
| `transfer_unit_institution_for_superadmin` | `supabase_unit_backend_commands_gateway.dart:48` |
| `unit_directory_filter_options` | `supabase_unit_directory_repository.dart:162`; **`supabase_group_directory_repository.dart:121`** |
| `update_unit_for_superadmin` | `supabase_unit_directory_repository.dart:52` |

Duas consequências que a leitura de `pg_proc` precisa cobrir:

1. `list_units_for_superadmin` e `unit_directory_filter_options` são
   compartilhadas com o diretório de Turmas. O que faltar ali derruba as duas
   telas, não só Unidades.
2. Quatro delas (`superadmin_prepare_unit_identity_upload`,
   `superadmin_request_unit_identity_delete`,
   `superadmin_unit_identity_download_descriptor`,
   `superadmin_unit_import_template`) são de mídia de identidade e de template
   de importação. Importação/exportação estão adiadas para depois do MVP, então
   a ausência dessas quatro não bloqueia o MVP — mas o botão precisa continuar
   honesto, sem tentar a chamada.

Consulta ampliada, para uma leitura só:

```sql
select n.nspname as schema,
       p.proname as funcao,
       pg_get_function_identity_arguments(p.oid) as assinatura,
       p.prosecdef as security_definer,
       coalesce(array_to_string(p.proacl, ' | '), 'sem ACL explicita') as grants
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where p.proname in (
        'change_unit_handle_for_superadmin',
        'create_unit_for_superadmin',
        'get_unit_form_for_superadmin',
        'list_units_for_superadmin',
        'preview_unit_institution_transfer_for_superadmin',
        'request_unit_type_for_superadmin',
        'superadmin_prepare_unit_identity_upload',
        'superadmin_request_unit_identity_delete',
        'superadmin_unit_identity_download_descriptor',
        'superadmin_unit_import_template',
        'transfer_unit_institution_for_superadmin',
        'unit_directory_filter_options',
        'update_unit_for_superadmin')
order by p.proname, n.nspname;
```
