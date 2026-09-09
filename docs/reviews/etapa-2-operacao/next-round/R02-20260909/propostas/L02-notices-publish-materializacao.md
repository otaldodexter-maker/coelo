---
title: "Pacote revisável — materialização e congelamento de audiência em notices.publish (L02)"
source: "docs/superpowers/specs/2026-08-05-superadmin-notices-mvp-design.md; packages/coelo_database/migrations/20260812003000_notices_production.sql; 20260820212340_notice_publication_worker_runtime.sql; 20260820220500_notice_publication_receipts_versioning.sql; 20260901185008_superadmin_internal_notices_v2.sql"
status: "proposto-nao-implementado"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# `notices.publish` — materialização e congelamento de audiência

Etapa 2 → `apps/superadmin` → menu Comunicação → tela Avisos → subtela Publicar →
`notices.publish`. Emissor L02, dono do domínio de notices nesta rodada.

Isto é um **pacote revisável, não implementado**. Nenhuma linha de SQL foi escrita
nem aplicada por causa dele. Escrevo o diagnóstico e a decisão que ele exige porque
a mudança correta é acoplada e eu não tenho como prová-la nesta máquina.

## 1. A divergência, verificada no código

A spec exige, na seção de ciclo de vida: *"Publicar move rascunho para agendado e
enfileira a materialização. Ao alcançar o início, o worker cria os recibos de
audiência e só ativa após concluir todo o job."* E, em tenant/segurança: a audiência
é *"resolvida server-side e congelada ao publicar"*, com cada geração pertencendo ao
`publication_job_id` mais a versão congelada.

O que existe hoje:

- `public.superadmin_notice_publish_v2` (`20260901185008`, bloco de ativação) calcula
  `next_status := case when starts_at > clock_timestamp() then 'scheduled' else 'active' end`
  e grava direto. **Não insere linha em `app_private.notice_publication_jobs`** e
  **não congela audiência** em lugar nenhum.
- `app_private.superadmin_notice_json` conta `reach`, `delivered_count`,
  `viewed_count` e `accepted_count` sobre `public.notice_receipts` **sem filtrar por
  geração de publicação**. Republicar mistura destinatários e métricas de gerações
  diferentes, que é exatamente o que a spec proíbe.

O que já existe e está pronto para ser usado:

- `app_private.notice_publication_jobs` tem `notice_version bigint`,
  `audience_snapshot jsonb`, `state`, `cursor_key`, `resolved_count` e
  `unique(notice_id, notice_version)` — ou seja, a tabela **já foi desenhada** para
  congelar audiência por geração.
- `app_private.run_notice_publication_job` e
  `app_private.materialize_notice_publication_job` (`20260820220500`) materializam
  recibos por job, com versionamento.
- O worker está agendado por `pg_cron` em `20260820212340`, com wrappers públicos
  concedidos somente a `service_role`.

## 2. Por que as duas metades são acopladas, e por que eu não a implementei

A tentação é entregar só a metade segura: enfileirar o job com a audiência congelada
e deixar a transição de status como está. **Isso não funciona.**

`app_private.run_notice_publication_job` exige `notice.status = 'scheduled'` para
processar o job, e é ele quem promove o aviso a `active` ao concluir. Se
`publish_v2` continuar gravando `active` direto e ainda assim enfileirar um job, o
worker encontra um aviso que não está `scheduled`, e o job não avança — fica parado
ou falha, acumulando tentativas.

Portanto a mudança correta é atômica e tem três partes indissociáveis:

1. `publish_v2` passa a gravar **sempre** `scheduled`, nunca `active` direto.
2. `publish_v2` insere `notice_publication_jobs(notice_id, notice_version,
   audience_snapshot)` na mesma transação, com `notice_version = management_version + 1`
   e `audience_snapshot = platform_notices.audience_json` congelado naquele instante.
3. `superadmin_notice_json` passa a calcular métricas restritas à geração corrente,
   juntando `notice_receipts` com o `publication_job_id` da última publicação.

## 3. O risco que exige decisão, e não é meu para tomar

Depois dessa mudança, **um aviso só fica ativo se o worker rodar**. Hoje um aviso
com `starts_at` no passado fica ativo imediatamente, de forma síncrona, dentro da
própria chamada de publicação. Depois, a ativação passa a depender de:

- `pg_cron` estar instalado e a agenda `coelo-notice-publication-worker` viva no
  ambiente de destino;
- o processo `service_role` que consome `claim_notice_publication_jobs_for_worker`
  estar de fato em execução.

Não consigo verificar nenhuma das duas coisas: o remoto é produção e eu não tenho
autorização de aplicação nem de inspeção, e não há runner de Postgres nesta máquina.
Se o worker não estiver rodando no destino, essa mudança transforma "publica na hora"
em "nunca publica" — uma regressão funcional silenciosa e visível ao cliente.

Por isso **não implementei**. Entregar essa migration às cegas seria trocar uma
divergência de spec conhecida e documentada por um risco de indisponibilidade não
medido, decidido por mim sozinho.

## 4. O que peço, e para quem

Para **D00**, dono da serialização e da aplicação remota, antes de qualquer código:

1. Confirmar se `pg_cron` está instalado no destino e se a agenda
   `coelo-notice-publication-worker` está ativa e executando.
2. Confirmar se existe processo `service_role` consumindo os wrappers do worker.

Se as duas respostas forem sim, implemento as três partes da seção 2 como migration
forward-only, com pgTAP cobrindo: publicação sempre em `scheduled`; job criado com a
audiência congelada; `unique(notice_id, notice_version)` impedindo geração duplicada;
worker promovendo a `active` só ao concluir; e métricas restritas à geração corrente.

Se alguma resposta for não, a decisão correta é **manter a divergência documentada**
e tratá-la como pendência de plataforma, não de front-end — porque o desenho da spec
pressupõe um worker operante que o ambiente ainda não garante.

## 5. O que NÃO é problema, corrigindo um apontamento meu anterior

Na revisão 3 do meu handoff eu listei como divergência que o cliente ofereceria as
dimensões de audiência `role` e `plan`, que o validador do servidor rejeita. **Isso
está errado e eu retiro o apontamento.** Verifiquei em
`notice_form_controller.dart`: `NoticeAudience.role` é mapeado para
`NoticeAudienceDimension.platform`, e nenhum caminho da UI emite `role` ou `plan`
como dimensão de regra. Os dois valores existem no enum `NoticeAudienceDimension` e
nunca são usados — é superfície morta do enum, não um contrato divergente entre
cliente e servidor. Vale limpar algum dia; não é defeito de comportamento e não
retém nenhum aceite.
