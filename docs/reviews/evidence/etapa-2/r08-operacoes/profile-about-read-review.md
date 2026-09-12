# Revisao G7 - Perfil: leitura autorizada

- Data: 2026-09-12
- Escopo: leitura da cadeia `get_profile_about` / `parseProfileAboutReadResponse`, no SHA `dc357d71f` do pacote G4.
- Fora do escopo: Flutter, SQL, fixture, producao e alteracao de rastreadores.

## Fonte vigente

A unica definicao encontrada de `public.get_profile_about` e a baseline
`20260910000000_baseline_producao.sql` (linhas 21946-21986). Nao ha migration
sucessora que a redefina. Quando ha pagina visivel, a funcao retorna um objeto
plano: `id`, `subject_type`, `subject_id`, `version`, `state`, `fields` e
`sections`. Ela retorna `null` para ausencia de pagina (e para pagina nao
publicada sem permissao de gestao).

Cada campo da RPC usa `key`; cada secao usa `type`. Esses sao diferentes das
colunas de tabela `field_key` e `section_type` usadas por
`parseProfileAboutPage`.

## Achado

O parser do cliente espera um envelope inventado
`{page: {...}, fields: [...], sections: [...]}` e retorna `null` quando a
chave `page` nao existe. Portanto, toda resposta plana nao nula da RPC e
silenciosamente tratada como ausencia de pagina. O teste existente reproduz o
envelope e tambem usa `field_key`/`section_type`; ele nao representa o contrato
SQL vigente. O tratamento de `response == null` introduzido em `b32ad2453` e
correto para ausencia legitima, mas nao resolve essa divergencia de forma.

## Oraculo RED fiel

Acrescentar apenas um teste unitario puro de
`parseProfileAboutReadResponse` com uma resposta nao nula exatamente plana da
RPC: raiz contendo pagina e listas `fields`/`sections`, com ao menos um campo
`key` conhecido e uma secao `type` conhecida. O esperado e uma
`ProfileAboutPage` nao nula que preserve versao, campo e secao. Hoje esse teste
falha porque o parser devolve `null`.

A correcao deve normalizar exclusivamente o formato canonico da RPC antes de
chamar o parser comum: raiz como `pageRow`, `key -> field_key` e
`type -> section_type`. A leitura direta por tabelas permanece com seus nomes
de coluna e nao autoriza aceitar ou documentar o envelope inexistente.
