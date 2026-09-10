---
title: "Estrutura — chaves de composição por pacote SQL"
source: "apps/superadmin/lib/main.dart; apps/superadmin/lib/core/config/superadmin_auth_scope.dart; apps/superadmin/lib/app/superadmin_app.dart; repositórios das famílias do recorte"
status: "levantamento do executor; quem liga a chave é o coordenador, depois de aplicar o SQL"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# O que precisa ser ligado depois de cada pacote SQL

Cada pacote SQL de Estrutura tem um par no cliente que hoje está fechado.
Aplicar a migration sem virar a chave não muda nada na tela: o repositório
continua devolvendo indisponível antes de tocar a rede. Ligar a chave sem a
migration produz erro de RPC inexistente. Os dois passos são um só, na ordem
SQL → chave, e ambos são do coordenador.

| Pacote SQL | RPC criada | Chave de composição | Arquivo |
| --- | --- | --- | --- |
| `20260909192000_superadmin_location_consumer_bindings_v2` | `public.superadmin_location_consumer_bindings_v2` | `SupabaseLocationConsumerBindingsReader` já é composto sem gate próprio; a chave irmã é `SupabaseLocationConsumerSelectionReader(..., available: false)` | `main.dart:131` e `main.dart:147` |
| `20260909200000_superadmin_activity_location_create_v2` | `public.superadmin_activity_location_create_v2` | `SupabaseActivityCommandRepository(..., activityLocationCreateAvailable: false)` | `supabase_activity_command_repository.dart:17`, composto em `superadmin_auth_scope.dart:359` |
| `20260909210000_superadmin_group_location_create_v2` | `public.superadmin_group_location_create_v2` | `SupabaseGroupLocationCreateRepository(..., available: false)` — hoje **nem é composto**: não aparece em `main.dart` nem no escopo de produção | `supabase_group_location_create_repository.dart:8` |

## O gate maior, acima dos três pacotes

Independente dos pacotes acima, a composição de produção mantém três decisões
que sozinhas explicam por que Unidades e Turmas não fecham ponta a ponta:

- `superadmin_auth_scope.dart:375` fixa `structureMutationsEnabled: false`, com
  a justificativa registrada no próprio código (OQ-032/OQ-043: os repositórios
  de CRUD ainda apontam para o realm legado baseado em pessoas).
- `superadmin_auth_scope.dart:367` compõe `unitDirectoryRepository` como
  `UnavailableUnitDirectoryRepository`.
- `superadmin_auth_scope.dart:366` compõe `groupDirectoryRepository` como
  `UnavailableGroupDirectoryRepository`.

Ou seja: mesmo com as cinco RPCs de Unidades presentes em produção, o diretório
de Unidades continuaria fechado no cliente, porque a composição real nunca
instancia o repositório Supabase. Conferir `pg_proc` responde a metade da
pergunta; a outra metade é esta composição.

Consequência para a régua do MVP: nenhuma ação de `units.*` ou `groups.*` pode
ser declarada verificada enquanto a composição de produção entregar
`Unavailable*`. Tela que abre com repositório indisponível é `fail-closed`, e
`fail-closed` não conta como verificado.
