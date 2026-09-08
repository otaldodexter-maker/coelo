---
title: "C07 — registro consolidado dos defeitos da rodada R01, por dono"
source: "medições próprias de C07 no baseline 4af42925: sete arquivos de aceite reservados, três reproduções em C07-evidence/repro/, laudo das 61 divergências com duas erratas, varredura do padrão FocusableActionDetector e dossiê do Publicar no Agora; decisão R01-VISUAL-1835 e instruções R01-C07-I002/I003 da C00; pedido operacional da C06 de 2026-09-08T19:42-03:00"
status: "evidence-registry"
generated_at: "2026-09-08T19:40:00-03:00"
timezone: "America/Sao_Paulo"
---

# Registro consolidado — defeitos encontrados por C07 na R01

Documento único para o fechamento. Reúne o que hoje está espalhado entre o laudo, o dossiê, a
varredura e os sete arquivos de aceite. Inclui os já corrigidos, marcados como tal, para o registro
não envelhecer.

**Convenção:** "medido" significa que existe teste ou medição minha com valor; "lido" significa
leitura de código sem execução. Nenhum defeito aqui foi corrigido por mim — não tenho reserva de
código, e a C00 negou a que pedi. Todos foram encaminhados pela C06 aos donos.

## Quadro geral

| # | Defeito | Dono | Estado | Prova |
|---|---|---|---|---|
| 1 | Acompanhamento trava em carregando quando a carga lança `Error` | C04 | aberto | medido |
| 2 | Retry de Pessoas descarta busca, filtro e página | C04 | aberto | medido |
| 3 | Dois `Limpar filtros` com comportamentos diferentes em Pessoas | C04 | aberto | medido |
| 4 | Indicador de status de Pessoas: Enter abre a pessoa em vez de expandir | C04 | aberto | medido |
| 5 | Indicador de status de Pessoas com alvo de 24, não 48 | C04 | aberto | medido |
| 6 | Card de Instituições exige dois Tab para ativar | C04 | aberto | medido |
| 7 | Indicador de status de Instituições não ativa por teclado | C04 | aberto | medido |
| 8 | Banner Criar compartilhado exige dois Tab | C00 | em correção | medido em 2 telas |
| 9 | Contorno do card do inbox do Chat coberto pelo rodapé | C05 | encaminhado | medido |
| 10 | Publicar no Agora não alcança o ramo amplo em 1440 | C05 | encaminhado | medido |
| 11 | Publicar no Agora divergente da referência aprovada | C05 | encaminhado | lido, com referência verificada |
| 12 | Rodapé do formulário no compacto contraria a baseline aprovada | C00 | aberto | lido |
| 13 | Indicador de status movido no card de Comunicações | C05 | aberto | lido |
| 14 | `_PageHeader` compacto desloca o título quando há ações | C00 | **corrigido** em `c4a7feff` | medido por mim antes |
| 15 | `CoeloAdminToggleField` sem ativação por teclado | C00 | aberto | lido |
| 16 | `principal_happens_publication_page.dart` com foco duplo | C05 | aberto | lido |

## Defeitos medidos

### 1. Acompanhamento trava em carregando — o mais grave

- **Arquivo:** `apps/superadmin/lib/features/student_tracking/presentation/student_tracking_view_model.dart`,
  linhas 78, 92, 105, 117 e 132.
- **Causa:** as cinco capturas usam `} on Exception catch (error) {`. Em Dart, `on Exception` não
  captura `Error`.
- **Medido:** um `TypeError` de decodificação escapa de `load()`, o estado nunca sai de `Loading` e o
  finder do rótulo "Carregando acompanhamento" continua encontrando o widget depois da falha. Sem
  mensagem, sem retry.
- **Por que importa:** é exatamente a falha que `fdf0972d` corrigiu em quatro view models de
  diretório, trocando `on Exception` por `on Object`, com o comentário "a load that throws and leaves
  the spinner on screen is a silent hang". Este quinto ficou de fora.
- **Reprodução:** `apps/superadmin/test/acceptance/c07_students_directory_test.dart`, três casos
  vermelhos.
- **Correção mínima:** a mesma troca, nas cinco capturas.

### 2. Retry de Pessoas descarta busca, filtro e página

- **Arquivo:** `apps/superadmin/lib/features/people/presentation/person_directory_view_model.dart`,
  linha 274 no `catch on Object` e linha 260 no ramo de negado.
- **Causa:** reseta `_query = PersonDirectoryQuery(pageSize: value.pageSize)` dentro da captura.
- **Medido:** o retry relê com consulta em branco enquanto o campo de busca continua com o termo
  digitado. A tela lista o diretório inteiro sob uma busca aparentemente ativa.
- **Por que importa:** os diretórios irmãos não fazem esse reset. Conferi Unidades. Pessoas diverge
  do contrato de retry que os outros três cumprem e que dois aceites meus provam.
