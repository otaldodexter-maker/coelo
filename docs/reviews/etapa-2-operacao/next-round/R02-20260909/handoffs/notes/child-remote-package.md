---
title: "D03 — pacote nominal remoto CHILD-READ01"
source: "D00 r11; contrato CHILD-READ01 de 2026-09-08; child-envelope-prerequisite.sql; migration 20260908051500; backend-gates.md"
status: "proposal-only-awaiting-d00-review-and-explicit-remote-authorization"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Pacote proposto

Alvo nominal: projeto Supabase de produção `coelo`, ref
`evvbomzejfijozbtgvpt`. A autorização D00 r11 cobre somente a preparação
revisável destes dois arquivos. Ela **não** concede autorização para executar o
SQL, chamar a RPC, usar uma sessão real ou alterar produção. Este documento não
declara o pacote recebido, aprovado ou aplicado.

O arquivo `child-remote-package.sql` propõe uma única transação para resolver a
dependência do envelope e criar o reader CHILD. Ele contém exatamente um
`begin;` e um `commit;`. Dentro deles, preserva os dois corpos-fonte e remove
somente o `begin;` e o `commit;` de nível superior de cada fonte:

1. `child-envelope-prerequisite.sql` confere o MD5 remoto antigo
   `b89d2dc22f032a1c3f155a77f0eaaf08`, metadata, owner e ACL do helper; instala
   o corpo canônico; e confere o MD5 novo
   `bfce7b85b8d5d43e93e5d3fba3a66dc8`.
2. `20260908051500_superadmin_child_context_directory_v2.sql` repete seus
   preflights de helpers, tipo de Auth, schema físico, constraints, matriz
   Owner-only `people.read` e ausência do gateway. Depois cria a função, fixa
   owner `postgres`, revoga `public`, `anon`, `authenticated` e `service_role`,
   e concede `EXECUTE` somente a `authenticated`.

Os advisory locks, timeouts, preflights, corpo das funções, pins, comentários e
ACLs das fontes foram mantidos. O postflight do envelope ocorre dentro da mesma
transação antes do preflight CHILD. Depois da região canônica LF da migration e
antes do commit, o pacote acrescenta um único `DO
$child_package_postflight$`. Esse guard de catálogo é próprio do pacote e não
altera a migration de produto: confere corpo, metadata e ACL resultantes do
gateway para impedir que um default ACL conceda acesso a outro role. O `DO` foi
preparado por revisão estática e ainda não foi executado.

Se qualquer preflight, DDL, ACL ou postflight falhar antes do commit, o
PostgreSQL desfaz toda a transação, inclusive a troca do helper. Depois de um
commit bem-sucedido não existe rollback destrutivo autorizado; qualquer
reversão exigiria outro pacote forward-only nominal, revisado contra o estado
então observado.

## Proveniência e hashes

| Fonte | Proveniência | SHA-256 raw do arquivo | Corpo sem wrapper, SHA-256 raw | Corpo sem wrapper, SHA-256 LF |
| --- | --- | --- | --- | --- |
| `handoffs/notes/child-envelope-prerequisite.sql` | commit autor `f0a97c1d8f9e1dc588f61bcd18e284081842bf06`; pin integrado recebido por D00 em r8 | `DB4D45728FDA94A041F7DDBFF0A3AA872402FF36DAE113F784DEC7302B336C03` | `E6853F0F452783A3CC78C6C0AA8F8F9C4529DCDE85E3B72B9FEEA5DB131E22C1` | `E6853F0F452783A3CC78C6C0AA8F8F9C4529DCDE85E3B72B9FEEA5DB131E22C1` |
| `packages/coelo_database/migrations/20260908051500_superadmin_child_context_directory_v2.sql` | candidato preservado em `14def90d3d2f7adbaf7289406183d3982a4580bf` com origem `2173cbd0` | `DE1EFEB5C3088560EFAA02894FF58FA8E019CD0116271ADF013F4D9923E92572` | `3322B2899ADA38BDE922F7564321F37CF81526E155FCC26A947681E28AF44BD5` | `E950A732811C7AAFC796AAE978C6666CA29B3FDA01D45FDE6DE5461374C817E8` |
| `docs/superpowers/specs/2026-09-08-child-directory-read-contract.md` | contrato CHILD-READ01, commit `eb6ff0bdaf4fd6cfd5798204d296983394a86eda` | `6FB45473F77070897A190B91F5FD1A1361D08350C0072CBE4BF6A7BE359B48B8` | n/a | n/a |
| `docs/reviews/evidence/etapa-2/estruturas/2026-09-08-child-directory-dto.md` | projeção local do contrato | `56A7239A5DBF7CD5838EAD5C092667A577F055D73EE347BCEE79B76F8A763BF7` | n/a | n/a |

