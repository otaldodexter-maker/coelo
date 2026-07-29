---
source: "AGENTS.md; docs/design/design-system.md; user-approved weekly Superadmin UI review plan on 2026-07-29"
status: "active"
generated_at: "2026-07-29"
---

# Revisão semanal profunda do Superadmin

Use este runbook para “revisão semanal”, “code review profundo”, “auditoria
visual” ou “sincronização UI” do Superadmin. Ele organiza a revisão; não
substitui specs de produto, ADRs nem o Design System.

## Timebox e lote

- Teto de 3 horas: 0–20 min para escopo/evidências; 20–70 para inspeção visual
  e código; 70–130 para fontes, skill, índice e catálogo; 130–155 para pequenas
  correções aprovadas; 155–180 para verificação e relatório.
- Após 2h35, não abrir frente nova.
- Priorizar telas citadas. Sem lista explícita, examinar os últimos sete dias,
  exigir prova canônica de aprovação e escolher no máximo três famílias
  relacionadas. Commit recente, sozinho, não comprova aprovação.
- Aprovação visual exige golden aprovado, screenshot aprovada, exemplo fiel do
  catálogo ou aplicação executada no estado relevante. Código-fonte não basta.

## Matriz de investigação

Registrar somente o que for útil ao lote:

| Superfície | Evidência visual | Padrão/componente | Divergência | Lacuna documental | Ação |
| --- | --- | --- | --- | --- | --- |

Ler implementação e testes para anatomia, tokens, estados, responsividade,
acessibilidade, teclado e foco. Classificar achados por severidade com arquivo,
linha, evidência, risco concreto e correção recomendada.

## Gate das quatro camadas

Cada camada termina com melhoria comprovada ou `no-op` sustentado por evidência:

1. **Design System/fontes:** regra transversal no Design System; arquitetura ou
   ownership em ADR; comportamento de superfície em spec.
2. **`coelo-ui`:** instrução de descoberta curta e pesquisável, apontando para
   referência visual, artefato aprovado, componente público, estados,
   precedência e fonte canônica.
3. **Índice/catálogo:** termos reais nos campos existentes, registry, exemplo
   fiel e teste proporcional. Não alterar schema para sinônimos.
4. **Markdown/conhecimento:** somente documentos responsáveis pela regra;
   fonte canônica antes da projeção e gate da `coelo-knowledge`.

Conflitos entre fontes vão para `docs/open-questions.md`; nunca escolher
silenciosamente.

## Correções diretas e evolução da skill

Corrigir diretamente apenas quando o padrão já está aprovado, a mudança é
visualmente neutra, fica no lote, não altera domínio/permissões e não cria API,
variante, token ou componente público. Caso contrário, apresentar proposta e
aguardar aprovação.

Para mudar a skill: formular cenário real, executar em contexto novo com a
versão anterior (**RED**), alterar o mínimo, repetir o mesmo cenário
(**GREEN**) e manter apenas se a recuperação/aplicação melhorar.

## Verificação e entrega

- Markdown/skill/índice/catálogo: cenários RED/GREEN, testes da skill e consulta,
  validadores de índice/catálogo, links e gate da `coelo-knowledge`.
- Dart/Flutter: formatar somente Dart afetado, análise estática, testes focados,
  goldens relevantes e `git diff`.
- Quando a dimensão mudar, verificar 375/768/1024/1440, light/dark, texto 200%,
  teclado, foco e estados interativos.
- Executar goldens sem atualização primeiro; atualizar somente após inspeção
  visual. `goldens/` contém referências aprovadas. `failures/` contém
  comparadores transitórios e nunca comprova aprovação.

Comandos-base, ajustando app/package e arquivos ao lote:

```powershell
& .agents/skills/coelo-ui/tests/query-index.tests.ps1
& .agents/skills/coelo-ui/tests/surface-interaction-contracts.tests.ps1
Push-Location apps/catalog
dart run tool/validate_catalog_index.dart assets/coelo-ui.index.jsonl ..\..
dart run tool/validate_package_boundaries.dart assets/coelo-ui.index.jsonl ..\..
dart run tool/validate_catalog_sync.dart assets/coelo-ui.index.jsonl lib/catalog/catalog_registry.dart assets/catalog-sync-report.json ..\..
Pop-Location
dart format <dart-afetado>
dart analyze
flutter test <teste-focado>
& .agents/skills/coelo-knowledge/scripts/Test-CoeloKnowledge.ps1
& .agents/skills/coelo-knowledge/tests/Test-CoeloKnowledge.ps1
git diff --check
```

Entregar, nesta ordem: resultado; telas/evidências; achados; fontes canônicas;
skill; índice/catálogo; outros Markdown; reutilização/duplicações; correções;
RED/GREEN; testes; gate de conhecimento; pendências. Consolidar a investigação
na matriz final:

| Superfície | Referência | Componente/padrão | Achado | Ação | Verificação |
| --- | --- | --- | --- | --- | --- |

Incluir também a matriz de sincronização:

| Camada | Lacuna encontrada | Arquivos alterados | Melhoria ou no-op | Evidência/teste |
| --- | --- | --- | --- | --- |
| Design System/fontes | | | | |
| coelo-ui | | | | |
| Índice/catálogo | | | | |
| Markdown/conhecimento | | | | |
