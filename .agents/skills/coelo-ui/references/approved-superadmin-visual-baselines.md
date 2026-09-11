---
source: "Aprovação visual do Owner Coelo em 2026-07-29 e confirmação em 2026-08-04; docs/design/design-system.md; goldens e testes do Superadmin"
status: "active"
generated_at: "2026-08-04"
---

# Baselines visuais aprovadas do Superadmin

**Escopo:** família visual administrativa do Superadmin e sua adoção no Admin.
As telas `Coelo (Principal)` seguem [seu contrato próprio](principal-visual-surfaces.md),
mesmo dentro de `apps/superadmin`. O Site não herda esta composição.

Esta matriz transforma os 32 anexos aprovados pelo Owner Coelo em referência
persistente. Os anexos temporários serviram para a aprovação; depois dela, os
goldens, testes e regras abaixo são a evidência canônica. Não usar imagens em
`failures/` como referência.

Esta matriz é obrigatória para criar, refazer, refatorar ou corrigir qualquer
UI do Superadmin, do estado interativo à página inteira. Quando o usuário
nomear uma tela como referência, abrir sua implementação, componentes
compartilhados, testes e golden; não basta imitar a aparência. Toda proposta
também deve ser comparada com os
[padrões rejeitados](rejected-visual-patterns-inbox.md).
Para estados interativos, usar obrigatoriamente também a
[matriz de evidência](interactive-state-evidence-matrix.md), que liga cada
estado ao código real, componente, teste e golden exato.

## Matriz de aprovação

Consultar também os [15 anexos de correções de Estruturas](../../../../docs/reviews/evidence/etapa-2/estruturas-superadmin/README.md)
quando a tela estiver nesse recorte. O manifesto registra a correção por tela,
incluindo Turmas, Atividades e Avaliações; distingue referências de problemas.
Preservação do arquivo não certifica a correção nem transforma defeito em padrão.