Pacote composto canônico: `child-remote-package.sql`, UTF-8 sem BOM, somente LF,
22.264 bytes, SHA-256
`1193649F37C15EAA964A7486B83014806BC76C70AB4BD04537908CB57EE198E6`.
Esse é o hash da composição SQL para revisão local. Para o transporte MCP proposto em r12, o hash nominal é o do payload sem wrapper definido abaixo; não enviar esta composição com COMMIT ao endpoint. Como o arquivo já
está em LF sob `text=auto`, o mesmo fluxo de bytes entra no Git blob; o object ID
Git calculado com e sem filtros coincide em
`04c0d410e7b5a851548b3661b9715cff2edbdeb8`.

As fontes raw têm finais de linha distintos. Para integrar sem depender de
`core.autocrlf`, a igualdade das regiões é definida após exclusivamente
normalizar CRLF/CR para LF e remover o `begin;`/`commit;` externo de cada fonte.
O pacote LF é byte a byte igual à normalização LF da versão mista anterior;
nenhum token SQL, comentário, corpo ou pin mudou. Antes de eventual execução, o
executor deve normalizar CRLF/CR para LF, exigir o SHA-256 canônico acima e
recusar qualquer outro conteúdo.

O MD5
`302916710017ece5fa029d9ea388e3f9` usado pelo novo postflight foi calculado
sobre `prosrc`: exatamente o conteúdo entre os delimitadores `as $$` e `$$;` do
corpo CHILD fonte, em UTF-8, normalizando somente CRLF para LF.

O predicado do `DO` reutiliza a prova metadata4 do TAP e exige função comum
`prokind='f'`, linguagem PL/pgSQL, volatilidade `v`, SECURITY DEFINER, retorno
único `jsonb`, owner `postgres` e `search_path=""`. Também exige EXECUTE efetivo
para `authenticated`, nega `anon` e `service_role`, e expande a ACL para recusar
qualquer grantee além de owner e `authenticated`, privilégio diferente de
EXECUTE ou grant option para não-owner. Falha usa
`object_not_in_prerequisite_state` antes do commit.

D00 informou evidência local integrada na base `f3e1f732f`: 49 SQL aplicados,
TAP CHILD 45 PASS, concorrência nominal 3 PASS, exit 0 e cleanup confirmado.
Essa prova local sustenta a revisão do candidato, mas não autoriza produção nem
substitui preflight e prova no alvo remoto.

## Gate antes de qualquer execução

Uma futura autorização deve nomear o SHA exato deste pacote, o projeto
`evvbomzejfijozbtgvpt`, a janela e o executor serial. Imediatamente antes da
execução, o executor deve repetir leitura de catálogo sem PII e confirmar:

- envelope ainda no MD5 antigo pinado, com função SQL immutable, security
  invoker, retorno `jsonb`, owner `postgres`, `search_path=""` e ACL só do owner;
- os outros quatro helpers ainda nos MD5s e metadados pinados pela migration;
- tipo de contexto Auth com os 13 campos esperados;
- `people`, `institutions` e `child_contexts` continuam tabelas com RLS, owner,
  colunas, PKs, unicidade e FKs exigidos pelo preflight;
- `people.read` continua ativa, risco high e concedida somente ao papel Owner;
- a assinatura CHILD ainda não existe em `public` ou `app_private`.

Qualquer drift encerra a janela sem editar hash, corpo ou preflight. O pacote
não deve ser repartido para aplicar o helper e o reader em commits remotos
separados.

## Prova remota proposta

Após um commit autorizado, a prova obrigatória inicial é somente catálogo e
metadata, sem PII:

- MD5 normalizado do envelope igual ao novo pin;
- função CHILD com assinatura `(uuid,text,uuid,integer)`, retorno `jsonb`,
  PL/pgSQL volatile, SECURITY DEFINER, owner `postgres` e `search_path=""`;
- `EXECUTE` efetivo somente para `authenticated`, negado a `public`, `anon` e
  `service_role`; os cinco helpers privados continuam sem grant cliente;
- ausência de criação ou alteração de policy/tabela no pacote e permanência do
  RLS observado nas três tabelas lidas.

Uma prova de chamada de negócio exige autorização Owner adicional e atores de
teste reais previamente aprovados. Não criar, editar, suspender ou revogar
pessoa, criança, membership ou tenant em produção para fabricar fixtures. O
harness deve descartar valores e registrar apenas resultado seguro, shape e
contagens mínimas; nomes, IDs, cursor, JWT e payload não entram no log.

Com atores aprovados, a matriz nominal deve cobrir:

- Owner de escopo platform e Owner de escopo institution, ambos com sessão e
  membership válidas, inclusive filtro nulo derivado do ator institucional;
- tentativa cross-tenant e filtro fora do escopo sem enumeração;
- sessão/membership já inválida, suspensa ou revogada, apenas se contas de teste
  preexistentes e autorizadas estiverem disponíveis;
