---
source: "specs/013-ui-packages-componentization.md; docs/superpowers/plans/2026-07-22-coelo-ui-foundation-componentization-catalog.md"
status: "completed"
generated_at: "2026-07-24"
---

# Checkpoint — Task 14

## 1. Resultado obtido

O conteúdo útil do showroom antigo foi migrado para o catálogo independente.
As áreas `actions`, `forms`, `selection`, `status`, `colors`, `typography` e
`themes` possuem ids compactos, orientação sob demanda e referências
interativas. Componentes públicos são renderizados a partir dos barrels reais;
amostras Material não foram promovidas a componentes Coelo.

O showroom antigo não possuía consumidor e foi removido somente depois da
equivalência verde. O arquivo continua recuperável pelo Git.

## 2. Arquivos alterados

- `apps/catalog/assets/coelo-ui.index.jsonl`
- `apps/catalog/assets/catalog-sync-report.json`
- `apps/catalog/lib/app/catalog_app.dart`
- `apps/catalog/lib/catalog/catalog_foundation.dart`
- `apps/catalog/lib/catalog/catalog_foundations.dart`
- `apps/catalog/lib/catalog/catalog_registry.dart`
- `apps/catalog/lib/presentation/catalog_foundation_page.dart`
- `apps/catalog/lib/presentation/catalog_home_page.dart`
- `apps/catalog/tool/catalog_local_preview_main.dart`
- testes correspondentes em `apps/catalog/test/`
- removido:
  `apps/superadmin/lib/features/design_system/presentation/screens/design_system_showroom.dart`

## 3. Componentes criados, promovidos ou mantidos locais

- Nenhum novo componente público foi criado.
- O registry passou a renderizar as implementações reais já públicas de
  `CoeloStatePanel`, `CoeloAdminMultiSelectFilter` e
  `CoeloAdminCreateAction`.
- Ações, campos genéricos ainda não aprovados, controles Material e composições
  de demonstração não foram promovidos.
- Foram criadas somente páginas e modelos locais do catálogo para fundamentos e
  padrões aprovados.

## 4. Diferença visual encontrada

Nenhuma diferença foi introduzida na tela de instituições. O catálogo foi
inspecionado em light e dark na porta local `8770`; o conteúdo migrou para uma
estrutura própria do catálogo, sem obrigação de reproduzir o layout descartado
do showroom.

## 5. Testes executados

- `dart analyze` em `apps/catalog`: sem issues.
- suíte completa `apps/catalog`: 91 testes aprovados.
- equivalência e interação focadas: 12 testes aprovados.
- `validate_catalog_index.dart`: zero diagnóstico.
- `validate_package_boundaries.dart`: zero diagnóstico.
- `validate_catalog_sync.dart`: catálogo sincronizado, zero diagnóstico.
- `flutter build web --target tool/catalog_local_preview_main.dart`: concluído.
- inspeção visual do build em light e dark: concluída.

## 6. Pendências

- Task 15: integrar `Governança > Catálogo` sem importar o registry ou pacotes
  exclusivos do Principal.
- Task 16: executar a verificação final integrada e registrar a fronteira Astro.

## 7. Decisão que precisa de aprovação

Nenhuma decisão nova na Task 14. A integração da Task 15 seguirá a arquitetura
já aprovada de origem independente e host mínimo no Superadmin.
