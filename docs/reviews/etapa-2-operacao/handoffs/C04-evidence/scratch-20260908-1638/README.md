---
title: "C04 — preservação do scratch local de 08/09 16:38"
source: "I009 R01-C04; sessão e0191513-6656-4f3e-a0e8-753dd70bb590"
status: "preservado; recurso liberado"
generated_at: "2026-09-08T20:07:00-03:00"
timezone: "America/Sao_Paulo"
---

# O que é isto

Preservação exigida pela I009. São os arquivos que reconstroem, na íntegra, a
verificação local dos três candidatos SQL de Locais autorizados pela I008.

O container em si não existe mais (ver "Cleanup"). Estes arquivos são o que
sobrou, e são suficientes para repetir a execução inteira.

## O container

| Campo | Valor |
|---|---|
| Nome | `coelo-c04-scratch` |
| ID | `4bea596334959cb043dfae5eee68d853766c4705c3f3be0aac0fe0e937bf7c9c` |
| Imagem | `public.ecr.aws/supabase/postgres:17.6.1.165` |
| Porta | `55433:5432` |
| Volumes | nenhum |
| AutoRemove | sim (`--rm`) |
| Criado | 08/09 ~16:38:51 −03:00 |
| Removido por mim | 08/09 ~16:58 −03:00 |

Comando de criação, literal:

```
docker run --rm -d --name coelo-c04-scratch -e POSTGRES_PASSWORD=scratch \
  -p 55433:5432 public.ecr.aws/supabase/postgres:17.6.1.165
```

## Finalidade

Compilar e verificar o comportamento dos três candidatos da I008 em isolamento.

A razão de existir um container próprio foi **justamente não encostar** no
Supabase local compartilhado (`supabase_db_coelo_safe_...`), que estava de pé e
podia estar em uso por outra executora. Nenhum comando meu nomeou aquele
container em momento algum.

O que eu não sabia ao criar: que existia lease exclusiva C02 sobre banco local.
A I008 concedeu os três nomes de migration; eu li isso como autorização de
código e tratei a verificação local como parte de escrever o código. Foi leitura
minha, não concessão da I008.

## Bancos criados dentro dele

`c04scratch`, `c04run`, `c04run2`, `c04all`, `c04tap`, `c04tap2`, `c04tapall`.
Todos descartáveis, todos internos ao container.

## Os arquivos, na ordem em que foram executados

| Arquivo | Escrito às | Papel |
|---|---|---|
| `c04_compile_stubs.sql` | 16:39:27 | primeiros stubs, só para compilar os corpos plpgsql |
| `c04_body.sql` | 16:39:39 | corpo do pacote A, extraído da migration entre preflight e postflight |
| `c04_real_helpers.sql` | 16:40:23 | `normalize_v2`, `owner_v2` e `payload_v2` extraídos **literalmente** de `20260908031000` |
| `c04_harness.sql` | 16:44:05 | ator configurável no lugar da pilha de auth, mais as tabelas mínimas |
| `c04_behaviour.sql` | 16:44:05 | 26 verificações de editar e status |
| `c04_body_copy.sql` | 16:50:13 | corpo do pacote B |
| `c04_behaviour_copy.sql` | 16:50:50 | 17 verificações de copiar |
| `c04_body_schedule.sql` | 16:55:45 | corpo do pacote C |
| `c04_behaviour_schedule.sql` | 16:56:42 | 21 verificações de agenda |

Os horários são o mtime real de cada arquivo, não reconstrução.

## Como repetir

```
docker run --rm -d --name <nome> -e POSTGRES_PASSWORD=scratch -p <porta>:5432 \
  public.ecr.aws/supabase/postgres:17.6.1.165
createdb c04all
psql -d c04all -v ON_ERROR_STOP=1 -f c04_harness.sql -f c04_real_helpers.sql \
  -f c04_body.sql -f c04_body_copy.sql -f c04_body_schedule.sql
psql -d c04all -v ON_ERROR_STOP=1 -f c04_behaviour.sql -f c04_behaviour_copy.sql \
  -f c04_behaviour_schedule.sql
```

Para os pgTAP entregues, mesmo preparo mais uma instituição e uma unidade
semeadas, e então os três arquivos de
`packages/coelo_database/supabase/tests/superadmin_locations_*_v2_test.sql`.

**Não executar sem janela concedida pela C00.** Isto está aqui como evidência,
não como convite.

## Resultado registrado

| Suíte | Verificações | Resultado |
|---|---|---|
| comportamento — editar e status | 26 | verdes |
| comportamento — copiar | 17 | verdes |
| comportamento — agenda | 21 | verdes |
| pgTAP entregue — pacote A | 29 | verdes |
| pgTAP entregue — pacote B | 18 | verdes |
| pgTAP entregue — pacote C | 37 | verdes |

Zero falhas e zero erros na última execução dos três pacotes aplicados em ordem.

## O que não foi preservado

O filesystem do container. Ele tinha `--rm` e nenhum volume, então removê-lo
apagou o que havia dentro. Os logs do `psql` existiam só como saída de terminal;
o que sobrou deles está transcrito nas revisões 18, 19 e 20 do handoff, com as
contagens exatas.

Removi o container **antes** de ler a I009. Não foi contorno de ordem: a ordem
ainda não tinha sido lida por mim quando o cleanup aconteceu.

## Cleanup e release

Recurso liberado. Não existe container, imagem extra, volume ou porta reservada
por mim. `docker ps -a` estava vazio depois da remoção.