| Anexos | Superfície e estados aprovados | Evidência persistente |
| --- | --- | --- |
| 1–7 | Login: campo em repouso e foco, senha, checkbox, botão padrão/hover, link e aviso de acesso restrito | `apps/superadmin/test/features/auth/presentation/screens/goldens/superadmin_login_light.png`; `superadmin_login_golden_test.dart`; `superadmin_login_screen_test.dart` |
| 8–18 | Instituições: paginação, criar card, card/hover, grid, arquivos, filtros, busca/foco, toggle, tabela e seus espaçamentos | `apps/superadmin/test/features/institutions/presentation/screens/goldens/`; `institution_directory_page_golden_test.dart`; `institution_directory_page_test.dart` |
| 19 | Home/Central de ajuda: conversas à esquerda, ajuda central, sugestões e compositor inferior | `apps/superadmin/test/features/help_center/presentation/screens/goldens/help_center_empty_light_1440.png`; `help_center_page_golden_test.dart` |
| 20–24 | Menu expandido e rail compacto; níveis, seleção, hover e flyouts de Tour/Acessos | `apps/superadmin/test/app/shell/superadmin_shell_test.dart`; `apps/superadmin/test/features/institutions/presentation/screens/goldens/institution_directory_collapsed_flyout_hover_light_1024.png` |
| 25–26 | Flyout da conta: Perfil, Configurações, divisor e Sair negativo, incluindo hover | `apps/superadmin/test/app/shell/superadmin_shell_test.dart`; contrato `pattern.flyout-actions` |
| 27 | Perfil: cards em duas colunas, formulário, acesso/segurança e rodapé com extremos | `apps/superadmin/test/features/account/presentation/screens/goldens/profile_1440_dark.png`; `account_pages_golden_test.dart`; `profile_page_test.dart` |
| 28 | Ajustar foto: cabeçalho, X vermelho, crop, reset, slider e ações 50/50 | `apps/superadmin/test/features/account/presentation/screens/profile_page_test.dart`; contratos `pattern.overlay-surfaces` e `pattern.dialog-actions` |
| 29 | Configurações: largura central, cards, tema segmentado e reduzir animações | `apps/superadmin/test/features/account/presentation/screens/goldens/settings_1440_dark.png`; `account_pages_golden_test.dart`; `settings_page_test.dart` |
| 30 | Bug: popup neutro, X vermelho, selects, texto, anexo, ajuda e Enviar disabled | goldens `*_bug_open_light_1440.png`; `CoeloAdminDialogShell`; `pattern.overlay-surfaces` |
| 31–32 | Criar/Editar instituição: baseline obrigatória de qualquer tela que crie ou edite uma entidade; estado atual completo, incluindo shell/menu atual, chat, stepper lateral, conteúdo, uploads, campos e rodapé de tela | `apps/superadmin/test/features/institutions/presentation/screens/goldens/institution_form_create_light_375.png`; `institution_form_edit_dark_1440.png`; `institution_form_page_golden_test.dart` |
| Aprovação 2026-08-03 | Acessos > Pessoas: toolbar em faixa própria e tabs lineares sutis para categorias irmãs | `apps/superadmin/lib/shared/presentation/widgets/superadmin_underline_tabs.dart`; `person_directory_page_test.dart`; contrato `pattern.directory-linear-tabs` |
| Aprovação 2026-08-04 | Rodapé de fluxo: `Cancelar` no extremo esquerdo; `Anterior` + `Continuar` outlined e `Salvar alterações` filled no extremo direito; estados menores preservam a ordem | `SuperadminFormActionFooter`; `pattern.form-controls`; testes do componente e do catálogo |
| Aprovação 2026-08-04 | Mídia e marca: ajuste circular de foto, ajuste retangular de capa e seletor avançado de cores | `AvatarCropDialog`; `CoverCropDialog`; `showSuperadminAdvancedColorPicker`; `pattern.media-adjustment`; `superadmin.advanced-color-picker` |
| Aprovação 2026-08-04 | Navegação paginada de qualquer fluxo sequencial: concluída, atual tonal e pendente; paginação de registros permanece um contrato distinto | `SuperadminFormStepNavigation`; `pattern.form-step-navigation`; `pattern.directory-pagination` |
| Aprovação 2026-09-10 | Decisão por arquivo dos 165 goldens claros divergentes e regras transversais: menu/cabeçalho de Instituições e Atividades com Pesquisar e Bug em toda tela; chat da referência; card Criar primeiro no grid, inclusive vazio e falha; abas Todos/Ativos/Rascunhos/Inativos; Continuar/Cancelar no rodapé mobile; sem fundo cinza; flyouts com respiro; arquivar/duplicar no conceito do card de modelo de atividade | [Decisões dos goldens claros](../../../../docs/reviews/evidence/etapa-2/goldens-claro-decisoes-2026-09-10.md); anexo do diretório de Instituições de 10/09 |
| Aprovação 2026-08-04 | Saúde e Cuidado: Perfis de cuidado e Planos de medicação como áreas irmãs; múltipla escolha de formulário e status Histórico | `CoeloAdminMultiSelectField`; `CoeloStatusColors.historyContainer`; `specs/020-superadmin-health-care.md` |

## Regras que os anexos tornam explícitas

### Login

- Campo usa superfície neutra, label persistente, ícone e borda
  `outlineVariant`; foco usa borda `primary` de 2 px sem preenchimento laranja.
- Checkbox selecionado e ação principal usam `primary`. O botão principal
  permanece laranja no hover, com o estado pressionado/forte do tema, sem
  overlay cinza.
- Link de recuperação usa a cor de ação aprovada e sublinhado. O aviso de
  acesso restrito é uma superfície tonal informativa, não um alerta de erro.

### Instituições

- Toolbar, conteúdo e paginação formam uma composição única. Não alterar
  medidas de card, tabela, gaps ou paginação isoladamente.
- Card comum preserva `surface` no hover; somente borda e sombra ganham ênfase
  primária sutil. O card de criar usa borda tracejada; no hover, borda e círculo
  do ícone assumem a hierarquia primária.
- Instituições é a baseline obrigatória para todo card de diretório
  administrativo, não apenas para esta feature. O card nunca recebe hover cinza
  ou retangular: preserva `surface`, `radius.lg` e overlay transparente.
- O status do card começa como indicador circular de 24 × 24 sem texto e
  expande para revelar o rótulo em hover, foco ou toque no indicador. As cores
  são semânticas, o texto impede dependência exclusiva de cor e reduced motion
  remove a animação não essencial.
- Filtro aberto usa linhas contínuas. Opção hovered não recebe raio; seleção
  usa checkbox laranja. O rodapé do multi-select divide `Limpar` tonal e
  `Aplicar` preenchido em 50/50.
- A tabela preserva cabeçalho tonal neutro, divisores, linhas contínuas e
  distância `space4` da faixa de criação. Linha hovered não vira card.

