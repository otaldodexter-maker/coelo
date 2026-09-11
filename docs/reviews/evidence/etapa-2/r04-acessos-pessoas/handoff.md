---
title: "Handoff - grupo acessos-pessoas, Rodada 4"
round: "E2-R04-20260911"
base: "origin/dev 14b96e446 (lotes 8 a 14 em producao)"
branch: "work/etapa2-r04-acessos-pessoas"
status: "mini-revisao das 04:00 (rascunho ate a revisao final do JSON)"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# Handoff - acessos-pessoas (R04)

Recorte: people, access_profiles, access_models, invites, internal_users,
child_safety, profile_files (38 acoes). Canal oficial:
`docs/reviews/etapa-2-operacao/comunicacao/acessos-pessoas.json` (revisoes 95
a 103). Capturas em `capturas/`.

## Como a prova foi feita

Build web release do Superadmin (`flutter build web`, dart-define do
`.env.local`) servido por um servidor Node com fallback de SPA em
`localhost:3000`; Chrome dedicado dirigido pelo Chrome DevTools Protocol
(porta propria, perfil isolado, SwiftShader porque o CanvasKit sem GPU rende
em branco); sessao real `qa-r03@coelo.me` com "Manter sessao aberta", entrada
digitada a partir do arquivo de ambiente sem passar pelo chat. Backend
conferido por REST com a mesma sessao (`rpc.js` no scratchpad) e por
`supabase db query --linked` somente leitura. Base de prova SQL: projeto
descartavel `coelo_acessos` (baseline + seed + todas as migrations ate o lote
10 + candidatos do grupo).

A maquina reiniciou as 00:27 por falta de memoria; nenhum commit se perdeu.

## Pacotes SQL

| Pacote | Estado | Prova |
| --- | --- | --- |
| 171000 has_platform_permission por instituicao (P7) | em producao (lote 10) | pgTAP 20/20 |
| 171100 follow_links: acompanhamento automatico da hierarquia (D1) | em producao (lote 12) | pgTAP 24/24 sobre baseline + lotes ate o 10 |
| 171200 semente do perfil interno de qa-r03 | em producao (lote 14) | pgTAP 6/6 |
| 171300 catalogo de permissoes e Modelos de acesso sobre a baseline | ver JSON (subagente) | pgTAP historicos do pacote |

## Cliente

- Seguranca infantil compoe o repositorio legado (leitura e escrita), porque
  a ponte de ator do lote 10 o autoriza; o v2 interno e somente leitura.
- Pessoas: criar/editar ligados pela capacidade composta (`/people`).
- Usuarios internos: Owner interno recebe capability owner (antes, auditor).
- Decisao 7: sem balao de chat nos formularios do recorte.
- 22 goldens de Usuarios internos e o de Seguranca infantil regravados pelo
  menu aprovado (MENU) e botao de Bug; `platform_user_create_light_375` fica
  ate o P15.

Sem `flutter analyze`/build apos 00:27 por memoria: o coordenador valida na
base conjunta.

## Estado por action_id

Ver `ROTA_NORMAL_03h00_por_action_id` e a mini-revisao no JSON. Resumo:
rota normal abre e lista com dados reais em people.list, access-profiles.list,
internal-users.list, invites.list, child-safety.list e os seis
profile-files.* (adiados e honestos). Nenhuma acao chega a `verified` pela
regua completa (CRUD + reload) sem um build novo do cliente; as escritas de
Pessoas e Usuarios internos ja tem backend respondendo.

## Gates abertos

| Aberto | Primeiro gate |
| --- | --- |
| invites.create/detail/resend/revoke | producao tem 0 `institution_roles`: sem perfil, o convite nao passa do passo 1. Decisao de produto (papeis padrao de instituicao) ou criar perfil Admin pela tela apos o 171300. |
| access-profiles.create/edit, access-models.* | 171300 (catalogo de permissoes) aplicado + build. |
| people.create | `PersonIdentityLookupGate` sem implementacao Supabase (resolucao de identidade). |
| people.links/reload | diretorio abre o editor, nao o detalhe; ligar `/people/:id` a partir do card. |
| internal-users.create | sem RPC de criacao em producao (identidade + auth user). |
| internal-users.edit/suspend, child-safety.create/edit/suspend, people.edit | build novo do cliente com os commits desta rodada. |
| golden platform_user_create_light_375 | P15 (respiro do rodape) do grupo estrutura. |
