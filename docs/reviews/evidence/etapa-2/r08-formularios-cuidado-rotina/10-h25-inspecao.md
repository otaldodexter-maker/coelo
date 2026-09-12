---
source: "R08-backlog H25; coelo_ui_admin tabela; forms_accessibility_guidelines_test; handoff09/09 e autocorreção10/09; contrato visual tabela administrativa"
status: "implementado sob posse nominal C0; local-green no recorte; sem AA global"
generated_at: "2026-09-12"
---

# H25: alvo de redimensionamento

Base inspecionada: `a7b081674`, merge do ciclo150. `apps/superadmin -> Formulários -> diretório -> tabela -> H25` (subaceite de acessibilidade; não cria action_id).

O componente compartilhado é `packages/coelo_ui_admin/lib/src/table/coelo_admin_resizable_table.dart`. `_ColumnResizeIndicator` tem largura `CoeloSpacing.space3` (12), altura herdada do cabeçalho (56 no diretório). `_ColumnResizeHandle` expõe tap para foco, drag, setas de teclado em passos de8 e ações semânticas increase/decrease. Os testes nominais `exposes accessible resize handles and resizes in eight pixel steps` e `clamps drag resizing to the configured minimum and maximum` já cobrem teclado/semântica/limites; não foram reexecutados nesta inspeção.

O alvo sobrepõe o botão de ordenação que cobre toda a célula (`Positioned.fill`). A nota10/09 documenta por que apenas ampliar overlay para48 roubaria36px da ordenação. Não é uma correção visualmente neutra.

O teste ignorado `the forms directory meets tap size, labelling and contrast` também documenta outro achado histórico: nó focus/longPress128x48 sem rótulo no topo. Corrigir a alça não autoriza retirar o skip sem medir esse segundo achado.

A inspeção seguiu esse segundo motivo: `CoeloAdminDirectoryViewToggle` já contém `Semantics(container: true, label: ...)` sobre o detector de longPress, e `superadmin_directory_view_toggle_test.dart` documenta a correção e cobre o rótulo. O componente atual foi consolidado em `60747d57b`. Portanto o comentário do skip pode estar parcialmente obsoleto; a medição do composto, não a repetição da nota histórica, decidirá sua remoção.

Há ainda redimensionador em coluna fixa: Ações tem min=max72. A proposta focal para C0 é reservar uma faixa própria de48 (`CoeloSize.touchMin`) somente nas colunas redimensionáveis, limitar o sort à área restante e preservar o indicador visual estreito. Coluna fixa não deve oferecer ajuste sem efeito. A geometria das colunas, a cópia fixa, o scroll e o ellipsis precisam ser preservados; larguras menores e rótulos longos exigem teste. Não houve edição no componente, alteração de skip ou execução Flutter.

Aceites propostos após posse: dimensões semânticas, sort e resize sem dupla ação, teclado, drag, limites, coluna fixa sem ação inútil, composto Formulários e validação do motivo restante do skip. Nenhuma decisão nova de produto registrada; C0 decide o ajuste compartilhado antes da implementação.

## Execução autorizada e resultados

C0 concedeu posse nominal do componente e slot Flutter por8min. Faixa48 reservada; sort limitado à área restante; indicador visual alinhado na borda como antes, inclusive cópia não interativa. Min=max não expõe alça. Três testes novos na tabela: targets disjuntos/sort/tap/teclado, coluna fixa e coluna ordenada90→80.

RED inicial:0PASS/2FAIL (`10-h25-red.log`). Primeiro GREEN:19PASS/0FAIL (`10-h25-green.log`). G4 encontrou overflow em Anexos do Suporte:90→80 menos faixa48/padding24 deixa18→8 para ícone20+gap4. Novo RED:0PASS/1FAIL (`10-h25-narrow-red.log`). Quando não cabe o conteúdo, LayoutBuilder apresenta só o ícone com escala reduzida; o wrapper semântico mantém nome/direção completos. Não ampliamos larguras dos consumidores. GREEN final:20PASS/0FAIL (`10-h25-green-final.log`). Análise do componente/teste:exit0, sem problemas (`10-h25-analyze.log`).

Composto Formulários:1PASS em1440 e375 no mesmo caso (`10-h25-directory-final.log`), com assert da alça real e diretrizes de tamanho de toque e rótulo. O primeiro run também passou, mas o segundo adicionou a confirmação explícita de presença da tabela; não somar rerun. O skip histórico de toque/rótulo/contraste permanece separado, conforme C0; contraste não foi recertificado nesta fatia. Testes totais pertinentes:21 únicos,0falhos finais,4novos (17 de regressão). Não somar aos pacotes anteriores ou execuções intermediárias.

Limite comunicado a C0/G4: em coluna80/90, faixa48 deixa32/42 para sort. Dois alvos48 não cabem na largura existente; este pacote não declara AA de todos os consumidores. Formulários passa nos tamanhos medidos; Suporte exige decisão de composição/largura em gate próprio. Sem E2E ou câmera/browser, sem alteração de rastreadores. G4 revisou o diff e confirmou o ajuste focal; parecer por SHA será anexado por G4.