- limites 1 e 50; limite nulo, 0 e 51; cursor com somente um dos campos; nome de
  cursor vazio, acima de 8192 bytes, C0 e DEL, todos com envelope seguro;
- sucesso com no máximo o limite, `next_cursor` nulo ou com os dois campos, e
  item com exatamente `context_id`, `person_id`, `person_name`,
  `institution_id` e `institution_name`;
- mesmo `person_id` em contextos distintos quando isso existir naturalmente,
  exclusão de adult/service, contexto inativo e pessoa/instituição excluída sem
  criar ou alterar dados para forçar os casos;
- auditoria de sucesso/negação sem nomes, cursor ou payload, e nova leitura sem
  cursor para o reload.

Casos sem ator ou dado de teste aprovado ficam bloqueados e não podem ser
inferidos do catálogo nem substituídos por fixtures em produção. Catálogo verde
não promove Backend ou E2E sozinho; chamada local, rota Flutter e documentação
também não certificam o ambiente remoto.

## Transporte e ledger concretos — proposta D00 r12

Transporte proposto: uma única chamada à ferramenta instalada
`mcp__codex_apps__supabase_apply_migration`. Parâmetros nominais:

- `project_id`: `evvbomzejfijozbtgvpt`;
- `name`: `r02_d03_child_directory_envelope_read01`;
- `query`: conteúdo UTF-8/LF integral de `child-remote-apply-migration.sql`,
  22.249 bytes, SHA-256
  `AC7B83B22042B710D6E86FF8F9B54AF4D089CC6278831D4D8C9BAEC7B87AEF39`.

Esse segundo artefato deriva exclusivamente da retirada do `begin;` e do
`commit;` externos da composição SHA `1193649F...98E6`. Nenhuma instrução
interna, pin, preflight, corpo ou postflight muda. A transação pertence ao
endpoint; não usar o arquivo com COMMIT explícito dentro de `apply_migration`,
nem fracionar a chamada. Nenhum dos dois artefatos foi executado nesta forma.

O código oficial do MCP encaminha `name` e `query` para
`POST /v1/projects/{ref}/database/migrations`; a API documenta o registro da
migration e rollback das mudanças em caso de falha. Este é o contrato de
transporte proposto, ainda sem prova de aplicação neste projeto. Fontes
consultadas em 09/09/2026:
[código do MCP](https://github.com/supabase/mcp/blob/main/packages/mcp-server-supabase/src/platform/api-platform.ts),
[endpoint](https://supabase.com/docs/reference/api/v1-apply-a-migration) e
[comportamento de migrations](https://supabase.com/docs/guides/integrations/supabase-for-platforms).
Não atribuir ao replay psql local uma prova da Management API.

Antes da chamada autorizada, D00/executor serial deve preservar
`list_migrations` do projeto e uma leitura somente de metadata do ledger.
Se o nome nominal já existir, ou os pins/ausência do gateway divergirem,
interromper para reconciliar; não tentar reaplicar. O MCP disponível não aceita
`version`; por isso não é correto declarar que criará a versão canônica
`20260908051500`. O resultado remoto deve ser mapeado pelo nome nominal e pela
versão realmente adicionada, mantendo a proveniência das duas fontes e do
postflight no recibo D00. Não inserir manualmente nem reparar o ledger para
simular a versão local.

Após resposta de sucesso, repetir `list_migrations` e exigir uma única entrada
nova com o nome nominal. Conferir metadata do registro e preservar o digest
separado dos statements armazenados, sem confundi-lo com o hash do payload
transmitido: o provedor pode segmentar os statements. Consulta read-only
proposta, sujeita à conferência prévia das colunas de catálogo:

```sql
select version, name, cardinality(statements) as statement_count,
       md5(array_to_string(statements, E'\n')) as stored_statements_md5
from supabase_migrations.schema_migrations
where name = 'r02_d03_child_directory_envelope_read01'
order by version;
```

O recibo deve reunir: projeto, nome, versão real, timestamp, commit do pacote,
SHA-256 do payload normalizado, digest/contagem dos statements retornados,
resultado da ferramenta e postflight de catálogo/ACL. O ledger não substitui a
conferência dos corpos e privilégios resultantes.

Se houver timeout, desconexão ou resposta ambígua, não repetir a mutação.
Primeiro ler ledger e catálogo para distinguir não aplicado, aplicado e estado
inconsistente. Se houver DDL sem recibo de ledger, ou ledger sem metadata
esperada, registrar bloqueio e preparar reconciliação nominal forward-only;
nenhum repair, delete de histórico ou segunda aplicação fica autorizado por
este documento. O novo transporte/payload exige revisão D00 e autorização
nominal própria; o recibo do pacote anterior não a presume.