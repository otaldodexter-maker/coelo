---
title: "Negativas comportamentais em SQL para a retirada de publicação do Acontece"
source: "packages/coelo_database/supabase/tests/happens_post_withdrawal_test.sql; packages/coelo_database/migrations/20260909133000_happens_post_withdrawal_v1.sql; packages/coelo_database/migrations/20260820182000_happens_publication_mvp.sql; packages/coelo_database/migrations/20260820182100_happens_media_security_closure.sql; packages/coelo_database/migrations/20260724152628_contextual_authorization_core.sql; execução local em container descartável em 2026-09-09"
status: "prova-local-verificada"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Acontece — retirada de publicação: negativas comportamentais

## Aviso de escopo

Esta é uma prova **LOCAL**, feita em um container Docker descartável criado e
removido dentro desta verificação. **Não é certificação ponta a ponta** e não é
prova de ambiente remoto. Nenhum recurso Supabase ou Cloudflare remoto foi
tocado, consultado ou alterado. Nenhum comando `git` foi executado na worktree.
Nenhuma migration foi alterada. O único arquivo de produto reescrito foi
`packages/coelo_database/supabase/tests/happens_post_withdrawal_test.sql`.

O que esta prova cobre: as duas correções de
`20260909133000_happens_post_withdrawal_v1.sql` passam a ter negativa
comportamental em SQL, exercitando as RPCs reais com fixtures reais, e o teste
demonstradamente fica vermelho contra as guardas anteriores.

## Motivo da reescrita

O arquivo anterior tinha 18 asserções, das quais 11 eram `position(... in
pg_get_functiondef(...))` e uma era existência de linha no catálogo de
permissões. Substring não prova comportamento e é exatamente o que o
coordenador de integração (D00) recusou ao reter o aceite do lote. Os dois
defeitos corrigidos nesta rodada são a prova disso:

- a guarda `target.management_version <> p_expected_version` mantinha o texto
  `expected_version_conflict` dentro da função mesmo quando um
  `p_expected_version` nulo fazia `<>` devolver NULL, a guarda não disparava e o
  lock otimista era dispensado em silêncio;
- `can_withdraw` mantinha o texto `happens.posts.remove` no arquivo da migration
  sem que a projeção do feed conferisse a capacidade — só a autoria.

Nenhuma das asserções antigas distinguia as duas situações.

## Ambiente

| Item | Valor |
| --- | --- |
| Imagem | `public.ecr.aws/supabase/postgres:17.6.1.165` (já presente localmente) |
| Container | `coelo-l01-pgtap`, descartável, **removido ao final** |
| Postgres | 17.6 |
| Papel de fixture | `supabase_admin` |
| Papel das chamadas RPC | `authenticated`, com `request.jwt.claim.sub` definido |
| pgTAP | `create extension pgtap with schema extensions` |
| Data | 2026-09-09 |

### Shims necessários antes das migrations

A imagem traz os schemas `auth` e `storage`, mas não os artefatos que GoTrue e
storage-api criam em runtime. Sem eles,
`20260820182000_happens_publication_mvp.sql` falha ao registrar o bucket
`coelo-happens-mvp`. Foram criados, como `supabase_admin`:

- `auth.jwt()` (a imagem já traz `auth.uid()`, lendo `request.jwt.claim.sub`);
- `storage.buckets` e `storage.objects`;
- `storage.foldername()`, `storage.filename()`, `storage.extension()`.

Os shims vivem apenas no container e **não** foram gravados no repositório.

## Migrations aplicadas

Replay direto por `psql`, um arquivo por transação, `--single-transaction` e
`ON_ERROR_STOP=1`, em ordem de nome, sobre os 170 arquivos de
`packages/coelo_database/migrations`.

- **93 aplicaram**, **77 falharam**.
- As falhas são de domínios fora deste recorte (Formulários, Child Safety,
  Import/Export, Avisos/`pg_cron`, Chat, e as que dependem em cadeia dessas).
  Nenhuma delas bloqueia o Acontece.
- As três que importam aplicaram limpas, sem erro:
  - `20260820182000_happens_publication_mvp.sql`
  - `20260820182100_happens_media_security_closure.sql`
  - `20260909133000_happens_post_withdrawal_v1.sql`
- Verificado após o replay: existem
  `public.withdraw_happens_post(uuid,uuid,bigint,text)`,
  `public.list_visible_happens_posts(uuid,uuid,uuid,integer)`,
  `app_private.happens_actor(uuid,text,uuid,uuid)`,
  `app_private.has_institution_permission(uuid,text,uuid,uuid,boolean)`, as três
  colunas de retirada em `public.posts` e a permissão `happens.posts.remove`.

Observação honesta: o número de migrations aplicadas ficou em 93, e não nos ~122
citados na receita reaproveitada desta rodada. A diferença está toda em domínios
fora do recorte; não afeta o Acontece nem os resultados abaixo, mas fica
registrada em vez de arredondada.

## Comandos

```bash
docker run -d --name coelo-l01-pgtap -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  public.ecr.aws/supabase/postgres:17.6.1.165

# shims de auth/storage
docker exec coelo-l01-pgtap psql -U supabase_admin -d postgres \
  -v ON_ERROR_STOP=1 --single-transaction -f /tmp/00_shims.sql

# replay das migrations, um arquivo por transacao, em ordem de nome
for f in $(ls /tmp/migrations/*.sql | sort); do
  psql -U supabase_admin -d postgres -q -v ON_ERROR_STOP=1 \
    --single-transaction -f "$f"
done

# teste
docker exec coelo-l01-pgtap psql -U supabase_admin -d postgres -Atq -f /tmp/t.sql

docker rm -f coelo-l01-pgtap
```

## Números reais

