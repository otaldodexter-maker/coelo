---
title: "Handoff - grupo acessos-pessoas, Rodada 3"
round: "E2-R03-20260910"
base: "bb15db748 (dev)"
branch: "work/etapa2-r03-acessos-pessoas"
status: "em curso"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# Handoff - acessos-pessoas

## Base

Worktree `C:/Users/adrie/Documents/Coelo.worktrees/e2-r03-acessos-pessoas`,
branch `work/etapa2-r03-acessos-pessoas`, criada de `bb15db748`.
`base.fase0Head` nunca foi publicado em `coordenacao.json`, que segue na revisao
31 da Rodada 2, entao trabalhei pelo backend, como o P5 manda quando a base da
Fase 0 nao existe. **Nenhuma tela de diretorio foi tocada.**

## O que fechou

**Quatro pacotes prontos para a fila, 168 testes pgTAP verdes.**

| Pacote | Migrations | pgTAP | Desbloqueia |
| --- | --- | --- | --- |
| `AP-PEOPLE-DETAIL-V2` | `20260828005000` | 42 PASS | `people.links`, `people.reload` |
| `AP-INVITES-V2` | `20260901190432` (com minha correcao) | 33 PASS | as 5 de Convites |
| `AP-INTERNAL-USERS-V2` | `20260901210000` e `20260908021644` | 48 PASS | as 4 de Usuarios internos |
| `AP-CHILD-SAFETY-INTERNAL-READS` | `20260812002100` (com minha correcao), `20260812002200`, `20260909193000` | 45 PASS | as 5 de Seguranca infantil |

Sao **16 das 38 acoes** do recorte, e **nenhuma exige mudanca em Dart**: as
chaves de composicao ja estao ligadas no escopo produtivo. O que faltava era a
funcao existir no banco.

Fora desses quatro, `access_profile_models_aal1_phase_policy_test` passou com 34
testes no perfil `ModelAal1PhasePolicy`, mas nao e pacote novo: as RPCs de
Perfis e Modelos ja estao em producao.

**Dois defeitos de SQL corrigidos**, ambos do meu recorte e ambos impeditivos
em qualquer ambiente:

- `20260812002100` Seguranca infantil usava `authorization`, palavra reservada,
  como alias de tabela: `42601`. Renomeado para `authorization_record`, com a
  cadeia de hashes do perfil `SafetyInternalReads53` refeita.
- `20260901190432` Convites chamava `gen_random_bytes` sem schema dentro de uma
  funcao `security definer set search_path=''`. pgcrypto vive em `extensions`,
  entao emitir e reenviar convite devolviam `SAI_INTERNAL_ERROR` 500. Qualificado.
  O pgTAP saiu de 27/33 para 33/33.

**Quatro perfis nominais de prova** -- `PersonDetailV2`, `InvitesV2`,
`InternalUsersV2` e o `SafetyInternalReads53` reparado -- registrados nos dois
scripts do harness de forma aditiva.

**Uma proposta de contrato** para o acompanhamento automatico da D1, aguardando
acordo com `principal-chat-sistema`.

## O achado que importa mais que o meu recorte

96 das 162 RPCs que o Superadmin chama **nao existem em producao**. O cliente foi
migrado para o realm interno v2 e as migrations nunca chegaram ao banco; o ledger
remoto para em 01/09/2026. Isso atinge Instituicoes, Unidades, Grupos,
Atividades, Locais, Chat, Circulares, Avisos, Avaliacoes, Convites, Formularios,
Criancas, Seguranca infantil, Pessoas e as publicacoes do Principal. Enquanto
nao forem aplicadas, nenhuma frente fecha E2E pela regua do MVP, porque a rota
normal nao abre. Medicao e fila ordenada em
[`rpc-cliente-vs-producao-2026-09-10.md`](rpc-cliente-vs-producao-2026-09-10.md).

E parte dessa fila **nao aplica como esta escrita**. Encontrei **cinco**
migrations quebradas em cerca de doze que tentei aplicar de verdade:

| Migration | Erro | Dono |
| --- | --- | --- |
| `20260812002100` Seguranca infantil | `42601` alias reservado | meu, **corrigido** |
| `20260901190432` Convites | `42883` funcao sem schema | meu, **corrigido** |
| `20260901101500` Chat v2 | `23502` rotulos NOT NULL ausentes | principal-chat-sistema |
| `20260901185008` Avisos v2 | `42P01` schema errado | publicacoes-agenda |
| `20260901191921` Circulares v2 | `23502` mesmos rotulos ausentes | publicacoes-agenda |

