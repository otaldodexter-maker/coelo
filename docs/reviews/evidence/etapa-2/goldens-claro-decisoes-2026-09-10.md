---
title: "Decisões do Owner sobre os 165 goldens claros divergentes"
source: "Lista do Owner Coelo em 2026-09-10 sobre quatro páginas de comparação lado a lado (referência guardada, render atual em dev, diferença); suíte completa de apps/superadmin de 2026-09-10 03:42 sobre dev 67faf0e2b; anexo do Owner com o diretório de Instituições"
status: "approved"
generated_at: "2026-09-10"
---

# Decisões do Owner sobre os goldens claros divergentes

Em 10/09/2026 o Owner revisou as 165 comparações em tema claro e decidiu,
arquivo por arquivo, qual imagem vale. Esta página é a fonte dessas decisões.
Os goldens escuros equivalentes seguem a decisão do golden claro de mesmo
nome. Nada é regravado antes de aplicar a observação do item.

## Legenda

- **Referência (R)**: a imagem guardada em `goldens/` continua valendo. O
  código volta a ela. Quando há observação, a referência vale exceto no ponto
  indicado, que é corrigido antes de regravar.
- **Atual (A)**: o render atual em `dev` passa a ser a referência. Quando há
  observação, o golden só é regravado depois de corrigir o ponto indicado.
- Observações curtas usam os códigos das regras transversais abaixo.

## Regras transversais (valem para todas as telas administrativas)

| Código | Regra aprovada |
| --- | --- |
| MENU | O menu lateral e o cabeçalho de todas as telas seguem a referência guardada de Instituições e Atividades (anexo do Owner de 10/09): Estrutura expandida, item ativo em laranja, flyout Aparência/Unidades/Turmas/Atividades, campo **Pesquisar** no menu, botão de **Bug** no cabeçalho, avatar/conta. O "pesquisar no menu" nunca é removido; o botão de bug nunca é omitido. |
| CHAT | O widget de chat (balão flutuante e painel) segue a referência guardada de Atividades e Instituições em todas as larguras, inclusive mobile. |
| CRIAR | Todo diretório tem card **Criar** como primeiro item do grid, no padrão de Criar instituição, inclusive nos estados vazio e de falha. Diretórios em tabela ou lista mantêm o Criar acima do conteúdo, inclusive acima de "Nenhum resultado". |
| TABS | Diretórios com estado mantêm as abas Todos / Ativos / Rascunhos / Inativos abaixo do filtro, como no render atual de Atividades. |
| RODAPÉ | Formulários em mobile levam Continuar e Cancelar ao rodapé, no contrato de Criar/Editar instituição. |
| FUNDO | Nenhuma tela usa fundo cinza nem botão principal fora do laranja; cabeçalho de menu presente. Padrão `coelo-ui`. |
| TABELA | Tabelas seguem o padrão administrativo (alinhamento interno, filtros alinhados, toggle card/tabela). |
| FLYOUT | Flyouts de perfil e do card com foto ou sigla abrem com respiro, nunca colados na borda da tela. |
| ARQUIVO | Botão de arquivar/duplicar nos cards de Cardápios e Planos segue o conceito de duplicar do card de modelo de atividade; o ícone atual está errado. |
| DADOS | Dados fictícios dos goldens usam as quantidades já alinhadas com o Owner. |
| MENU-M | Cabeçalho mobile (375/768) segue o anexo do Owner de 10/09: logo Coelo com breadcrumb "Coelo ›", sino e avatar/sigla à direita, **mais o botão de Bug**, que hoje falta. |
| ARQUIVOS-CHAT | Decisão de 10/09: o botão Arquivos (importar/exportar) fica **escondido em Conversas** em todas as larguras; os demais diretórios mantêm o botão. É uma configuração do componente compartilhado, não exceção codificada na tela. |

Para Coelo (Principal) hospedado no Superadmin:

| Código | Regra aprovada |
| --- | --- |
| SHELL | No web do Superadmin, Acontece, Momentos e Perfil aparecem com o shell/menu e o conteúdo Principal dentro do contêiner. |
| MAIS | O botão "mais" do Acontece é laranja com o "+" branco; o tracejado é mantido. |
| IMG | Momentos não perde nem corta imagem no mobile; no desktop a área preta preenche mais e a largura em 1024 se aproxima da de 1440. |
| FOTO | A foto do perfil Principal não pode aparecer recortada. |

## Estrutura (73)

### Atividades

