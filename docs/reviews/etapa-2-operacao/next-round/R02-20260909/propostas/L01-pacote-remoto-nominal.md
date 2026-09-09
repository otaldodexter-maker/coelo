---
title: "L01 — pacote remoto nominal da rodada E2 R02"
source: "CONTRATO.md; assignments/L01.md (L00 rev.1); decisions/0032-mvp-private-media-r2.md; provas locais desta rodada"
status: "proposta-para-serializacao-d00; nao-aplicado"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Pacote remoto nominal — L01

Este documento descreve, de forma revisável e concreta, **o que precisaria ser
aplicado** para que as ações do recorte L01 possam ser certificadas ponta a ponta.

**Nada aqui foi aplicado.** Todo Supabase e Cloudflare remoto do Coelo é produção.
Nenhuma migration, função ou segredo desta rodada foi enviado a qualquer ambiente
remoto. A serialização e a aplicação pertencem a D00, sob autorização nominal do
Owner para o pacote exato. Credencial ou MCP disponível não autoriza mutação.

Branch de origem: `codex/e2-r02-l01-publicacoes`, publicada em `origin`.

## Conteúdo do pacote, na ordem de aplicação

A ordem abaixo é a ordem lexical dos arquivos, que também é a ordem de dependência.
Todos são **forward-only** e nenhum edita migration existente.

| # | Arquivo | Ação | SHA |
| --- | --- | --- | --- |
| 1 | `packages/coelo_database/migrations/20260909130000_moments_feed_and_withdrawal_v1.sql` | `momentos.view` e `momentos.remove` | `e02b5f1b` |
| 2 | `packages/coelo_database/migrations/20260909131000_now_publication_expiry_transition_v1.sql` | `agora.expire` | `c8f8f379` |
| 3 | `packages/coelo_database/migrations/20260909132000_circulars_media_private_r2_v1.sql` | Circulares em R2 privado (ADR 0032) | `9a3fb6b5` |
| 4 | `packages/coelo_database/migrations/20260909133000_happens_post_withdrawal_v1.sql` | `acontece.remove` | `8b83784e` |

Não há dependência cruzada entre os quatro: cada um toca o esquema de um domínio
distinto. Podem ser aplicados isoladamente, e a falha de um não exige reverter os
outros.

### Função de borda a implantar

`packages/coelo_database/supabase/functions/circular-media/` (SHA `9a3fb6b5`),
**depois** da migration 3. A função lê `storage_provider` e degrada para o ramo
legado Supabase Storage quando a coluna ainda não conhece `'r2'`, então a ordem
inversa também não quebra conteúdo publicado — mas é a ordem migration → função
que efetivamente habilita o R2.

### Segredos server-side exigidos pela função

`COELO_R2_ENDPOINT`, `COELO_R2_REGION`, `COELO_R2_ACCESS_KEY_ID` e
`COELO_R2_SECRET_ACCESS_KEY`, apenas no ambiente de Edge Functions. Nenhum deles
entra no cliente Flutter, em bundle, log, URL ou repositório. Exigem autorização
nominal do Owner e não foram configurados por L01.

### Pré-condições de infraestrutura, não verificadas por L01

Os buckets R2 privados `coelo-media-prod` (imagem e vídeo) e `coelo-documents-prod`
(PDF) precisam existir, estar privados e ter token S3 com escopo mínimo de PUT, GET
e DELETE apenas neles. **O estado remoto não foi inspecionado nesta rodada.**

## Capacidades novas catalogadas

As migrations 1 e 4 inserem duas capacidades em `public.institution_permissions`:
`moments.publications.remove` e `happens.posts.remove`. Catalogar não concede: nenhum
perfil recebe a capacidade automaticamente, e o comportamento permanece deny-by-default
até que a atribuição seja feita deliberadamente. Isso é uma decisão de produto e de
segurança que pertence ao Owner e a D04, não a L01.

## Superfície de risco, por item

1. **`list_visible_happens_posts` muda o tipo de retorno.** É a única mudança
   incompatível do pacote. Exigiu `drop` + `create` porque PostgreSQL não permite
   alterar colunas de saída com `create or replace`. Entre o `drop` e o `create`, dentro
   da mesma transação, a função não existe. O único consumidor é
   `SupabasePrincipalHappensFeedRepository`, que já lê as colunas novas de forma
   tolerante. Um cliente antigo continua funcionando: as colunas anteriores foram
   todas preservadas, apenas acrescentaram-se `post_id`, `management_version` e
   `can_withdraw`.
2. **`claim_stale_circular_media(integer)`** também foi recriada com `drop` + `create`,
   mantendo a mesma assinatura de argumentos e acrescentando duas colunas de saída.
   O único consumidor é a função de borda `circular-media`, que é implantada junto.
3. **Constraints novas de Circulares são `NOT VALID` de propósito.** O acervo legado
   não é revalidado, não é migrado e continua legível. Migrar bytes antigos para o R2
   é decisão e pacote separados.
