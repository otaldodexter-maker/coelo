---
fonte: C0; pacote H25 de G3 54c892ebcf3f79ae28f12cb818bbb70aab0ae5f5
status: revisao-focal-concluida-fix-publicado
data_geracao: 2026-09-12
---

# H25 — revisão focal G4

C0 atribuiu leitura do resize48 separado de sort e remoção do handle quando
minWidth=maxWidth, no CoeloAdminResizableTable. Sem edição nos arquivos G3,
sem Flutter/Chrome G4, sem mudança de mínimo nas colunas consumidoras.

## Achado confirmado

No primeiro delta G3, reservar48 no cabeçalho deixa colunas sorted estreitas
sem espaço para gap4+ícone20. Exemplo produtivo: Suporte, coluna Anexos,
`support_ticket_rows.dart:101–108`, initial90/min80/max120, sortable.
Após reserva48 e padding24, sobram18px na largura90 e8px na largura80;
o conteúdo fixo24px causava overflow6/16px. G4 encaminhou antes da publicação.
G3 confirmou RED0PASS/1FAIL e corrigiu, relatando GREEN20PASS/0FAIL na tabela.

A correção inspecionada usa LayoutBuilder após padding e, quando sorted com
menos de24px úteis, mostra ícone com FittedBox.scaleDown. Não amplia a coluna;
o wrapper semântico de ordenação conserva rótulo e direção. O teste percorre
90→80 e exige ausência de exceção. Achado concreto atendido.

## Contrato focal inspecionado

- Área de sort termina onde começa a reserva de48 do resize, sem sobreposição.
- O GestureDetector opaco recebe a reserva completa, mantendo indicador visual
  alinhado à direita. Toque na borda de sort ordena; toque/drag no resize não.
- Teclado/setas e ações semânticas de resize continuam ligados à largura.
- Coluna fixa min=max não constrói handle nem indicador ineficaz.
- Cópia não interativa do cabeçalho fixado continua IgnorePointer/ExcludeSemantics.

Limite: colunas80/90 deixam sort32/42; dois alvos independentes48 não cabem nessas
larguras. G3/C0 informados. Esta revisão não certifica H25 globalAA, não aprova
novos mínimos e não amplia o gate de Formulários para todas as tabelas. Os20
testes são resultados de G3, sem rerun G4; certificação integrada pertence a C0.
Nenhum contrato novo aprovado ou conhecimento durável adicional a projetar.

Composição Formulários incluída no mesmo SHA: um teste em1440/375 confere
presença da alça, androidTapTargetGuideline e labeledTapTargetGuideline;1PASS
atribuído a G3. Total do pacote21IDs únicos (20tabela+1composto), analyze0.
O skip histórico de contraste permanece; nenhum rerun ou aceite visual G4.

## Complemento após integração C0

O ciclo integrado C0 encontrou quatro falhas de golden em Atividades e
Instituições: a reserva48 encurtava a pintura do texto em36px. G4 inspecionou
master/testImage e confirmou Unidades/Representantes legais abreviados pela
nova geometria, sem regravar imagens.

FixG3 f0e148a70 revisado: sort mantém hitbox disjunto até width-48 e pinta seu
estado de foco abaixo; conteúdo passa para Positioned.fill/IgnorePointer na
largura original, com ExcludeSemantics quando o sort já fornece rótulo. Resize
continua último alvo48. Isso preserva a pintura aprovada e os limites de toque.
G3 publicou RED1 da largura de pintura→GREEN21tabela+16nosdoisarquivosgolden,
37PASS/0FAIL/analyze0, sem PNG modificado. Esses resultados substituem a fatia
anterior correspondente; não somar reruns nem declarar AA global. Nenhum runner
G4; C0 fará a verificação integrada após receber o slot13h55.

## Memória na base integrada

Após fast-forward7d2b66a3e, G4 leu o delta C0 65f219550 no Design System17.1,
na referência coelo-ui/surface-interaction-contracts e na projeção team/
coelo-admin-directory-composite. As três fontes concordam: faixa48 disjunta,
pintura preservada sem eventos/semântica duplicada, coluna fixa sem alça e
residual32/42 explícito. Não foi necessária nova edição de memória por G4.