| Golden | Decisão | Observação |
| --- | --- | --- |
| activity_detail_light_375 | A | |
| activity_directory_bug_open_light_1440 | R | MENU: menu e mensagem desta referência valem para todos |
| activity_directory_card_hover_light_1440 | R | MENU |
| activity_directory_cards_light_1024 | R | MENU |
| activity_directory_cards_light_1440 | R | MENU |
| activity_directory_cards_light_375 | A | CHAT igual à referência, para todos |
| activity_directory_cards_light_768 | A | CHAT; ajustar posicionamento dos filtros |
| activity_directory_filter_open_light_1440 | R | MENU |
| activity_directory_models_light_1440 | R | MENU pela referência; acrescentar **Arquivos** que existe no atual; manter TABS do atual abaixo do filtro; CHAT |
| activity_directory_pagination_open_light_1440 | R | MENU |
| activity_directory_profile_open_light_1440 | R | MENU; FLYOUT: ao clicar no card OC (foto ou sigla) o flyout abre colado, precisa de espaço |
| activity_directory_table_light_1024 | R | MENU; manter TABS do atual |
| activity_directory_table_light_375 | A | CHAT |
| activity_directory_table_light_768 | A | CHAT |
| activity_directory_table_row_hover_light_1440 | R | manter TABS do atual |
| activity_directory_text_200_light_375 | A | CHAT |
| activity_directory_tour_open_light_1440 | R | |
| activity_form_create_light_375 | A | RODAPÉ com Continuar e Cancelar da referência; CHAT |
| activity_form_location_dialog_light_375 | A | |

### Turmas

| Golden | Decisão | Observação |
| --- | --- | --- |
| group_directory_bug_open_light_1440 | A | card com excesso de espaçamento; MENU |
| group_directory_card_hover_light_1440 | A | card com excesso de espaçamento; MENU |
| group_directory_cards_light_1024 | A | card com excesso de espaçamento; MENU |
| group_directory_cards_light_1440 | A | card com excesso de espaçamento; MENU |
| group_directory_cards_light_375 | A | card de criar turma talvez exagerado; revisar tamanho |
| group_directory_cards_light_768 | A | card com excesso de espaçamento |
| group_directory_create_banner_focus_light_1440 | A | MENU |
| group_directory_create_card_hover_light_1440 | A | card com excesso de espaçamento; MENU |
| group_directory_filter_selected_light_1440 | A | card com excesso de espaçamento; MENU |
| group_directory_institution_filter_open_light_1440 | A | card com excesso de espaçamento; MENU |
| group_directory_pagination_page_size_open_light_1440 | A | card com excesso de espaçamento; MENU |
| group_directory_profile_open_light_1440 | A | card com excesso de espaçamento; MENU; FLYOUT de perfil muito colado |
| group_directory_table_light_1024 | A | card com excesso de espaçamento; MENU |
| group_directory_table_light_1440 | A | |
| group_directory_table_light_768 | A | |
| group_directory_table_row_hover_light_1440 | A | MENU |
| group_directory_tour_open_light_1440 | A | card com excesso de espaçamento; MENU |
| group_form_create_light_375 | A | RODAPÉ: Continuar e Cancelar mais ao rodapé; CHAT |

### Instituições

| Golden | Decisão | Observação |
| --- | --- | --- |
| institution_directory_card_hover_light_1440 | R | DADOS |
| institution_directory_cards_light_1024 | R | |
| institution_directory_cards_light_1440 | R | |
| institution_directory_cards_light_375 | A | |
| institution_directory_cards_light_768 | A | |
| institution_directory_collapsed_flyout_hover_light_1024 | A | |
| institution_directory_empty_light_1440 | R | |
| institution_directory_failure_light_1440 | R | CRIAR: sem nenhuma instituição, o card Criar tem que existir |
| institution_directory_filter_selected_light_1440 | R | |
| institution_directory_loading_light_1440 | R | |
| institution_directory_no_results_light_1440 | R | |
| institution_directory_pagination_disabled_light_1440 | R | MENU: não desconsiderar o Pesquisar no menu, para todos |
| institution_directory_pagination_page_size_open_light_1440 | R | |
| institution_directory_search_focus_light_1440 | R | |
| institution_directory_status_tabs_light_1440 | R | |
| institution_directory_table_flyout_open_light_1440 | R | |
| institution_directory_table_light_1024 | R | |
| institution_directory_table_light_1440 | R | |
| institution_directory_table_light_375 | A | TABELA no padrão da referência |
| institution_directory_table_light_768 | A | |
| institution_directory_unauthorized_light_1440 | R | |
| institution_form_bio_light_1440 | R | |
| institution_form_create_light_375 | A | |

