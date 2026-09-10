---
title: "A baseline revela: dez das 23 RPCs do recorte não existem em produção"
source: "packages/coelo_database/migrations/20260910000000_baseline_producao.sql (dump do projeto coelo em 10/09/2026) mais os pacotes aplicados depois dela; chamadas do cliente em apps/superadmin/lib/features"
status: "achado; corrige o mapa de gates que eu mesmo publiquei mais cedo"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# O que a baseline mudou

Até hoje eu media cobertura por **migration versionada**. A baseline de produção
introduziu a medida que importa: o que está **aplicado**. As duas não coincidem,
e a diferença é grande.

Cruzei as 23 RPCs que o cliente das seis famílias do recorte chama contra o dump
de produção mais os pacotes aplicados depois dele. **Dez não existem em
produção:**

| RPC ausente | Família |
| --- | --- |
| `superadmin_institution_directory_v2` | institutions |
| `superadmin_institution_detail_v2` | institutions |
| `superadmin_institution_filter_options_v2` | institutions |
| `superadmin_institution_edit_core_v2` | institutions |
| `superadmin_activity_directory_v2` | activities |
| `superadmin_activity_detail_v2` | activities |
| `superadmin_activity_filter_options_v2` | activities |
| `superadmin_create_scoped_activity_template` | activities |
| `superadmin_unit_detail_v2` | units |
| `superadmin_group_detail_v2` | groups |

# Onde eu errei, e a correção

No `gate-map-49-acoes.md` eu escrevi que Instituições e Atividades tinham
"repositório Supabase composto de verdade" e eram "as candidatas naturais a
fechar primeiro". Isso estava certo sobre a composição do cliente e **errado
sobre o banco**: a cadeia interna v2 das duas famílias foi escrita e versionada,
mas nunca chegou a produção. Na rota normal elas falham por RPC inexistente.

A conclusão prática se inverte: as famílias mais perto de funcionar em produção
hoje são **Unidades e Turmas**, cujas RPCs existem — as treze de Unidades
versionadas em `20260910160000` e as quatro de Turmas
(`superadmin_group_directory`, `_get`, `_save`, `_export_create`) já presentes na
baseline. Foi por isso que compus `SupabaseUnitDirectoryRepository` e
`SupabaseGroupDirectoryRepository` no lugar dos `Unavailable*`: ali o banco
responde.

Os **detalhes** de Unidade e de Turma continuam fail-closed, porque
`superadmin_unit_detail_v2` e `superadmin_group_detail_v2` não existem.

# Por que os três pacotes de Locais não passam na baseline

Reemiti os três com carimbo novo (`20260910180000`, `180100`, `180200`) e rodei
`db reset` com baseline + seed num projeto descartável. O primeiro aborta no
próprio preflight:

```
ERROR: reviewed reservation reader prerequisites missing (SQLSTATE 55000)
```

Não é defeito do pacote. É a cadeia inteira de Locais v2 que nunca foi aplicada.
Produção tem a tabela `activity_locations` e `activity_request_uuid`, e **não
tem** nada disto:

| Objeto que falta | Vem de |
| --- | --- |
| `superadmin_location_owner_v2`, catálogo v2 | `20260908031000_superadmin_location_catalog_v2.sql` |
| `superadmin_location_locked_v2` | `20260908190646_superadmin_locations_update_status_v2.sql` |
| copiar local | `20260908190648_superadmin_locations_copy_v2.sql` |
| agendamento | `20260908190650_superadmin_locations_schedule_v2.sql` |
| `superadmin_location_reservations_v2`, `location_bindings`, `superadmin_location_reservation_create_v2` | `20260909165000_superadmin_location_reservations_v2.sql` |
| `superadmin_activity_save_v2`, `superadmin_internal_activity_save_receipts` | `20260908154257_superadmin_activity_save_v2.sql` |

Todos estão em `migrations-historico/`.

# O que peço ao coordenador

O gate como foi passado — "reprovar os três pacotes de Locais sobre a baseline" —
**não pode passar**, e nenhuma correção nos três resolve. Antes deles a fila
precisa de seis pacotes da cadeia histórica, nesta ordem, recarimbados depois de
`20260910160000`:

1. `20260908031000_superadmin_location_catalog_v2`
2. `20260908154257_superadmin_activity_save_v2`
3. `20260908190646_superadmin_locations_update_status_v2`
4. `20260908190648_superadmin_locations_copy_v2`
5. `20260908190650_superadmin_locations_schedule_v2`
6. `20260909165000_superadmin_location_reservations_v2`

Só então os três de Locais (`180000`, `180100`, `180200`).

Isso é decisão de fila, não minha: são seis pacotes de outras fatias, alguns
tocando Atividades, e recarimbá-los por conta própria atravessaria o
sequenciamento que você mantém. Os três meus continuam prontos e reemitidos na
branch, esperando a cadeia.

# O bloqueio final não é técnico: faltam as capacidades em produção

Depois de corrigir as duas comparações literais de ACL — a da tabela e a das
sete funções legadas — a cadeia avançou até o próprio contrato do pacote:

```
ERROR: location candidate requires separate Owner-only capability fixture (SQLSTATE 55000)
```

O pacote recusa-se a inventar capacidade, e está certo. Fui conferir o catálogo
de produção: **não existe nenhuma permissão `locations.*` no seed**. Zero.

As nove que a cadeia exige são:

| Permissão | De onde vem a exigência |
| --- | --- |
| `locations.read`, `locations.create`, `locations.update`, `locations.status`, `locations.copy`, `locations.schedule` | catálogo v2 e as fatias de status, cópia e agendamento |
| `locations.reservations.read`, `locations.reservations.manage`, `locations.reservations.override` | motor de reservas |

Isso muda a natureza da pendência. Não é mais "recarimbar e aplicar": alguém
precisa **decidir e provisionar** essas nove permissões no catálogo de produção,
com código, módulo, tela, ação, rótulo, nível de risco, `requires_mfa` e a
concessão inicial ao Owner. `locations.reservations.override` é, pelo próprio
nome, uma capacidade de confirmar conflito de reserva — o tipo de coisa que não
se cria por conta própria.

Enquanto as capacidades não existirem, nenhuma ação de Locais funciona em
produção, mesmo com toda a cadeia SQL aplicada: as RPCs chamam
`require_superadmin_internal_context('locations.…')` e vão negar.

**Isto é decisão do Owner**, e foi levada a ele. Não provisionei as capacidades:
inventar permissão e concedê-la ao Owner é exatamente o tipo de mudança que a
régua do projeto manda não fazer sozinho.
