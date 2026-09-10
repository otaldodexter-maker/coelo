---
title: "Superadmin: o que o cliente chama e o que existe em producao"
source: "Dump schema-only do projeto Supabase de producao coelo (evvbomzejfijozbtgvpt), schemas public e app_private, em 2026-09-10; varredura de client.rpc() em apps/superadmin/lib na base bb15db748"
status: "measured"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
author: "Rodada 3, grupo acessos-pessoas"
---

# 96 das 162 RPCs que o Superadmin chama nao existem em producao

## O que foi medido

Extrai por varredura todas as chamadas `client.rpc('<nome>')` de
`apps/superadmin/lib` e comparei cada nome com o schema real do banco de
producao, obtido por `supabase db dump` dos schemas `public` e `app_private`
em 10/09/2026. O resultado bruto, com o consumidor de cada RPC e a migration
que a cria, esta em
[`rpc-cliente-vs-producao-2026-09-10.json`](rpc-cliente-vs-producao-2026-09-10.json).

| Medida | Valor |
| --- | --- |
| RPCs distintas chamadas pelo cliente | 162 |
| Existem em producao | 66 |
| **Ausentes em producao** | **96** |
| Migrations do repositorio que as criam | 36 |
| RPCs sem nenhuma migration que as crie | 8 |

O metodo se auto-valida: as 66 que casaram provam que a extracao e a comparacao
funcionam. Um falso negativo exigiria que o `pg_dump` omitisse uma funcao de
`public`, o que ele nao faz.

## Correcao da primeira medicao

A primeira versao desta pagina disse 90 de 137. O numero estava baixo: o padrao
de extracao parava no primeiro `>` e por isso perdia chamadas com generico
aninhado, como `rpc<Map<String, dynamic>>('...')`. Corrigido, aparecem mais 25
chamadas e mais 6 ausencias, entre elas as tres RPCs de **Usuarios internos**
(`superadmin_internal_user_profiles`, `superadmin_internal_user_detail`,
`superadmin_internal_users_list`) e as de contexto e feed do Principal. Os
numeros desta pagina sao os corrigidos.

## Por que isso importa

O cliente do Superadmin foi migrado para o realm interno v2 ao longo de agosto e
setembro, mas as migrations correspondentes nunca chegaram ao banco. O ledger
remoto para em `20260901200206`. O efeito nao e "funcionalidade incompleta": e
erro de funcao inexistente na primeira chamada da rota produtiva.

Isso explica de forma economica por que praticamente todo o inventario da
Etapa 2 esta em `pending-verification` ou `fail-closed`, e por que nenhuma
frente conseguiu fechar E2E: **o app nao tem como funcionar contra producao no
estado atual**, independentemente da qualidade do Front-end.

## Alcance por familia

Nao e um problema de um grupo. Atinge praticamente todos:

- **Instituicoes, Unidades, Grupos** — `superadmin_institution_detail_v2`,
  `_directory_v2`, `_filter_options_v2`, `_edit_core_v2`, `superadmin_unit_detail_v2`,
  `superadmin_group_detail_v2`
- **Atividades** — `superadmin_activity_directory_v2`, `_detail_v2`,
  `_filter_options_v2`, `_save_v2`, `_location_create_v2`,
  `superadmin_create_scoped_activity_template`
- **Locais** — 15 RPCs, o catalogo v2 inteiro mais reservas e agendamento
- **Chat** — 8 RPCs, incluindo `superadmin_chat_inbox_v2` e `_send_message_v2`
- **Circulares** — 7 RPCs; **Avisos** — 6; **Avaliacoes** — 8
- **Convites** — as 6 RPCs v2 (`directory`, `options`, `detail`, `issue`, `resend`, `revoke`)
- **Pessoas** — `superadmin_person_detail_v2`
- **Seguranca infantil** — as 8 RPCs, tanto leitura quanto comandos
- **Formularios** — `superadmin_forms_directory_v2`
- **Principal** — `publish_now`, `publish_moment`, os rascunhos e as retiradas
- **Criancas** — `superadmin_child_context_directory_v2`

## As 8 sem migration nenhuma

Estas o cliente chama e **nenhum arquivo do repositorio cria**, nem em
`packages/coelo_database/migrations` (186) nem no espelho da CLI (17):

`superadmin_agenda_contexts_v2`, `superadmin_agenda_get_v2`,
`superadmin_agenda_list_v2`, `superadmin_attendance_call_detail`,
`superadmin_attendance_context_options`, `superadmin_attendance_create_call`,
`superadmin_attendance_directory`, `superadmin_attendance_undo_bulk`.

De Agenda existe apenas um pgTAP de contrato
(`supabase/tests/superadmin_agenda_read_v2_contract_test.sql`) sem a migration
correspondente. Assiduidade nao tem nem isso. Sao pendencias de escrita de
backend, nao de aplicacao.

## Relacao com o bloqueio OQ-042

O bloqueio ja registrado em `docs/open-questions.md` (OQ-042) continua valendo e
eu o reproduzi de forma independente: o replay integral da cadeia canonica falha
na 53a migration, `20260812002010_import_export_unit_source_retention.sql`, com
`42P01` porque `app_private.unit_import_source_attestations` nao existe. Nenhuma
migration do repositorio cria essa tabela; ela e criada pela orfa
`20260811222209`, que esta no ledger remoto e **nao existe como arquivo**.
A tabela existe em producao.

A consequencia pratica precisa ficar dita com todas as letras: **o repositorio
nao consegue reconstruir producao**. Por isso os perfis nominais de
`replay/profiles/` existem — sao subconjuntos curados para contornar o buraco.
E por isso a regua "pgTAP local verde entao aplicar em producao" da ADR 0034
precisa de um passo a mais: o verde local so vale sobre um perfil que reproduza
as dependencias reais do pacote, nunca sobre a cadeia integral.

## Encaminhamento

Isto e maior que o grupo acessos-pessoas e nao cabe a um executor decidir. Para
o coordenador e para o Owner:

1. A fila SQL da Rodada 3 nao sao alguns pacotes: sao **36 migrations** ja
   escritas, esperando aplicacao, mais 8 RPCs por escrever.
2. A ordem da fila precisa considerar que producao esta em 01/09/2026, nao em
   09/09/2026, e que ha objetos em producao sem migration de origem.
3. Enquanto essas 36 nao forem aplicadas, nenhuma frente consegue fechar E2E
   pela regua do MVP, porque a rota normal nao abre. Medir avanco de tela sem
   isso mede o Front-end contra um backend ausente.
4. A decisao de como reconciliar o ledger (baseline nova a partir do dump de
   producao, ou reconstrucao das orfas) e do Owner. Recomendo baseline nova:
   e o unico caminho que torna o repositorio capaz de reproduzir producao de
   novo, e o projeto nao tem clientes reais.
