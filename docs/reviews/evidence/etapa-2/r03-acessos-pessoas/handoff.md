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

**Um pacote pronto para a fila.** `AP-PEOPLE-DETAIL-V2`: a migration
`20260828005000_superadmin_internal_person_detail.sql`, que ja existia desde
28/08 e nunca foi aplicada, agora tem prova. 42 testes pgTAP PASS, 51 migrations
aplicadas em ordem, zero recurso residual. Reproduz com o perfil nominal
`PersonDetailV2`, que escrevi nesta rodada. Aplicar essa migration acende
`/people/:personId` sem tocar em Dart: `personDetailReader` ja e o reader real
no escopo produtivo. Fecha `people.links` e `people.reload`.

**Um defeito de SQL corrigido.**
`20260812002100_child_safety_read_models.sql` usava `authorization` como alias
de tabela, palavra reservada, e falhava com 42601 em qualquer ambiente.
Renomeado para `authorization_record`. Refiz a cadeia de hashes que fixa o
arquivo no perfil `SafetyInternalReads53`.

**Dois perfis nominais de prova**, `PersonDetailV2` e `InvitesV2`, registrados
nos dois scripts do harness de forma aditiva.

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

E parte dessa fila **nao aplica como esta escrita**. Encontrei tres migrations
quebradas em cerca de dez que tentei aplicar de verdade: a de Seguranca infantil
(corrigida), a de Chat v2 (23502, insert em `platform_permissions` sem os tres
rotulos NOT NULL) e a de Avisos v2 (42P01, altera `public.notice_events`, tabela
que o segundo passo da propria cadeia move para `analytics`). As duas ultimas sao
de outros grupos e ficaram reportadas, nao reparadas.

## O que ficou aberto, com o primeiro gate

| Aberto | Primeiro gate |
| --- | --- |
| `people.list`, `people.create`, `people.edit` | Decisao **AP-D1-AAL** do Owner. `app_private.assert_people_permission` exige AAL2 sem chave de escape, e o MVP e AAL1: em producao o diretorio de Pessoas nem lista. |
| Convites (5 acoes) | Execucao do perfil `InvitesV2`, em curso no fechamento desta nota. |
| Seguranca infantil (5 acoes) | A fixture do pgTAP insere em `public.units` sem `institution_type_id`. A base de prova e producao **discordam** da forma dessa tabela: a base pede `institution_type_id`, producao tem `unit_type_id`. Precisa de decisao antes de eu ajustar a fixture para um lado. |
| Usuarios internos (4 acoes) | As tres RPCs que o cliente chama nao existem em producao e as duas migrations que as criam estao fora do manifesto. Precisa de perfil proprio. |
| Modelos e Perfis de acesso | Producao ja tem a maior parte das RPCs. Falta medir acao a acao, o que so vale depois de resolver o AAL. |
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
