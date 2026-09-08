---
title: "C07 — varredura nominal do padrão FocusableActionDetector: paradas de foco inertes no Superadmin"
source: "leitura de código no baseline 4af42925 (worktree C07); defeito original provado em c07_institutions_directory_test.dart; contrato aprovado packages/coelo_ui_admin/lib/src/surface/coelo_admin_interactive_card.dart; pedido operacional da C06 de 2026-09-08T18:44-03:00"
status: "evidence-survey"
generated_at: "2026-09-08T18:52:00-03:00"
timezone: "America/Sao_Paulo"
---

# Varredura — paradas de foco inertes por `FocusableActionDetector`

## Por que esta varredura existe

Ao escrever o aceite do diretório de Instituições, um teste ficou vermelho por defeito real: o card
exige **dois** Tab para ativar. A causa é um `FocusableActionDetector` sem `actions:` envolvendo um
`InkWell` que já é focalizável. O contrato aprovado
(`packages/coelo_ui_admin/lib/src/surface/coelo_admin_interactive_card.dart`, linhas 29 e 73-74) usa
**um único** `FocusNode`, no próprio `InkWell`.

A pergunta que sobrou: o padrão se repete? Sim. Das 22 ocorrências do widget no Superadmin,
**6 estão defeituosas**, em quatro donos diferentes.

## Duas formas de defeito

- **DEFEITO-1, foco duplo.** O detector é focalizável e não tem `actions:`; o filho também é
  focalizável (`InkWell`, `TextButton`). Resultado: duas paradas de Tab por elemento. A primeira
  acende o realce visual e Enter não faz nada; a segunda ativa, com aparência idêntica.
- **DEFEITO-2, foco sem ativação por teclado.** O detector é focalizável e não tem `actions:`; o
  filho é um `GestureDetector`, que não é focalizável nem responde a teclado. Resultado: uma parada
  de Tab que Enter e Espaço não ativam.

  **Correção do que este documento afirmava antes:** eu supunha o agravante de que o elemento seria
  anunciado como botão sem ação. **Isso foi medido e é falso.** A prova em
  `c07_institutions_directory_test.dart` mostra que a semântica **passa**: o nó do indicador publica
  papel de botão e ação de toque (`isSemantics(label: 'Status: Ativa', isButton: true,
  hasTapAction: true)` é satisfeito), porque o `GestureDetector` filho anota o mesmo nó do
  `Semantics`. Logo leitores de tela **conseguem** ativar; quem não consegue é o teclado físico. O
  defeito é real e continua sendo falha de teclado, mas é menos grave do que eu havia escrito, e a
  ressalva do limite 2 abaixo fica resolvida por medição.

## Os seis defeitos

| # | Arquivo : linha | Forma | Filho | Dono |
|---|---|---|---|---|
| 6 | `apps/superadmin/lib/features/institutions/presentation/widgets/institution_directory_cards.dart:117` | DEFEITO-1 | `InkWell` | C04 |
| 7 | `apps/superadmin/lib/features/institutions/presentation/widgets/institution_status_presentation.dart:55` | DEFEITO-2, provado por medição | `GestureDetector` sob `Semantics(button: true)`; semântica OK, teclado quebrado | C04 |
| 8 | `apps/superadmin/lib/features/people/presentation/person_directory_page.dart:768` | DEFEITO-2 | `GestureDetector` sob `Semantics(button: true)` | C04 |
| 14 | `apps/superadmin/lib/features/principal_happens_publication/presentation/principal_happens_publication_page.dart:487` | DEFEITO-1 | `TextButton.icon` | C05 |
| 18 | `apps/superadmin/lib/shared/presentation/widgets/superadmin_directory_create_banner.dart:114` | DEFEITO-1 | `InkWell` | C00 |
| 19 | `packages/coelo_ui_admin/lib/src/filter/coelo_admin_toggle_field.dart:43` | DEFEITO-1 com agravante DEFEITO-2 | `GestureDetector` com `Switch` descendente focalizável | C00 |

As outras 16 ocorrências estão corretas: têm `actions:` mapeando `ActivateIntent`, ou o filho
focalizável é o único ponto de foco. Nenhuma das 22 usa `descendantsAreFocusable`,
`descendantsAreTraversable` ou `skipTraversal` — confirmado por busca em todo o repositório.

## Quatro achados que valem mais que a contagem

1. **O contrato correto já existe e foi copiado errado duas vezes.**
   `CoeloAdminExpandableStatusIndicator` (`coelo_ui_admin`) faz exatamente o que os casos 7 e 8
   deveriam fazer, com o mesmo layout, a mesma animação e os mesmos estados, mas **com** `shortcuts`
   e `actions`. Os dois indicadores de Instituições e Pessoas são forks locais que perderam
   `actions`. A correção certa é migrar para o componente, não remendar cada fork.

