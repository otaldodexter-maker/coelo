---
title: "Catálogo: 16 divergências de fingerprint e a armadilha do relatório regenerado"
source: "execução própria do grupo operacoes-sistema sobre a base d784462c1"
status: "medição e alerta de método; nada regenerado"
generated_at: "2026-09-09"
group: "operacoes-sistema"
branch: "work/etapa2-noturna-operacoes-sistema"
---

# Catálogo — estado real do sincronizador

## Resultado

O catálogo está **desatualizado com 16 diagnósticos**, todos do mesmo código:
`source-example-fingerprint-mismatch`, com a mensagem "A fonte mudou sem
atualização do exemplo". O rastreador registrava 14 em R01/16h; hoje são 16.

```
superadmin.advanced-color-picker    core.date-range-picker
core.state-panel                    core.date-range-field
admin.multi-select-field            core.date-time-field
admin.toggle-field                  superadmin.form-action-footer
admin.dialog-shell                  superadmin.forms-editor
admin.pagination                    superadmin.forms-response
admin.file-actions                  admin.flyout
admin.interactive-card              admin.expandable-status-indicator
```

Duas entradas novas apareceram desde o relatório versionado e não são
divergências: `pattern.coelo-time-picker` e `pattern.principal-surfaces`.

## O alerta de método, que é a parte mais importante

O relatório versionado em `apps/catalog/assets/catalog-sync-report.json` diz
`catalogStale` com **um** diagnóstico. Esse arquivo é a **linha de base da
comparação**, e não apenas uma saída: `validate_catalog_sync.dart` recebe o mesmo
caminho como entrada e como saída. Ele lê o relatório anterior daquele caminho,
compara fingerprint a fingerprint e escreve o novo por cima.

A consequência é uma armadilha real:

```bash
# ERRADO: fabrica "sincronizado"
dart run tool/validate_catalog_sync.dart assets/coelo-ui.index.jsonl \
  lib/catalog/catalog_registry.dart /caminho/novo.json ../..
# -> "Catálogo sincronizado: zero diagnóstico."
```

Com um caminho de saída que ainda não existe, não há relatório anterior, todo
componente cai no ramo `prior == null` e é gravado como estado corrente. O
resultado é um verde que não comparou nada. Foi exatamente o que aconteceu na
minha primeira execução, e só ficou evidente ao diferenciar os dois arquivos:
16 hashes de **fonte** haviam mudado com o hash de **exemplo** idêntico, o que é
a definição da divergência, e mesmo assim a saída dizia zero.

```bash
# CERTO: compara contra a linha de base versionada
cp assets/catalog-sync-report.json "$TMP/sync_compare.json"
dart run tool/validate_catalog_sync.dart assets/coelo-ui.index.jsonl \
  lib/catalog/catalog_registry.dart "$TMP/sync_compare.json" ../..
# -> "Catálogo desatualizado: 16 diagnóstico(s)."
```

É por isso que o rastreador diz "não regenerar hashes para ocultar falha".
Regenerar o relatório versionado zeraria os 16 diagnósticos sem que nenhum
exemplo tivesse sido atualizado. **Nada foi regenerado aqui**: a execução usou
uma cópia em diretório temporário e `apps/catalog/assets/catalog-sync-report.json`
permanece intocado.

## O que fecha a pendência

Atualizar os **exemplos** do catálogo para as fontes que mudaram, um a um, e só
então regenerar o relatório. Não é atualizar o relatório.

Os 16 pertencem majoritariamente a pacotes compartilhados — `coelo_ui_core`,
`coelo_ui_admin` e componentes Superadmin — e dois são de Formulários
(`superadmin.forms-editor` e `superadmin.forms-response`). O contrato permite
revisão do Catálogo fora do app apenas como dependência, então a distribuição
por dono é decisão da coordenação.

## Correção de uma afirmação anterior deste documento

A primeira versão deste relatório afirmou que "o aviso exibido ao usuário está
subnotificando o estado real". Fui verificar o widget e **a afirmação estava
imprecisa**. `CatalogStaleBanner` exibe um texto fixo — "Componente implementado;
índice e catálogo desatualizados" — e não mostra contagem nem lista de
diagnósticos. Ele é binário, e hoje está correto, porque o relatório versionado
já diz `catalogStale`.

O que de fato subnotifica é o **arquivo**, que é o que um revisor lê: ele
registra um diagnóstico enquanto existem 16.

E o risco real é o oposto do que eu escrevi: como o aviso é binário e deriva de
`status == catalogStale || diagnostics.isNotEmpty`, **regenerar o relatório
apagaria o aviso por completo**, deixando o catálogo verde aos olhos do usuário
enquanto as 16 divergências continuam no código. O perigo não é o aviso
subnotificar; é ele desaparecer.