4. **Nenhum grant foi alargado.** Todas as funções recriadas mantêm exatamente os
   `revoke` e `grant` originais. As funções novas seguem o padrão do domínio:
   `authenticated` para ação de usuário, `service_role` para varredura de sistema.
5. **Nenhuma linha é apagada por este pacote.** As duas retiradas são soft e a
   expiração do Agora é transição de estado; nenhuma delas remove publicação, mídia,
   vínculo ou trilha, e nenhuma altera política de retenção.

## Provas locais já produzidas

Todas em banco descartável, nunca remoto. **Prova local não é certificação ponta a
ponta** e não autoriza aplicação em produção.

| Item | Prova |
| --- | --- |
| `acontece.remove` | Postgres 17.6 descartável; pgTAP 53/53 no contrato existente e 18/18 no novo após corrigir uma assertiva do próprio teste; 15 de 15 itens comportamentais provados, incluindo retirada soft preservando post, links e assets, uma única linha de auditoria, replay idempotente, conflito de versão, recusa de rascunho e `can_withdraw` verdadeiro só para o autor, provado contra um segundo ator que tinha a capacidade |
| `agora.expire` | Postgres 17.6 descartável; pgTAP 16/16; sonda com 5 publicações sintéticas: 2 transicionadas no escopo, 1 global, 0 na repetição (idempotente), vigente e rascunho intactos, 3 linhas de auditoria |
| `momentos.view` e `momentos.remove` | Postgres com pgTAP 23/23; smoke funcional cobrindo feed do autor e do consumidor, negação a não autor, replay por `request_id`, ausência de segunda linha de auditoria, retirada soft preservando assets e links, negação de mídia após a retirada, conflito de versão, recusa de rascunho e paginação por cursor |
| Circulares em R2 | Deno 27 aprovados e 0 falhas na função de borda; pgTAP novo 46/46; o contrato anterior de Circulares continua 60/60 depois da migration |

### Limitação honesta do harness local

A cadeia completa de migrations do repositório **não** aplica limpa por replay direto
via `psql`: 122 de 168 aplicaram e 46 falharam, todas em domínios fora deste recorte
(Formulários, Child Safety, Notices, Import/Export, Chat v2, Assessments), com
`auth.jwt()` e o schema `storage` simulados por shim. As migrations deste pacote
aplicaram limpas sobre suas dependências reais. **D00 deve reexecutar no perfil
nominal** (`scripts/Invoke-SafeLocalMigrationReplay.ps1`, que sobe a stack completa
pelo Supabase CLI) antes de considerar o pacote pronto.

## O que continua sem prova e por quê

- **Nada foi exercitado contra R2 real, Supabase real ou o aplicativo em execução.**
  Não há E2E em nenhuma das quatro ações.
- RLS através do PostREST não foi testada: as fixtures entraram como superusuário e
  o que foi validado é a autorização interna às funções `security definer`.
- O conflito de versão foi provado em série, não sob concorrência real.
- Acesso cruzado entre tenants não foi exercitado no harness local.
- A varredura de expiração do Agora **não tem agendador implantado**: sem pg_cron,
  função agendada ou cron trigger de Worker, a transição só ocorre por chamada
  autorizada. Isso é decisão de infraestrutura, não lacuna de contrato.

## Recuperação

Cada item é revertido por uma migration nova de compensação, nunca por edição ou
remoção do arquivo aplicado:

- retirada do Acontece e de Momentos: recriar a função de leitura na forma anterior e
  revogar a execução das funções de retirada. As colunas podem permanecer: são
  aditivas, anuláveis, e nenhuma linha existente as usa.
- expiração do Agora: revogar a execução das duas funções. Publicações já
  transicionadas para `expired` continuam corretas, porque já estavam vencidas pelo
  filtro temporal que sempre existiu.
- Circulares em R2: reimplantar a versão anterior da função de borda e devolver o
  `default` de `storage_provider` para `'supabase'`. Ativos já gravados em R2
  precisariam de decisão do Owner; enquanto o `CHECK` aceitar os dois provedores, eles
  continuam válidos e legíveis.

## Pendências que este pacote deliberadamente não resolve

- Não existe um gateway de mídia único: há cinco funções de borda por domínio, e
  `happens-media` e `now-media` continuam em Supabase Storage. Unificá-las é maior
  que esta rodada e não foi tentado, para não criar plataforma por feature.
- `MediaUploadGateway` continua sem implementação de produção.
- `media_delivery_instances` e Cloudflare Stream não existem no repositório; a
  invariante de cópia HOT do Agora por até 24 horas não tem base implementada.
- `media_bindings` continua acoplada a Formulários e não serve como tabela de usos
  genérica de Publicações.
- Checksum declarado pelo cliente, dimensões, remoção de EXIF e política de retenção
  por finalidade continuam abertos no caminho de Circulares.
