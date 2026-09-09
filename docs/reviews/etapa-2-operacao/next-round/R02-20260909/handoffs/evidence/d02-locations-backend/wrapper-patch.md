---
source: "D00 r20; LocationCatalogV2 bbeaafa0a; wrappers canonicos somente leitura"
status: "review-ready; local-materialization-pass; sql-not-executed"
generated_at: "2026-09-09"
---

# Patch nominal do runner Locais

`location-catalog-wrapper-hunks.patch` acrescenta somente allowlist/dispatch
LocationCatalogV2, materializacao das duas fixtures locais e participacao do
perfil no conversor FormsDefinitionMaterialization herdado. Preserva hooks
CHILD/Auth e nao permite concorrencia de Atividades no perfil Locais.
O motor de reservas nao faz parte desta cadeia.

Fontes D00 normalizadas CRLF UTF-8 no momento da geracao:

- Prepare: `27ab616fcec60149f2024e095c17a7adc549620da45f70562d7cd2c2c6249bf9`.
- Invoke: `883ad760bd4f03192fa5486eb306bd5f99356c87ca4b9e92700f25bc26d2e971`.

`git apply --check` na raiz canonica passou sem aplicar. Materializar o patch
com LF a partir do blob antes de aplicar; o checkout Windows pode converter
EOL do artefato. Nao regravar wrappers inteiros nem normalizar SQL.

Prova local: executou-se copia temporaria de Prepare com apenas PSScriptRoot
resolvido para este pacote D02, mantendo ambos wrappers originais intactos.
Resultado final: 57 inputs (53 canonicos, 2 preflights, 2 fixtures locais),
fixtures imediatamente antes do cutover LOC01 e hash derivado de Forms igual
ao pai nominal. SQL 0 executado. Diretorio temporario proprio removido.
Dois erros iniciais do verificador (destino ausente e ascensao de path)
foram corrigidos; nao eram falhas do pacote SQL. Nao contam casos SQL.

Perfil, hashes, proveniencia e limites remotos: ver
`location-catalog-v2-static-profile.md`. D00 revisa/aplica estes hunks e
concede eventual janela SQL separadamente.