### Locais e Unidades

| Golden | Decisão | Observação |
| --- | --- | --- |
| location_detail_focus_light_375 | A | |
| location_detail_light_375 | A | |
| unit_directory_light_1024 | R | |
| unit_directory_light_1440 | R | |
| unit_directory_light_375 | A | |
| unit_directory_light_768 | A | |
| unit_directory_table_light_1024 | R | |
| unit_directory_table_light_1440 | R | |
| unit_directory_table_light_375 | A | |
| unit_directory_table_light_768 | A | |
| unit_form_create_light_375 | A | |

## Formulários e Cuidado (24)

| Golden | Decisão | Observação |
| --- | --- | --- |
| forms_directory_actions_light_1440 | A | MENU |
| forms_directory_empty_light_375_v4_19 | A | filtros fora do padrão `coelo-ui` |
| forms_directory_light_375 | A | filtros e TABELA fora do padrão `coelo-ui` |
| forms_directory_light_768 | A | filtros e TABELA fora do padrão `coelo-ui` |
| forms_directory_no_results_light_375_v4_19 | A | filtros fora do padrão `coelo-ui` |
| forms_directory_unauthorized_light_375_200_v4_19 | A | |
| forms_editor_catalog_groups_light_1440 | A | MENU; falta o Bug no cabeçalho |
| forms_editor_catalog_light_1440 | A | MENU; falta o Bug no cabeçalho |
| forms_editor_date_range_light_1440 | A | MENU; falta o Bug no cabeçalho |
| forms_editor_light_1024 | A | MENU; falta o Bug no cabeçalho |
| forms_editor_light_1440 | A | MENU; falta o Bug no cabeçalho |
| forms_editor_light_375 | A | falta o Bug no cabeçalho |
| forms_editor_light_375_text_200 | A | falta o Bug no cabeçalho |
| forms_editor_light_768 | A | |
| forms_operations_monitor_light_375 | A | falta o Bug no cabeçalho |
| form_response_light_375 | A | |
| medication_directory_mobile_light | A | falta o Bug no cabeçalho |
| medication_form_mobile_light | A | |
| profile_directory_card_hover_light_1440 | R | MENU; falta o Bug no cabeçalho |
| profile_directory_files_open_light_1440 | R | |
| profile_directory_mobile_light | A | |
| profile_directory_table_light_1440 | R | TABELA fora do padrão `coelo-ui` |
| profile_directory_tabs_selected_light_1440 | A | CRIAR acima de "Nenhum resultado"; MENU |
| profile_form_mobile_light | A | RODAPÉ; "Criar Perfil de cuidado" fora do padrão de criar de `coelo-ui` (Criar instituição) |

## Operação e sistema (42)

### Menu de desenvolvimento, Conta e Configurações

| Golden | Decisão | Observação |
| --- | --- | --- |
| dev_menu_all_parent_routes_light_375 | A | o grupo e as hierarquias do menu já tinham sido arrumados; conferir regressão |
| profile_375_light | A | |
| profile_768_light | A | |
| settings_375_light | A | |
| settings_768_light | A | |

### Agenda

| Golden | Decisão | Observação |
| --- | --- | --- |
| agenda_calendar_light_1440 | A | MENU |
| agenda_calendar_light_375 | A | retângulos muito amassados |
| agenda_calendar_light_768 | A | |
| agenda_create_light_375 | R | FUNDO: fora do padrão `coelo-ui`, fundo cinza, botão não laranja, sem cabeçalho de menu |
| agenda_detail_light_1440 | R | FUNDO: idem |
| agenda_detail_light_375 | R | FUNDO: idem |
| agenda_detail_light_768 | R | FUNDO: idem |
| agenda_list_light_1440 | R | MENU |
| agenda_list_light_375 | A | |
| agenda_list_light_768 | A | |

### Auditoria, Central de ajuda e Importações

| Golden | Decisão | Observação |
| --- | --- | --- |
| audit_directory_desktop_light_1024 | R | ajustar filtros |
| audit_directory_empty_light_1440 | R | |
| audit_directory_failure_light_1440 | R | |
| audit_directory_mobile_light_375 | A | |
| help_center_empty_light_1440 | R | |
| import_hub_wizard_light_375 | R | FUNDO: fora do padrão `coelo-ui`, fundo cinza, botão não laranja, sem cabeçalho de menu |

### Cardápios e Planos

