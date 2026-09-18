---
title: "Revisão dos seis candidatos SQL de publicacoes-midia (L01 3697dd49e)"
source: "Revisão de conteúdo pedida pelo coordenador da rodada noturna de 09-10/09/2026; branch codex/e2-r02-l01-publicacoes em 3697dd49e"
status: "review-only; nenhuma migration aplicada; nenhuma mutação remota executada"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Revisão dos seis candidatos SQL

> **Nota de carimbo (10/09).** Este documento foi escrito citando os carimbos
> **originais** dos candidatos em `codex/e2-r02-l01-publicacoes`, da família
> `2026090913xxxx`. Ao serem serializados na fila, os seis foram renumerados
> para `2026090921xxxx`, para ficarem depois da cauda `20260909210000`; a ordem
> relativa foi preservada e só o prefixo mudou. As referências abaixo já estão
> nos **nomes finais**, que são os que existem em
> `packages/coelo_database/migrations/`. O mapa é `131000→211000`,
> `132000→212000`, `133000→213000`, `134000→214000`, `135000→215000` e
> `136000→216000`. Os nomes antigos não existem mais em lugar nenhum: quem
> seguisse este documento como estava não encontraria arquivo.



Revisão de leitura, contra a checklist pedida pelo coordenador: `security definer`
com `search_path` vazio, `revoke` antes do `grant`, autorização conferindo ator,
escopo e visibilidade no servidor, negação mascarada sem vazar existência, e
existência de teste.

Os seis vivem em `packages/coelo_database/migrations/`, que é **rastreado** (180
arquivos em `dev`). O diretório ignorado é apenas
`packages/coelo_database/supabase/migrations/`. Integrar os candidatos a `dev` não
aplica nada em lugar nenhum: apenas os torna visíveis e revisáveis.

## Resultado por candidato

| Candidato | Funções | definer / search_path | revoke → grant | Suíte |
| --- | ---: | --- | --- | --- |
| `20260909211000_now_publication_expiry_transition_v1` | 4 | 4 / 4 | sim | `now_publication_expiry_transition_test.sql`, 18 asserções |
| `20260909212000_circulars_media_private_r2_v1` | 4 | ok | sim | `circulars_media_private_r2_v1_test.sql`, 38 asserções |
| `20260909213000_happens_post_withdrawal_v1` | 1 | ok | sim | `happens_post_withdrawal_test.sql`, 30 asserções |
| `20260909214000_happens_mixed_feed_withdrawal_v1` | 1 | 1 / 1 | não se aplica | **nenhuma** |
| `20260909215000_private_media_catalog_chat_kind_v1` | 2 | 2 / 2 | revoke, sem grant novo | `private_media_catalog_chat_kind_v1_test.sql`, 40 asserções |
| `20260909216000_moments_feed_and_withdrawal_v1` | 4 | 3 / 4 | sim | `moments_feed_and_withdrawal_test.sql`, 20 asserções |

## Pontos que pareciam defeito e não são

`20260909214000` não traz `revoke` nem `grant`. Está correto: é um
`create or replace` de `public.list_visible_happens_feed` com assinatura
inalterada, então os grants existentes são preservados. O cabeçalho do arquivo
declara isso explicitamente e explica por que não há `drop`.

`20260909215000` não cria nenhum `grant`. Está correto e documentado no próprio
arquivo: as duas funções são `app_private`, chamadas por gatilho e por funções
`definer`, e o autor registra deliberadamente que nenhum grant novo é criado.

`20260909216000` tem 4 funções e só 3 `security definer`. A quarta é
`app_private.moments_audience_matches_role`, um predicado
`language sql immutable` com `set search_path = ''` e
`revoke all ... from public, anon, authenticated, service_role`. Predicado puro
não precisa de direitos de definidor; a escolha está certa.

## Defeito encontrado — vazamento de existência em `withdraw_happens_post`

Em `20260909213000_happens_post_withdrawal_v1.sql`, `public.withdraw_happens_post`
levanta `post_not_found` **antes** de qualquer verificação de ator:

    select * into target from public.posts where id=p_post_id for update;
    if not found then raise no_data_found using message='post_not_found'; end if;

    select * into actor from app_private.happens_actor(...);
    if target.author_person_id<>actor.person_id then
      raise insufficient_privilege using message='happens_permission_denied';

Um ator autenticado distingue "existe mas não é seu" de "não existe", inclusive
para publicações de outro tenant. É um oráculo de existência, e contraria a
invariante do projeto de não entregar informação antes da autorização.

**A correção é de uma linha e o padrão certo está no arquivo irmão.** Em
`20260909216000`, `public.withdraw_moment` usa a MESMA mensagem
`publication_not_authorized` para "não encontrado" e para "não é o autor",
mascarando a existência. `20260909213000` deve fazer o mesmo: unificar a negação
sob `happens_permission_denied`, ou mover o `not found` para depois da
verificação de ator.

Severidade prática: baixa, porque exige estar autenticado e adivinhar um UUID v4,
o que torna a enumeração inviável. Severidade de invariante: é justamente o tipo
de distinção que `20260821190000_circulars_production.sql` evita de propósito,
mascarando toda negação como `circular_not_found`.

## Lacuna de prova — `20260909214000` sem suíte

É o único dos seis sem teste. `circulars_production_test.sql` não muda entre a
base e a branch autoral e não contém nenhuma asserção sobre `withdrawn`,
`can_withdraw` ou `management_version`.

O candidato copia "fielmente" um corpo grande de função e altera duas coisas: o
predicado de retirada e dois campos novos no payload de post. Cópia fiel de corpo
grande sem teste é exatamente onde uma divergência silenciosa se esconde, e esta
função é a que alimenta o feed misto de Acontece, que já está integrado e em uso.
Recomendo exigir uma suíte mínima antes da aplicação: publicação retirada não
aparece no feed misto, `can_withdraw` verdadeiro só para autor com capacidade no
escopo, e `management_version` projetado.

## Observação de contrato de mídia, para decisão

`public.authorize_circular_media_read` está no `grant ... to authenticated` e
devolve `bucket_id` e `object_key`. `public.authorize_moments_media_read`, no
candidato `20260909216000`, devolve `object_key` e `mime_type`, sem bucket — um
pouco melhor, mas ainda entrega a chave ao cliente.

As duas precisam ser chamáveis pelo usuário, porque a Edge Function usa o cliente
do usuário para autorizar antes de assinar. Nenhuma concede acesso: os buckets são
privados e sem assinatura nada é lido. Mas a ADR 0032 diz que bucket, chave e
provedor não vão ao cliente. Trocar o par por um identificador opaco muda o
contrato entre a RPC e a Edge Function e é decisão do Owner, não correção de
executor.

## O que esta revisão não afirma

Que as funções estão aplicadas em produção. Nada aqui foi aplicado, nenhuma
mutação remota foi executada e este grupo não recebeu autorização nominal. As
contagens de asserção são leitura estática dos arquivos; as suítes não foram
executadas contra banco nesta revisão.
