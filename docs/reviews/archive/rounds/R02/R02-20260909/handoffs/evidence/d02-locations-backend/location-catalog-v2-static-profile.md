---
title: "D02 — perfil estático LocationCatalogV2"
source: "assignment D00 r13/r17; commits históricos 9e689374, 27236a5a, ae7e8f5f, 15516da9; código local"
status: "candidate-local-static-green; sql-not-executed; remote-not-applied"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Resultado

O perfil nominal `LocationCatalogV2` resolve estaticamente 53 migrations
canônicas, incluindo LOC01–LOC04, mais dois preflights herdados e duas fixtures
locais anteriores a LOC01. Nenhum SQL, container ou recurso remoto foi
executado por esta verificação.

O snapshot local `030958` restaura somente a definição remota revisada de
`app_private.superadmin_get_activity_form_options(uuid)` antes do cutover. A
fixture `030959` cria somente as seis capabilities `locations.*` para o papel
Owner no banco descartável. `requires_mfa=false` acompanha a política de fase
vigente; o perfil não cria uma obrigação MFA nova.

O envelope que preserva `SAI_INVALID_ARGUMENT` vem da migration nominal já
selecionada `20260827235500_superadmin_internal_institution_list_filter.sql`,
hash normalizado
`c4496229e2d004907b1c878e9719cadfa60169307eeb92be67cd76c3ad5551aa`.
O descriptor continua com `extra_bridges=[]`; nenhum pin do pai foi alterado.

# Proveniência dos snapshots

- LOC01 migration e TAP de cutover: `9e689374`.
- LOC01 TAP de cadastro/leitura, autorização e isolamento: blobs finais de
  `7389ae63`, idênticos aos observados em `31d0abf6` e `6cd030f4`.
- LOC02 migration: `27236a5a`; TAP update/status final: `ae7e8f5f`.
- LOC03 migration: `ae7e8f5f`; TAP copy parte de `15516da9` e incorpora o
  corretivo revisado `6aa9c388`.
- LOC04 migration: `15516da9`; TAP schedule incorpora o mesmo corretivo
  `6aa9c388`.

O corretivo troca assertions frágeis de contagem por nomes das duas tabelas de
recibo realmente criadas e acrescenta em copy a prova nominal de
`superadmin_location_write_receipts`. Ambos os TAP usam `no_plan()` +
`finish()`; a nova assertion não exige atualizar uma contagem fixa de
`plan(n)`.

A comparação por blob com filtros Git confirmou **11/11** snapshots executáveis
exatos: quatro migrations e sete TAP nos SHAs acima.

# Verificação executada

Comando estático:

```powershell
Invoke-Pester -Script packages/coelo_database/scripts/tests/LocationCatalogV2.Tests.ps1 -PassThru
```

Resultado base em Windows PowerShell/Pester 3.4.0: **7 aprovados, 0 falhos,
0 ignorados, 0 pendentes, 0 inconclusivos**, duração 14,33 s. A correção para
checkout limpo alterou somente o caso de derivação: ele deixou de ler o snapshot
duplicado do handoff e passou a comparar o hash nominal do original sem opt-in.
Esse caso foi reexecutado isoladamente: **1 aprovado, 0 falhos**, 7,84 s; os
outros seis casos permaneceram inalterados e não foram repetidos. As provas
cobrem seleção exata, ordem das fixtures, ponte nominal do envelope sem repin,
capabilities Owner-only, política MFA da fase, rejeição de target anterior e
hashes das quatro migrations. São testes do perfil/ferramenta, não pgTAP nem
avanço de action_id.

# Hashes normalizados CRLF/UTF-8 do perfil

| Arquivo | SHA-256 |
| --- | --- |
| `profile.json` | `357bcca0c016e82105b3cd6c54038c2faab88afc33b3cadfc619825b44dbeeb1` |
| `Resolve-LocationCatalogV2.ps1` | `100ed73790b42560f38237518cb8b0c198cc8befe344eb4866798054b843fd49` |
| `LocationCatalogV2.Tests.ps1` | `9dcfa8343494a05b17639c297f8482a88af9e0c3c9bdb5d932f5306f98a10aca` |
| fixture snapshot `030958` | `99f3ad22a387d1f5c5d274fad5b294805842997386a1d147a486d48129e56d16` |
| fixture capabilities `030959` | `4cfc607816d7be959fb24d365f6cb9b995460586eb7869d8a985d8e2a0115bed` |

# Limite

Os sete arquivos pgTAP permanecem **não executados**. O perfil ainda não foi
ligado aos wrappers compartilhados nesta frente, conforme a reserva D00; isso
não autoriza execução manual. O pacote continua local e não aplicado.
