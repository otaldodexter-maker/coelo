---
title: "Handoff - grupo acessos-pessoas, Rodada 4"
round: "E2-R04-20260911"
base: "origin/dev 14b96e446 e seguintes (lotes 8 a 16 em producao)"
branch: "work/etapa2-r04-acessos-pessoas"
status: "mini-revisao das 04:00"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# Handoff - acessos-pessoas (R04)

Recorte: people, access_profiles, access_models, invites, internal_users,
child_safety, profile_files (38 acoes). Canal oficial:
`docs/reviews/etapa-2-operacao/comunicacao/acessos-pessoas.json` (revisoes 95
a 108). Deltas por action_id para o coordenador aplicar: `deltas-r04.json`.
Capturas em `capturas/`.

## Como a prova foi feita

Build web release do Superadmin (`flutter build web`, dart-define do
`.env.local`) servido por um servidor Node com fallback de SPA em
`localhost:3000`; um unico Chrome dirigido pelo Chrome DevTools Protocol
(porta propria, perfil isolado, SwiftShader porque o CanvasKit sem GPU rende
em branco); sessao real `qa-r03@coelo.me` com "Manter sessao aberta", entrada
digitada a partir do arquivo de ambiente sem passar pelo chat. Backend
conferido por REST com a mesma sessao (`rpc.js` no scratchpad) e por
`supabase db query --linked` somente leitura. Base de prova SQL: projeto
descartavel `coelo_acessos` (baseline + seed + migrations ate o lote 10 +
candidatos do grupo).

A maquina reiniciou as 00:27 por falta de memoria; nenhum commit se perdeu.
Depois disso: um Chrome por vez, sem subagente com Chrome, `flutter analyze`
e builds so quando a memoria permitiu (um build feito as 02:19).

## Pacotes SQL

| Pacote | Lote | Prova |
| --- | --- | --- |
| 171000 has_platform_permission por instituicao (P7) | 10 | pgTAP 20/20 |
| 171100 follow_links: acompanhamento automatico da hierarquia (D1) | 12 | pgTAP 24/24 |
| 171200 semente do perfil interno de qa-r03 | 14 | pgTAP 6/6 |
| 171300 catalogo de permissoes e Modelos de acesso sobre a baseline | 16 | pgTAP 32+11+17+12+8; politica AAL1 34/34 |
| 171500 backfill do acompanhamento D1 | 16 | pgTAP 5/5 |
| 171600 papeis de sistema de instituicao (Administrador, Coordenacao, Professor(a), Secretaria) | RETIDO ate P31 | pgTAP 7/7 |
| 171700 detalhe de perfil v3 (rascunho em branco + forma rica que o cliente le) | 18 | pgTAP 37/37 |
| 171800 decisao de retirada pelo Superadmin com child_safety.manage | RETIDO ate P32 (b) | pgTAP 25/25 |
| 171900 cast do enum em child_safety_decide_authorization (defeito de producao: nenhum ator persistia decisao) | 19 | pgTAP 4/4 (RED antes) |

Cliente (3682673da): o rascunho de perfil passa a enviar `capabilities`
[{code, effect}] como o servidor le; antes o perfil era salvo sem concessao.

Perguntas ao Owner registradas no JSON: P31 (papeis padrao de instituicao)
e P32 (quem decide autorizacoes de retirada em Seguranca infantil).

## Cliente (commits 2891e6977, ce6f061cc, e17b0ee84)

- Seguranca infantil compoe o repositorio legado (leitura e escrita), porque
  a ponte de ator do lote 10 o autoriza; o v2 interno e somente leitura.
- Pessoas: criar/editar ligados pela capacidade composta (`/people`).
- Usuarios internos: Owner interno recebe capability owner e a rota de
  edicao compoe o formulario.
- Decisao 7: `showChatLauncher: false` nos formularios do recorte (o launcher
  novo do principal-chat ainda aparece; conferir na base conjunta).
- 22 goldens de Usuarios internos e o de Seguranca infantil regravados pelo
  menu aprovado (MENU) e botao de Bug; `platform_user_create_light_375` fica
  ate o P15.

## O que fechou na rota real (sessao qa-r03)

- access-models.create: CRUD real pela UI, persistido em producao
  (`access_profile_templates` `qa-r04-modelo-sintetico-b6f3958c`).
- Listas com dados reais e reload: people.list, access-profiles.list,
  access-models.list, internal-users.list (+ detalhe com Editar/Acoes),
  child-safety.list e child-safety.child, invites.list (vazio honesto).
- child-safety.create no backend (autorizacao sintetica persistida e relida).
- profile-files.*: adiados e honestos na rota real.

## Gates abertos

| Aberto | Primeiro gate |
| --- | --- |
| invites.create/detail/resend/revoke | P31 (Owner): 0 `institution_roles` em producao; sem perfil o convite nao passa do passo 1. |
| access-profiles.create/edit/detail | 171700 aplicado (lote 18) e criar provado pela UI; a concessao selecionada so persiste com o cliente de 3682673da (build novo); assign/delete nao exercitados. |
| child-safety.edit (decisao) / suspend | 171900 (cast) aplicado no lote 19; quem decide e P32 (171800 retido com a opcao b). Sem revisor de unidade cadastrado, o Superadmin nao decide hoje. |
| people.create | Resolvedor de identidade (`PersonIdentityLookupGate`) sem implementacao Supabase/RPC. |
| people.links (FE) | ligado em bd0538ec6 (card abre o detalhe, detalhe tem Editar); prova na rota real depende de build novo. |
| internal-users.create | Sem RPC/Edge Function de criacao (identidade + auth user). |
| internal-users.edit/suspend, people.edit, access-models.edit (salvar) | Escrita pela UI nao exercitada por tempo/memoria; rotas abrem com dados reais. |
| golden platform_user_create_light_375 | P15 (estrutura). |

## Dados sinteticos a remover ao fim

- `app_private.superadmin_internal_profiles` do qa-r03 (semente 171200).
- `public.authorized_person_authorizations` 34d29829-a8b5-4b23-aacb-46e994dce7d7.
- `public.access_profile_templates` `qa-r04-modelo-sintetico-b6f3958c` e suas permissoes.
- `public.platform_roles` `qa-r04-perfil-sintetico-7f6f8d16` (546c4cd2-ea2d-4488-9961-e17576e836e5).
