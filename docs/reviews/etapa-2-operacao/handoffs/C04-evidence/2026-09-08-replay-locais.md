---
title: "C04 — runbook de replay dos tres pacotes de Locais"
source: "packages/coelo_database/migrations e supabase/tests desta worktree"
status: "pronto para janela nominal; nada aplicado por este executor"
generated_at: "2026-09-08T21:10:00-03:00"
timezone: "America/Sao_Paulo"
---

# Para que serve este documento

Os tres pacotes de Locais estao escritos, verificados localmente em container
descartavel e **nunca aplicados em lugar nenhum**. A execucao SQL esta suspensa
para mim desde a I009 e a janela e da C00.

Este runbook existe para que essa janela seja **um movimento**, e nao uma
reconstrucao. Quem aplicar nao precisa ler o meu handoff inteiro nem re-derivar
a ordem.

# O que ja esta pronto e o que falta

Pronto: SQL, testes pgTAP, cliente Dart (`coelo_api`), telas e testes de tela.
O cliente ja chama os cinco nomes; o teste
`apps/superadmin/test/features/rpc_definition_reach_test.dart` prova que as
cinco funcoes estao declaradas no repositorio.

Falta: aplicar. Nada mais.

# Pre-condicao

O pacote fundacao precisa estar aplicado antes:

```
packages/coelo_database/migrations/20260908031000_superadmin_location_catalog_v2.sql
```

Ele traz `superadmin_location_directory_v2`, `superadmin_location_detail_v2`,
`superadmin_location_create_v2` e a tabela
`app_private.superadmin_location_create_receipts`. Os tres pacotes abaixo
assumem tudo isso existindo.

Se a fundacao nao estiver aplicada, **pare**: aplicar so os tres deixa o
catalogo escrevendo sem ler.

# Ordem — os tres nao sao comutativos

| # | Arquivo | Cria | Depende de |
|---|---|---|---|
| 1 | `20260908190646_superadmin_locations_update_status_v2.sql` | `public.superadmin_location_update_v2`, `public.superadmin_location_set_status_v2`, `app_private.superadmin_location_locked_v2`, `app_private.superadmin_location_name_available_v2`, tabela `app_private.superadmin_location_write_receipts` | fundacao |
| 2 | `20260908190648_superadmin_locations_copy_v2.sql` | `public.superadmin_location_copy_v2`, tabela `app_private.superadmin_location_copy_lineage` | **pacote 1** |
| 3 | `20260908190650_superadmin_locations_schedule_v2.sql` | `public.superadmin_location_schedule_v2`, `public.superadmin_location_schedule_set_v2`, dois auxiliares `app_private`, tabela `public.activity_location_schedules` | **pacote 1** |

O pacote 2 **nao abre tabela de recibo propria**: ele amplia a allowlist de
verbo da tabela do pacote 1 para `('update','status','copy')`. Aplicar 2 antes
de 1 falha na hora, o que e o comportamento desejado.

O pacote 3 depende do 1 pelo lock de linha, nao pelos recibos.

# Como aplicar

Forward-only, um por vez, na ordem acima, conferindo entre um e outro. Nenhum
dos tres faz `drop` de nada; o unico caminho de volta e uma migration seguinte.

```bash
supabase db push --include-all
```

Se a janela for por `psql` nominal, o mesmo em tres transacoes separadas — cada
arquivo ja abre e fecha a sua.

# Como verificar depois

Os testes pgTAP acompanham, um por pacote:

```
packages/coelo_database/supabase/tests/superadmin_locations_update_status_v2_test.sql
packages/coelo_database/supabase/tests/superadmin_locations_copy_v2_test.sql
packages/coelo_database/supabase/tests/superadmin_locations_schedule_v2_test.sql
```

```bash
supabase test db
```

Uma asercao merece atencao porque **ja esteve errada**: o teste do pacote 2
confere que a copia nao abriu tabela de recibo propria comparando a lista
inteira de tabelas `app_private.superadmin_location_%receipts` com
`array['superadmin_location_create_receipts','superadmin_location_write_receipts']`.
A versao anterior afirmava "exatamente uma" e passava so porque o meu container
descartavel nunca criou a tabela da fundacao. Corrigida apos revisao da C00.

# O que a aplicacao destrava, e o que nao

Destrava `locations.edit`, `locations.status`, `locations.copy` e
`locations.schedule` **no servidor**.

**Nao** os torna alcancaveis na tela sozinha. A pagina de Locais deriva
`_canManage = canManage ?? canCreate` e o router passa
`canCreate: hasStructureMutationCapability()`, que e `false`. Com os pacotes
aplicados e a flag como esta, producao ganha leitura correta e as escritas
continuam fechadas na interface — que e a ordem certa: servidor primeiro, tela
depois.

# Verificacao local ja feita, e o que ela nao prova

Preservada em `C04-evidence/scratch-20260908-1638/`: 64 verificacoes de
comportamento e 84 asercoes pgTAP num container descartavel, com os stubs de
compilacao e os auxiliares reais que usei. O container foi removido.

Isso prova que os pacotes **fazem o que dizem** num Postgres limpo. Nao prova
nada sobre o remoto, que pode ter objetos que o HEAD canonico nao reproduz — e
exatamente a situacao da OQ-032 em Unidades. Por isso o replay e conferencia,
nao formalidade.
