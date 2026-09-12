---
fonte: R08 G5; candidato H28 G2; ordem nominal C0
status: composição preparada; retida até revalidação do blob atual
generated_at: 2026-09-12T14:29:00-03:00
---

# Lote 59 — composição nominal H28

## Fonte fixada

- branch: `origin/work/etapa2-r08-acessos-pessoas`;
- head observado: `df0a281cb561b0440a1eb8ab5cd541b8b6196fdb`;
- SQL: `packages/coelo_database/candidatos/acessos-pessoas/20260912143000_people_directory_context_filters_v1.sql`;
- blob Git: `707cc8b4fe37d46dc8e40a993dbbd8fe33b2d513`;
- bytes LF: 16873;
- SHA-256 LF: `8b6c66091b89e7a319b00f894f80869cb764ba66106baa18e9acbec943761b6e`.

O blob atual inclui a projeção `state_code` em `neighborhoods`, adicionada após
o primeiro verde 44/44. Por isso a promoção está retida até o G0 reexecutar a
versão atual no baseline descartável.

## Composição exata para o C0

Materializar o SQL acima como migration
`packages/coelo_database/migrations/20260912143000_people_directory_context_filters_v1.sql`.
Imediatamente antes do `commit;` terminal, e dentro da mesma transação, inserir:

```sql
insert into supabase_migrations.schema_migrations(version,name)
values ('20260912143000','people_directory_context_filters_v1');
```

Não incluir os dois testes na migration. A composição LF resultante deve ter
17002 bytes e SHA-256
`f2587890eaa9e71233d6c2825f4127c247a5f1f67c48c8c5b81246fced28a5d9`.
Se materializada com CRLF, terá 17173 bytes e SHA-256
`5fed5533a058f6b869210fc78eccc2b92ef410a352deffd7a7452cfed5f4dfe7`;
o conteúdo normalizado deve ser idêntico ao LF.

## Provas associadas

- estrutural: `20260912143000_people_directory_context_filters_v1_test.sql`,
  4284 bytes LF, SHA-256
  `d28091240fe733ccb88e503ac54fd3e66dd5e6536e6afd9c804fff4af5dc5aeb`;
- funcional: `e1cad10e2:packages/coelo_database/candidatos/realm-interno/20260912143100_people_directory_context_filters_fixture_v1_test.sql`,
  12880 bytes LF, SHA-256
  `dc1295bc55dcffca72ec88aafc154f15b88351781f40369168ed2712f953df8d`;
- preflight produtivo somente leitura: `lote59-preflight-readonly.sql` neste
  diretório.

O preflight deve mostrar ledger 0, somente a assinatura legada de 13 argumentos,
uma única sobrecarga de `superadmin_people_list`, `security definer`, owner
`postgres`, `stable`, `search_path` fixo, EXECUTE de `authenticated` e negação
de `anon` nas duas RPCs. Qualquer divergência interrompe a aplicação e exige
revisão; não adaptar o SQL silenciosamente.

Aplicação remota, backup, ledger, pós-prova e deploy pertencem exclusivamente
ao C0. G5 não os executou.
