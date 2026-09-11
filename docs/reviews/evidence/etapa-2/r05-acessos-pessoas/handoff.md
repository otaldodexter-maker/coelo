---
title: "Handoff - grupo acessos-pessoas, Rodada 5"
round: "E2-R05-20260911"
base: "origin/dev 2f6a6114f na abertura; merges de dev ate 530613fb5"
branch: "work/etapa2-r05-acessos-pessoas"
status: "mini-revisao das 15:45"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# Handoff - acessos-pessoas (R05)

Recorte: people, access_profiles, access_models, invites, internal_users,
students (32 acoes). Canal oficial:
`docs/reviews/etapa-2-operacao/comunicacao/acessos-pessoas.json` (revisoes 119
a 124). Deltas por action_id: `deltas-r05.json` (26, aplicados pelo coordenador
em dev 530613fb5) e `deltas-r05-2.json` (7, a aplicar). Capturas em `capturas/`.

## Como a prova foi feita

Build web de `test_driver/qa_main.dart` com `.env.local`, servido por Node em
`127.0.0.1:3000`; um Chrome dirigido por CDP (porta 9411, SwiftShader).
**Achado de metodo:** a extensao do Flutter Driver do `qa_main` emula o teclado
(`enableTextEntryEmulation`), entao nenhum campo aceita digitacao por CDP; a
sessao entrou por injecao no `localStorage` (chave
`coelo.superadmin.auth.session`, valor obtido pelo login por REST no proprio
processo) e o texto entra por `window.$flutterDriver({"command":"enter_text"})`.
Backend conferido por REST com a mesma sessao (`rpc.js`). pgTAP no projeto
descartavel `coelo_acessos_r05` (baseline + seed + as 107 migrations da ordem de
producao + candidato), encerrado no fechamento. A maquina ficou entre 0,01 e
2,5 GB livres durante a tarde; o Chrome parou de repintar abaixo de 0,5 GB.

## Pacotes SQL

| Pacote | Lote | Prova |
| --- | --- | --- |
| 20260911170100 person_handles_v1 (@ de pessoas: trava de 30 dias, reservados, geracao ao nascer, backfill, RPCs get/availability/set) | 31 | pgTAP 22/22 |
| 20260911170200 follow_links_safeupdate_fix_v1 (DELETE sem WHERE no sync do acompanhamento bloqueado pelo pg_safeupdate: toda escrita de vinculo de crianca pela API falhava desde o lote 12) | 34 | pgTAP 3/3 como supabase_admin, RED reproduzido |
| 20260911170300 institution_profile_system_model_create_v1 (perfil Admin criado pela plataforma nasce modelo do sistema; com institution_id e da instituicao; modelos de Admin editaveis pela plataforma) | 38-42 | pgTAP 8/8, RED reproduzido (23514) |

## Cliente (commits 3b4aaa5b6, 677d95682, c227e531f, bf9c2f186, b64bd9bf9)

- Perfis (P31): cards abrem o detalhe; modelo de sistema nao editavel com
  "Criar a partir deste modelo"; "Criar perfil" pergunta do zero ou a partir
  de um modelo ativo; `?from=<uuid>` pre-preenche o rascunho; revisao compara
  com o rascunho em branco; save desembrulha o envelope da RPC.
- Pessoas: secao "Identificador (@)" no detalhe com disponibilidade enquanto
  digita, motivo, trava de 30 dias e mensagens de reservado/tomado/formato;
  chave `enablePersonHandles` ligada.
- Alunos: vincular a turma (a turma decide a unidade, P36), transferir com
  motivo e editar vigencia, com as turmas do diretorio de Turmas.
- Goldens regravados apos o composto de tabela (G-SUP): 8 de Perfis
  (tambem regravados pela G7) e 4 escuros de Pessoas.

## O que fechou na rota real (sessao qa-r03)

- access-profiles.list/detail/create: modelos de sistema na aba Admin, detalhe
  nao editavel, criacao a partir de Secretaria persistida (d6264c5d).
- people.list/links/reload: diretorio real; detalhe com @; troca do @ da
  pessoa 9f04...0061 pela UI (qar04.profissional -> qa_r05.profissional),
  reload mantem e cooldown aplicado.
- invites.list: convite revogado 03e9c9d2 listado; passo 1 do novo convite com
  contextos e perfis de sistema.

## Gates abertos

| Aberto | Primeiro gate |
| --- | --- |
| invites.create/detail/resend/revoke pela UI | Chrome estavel (passos 2-4 nao concluidos por repintura); BE done por REST |
| students.link/edit/transfer pela UI | build novo com bf9c2f186 + Chrome; transfer positivo exige segunda unidade na mesma instituicao sintetica (estrutura) |
| access-models.list/filter/detail/edit/duplicate pela UI | rota real nao revisitada nesta rodada (BE done desde a R04) |
| internal-users.edit/suspend pela UI; internal-users.create | suspender o unico usuario interno derruba a sessao de teste; criar exige Edge Function com a API de administracao do Auth |
| people.create | resolvedor de identidade sem implementacao Supabase |
| people.list: clique no card nao abre o detalhe; abas nao filtram | code review do diretorio de Pessoas |
| @ de usuarios internos e edicao pela instituicao (Owner 12:15) | pendencia de modelo: identidade interna nao e public.people; contexto do app Admin |

## Dados sinteticos desta rodada

- convite 03e9c9d2 (revoked, e-mail sintetico) em `superadmin_internal_invitations`;
- person_handles: backfill de todas as pessoas (produto, nao lixo) e trocas de
  ec2a15a2 (qa_r05_teste) e 9f04...0061 (qa_r05.profissional) com ledger;
- institution_roles: 5afbe4a6 "Professor QA R05 v2" (inactive, is_system) e
  d6264c5d "Secretaria QA R05" (active, is_system) - apagar/inativar ao fim;
- child_group_links 8d766ca8 (crianca d0c4...0003 na turma 368a5cea, ends_at
  2026-12-15); vinculo de unidade d0c4...0005 revogado e reativado.

## Perguntas ao Owner

- P43: um modelo do sistema criado pelo Superadmin pode ser excluido? Hoje so
  inativa (delete protegido por desenho). Recomendo manter (inativar basta).
- P44: usuarios internos (realm interno) tambem tem @? Hoje o @ e de
  `public.people`; a identidade interna nao e pessoa. Recomendo @ interno
  na proxima rodada se ele quiser.