Tres dos cinco sao a mesma classe: a migration foi escrita contra um estado do
schema que deixou de valer **antes dela na propria cadeia**. Nenhum aparece em
leitura; todos aparecem na primeira aplicacao. Para corrigir Chat e Circulares
existe modelo pronto no repositorio: `20260901210000` preenche os tres rotulos
corretamente na linha 4.

## O que ficou aberto, com o primeiro gate

| Aberto | Primeiro gate |
| --- | --- |
| `people.list`, `people.create`, `people.edit` | Decisao **AP-D1-AAL** do Owner. `app_private.assert_people_permission` exige AAL2 sem chave de escape, e o MVP e AAL1: em producao o diretorio de Pessoas nem lista. |
| Convites (5 acoes) | So a aplicacao da migration pelo coordenador. pgTAP 33/33. |
| Seguranca infantil (5 acoes) | A fixture do pgTAP insere em `public.units` sem `institution_type_id`. A base de prova e producao **discordam** da forma dessa tabela: a base pede `institution_type_id`, producao tem `unit_type_id`. Precisa de decisao antes de eu ajustar a fixture para um lado. |
| Usuarios internos (4 acoes) | So a aplicacao das duas migrations pelo coordenador. pgTAP 48/48. |
| Perfis e Modelos de acesso | **Leitura ja funciona em producao hoje**: nenhuma das RPCs de leitura chama `has_mfa_aal2`. A escrita depende da decisao AP-D1-AAL, porque passa por `access_profile_require_mutation`, que exige AAL2. Nao falta migration: as RPCs ja estao no banco. |
| Arquivos de perfil (6 acoes) | Adiados por decisao. Botao visivel e honesto, sem picker nem job. Nada a fazer no MVP. |
| Acompanhamento (D1) | Acordo dos quatro pontos com `principal-chat-sistema`. |

## Riscos que o coordenador precisa saber

1. **A branch nao esta publicada.** O `git push` foi recusado pelo classificador
   de permissao da sessao. Sete commits vivem so no checkout local. Trabalho nao
   publicado e o unico tipo de perda sem correcao.
2. **A base de prova nao e producao.** O prefixo curado do manifesto reconstroi
   um estado intermediario do schema. Verde nela prova logica e autorizacao; nao
   prova aplicabilidade sobre producao. A regua da ADR 0034 precisa desse
   asterisco enquanto nao houver base fiel.
3. **Alterei tres artefatos compartilhados**, todos de forma aditiva ou
   justificada: os dois scripts do harness, o `profile.json` do perfil de
   Seguranca infantil e o hash do descritor no resolver dele. Tudo reversivel.

## Fechamento do corte de 16:30

Base: rebaseada em `origin/dev` 552058da0, publicada em
`work/etapa2-r03-acessos-pessoas`. Working tree limpo, sem WIP retido.

**Cinco pacotes verdes, 182 testes pgTAP**, todos reconfirmados do zero na base
rebaseada, cada um em processo isolado e com zero recurso residual:

| Pacote | pgTAP | Estado |
| --- | --- | --- |
| `AP-PEOPLE-DETAIL-V2` | 42 | na fila |
| `AP-INVITES-V2` | 33 | na fila |
| `AP-INTERNAL-USERS-V2` | 48 | na fila |
| `AP-CHILD-SAFETY-INTERNAL-READS` | 45 | na fila |
| `AP-PEOPLE-READ-AAL1` | 14 | **retido ate a decisao AP-D1-AAL** |

**22 perfis de replay restaurados.** O acrescimo de `20260812000000` ao
manifesto (F-R03-FCR-003) quebrou 18 dos 22: cada `profile.json` fixa o hash do
manifesto, cada resolver fixa o hash do seu `profile.json`, e a base subiu de 45
para 46 entradas, deslocando contagens, totais e posicoes em cascata pelos
derivados. Refeito por nivel, em cinco passes. De 4 verdes para 22.

**A baseline de producao ainda nao chegou.** A coordenacao anunciou
`20260910000000_baseline_producao.sql` e `migrations-historico/`, mas nenhum dos
dois existe em `origin/dev` nem no checkout principal no momento deste
fechamento. So o `.env.local` chegou. Por isso as provas desta revisao sao sobre
a cadeia de migrations, nao sobre a baseline.

**Primeiro gate aberto:** reprovar os cinco pacotes sobre a baseline assim que
ela entrar, e no mesmo movimento trocar a fixture de Seguranca infantil de
`institution_type_id` para `unit_type_id` — a coordenacao confirmou que producao
usa `unit_type_id`, o que responde a decisao AP-D3-UNITS que eu havia levantado.