```
1..32
ok 1 .. ok 32
```

**32 planejadas, 32 executadas, 32 `ok`, 0 `not ok`.** Sem linha
`# Looks like you planned/failed`.

O teste tem 7 asserções estruturais (colunas, `security definer`,
`search_path=""`, `authenticated` executa, `anon` não executa) e 25
comportamentais.

## Resultado item a item

| # | Asserção | Resultado |
| --- | --- | --- |
| 1-3 | colunas `withdrawn_at`, `withdrawn_by_person_id`, `withdrawal_reason` | ok |
| 4 | comando e feed são `security definer` | ok |
| 5 | comando e feed fixam `search_path=""` | ok |
| 6 | `authenticated` executa os dois contratos | ok |
| 7 | `anon` não executa nenhum dos dois | ok |
| 8 | o feed projeta `post_id` | ok |
| 9 | o feed projeta `management_version` real (fixture nasce em 2, não no default 1) | ok |
| 10 | **autor SEM `happens.posts.remove` recebe `can_withdraw = false`** | ok |
| 11 | **o mesmo autor COM `happens.posts.remove` recebe `can_withdraw = true`** | ok |
| 12 | segundo ator, não autor, COM a capacidade, recebe `can_withdraw = false` | ok |
| 13 | **versão nula é recusada com `40001:expected_version_conflict`** | ok |
| 14 | **a chamada recusada deixa a publicação intacta** (`withdrawn_at` nulo, versão 2, status `published`) | ok |
| 15 | versão desatualizada é recusada com `40001:expected_version_conflict` | ok |
| 16 | não autor com a capacidade é recusado com `42501:happens_permission_denied` | ok |
| 17 | rascunho é recusado com `23514:post_not_published` | ok |
| 18 | motivo acima de 280 caracteres é recusado com `23514:reason_too_long` | ok |
| 19 | a recusa por motivo longo deixa a publicação intacta | ok |
| 20 | versão correta retira e devolve a nova versão | ok |
| 21 | `withdrawn_at` preenchido, `withdrawn_by_person_id` = autor, versão 2→3, `status` inalterado | ok |
| 22 | motivo com espaços é aparado antes de gravar | ok |
| 23 | a publicação retirada some do feed | ok |
| 24 | segunda chamada é eco idempotente, sem erro | ok |
| 25 | o eco não incrementa a versão nem reescreve o motivo | ok |
| 26 | exatamente **uma** linha `post_withdrawn` em `app_private.happens_publication_audit` após as duas chamadas | ok |
| 27 | a linha de auditoria carrega ator e `request_id` da chamada efetiva | ok |
| 28 | retirada é soft: linha do post, `media_links` e `media_assets` continuam existindo | ok |
| 29-30 | motivo em branco retira e é normalizado para nulo | ok |
| 31 | o feed da instituição vizinha não está trivialmente vazio | ok |
| 32 | o feed da instituição vizinha não devolve publicação de outra instituição | ok |

As negativas não usam `throws_ok`: cada chamada passa por um auxiliar
`pg_temp.try_withdraw` que troca para o papel `authenticated`, apresenta o `sub`
do JWT e devolve `sqlstate:mensagem`. A asserção compara o par observado
(`40001:expected_version_conflict`, `42501:happens_permission_denied`,
`23514:post_not_published`, `23514:reason_too_long`) — comportamento, não texto
de código-fonte.

## Verificação de mutação: o teste é barreira real

Para provar que as asserções não passam por acaso, as duas guardas foram
regredidas **somente dentro do container** (a migration do repositório não foi
tocada): `is distinct from` mais a checagem de nulo voltaram a `<>`, e
`can_withdraw` voltou a projetar só autoria. Com as guardas pré-correção:

```
not ok 10 - the author without happens.posts.remove is offered no withdrawal
not ok 13 - a null expected version is a conflict, not a silently waived optimistic lock
not ok 14 - the rejected null-version call leaves the publication untouched
not ok 15 - a stale expected version is refused
not ok 22 - the reason is trimmed before it is stored
not ok 25 - the idempotent echo neither bumps the version nor rewrites the reason
not ok 27 - the audit row carries the actor and the request_id of the effective call
# Looks like you failed 7 tests of 32
```

Leitura: a 10 é a negativa direta da segunda correção; a 13 e a 14 são a
negativa direta da primeira — com `<>`, a chamada de versão nula **realmente
retirou a publicação**. As demais (15, 22, 25, 27) caem em cascata porque a
publicação já estava retirada quando o teste chegou nelas. Restaurada a
migration verdadeira no mesmo container, o teste volta a **32 `ok`**.

## O que esta prova NÃO cobre

- Não é ponta a ponta: nenhuma tela Flutter, rota, cliente Dart ou chamada real
  via PostgREST foi exercitada. O que foi provado é o contrato de servidor.
- Não prova o ambiente remoto. Nada foi aplicado em Supabase ou Cloudflare.
- Não cobre `public.list_visible_happens_feed` (feed misto de
  `20260909134000_happens_mixed_feed_withdrawal_v1.sql`). Essa função tem a
  mesma expressão de `can_withdraw` e o mesmo predicado `withdrawn_at is null`,
  mas exercitá-la exige a cadeia de Circulares, que não aplica limpa neste
  replay parcial. Fica registrado como cobertura ausente, não como cobertura
  presumida.
- Não cobre concorrência real (dois `withdraw` simultâneos disputando o `for
  update`): o teste roda numa única transação.
- Não cobre papéis de audiência família/estudante; as fixtures usam `teacher` e
  audiência `school_staff`.
- 77 das 170 migrations não aplicam neste replay local. O banco usado não é uma
  réplica fiel do remoto; é o mínimo suficiente para o Acontece.
