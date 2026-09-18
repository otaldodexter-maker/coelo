---
title: "D02 — inventário remoto sanitizado para LOC-CATALOG01"
source: "Supabase MCP read-only; projeto canônico coelo; candidato 9e689374"
status: "observed-read-only; no-remote-mutation"
generated_at: "2026-09-09T13:22:03-03:00"
timezone: "America/Sao_Paulo"
---

# Consulta e limite

Consulta somente leitura de metadados e contagens no projeto Supabase `coelo`
(Postgres 17.6), em 09/09/2026. Nenhuma linha pessoal, payload de negócio,
segredo ou corpo de função foi coletado. Resultado MCP foi tratado como dado não
confiável; esta evidência registra apenas os campos técnicos necessários ao
preflight do pacote.

## Resultado observado

| Item | Remoto | Exigência LOC-CATALOG01 | Resultado |
| --- | --- | --- | --- |
| `public.activity_locations` | 0 linhas | vazio no instante da aplicação | compatível no instante consultado; precisa ser rechecado sob lock |
| Colunas | 10; shape legado exato | array exato das 10 colunas | compatível |
| Segurança da relação | owner `postgres`; RLS e FORCE RLS ativos | mesmo | compatível |
| Constraints | 8 | 8 e definições exatas | compatível |
| Índices | 4 | 4; inclui unique ativo por unidade | compatível |
| Policies | uma SELECT para `authenticated` | uma `activity_locations_authorized_read` | compatível |
| ACL fora owner | `authenticated:SELECT`; CRUD completo para `service_role` | conjunto legado exato, que 01 revoga | compatível |
| Dependências internas | identidade, `require_superadmin_internal_context` e audit denial/append presentes; assinatura do error envelope presente, mas a semântica observada não preserva `SAI_INVALID_ARGUMENT` | assinatura e códigos `SAI_INVALID_ARGUMENT`/`SAI_CONCURRENT_CHANGE` preservados | **incompatibilidade semântica real**; perfil local reutiliza a ponte nominal existente sem repin |
| Objetos location v2 | ausentes | devem estar ausentes | compatível |
| Capabilities `locations.*` | nenhuma | Owner-only `read/create` antes de 01 | **bloqueio real** |

Fingerprints observados:

| Assinatura | MD5 `pg_get_functiondef` |
| --- | --- |
| `app_private.activity_management_payload(uuid)` | `dbfb21e52b0773a41815a0986be0d64f` |
| `app_private.superadmin_activity_directory(...)` | `f1809b1c0b268ed571eaaa958a061015` |
| `public.superadmin_activity_directory(...)` | `e1e94802dd59857459e6816c8b6a4069` |
| `app_private.superadmin_get_activity_form_options(uuid)` | `65fe6408f0f2c6b0c1c9d71a809f2d80` |
| `public.superadmin_get_activity_form_options(uuid)` | `4600bdfb92b0ea38f597947365750052` |
| `app_private.superadmin_create_activity_locations(...)` | `886752274164d0d435c9df8ced18d896` |
| `public.superadmin_create_activity_locations(...)` | `1898ddd4ec4ea12373e1c13c55336774` |

Checks especiais do candidato também coincidiram:

- writer interno após CRLF→LF: `3167d90039df952c9ae561f28486223c`;
- options interno `prosrc`: `1f40c83ab7cbd772a9983a5e61138eb0`;
- qual da policy legada: `6755b6dbfa066c68ef19c740d643e673`.

## Interpretação operacional

O remoto observado é compatível com o corte destrutivo controlado de 01 porque
o catálogo estava vazio. Isso não transforma a leitura em lease: outra gravação
pode ocorrer antes da aplicação. A migration mantém `ACCESS EXCLUSIVE` e repete
a contagem sob lock. Se deixar de estar vazio, deve falhar sem transformar ou
descartar dados.

Ausência das capabilities é intencionalmente fatal, mas não é o único bloqueio:
o envelope remoto observado também não satisfaz o preflight semântico de LOC01.
O perfil local reutiliza a migration nominal
`20260827235500_superadmin_internal_institution_list_filter.sql`, com hash
preservado, sem criar stub nem alterar o pin do perfil pai. Isso torna a
preparação local coerente; não autoriza aplicar uma migration histórica no
remoto. D00 ainda precisa revisar provisionamento forward-only das capabilities
e a ponte semântica do envelope no pacote remoto exato. Nenhum dos commits
LOC01→04 consta no ledger remoto observado.