| Golden | Decisão | Observação |
| --- | --- | --- |
| meal_plan_directory_card_hover_light_1440 | R | ARQUIVO |
| meal_plan_directory_flyout_light_1440 | R | sem botão Excluir; sem shell |
| meal_plan_directory_light_1440 | R | ARQUIVO |
| meal_plan_directory_light_375 | R | ARQUIVO |
| meal_plan_wizard_new_light_375 | R | |
| plan_cards_light_1024 | R | ARQUIVO; FUNDO cinza incorreto, usar `coelo-ui` |
| plan_cards_light_1440 | R | ARQUIVO; FUNDO |
| plan_cards_light_375 | R | ARQUIVO; FUNDO |
| plan_cards_light_768 | R | ARQUIVO; FUNDO |

### Suporte

| Golden | Decisão | Observação |
| --- | --- | --- |
| support_detail_light_1024 | R | |
| support_detail_light_1440 | A | |
| support_detail_light_375 | A | |
| support_detail_light_768 | A | |
| support_kanban_light_1024 | A | |
| support_kanban_light_1440 | A | |
| support_kanban_light_375 | A | |
| support_kanban_light_768 | A | filtros desalinhados |
| support_table_light_1024 | A | filtros desalinhados; MENU; TABELA fora do padrão |
| support_table_light_1440 | A | MENU; TABELA (alinhamento interno); melhorar o card Criar |
| support_table_light_375 | A | CHAT |
| support_table_light_768 | A | MENU; TABELA (alinhamento interno); melhorar o card Criar; CHAT |

## Coelo Principal e Comunicação (26)

### Chat administrativo

| Golden | Decisão | Observação |
| --- | --- | --- |
| superadmin_chat_light_1024 | A | regressão: sumiram Criar grupo, Fixar conversas e sinalizadores de bandeira; MENU |
| superadmin_chat_light_1440 | A | regressão: idem; MENU |
| superadmin_chat_light_375 | A | |
| superadmin_chat_light_768 | A | regressão: idem; MENU |
| superadmin_chat_reduced_motion_light_375 | A | ARQUIVOS-CHAT: esconder o botão Arquivos em Conversas (decisão B de 10/09); MENU-M |

### Circulares, Comunicações e Avisos

| Golden | Decisão | Observação |
| --- | --- | --- |
| circular_directory_light_375 | A | |
| circular_directory_text_200_375 | A | |
| communication_directory_light_375 | A | falta o toggle card/tabela de `coelo-ui` |
| communication_directory_text_200_375 | A | |
| notice_form_initial_mobile_light_375 | R | FUNDO cinza fora de `coelo-ui` |

### Coelo Principal

| Golden | Decisão | Observação |
| --- | --- | --- |
| principal_happens_light_1024 | A | SHELL; MAIS |
| principal_happens_light_1440 | A | SHELL; MAIS |
| principal_happens_light_375 | A | contêiner das imagens do Acontece ruim e fora do padrão de contêiner `coelo-ui` |
| principal_happens_light_768 | A | SHELL; MAIS |
| principal_happens_now_hover_light_1440 | A | SHELL; MAIS |
| principal_moments_light_1024 | R | IMG: largura muito pequena, aproximar de 1440 |
| principal_moments_light_1440 | R | IMG: parte preta preencher mais |
| principal_moments_light_375 | A | IMG: sem perder nem cortar imagem |
| principal_moments_light_768 | A | IMG: sem perder nem cortar imagem |
| principal_moments_like_hover_light_1440 | R | IMG: parte preta preencher mais |
| principal_moments_text_200_light_375 | A | |
| principal_profile_light_1024 | R | FOTO; SHELL |
| principal_profile_light_1440 | R | FOTO; SHELL |
| principal_profile_light_375 | R | FOTO |
| principal_profile_light_768 | R | FOTO |
| principal_profile_text_200_light_375 | R | |

## Como executar

1. Aplicar primeiro as regras transversais (MENU, CHAT, CRIAR, TABS, RODAPÉ,
   FUNDO, TABELA, FLYOUT, ARQUIVO) nos componentes compartilhados do shell e
   de `coelo_ui_admin`, porque elas resolvem a maior parte das observações de
   uma vez.
2. Para cada golden **R**: corrigir o código até bater com a imagem guardada,
   mais a observação; o golden não muda.
3. Para cada golden **A** sem observação: regravar o golden com o render atual.
4. Para cada golden **A** com observação: corrigir a observação e só então
   regravar.
5. Goldens escuros seguem o claro de mesmo nome. Só regravar com o mesmo SDK
   da suíte de referência, para não misturar deriva de renderização com
   decisão visual.
6. Registrar no rastreador Front-end, por tela, quais goldens foram regravados
   e quais voltaram à referência, com o SHA.