### Navegação, flyouts e ações negativas

- Menu expandido e rail compacto compartilham a mesma semântica: top-level
  selecionado usa fundo primário; filho hovered usa `primaryContainer`; filho
  selecionado usa primário. Pai de seção ativa ganha ênfase sem competir com o
  item filho.
- Flyouts de Tour, Acessos, Arquivos e Conta usam `surface`, borda, elevação e
  item discreto arredondado. Não usar fundo tonal no flyout inteiro.
- `X`, Sair, Desligar, Encerrar, Fechar, Remover, Deletar e Excluir usam
  `error` em repouso e `errorContainer` no hover/foco. Ações terminais ficam em
  grupo inferior separado por divisor.
- Em `Acessos > Pessoas`, categorias irmãs usam tabs lineares sem cápsula:
  linha-base neutra, label e underline laranja somente na seleção, hover/foco
  tonal primário sutil e `space4` separando toolbar, tabs e conteúdo. Esse
  padrão não substitui o toggle Cards/Tabela nem filtros/chips.

### Perfil, Configurações, Home e formulários

- Perfil usa conteúdo principal mais largo e coluna auxiliar; o rodapé de tela
  posiciona Redefinir/Cancelar à esquerda e Salvar à direita.
- Configurações usa conteúdo central com largura máxima, cards neutros, três
  segmentos de tema iguais e switch de reduzir animações.
- Home preserva painel de conversas, área central de orientação e compositor
  inferior; sugestões são ações tonais e o envio mantém a hierarquia laranja.
- Criar/Editar instituição é a verdade visual padrão de toda criação/edição no
  Superadmin, seja formulário simples ou wizard de página. O domínio altera
  conteúdo e regras, não autoriza uma identidade paralela. Em desktop, Cancelar
  fica no extremo esquerdo e o grupo Anterior/Continuar/Salvar no direito.
  `OutlinedButton` é secundário, `TextButton` é terciário e somente uma ação
  preenchida é primária.
- Por confirmação do Owner em 2026-08-04, os goldens de Criar/Editar registram
  a tela como existe hoje por inteiro. O shell, o menu atual e o chat exibidos
  nesses goldens também pertencem à referência; não devem ser removidos,
  substituídos ou aproximados por uma versão antiga ao reutilizar a baseline.
- Qualquer divergência de composição ou identidade deve ser proposta ao Owner
  antes do código, com comparação, componentes, estados, tokens,
  responsividade e testes. Sem aprovação explícita, preservar esta baseline.
- Em dialogs: uma ação ocupa 100%, duas dividem 50/50 e três dividem em terços.
  Em tela ampla: usar extremos; não aplicar a regra 50/50 do dialog ao rodapé.

## Gate visual

Antes de concluir mudança nessas superfícies:

1. consultar `pattern.approved-superadmin-surfaces` e o padrão específico;
2. identificar o golden aprovado equivalente;
3. validar 375, 768, 1024 e 1440 quando a composição responder por breakpoint;
4. validar light/dark, hover, foco, teclado, texto a 200% e reduced motion;
5. executar teste funcional antes do golden e nunca atualizar golden para
   esconder regressão.
6. não aceitar golden geral da página como prova de hover, foco, seleção, menu
   aberto, expansão ou ação negativa; usar o arquivo exato da matriz.

## Decisões do Owner de 2026-09-10 sobre Cuidado, Medicação e Rotina

Registradas na ADR 0034, Decisão 9, a partir da página de comparação lado a
lado do grupo `formularios-cuidado-rotina`.

### Goldens de Perfis de cuidado e Planos de medicação

| Arquivo | Decisão | O que ela obriga |
| --- | --- | --- |
| `medication_form_mobile_light` | **R** | A referência guardada continua valendo. O código volta a ela; o render atual é a regressão. |
| `profile_form_mobile_light` | **A** | O render atual passa a ser a referência, mas só depois de aplicar a observação abaixo. |
| `profile_form_desktop_dark` | **A** | Idem, seguindo esta skill. |

Observação do Owner que condiciona os dois `A`: **o wizard de Perfis de cuidado
não segue 100% o padrão administrativo**, e ele citou o contêiner interno como
exemplo. Alinhar o wizard a esta skill antes de regravar; regravar primeiro
congelaria o desvio como referência.

`profile_form_desktop_dark` não pôde ser deduzido pela regra "o escuro segue o
claro de mesmo nome", porque o claro que diverge é o de 375 px e não o de
1440 px. Por isso foi decidido separadamente.

