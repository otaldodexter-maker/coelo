---
fonte: contrato coelo-ui touchMin48; PersonStatusIndicator; teclado R02 33fccac631; delegação nominal do pai
status: correção local comprovada; inspeção visual/publicação pelo pai
data_geracao: 2026-09-09
---

apps/superadmin -> Acessos -> Pessoas -> diretório/cards -> indicador informativo de status. Recorte limitado ao alvo interativo, sem alteração de status real, repository, rota ou política. Não se reauditaram outros controles.

RED comprovou tamanho interativo24×24 onde o contrato exige48×48. A correção envolve o desenho existente em ConstrainedBox com minWidth/minHeight CoeloSize.touchMin e Align central; GestureDetector usa HitTestBehavior.opaque para a borda transparente também responder. O círculo continua24×24, centralizado no alvo. A expansão continua apenas revelando o rótulo. A implementação de teclado R02 foi preservada.

Código único: apps/superadmin/lib/features/people/presentation/person_directory_page.dart, em _PersonStatusIndicatorState.

Teste alterado: apps/superadmin/test/features/people/presentation/person_status_keyboard_test.dart. O caso novo mede alvo48, círculo24 e centros coincidentes; toca bottomRight−(2,2), fora do círculo e dentro do alvo; exige expansão sem chamar edição do card; Enter recolhe após sair do foco, ainda sem chamar edição. O teste existente percorre Tab e verifica Enter. person_suspended_status_ui_test.dart foi executado, sem alteração, para preservar apresentação/semântica de suspensão em claro/escuro.

Prova final única: P4/F0/B0/S0/U0, N4. RED anteriorF1 resolvido, não somado. Não houve execução nem atualização de goldens. Os logs e hashes estão neste diretório. A análise estática focal está registrada em analyze.txt: zero problemas, exit0. Logs normalizados para UTF8 sem BOM, LF e sem espaços finais. Runner recolhido; slot Flutter liberado.

O footprint48 é uma alteração intencional e comprovada; pode deslocar o header do card. O pai deve inspecionar os renders afetados antes de qualquer reconciliação nominal de golden. Não se declara conclusão visual integral nem FE/BE/E2E. tracker_delta_proposto: [] (sem promoção de ação).

Nenhuma mutação Git, shared, router, SQL, JSON central ou recurso remoto. Fonte e teste serão revisados/publicados pelo pai. Memória: aplica contrato48 existente, sem decisão nova de produto; nenhuma projeção criada apenas para registrar atividade.

Pai revisou fonte/testes e abriu individualmente os quatro renders de cards375/768/1024/1440 antes de substituir as referencias. Causa intencional comprovada: alvo48 amplia header4px e desloca o circulo12px para dentro, preservando diametro24; fonte/testes deste lote. Pares antes/inspected e paths/hash em renders.json. Tabelas quatro permaneceram sem divergencia; nenhuma referencia de tabela alterada. Comparador posterior1P e texto200%1P em visual-green.txt, exit0. A verificacao200% foi executada pela mudanca real do footprint. Total do recorte6P (4funcionais+golden1+200%1), mas apenas5P acrescem ao total noturno pois o mesmo IDgolden ja estava contado. Essa reexecucao tem motivo material (sourcefix), nao aumenta a cobertura do caso diretorio ja contado.