2. **O pacote central está atrás da cópia da feature.** `CoeloAdminToggleField` (caso 19) é o gêmeo
   de `PrincipalPublicationToggleField` (`principal_publication_frame.dart:398`): estrutura
   idêntica, mas o da feature tem `shortcuts` e `actions` e o do pacote não tem. Isso amplia o
   alcance muito além de uma tela: **25 usos em 13 arquivos** (contagem minha, conferida por grep), cruzando Atividades e Agenda,
   Turmas e Unidades, Circulares e Comunicações, e ainda Formulários, Rotina, Cardápios, Segurança e
   Catálogo. **Uma correção no pacote resolve os 25.**

3. **O card de Instituições tem defeito aninhado.** Ele é o caso 6 e contém o caso 7: dentro do
   mesmo card há uma parada de Tab inerte no card e outra no indicador de status.

4. **A mesma raiz aparece na reserva já concedida à C01.** O seletor múltiplo
   (`coelo_admin_multi_select_field.dart:307`) usa `Semantics` mais `ExcludeSemantics` sobre um
   `MenuItemButton` — é a família "anotação semântica declarada num nível, ativação real noutro".
   Não é `FocusableActionDetector` e não colide com este recorte, mas os casos 5, 9, 17 e 19 têm a
   mesma origem: `ExcludeSemantics` usado como se também excluísse foco.

## Correção mínima sugerida, por caso

Nenhuma delas é minha para aplicar; entrego a sugestão para o dono decidir.

| # | Correção mínima |
|---|---|
| 6 | trocar o par detector + `InkWell` por `CoeloAdminInteractiveCard`; ou remover o detector e mover o realce para `InkWell.onFocusChange` com `focusNode` próprio |
| 7, 8 | substituir o fork local por `CoeloAdminExpandableStatusIndicator`; se não couber agora, copiar `shortcuts` e `actions` das linhas 75-85 do componente |
| 14 | remover o detector e ligar o realce ao `TextButton.icon` por `onFocusChange` mais `focusNode`; o botão já ativa por Enter e Espaço |
| 18 | mesma correção do 6 |
| 19 | acrescentar ao detector os mesmos `shortcuts` e `actions` já presentes em `principal_publication_frame.dart:398`, e envolver o `Switch` em `ExcludeFocus` para eliminar a segunda parada |

## Limites honestos desta varredura

1. **A ordem e a contagem de paradas de Tab foram inferidas do código, não medidas**, exceto no caso
   6, que está provado por teste com valor medido (`Expected: <1> / Actual: <2>`). A inferência se
   apoia na implementação do widget, que é um `Focus` com `canRequestFocus` ligado a `enabled` e sem
   `skipTraversal`, e no fato de nenhuma das 22 ocorrências passar as flags que desligariam isso.
   Confirmar de fato exige enviar Tab e checar o foco primário em cada ocorrência.
2. ~~A fusão de nós semânticos não foi verificada nos casos 7 e 8.~~ **Resolvido por medição:** a
   semântica do indicador publica papel de botão e ação de toque, então o nó é fundido e leitores de
   tela ativam. Só o teclado físico está quebrado. A redação original deste item dizia: Se o `GestureDetector` filho
   anotar o mesmo nó do `Semantics(button: true)`, leitores de tela conseguem ativar e só o teclado
   físico fica quebrado; se houver fronteira de nó, o elemento é anunciado como botão sem ação
   nenhuma. Só um exame da árvore semântica decide. Estou provando esse caso especificamente no meu
   arquivo de aceite reservado.
3. **A ativação por Enter nos casos que têm `actions` mas não `shortcuts` depende dos atalhos padrão
   do `WidgetsApp`.** Foi verificado que o app não sobrescreve `shortcuts`, mas não foram
   verificados todos os `MaterialApp` de preview e teste espalhados pelas features.
4. **O impacto por tela dos 25 usos do toggle não foi estimado**: sei o número e os 13 arquivos, mas
   não abri cada um para saber quantos estão visíveis no MVP.
5. **Nenhum teste existente cobre as 6 ocorrências defeituosas.** Os cinco testes que tocam o padrão
   cobrem apenas ocorrências corretas. Isso é, em si, a explicação de por que os defeitos passaram.
6. A varredura é leitura de código feita por subagente somente-leitura, revisada por mim nos seis
   casos defeituosos, que conferi diretamente na fonte. Nenhum arquivo de produto foi editado.
