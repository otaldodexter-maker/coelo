---
source: "specs/013-ui-packages-componentization.md; docs/superpowers/plans/2026-07-22-coelo-ui-foundation-componentization-catalog.md"
status: "implemented-local-foundation"
generated_at: "2026-08-06"
---

# Coelo UI Catalog

Aplicacao Flutter Web independente para consultar fundamentos, componentes e
padroes aprovados do Coelo. O app renderiza as implementacoes reais dos pacotes
e mantem seu registro fora do bundle do Superadmin.

O indice canonico e economico para agentes fica em
`assets/coelo-ui.index.jsonl`. Entradas `approved` podem apontar para arquivos
planejados; `implemented`, `catalog-stale` e `deprecated` exigem arquivos reais.

Validacao estrutural a partir deste diretorio:

```powershell
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe run tool/validate_catalog_index.dart assets/coelo-ui.index.jsonl ..\..
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe run tool/validate_package_boundaries.dart assets/coelo-ui.index.jsonl ..\..
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe run tool/validate_catalog_sync.dart assets/coelo-ui.index.jsonl lib/catalog/catalog_registry.dart assets/catalog-sync-report.json ..\..
rtk proxy C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe run tool/validate_admin_visual_contracts.dart ..\.. assets/admin-visual-contract-allowlist.json
```

O ultimo comando e um gate bloqueante para novas interacoes administrativas
fora do padrao Coelo. Ele impede novos usos crus de `PopupMenuButton`,
`PopupMenuItem`, `MenuAnchor`, `MenuItemButton` e `InkWell` nas features do
Superadmin. O estado legado permanece registrado por arquivo, simbolo, contagem
maxima e justificativa em `assets/admin-visual-contract-allowlist.json`.
Reduzir a contagem e permitido; aumentar, criar uma entrada ou alterar uma
justificativa exige review visual explicito. A allowlist nao aprova o visual
legado e nao deve ser usada para desenvolver uma nova tela.

## Acesso e publicacao

O entrypoint atual abre o catalogo temporariamente sem exigir sessao, conforme
decisao explicita de produto. O gate de sessao Coelo e autorizacao server-side
permanece implementado e testado para ser reativado quando usuarios e
permissoes forem definidos.

Enquanto o modo publico estiver ativo, a origem do catalogo nao deve ser tratada
como privada nem receber conteudo sensivel. Na publicacao restrita futura, o
host/edge devera proteger todos os artefatos estaticos e enviar CSP com
`frame-ancestors` restrito ao Superadmin. A origem continua distinta da origem
do Superadmin. Nenhum deploy faz parte desta entrega.

## Escopo

O catalogo organiza fundamentos, componentes, padroes, produtos e governanca;
filtra por consumidores; muda tema e viewport; renderiza os componentes reais;
e mostra orientacao e codigo minimo. Nao e editor de codigo, CMS ou mecanismo de
aprovacao do Design System.

O registry interativo renderiza somente componentes importaveis dos pacotes UI
materializados. Componentes privados em `apps/*` permanecem no indice e na
verificacao de arquivos e fingerprints, sem builder. O catalogo e ferramenta de
governanca, nao consumidor, e nunca importa outro app.