### As seis referências da Rotina

A decisão D8 mandava "regravar as seis referências" do editor de Rotina sem
nomear os arquivos. O Owner esclareceu em 2026-09-10: **as referências são as do
modelo de atividade, aplicadas ao modelo de rotina diária**. Ou seja, o editor
de modelo de Rotina segue a família visual do modelo de atividade; não existem
seis goldens de rotina esperando regravação por conta própria.

A guarda de alterações não salvas do editor de Rotina já estava ligada e
provada antes desta decisão (`PopScope` com `canPop: !_isDirty`, confirmação
também na saída pelo menu, e `daily_routine_dirty_exit_test`).

## Referência do Owner de 2026-09-11 para o calendário da Agenda

Em 11/09/2026 (10:13), ao responder as dúvidas visuais da Rodada 4, o Owner
enviou uma captura do calendário nativo do iPhone (visão mensal, setembro de
2026) como **referência de agenda/calendário**. O arquivo está guardado em
`docs/reviews/evidence/etapa-2/referencias/agenda-calendario-mensal-ios-2026-09-11.png`
(versionado em 11/09 às 10:55 a pedido do Owner); esta descrição resume o que ele fixa. O que a referência define, e que a Agenda
do Coelo (`agenda.view`, `agenda_calendar_*`) segue em todas as larguras:

- **Cabeçalho**: navegação de volta para o ano à esquerda ("< 2026"), ações à
  direita em um grupo compacto (lista, buscar, criar) e o nome do mês em título
  grande e pesado abaixo.
- **Grade mensal**: sete colunas com a inicial do dia da semana (D S T Q Q S S),
  linhas de altura igual e generosa, separadas por linhas finas; fins de semana
  em cinza; o dia de hoje em círculo cheio na cor de destaque com o número em
  branco.
- **Eventos dentro da célula**: cada evento é uma pastilha com fundo suave na
  cor da categoria, ícone pequeno à esquerda e o título truncado; várias
  pastilhas empilhadas na mesma célula, uma por linha, sem reduzir a célula.
  Isto responde à observação "retângulos muito amassados": as células não
  encolhem, o texto trunca.
- **Evento cancelado**: pastilha com fundo hachurado, prefixo "CANCELADO:" e o
  horário abaixo do título; continua visível no calendário.
- **Rodapé**: botão "Hoje" à esquerda e, à direita, um grupo com alertas e
  caixa de entrada com contador; o botão de criar fica no cabeçalho, não no
  rodapé.
- No Coelo, as pastilhas usam as cores semânticas do Design System (categoria
  do evento) e a família Nunito Sans; o composto não replica a barra de status
  do sistema.

Esta referência prevalece sobre `agenda_calendar_light_375` guardado quando o
Owner responder P33; a regravação só acontece depois de aplicar o padrão acima.

### Segunda captura (10:17): visão diária

O Owner enviou também a **visão diária** do mesmo calendário (terça-feira, 8
de setembro de 2026), guardada em
`docs/reviews/evidence/etapa-2/referencias/agenda-calendario-diario-ios-2026-09-11.png`.
O que ela define para o detalhe de dia da Agenda:

- **Cabeçalho**: voltar para o mês à esquerda ("< Setembro"), o mesmo grupo de
  ações à direita, e abaixo a faixa da semana com as iniciais dos dias e os
  números; o dia selecionado em círculo cheio escuro com o número em branco;
  o dia de hoje em vermelho sem preenchimento; fins de semana em cinza.