- **Reprodução:** `c07_people_directory_test.dart`, caso de retry.

### 3. Dois `Limpar filtros` divergentes na mesma tela

- **Arquivo:** `apps/superadmin/lib/features/people/presentation/person_directory_page.dart`,
  linha 439 contra linha 526.
- **Causa:** a toolbar limpa o controlador antes de chamar `clearFilters`; o painel de sem-resultados
  chama `clearFilters` direto e o campo continua preenchido.
- **Medido:** o caminho da toolbar passa e serve de controle; o do painel falha.
- **Reprodução:** `c07_people_directory_test.dart`, caso de sem-resultados.

### 4 e 5. Indicador de status de Pessoas

- **Arquivo:** `apps/superadmin/lib/features/people/presentation/person_directory_page.dart`,
  linha 768.
- **Causa:** `FocusableActionDetector` sem `actions:` nem `shortcuts:`.
- **Medido:** o Enter não expande e ainda **abre a pessoa**, porque o `ActivateIntent` sobe até o
  `InkWell` do card. O alvo mede **24 × 24**, sem o mínimo de 48 que o componente aprovado impõe na
  mesma composição.
- **Por que é pior que o gêmeo:** em Instituições o Enter não faz nada; aqui ele faz a coisa errada.
- **Reprodução:** `c07_people_directory_test.dart`, dois casos.

### 6. Card de Instituições exige dois Tab

- **Arquivo:** `apps/superadmin/lib/features/institutions/presentation/widgets/institution_directory_cards.dart`,
  linha 117, envolvendo o `InkWell` da linha 152.
- **Medido:** `Expected: <1> / Actual: <2>` — Enter só ativa no segundo ponto de foco. Num diretório
  de 11 cards são 11 paradas inertes, visualmente idênticas às válidas. O toque funciona.
- **Contrato divergido:** `packages/coelo_ui_admin/lib/src/surface/coelo_admin_interactive_card.dart`,
  linhas 29 e 73-74, usa um único `FocusNode` no próprio `InkWell`.
- **Corroboração forte:** o card de **Turmas passa** no mesmo contrato, porque usa o componente
  canônico. A correção certa é migrar, não remendar o fork.
- **Reprodução:** `c07_institutions_directory_test.dart`.

### 7. Indicador de status de Instituições não ativa por teclado

- **Arquivo:** `apps/superadmin/lib/features/institutions/presentation/widgets/institution_status_presentation.dart`,
  linha 55.
- **Medido, com uma correção contra mim:** a **semântica passa** — o nó publica papel de botão e ação
  de toque, então leitor de tela ativa. Eu havia suposto o contrário na varredura e a medição me
  desmentiu. O toque expande de 24,0 para 56,5 e recolhe. O que não funciona é o teclado: com foco a
  largura vai a 56,5 só pelo realce, o Enter não muda nada, e ao sair do foco volta a 24,0. A
  expansão sob foco é cosmética.
- **Detalhe de método:** medir só com foco daria falso verde. A prova precisou medir depois do blur.
- **Reprodução:** `c07_institutions_directory_test.dart`.

### 8. Banner Criar compartilhado exige dois Tab

- **Arquivo:** `apps/superadmin/lib/shared/presentation/widgets/superadmin_directory_create_banner.dart`,
  linha 114, envolvendo o `InkWell` por volta da linha 143.
- **Medido em duas telas:** Instituições e Turmas, ambas com ativação no ponto de foco 2. Como o
  widget é compartilhado, o custo atinge toda tela com faixa de criar na tabela.
- **Estado:** a C00 informou correção com RED4→GREEN4 provado, commit em preparação.
- **Reprodução:** `c07_institutions_directory_test.dart` e `c07_groups_directory_test.dart`.

### 9. Contorno do card do inbox do Chat coberto pelo rodapé

- **Arquivos:** `apps/superadmin/lib/features/chat/presentation/screens/superadmin_chat_page.dart`,
  linhas 617-624 e 798-815, com
  `apps/superadmin/lib/shared/presentation/widgets/superadmin_listing_pagination_footer.dart`,
  linhas 42-56.
- **Medido por leitura de pixels em 1024×900 claro:** borda acima do rodapé em (308, 768) vale
  `#FFDDE0E2`; dentro da faixa do rodapé em (308, 828) vale `#FFFFFFFF`; o canto inferior esquerdo em
  (309, 863) vale `#FFFFFFFF` em vez do fundo `#FFF7F8F8`.
- **Decisão da C00:** corrigir no consumidor, preservando geometria e pintura de borda, sem mudar o
  rodapé compartilhado.
- **Reprodução:** `C07-evidence/repro/chat_inbox_border_under_pagination_test.dart`.

### 10. Publicar no Agora não alcança o ramo amplo em 1440