- **Título do dia** centralizado por extenso ("Terça-feira – 8 de set. de
  2026") sobre uma linha divisória.
- **Grade por hora**: rótulos de hora à esquerda ("04:00", "05:00"…), linhas
  finas horizontais, altura fixa por hora; rolagem vertical.
- **Evento no horário**: bloco que ocupa a faixa entre início e fim, com barra
  vertical à esquerda na cor da categoria, título e subtítulo dentro; ícones
  de recorrência e anexo no canto direito.
- **Evento cancelado**: mesmo bloco em cinza, título **riscado**, prefixo
  "CANCELADO:"; permanece no horário.
- **Rodapé**: botão Hoje à esquerda e, à direita, o atalho para o mês e a
  caixa de entrada com contador.

As duas capturas juntas fixam a navegação ano → mês → dia da Agenda e o
tratamento de evento cancelado (hachurado no mês, riscado no dia).

## Respostas do Owner de 2026-09-11 (tarde) às dúvidas visuais da Rodada 5

- **G-SUP (Suporte e Em implantação alinhados como Instituições; 16 goldens
  claros `support_*_light_*` e `plan_table_light_*`): aprovado às 14:20**
  ("está tudo aprovado, ficou legal"). Regra que vira baseline: toda célula de
  `CoeloAdminResizableTable` é alinhada à esquerda e centralizada na linha
  pelo composto; detalhe lateral em corpo estreito no desktop entra como
  `bodyOverride` do composto para manter a toolbar.
- **Agenda P33/P34 (12 goldens `agenda_calendar_*` e `agenda_detail_*`,
  regravados no 3.44.2 após as observações):** página lado a lado enviada
  (artefato 881e760e; cópia em
  `docs/reviews/evidence/etapa-2/r05-publicacoes-agenda/duvidas-visuais.html`),
  aguardando resposta. Até lá os goldens regravados valem como render atual,
  não como aprovação.
- **Perfil do Principal (P28) e perfil Coelo (P35):** goldens de Perfil,
  Acontece, Para você e publicadores regravados pela frente principal-chat
  após a observação do cabeçalho; aprovação visual do Owner pendente na
  próxima página lado a lado.

## Respostas do Owner de 2026-09-11 às dúvidas visuais da Rodada 4

Fonte: página de decisões da R04 (artefato "Decisões R04", respondida às
10:40 de 11/09). Convenção: **R** referência guardada, **A** regravar, **A+**
regravar depois de aplicar a observação.

- **P26 error_409_light / error_409_dark: A.** As duas imagens candidatas
  viram golden oficial da família de erro.
- **G-FORM forms_editor_* 1440 (5 arquivos): A.** Regravar no SDK 3.44.2.
- **G-SUP support_kanban/table/detail (32 arquivos): A+.** "Ficou muito
  bom", mas a tabela de Suporte e a de Em implantação ainda têm colunas
  desalinhadas: o conteúdo alinha à esquerda, porém colunas como Origem ficam
  no canto superior esquerdo da célula. Alinhar igual à tabela de
  Instituições (alinhamento vertical e horizontal das células no composto),
  depois regravar; support_detail_light_1024 continua R.
- **P34 agenda_detail_light_375/768/1440: A+.** "Não está legal": fundo cinza
  fora dos tokens; cancelar/excluir fica à esquerda e salvar/continuar à
  direita; o rodapé precisa ser igual ao de criar/editar Instituição
  (SuperadminFormFrame). Corrigir e regravar.
- **P33 agenda_calendar_light_375: R.** "Ficou legal, mas faltam ajustes
  pequenos; tem de ficar mais próximo do calendário do iPhone": canto
  arredondado menos redondo; a fonte da data um pouco menor, colada ao canto
  superior esquerdo da célula com respiro; provavelmente o problema é o
  calendário estar dentro de um contêiner. O par de botões calendário/lista
  divide 50% cada, maior e centralizado. Regra de conteúdo: o calendário
  mostra tudo a que a hierarquia dá direito (eventos, aniversários de amigos
  de turma, de funcionários se a unidade liberar, provas); responsável vê
  todas as crianças e filtra pela opção de perfil; funcionário filtra por
  turma, instituição e outros; híbrido escolhe.
- **P28 principal_profile_light_1440: R**, com quatro correções antes de
  qualquer regravação:
  1. o círculo do avatar está "cortado" embaixo, como se o nome o cortasse;
  2. o cabeçalho (Bug, sino, perfil, logo) está diferente do contexto mobile:
     a logo não é a nossa e o espaçamento parece incorreto;
  3. o @ do perfil deve aparecer;
  4. os avatares de vínculos sobrepostos (laranja por padrão) ficam bonitos,
     mas precisam de contorno (branco no claro, preto ou outro tom do laranja
     no escuro) para não parecer uma coisa só.
  Regras de produto que acompanham: a opção de perfil no cabeçalho do
  Principal faz filtragem (responsável por criança, funcionário por turma e
  instituição, híbrido por "ver como responsável", "como funcionário" ou
  ambos), com até 5 perfis inline e "ver todos" abrindo um popup simples de
  lista; responsável não tem "+ Agora", que adiciona no Acontece e só aparece
  para quem pode publicar; ao publicar fora do perfil selecionado, o app
  pergunta em qual perfil vai publicar.