- **Arquivos:** `apps/superadmin/lib/features/principal_now_publication/presentation/principal_now_publication_page.dart`,
  linhas 320 e 429, com
  `apps/superadmin/lib/features/principal_shared/presentation/principal_publication_frame.dart`,
  linhas 61-62.
- **Medido:** o palco mede 260,0 em 1024 e 260,0 em 1440; o corpo vê 1120,0 enquanto a decisão
  compara com 1200.
- **Ressalva importante, aplicada por orientação da C00:** a reprodução **não exige** corpo maior ou
  igual a 1200. Esse número é diagnóstico na mensagem de falha, não condição. Dá para resolver pelo
  viewport sem ampliar o frame, e a escolha é de quem corrige.
- **Reprodução:** `C07-evidence/repro/now_publication_wide_stage_test.dart`.

## Defeitos lidos, sem medição própria

### 11. Publicar no Agora divergente da referência aprovada

Detalhado em `C07-evidence/2026-09-08-dossie-decisao-publicar-no-agora.md`. Resumo: a referência
aprovada pelo Owner em 2026-08-31 existe, foi lida por mim, e não corresponde nem ao master nem ao
código. O commit `3419a89e` acertou ao remover o trilho de etapas e errou ao remover `Sua publicação`
e a prévia lateral e ao acrescentar a barra de progresso. Os 13 goldens deixam de ser decisão do
Owner e viram defeito com alvo conhecido.

### 12. Rodapé do formulário no compacto

`apps/superadmin/lib/shared/presentation/widgets/superadmin_form_frame.dart`, alterado por
`d4374e39`. Três fontes aprovadas posteriores exigem o rodapé fora da rolagem, incluindo o plano que
criou o próprio frame. O commit tem corpo vazio e o único motivador visível é destravar um teste de
widget. Agrava porque o mesmo frame é a baseline dos anexos 31-32, o que explica o golden aprovado de
Criar Instituição falhar hoje. Detalhado na Errata 2 do laudo.

### 13. Indicador de status movido no card de Comunicações

`116231bd` tirou o indicador da linha do título no card compacto. Três fontes aprovadas exigem
reutilizar **literalmente** a anatomia de Instituições, e Comunicações é o único consumidor que
moveu. A causa raiz é o alvo de 48 que consome largura de layout, contra a doutrina aprovada de
"área interativa invisível". Detalhado na Errata 2 do laudo.

### 15. `CoeloAdminToggleField` sem ativação por teclado

`packages/coelo_ui_admin/lib/src/filter/coelo_admin_toggle_field.dart`, linha 43. É o gêmeo de
`principal_publication_frame.dart:398`, que **tem** `shortcuts` e `actions`; o do pacote não tem.
Alcance: **25 usos em 13 arquivos**, contagem minha, cruzando Atividades, Agenda, Turmas, Unidades,
Circulares, Comunicações, Formulários, Rotina, Cardápios, Segurança e Catálogo. Uma correção no
pacote resolve os 25.

### 16. `principal_happens_publication_page.dart` com foco duplo

Linha 487: `FocusableActionDetector` sem `actions:` envolvendo um `TextButton.icon`, que já é
focalizável. Mesma forma do card de Instituições.

## Já corrigido

### 14. `_PageHeader` compacto desloca o título quando há ações

- **Arquivo:** `apps/superadmin/lib/app/shell/superadmin_shell.dart`, `_PageHeader` por volta das
  linhas 1535-1566, com o `Column` pai sem `crossAxisAlignment.stretch`.
- **Medido por mim antes da correção:** título sem ações em dx 20,0; com ações em dx 39,17 a 375 e
  dx 235,67 a 768, com o bloco centralizado na tela. Achado extra: o ramo é acionado por qualquer
  `actions` não vazio, não só por `compactActions`, então atingia toda página compacta com ações.
- **Estado:** corrigido pela C00 em `c4a7feff`, com RED8→GREEN8 e regressão de 14 casos.
- **Ressalva:** minha reprodução roda contra o baseline `4af42925`, anterior à correção, e por isso
  continuaria vermelha aqui. Não é regressão: é baseline. Ofereci reexecutá-la num baseline novo para
  confirmar o verde por medição minha, em vez de aceitar o resultado de quem corrigiu.

## O que este registro não cobre

1. Os defeitos 12, 13, 15 e 16 são leitura de código sem execução. Merecem reprodução antes de
   virarem certificação.
2. A varredura de `on Exception` em caminhos de carga está em andamento no momento desta escrita e
   pode acrescentar itens. O defeito 1 é a primeira ocorrência conhecida dessa família.
3. Nenhum item aqui certifica FE, BE ou E2E. São defeitos medidos ou lidos em cliente, com repositório
   duplo, sem backend real.
4. Os 43 casos classificados como master desatualizado **não** são defeito e não estão neste
   registro. Eles esperam decisão de regeneração pela C00, e a regeneração é consequência da
   correção, nunca o contrário.
