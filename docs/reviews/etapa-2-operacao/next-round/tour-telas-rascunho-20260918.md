---
title: "Tour por tela — rascunho de texto para revisão do Owner"
source: "apps/superadmin/lib/app/navigation/superadmin_navigation.dart (destinos roteados em 18/09/2026); páginas em apps/superadmin/lib/features/*; tour-menu-rascunho-20260918.md (formato); decisions/0045"
status: "approved"
lifecycle: "future"
generated_at: "2026-09-18"
updated_at: "2026-09-19"
audience: "owner"
---

# Tour por tela — rascunho

Aprovado pelo Owner em 18/09 (todos os lotes; telas de criar/publicar entram
no tour completo). Fonte executável: `apps/superadmin/lib/app/tour/screens/`,
gerada deste arquivo; ajustes de texto feitos aqui foram levados ao Dart. Onde a
tela não tinha o elemento do rascunho, o passo foi ajustado ao que existe
(anotado nas tabelas pelas âncoras).

Mesmo conceito do tour do menu: um balão por elemento, apontando o que a tela
tem, com uma frase do que cada coisa faz. Botões **Próximo**, **Voltar**, **Pular
tour**; no último passo **Concluir**. Passo cujo elemento não está na tela (estado
vazio, sem permissão, largura estreita) é pulado sem aviso.

Âncoras genéricas, colocadas uma vez nos componentes compartilhados:

| Âncora | Onde | Componente |
|---|---|---|
| `page.header` | título e subtítulo da tela | cabeçalho da página no shell |
| `page.actions` | botões do cabeçalho (Nova chamada, Exportar…) | cabeçalho da página no shell |
| `directory.search` | campo de busca | `CoeloAdminDirectory` / `CoeloAdminListingToolbar` |
| `directory.filters` | filtros e "Limpar filtros" | `CoeloAdminDirectory` |
| `directory.view` | alternador Cards / Tabela (e visões da tabela) | `CoeloAdminDirectoryViewToggle` |
| `directory.files` | Importar / Exportar | `CoeloAdminFileActions` |
| `directory.leading` | abas acima da toolbar (Modelos / Atividades…) | `CoeloAdminUnderlineTabs` (leading) |
| `directory.tabs` | abas de status abaixo da toolbar | `CoeloAdminUnderlineTabs` (tabs) |
| `directory.create` | card ou banner Criar | `CoeloAdminCreateAction` |
| `directory.body` | cards, tabela ou kanban | `CoeloAdminDirectory` (resultados) / `CoeloAdminKanbanBoard` |
| `directory.pagination` | rodapé de paginação | `CoeloAdminPaginationFooter` |
| `form.navigation` | trilho de seções do formulário | `SuperadminFormFrame` |
| `form.body` | campos do formulário | `SuperadminFormFrame` |
| `form.footer` | rodapé com Cancelar / Salvar | `SuperadminFormFrame` |
| `principal.nav` | barra do Principal (Home, Para você, Momentos, Publicar, Mensagens) | `principal_global_navigation` |
| `principal.context` | "Trocar contexto" / "Ver como" | `principal_preview_app_bar` |

Âncoras específicas (`<tela>.<elemento>`) só onde a tela tem algo próprio.

Telas sem tour (lista explícita de exclusão): **Planos** (`plans`, só em
desenvolvimento, sem passo também no tour do menu). Telas de editar/detalhe
(`/…/:id`) não são destinos do menu e não entram; o tour de "criar" aponta os
campos sem preencher nem salvar nada.

Ordem = ordem do menu. Lotes para aprovação: Estrutura → Acompanhamento →
Acessos → Saúde → Operação → Comunicação → Governança → Coelo (Principal).
Home vai no primeiro lote.

---

## Home (`home`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Home | Sua página inicial. Tire dúvidas e encontre orientações sobre o Coelo sem sair do painel. |
| 2 | `home.question` | Pergunte sobre o Coelo | Escreva uma pergunta sobre recursos, rotinas ou navegação e envie. A resposta aparece aqui mesmo. |
| 3 | `home.history` | Conversas desta sessão | Suas perguntas ficam listadas aqui enquanto você usa o painel. "Nova conversa" começa do zero; o painel pode ser recolhido. |

## Lote Estrutura

### Instituições (`institutions`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Instituições | Cada cliente do Coelo. A instituição é única e administra suas unidades. |
| 2 | `directory.search` | Buscar por nome | Digite parte do nome para filtrar a lista na hora. |
| 3 | `directory.filters` | Filtros | Refine por plano, situação e outros critérios. "Limpar filtros" volta à lista completa. |
| 4 | `directory.view` | Cards ou tabela | Escolha ver como cards, com resumo de cada instituição, ou como tabela, com mais colunas. |
| 5 | `directory.files` | Importar e exportar | Traga instituições de uma planilha ou exporte a lista atual em CSV ou XLSX. |
| 6 | `directory.tabs` | Situação | Todos, Ativos, Em Implantação ou Inativos. A aba muda o que aparece abaixo. |
| 7 | `directory.create` | Criar instituição | Abre o formulário de uma nova instituição. Fica sempre no início, mesmo com a lista vazia. |
| 8 | `directory.body` | A lista | Clique numa instituição para abrir seus dados, unidades e locais. |
| 9 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

### Unidades (`units`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Unidades | Cada escola, sede ou filial. Turmas, equipe e famílias pertencem sempre a uma unidade. |
| 2 | `directory.search` | Buscar por nome | Encontre uma unidade pelo nome. |
| 3 | `directory.filters` | Filtros | Filtre por instituição e situação. "Limpar filtros" desfaz tudo. |
| 4 | `directory.view` | Cards ou tabela | Na tabela você pode ver Agrupado, Por turmas ou Por atividades. |
| 5 | `directory.files` | Importar e exportar | Importe unidades de uma planilha ou exporte em CSV ou XLSX. |
| 6 | `directory.tabs` | Situação | Todos, Ativos, Em Implantação ou Inativos. |
| 7 | `directory.create` | Criar unidade | Abre o formulário de uma nova unidade dentro de uma instituição. |
| 8 | `directory.body` | A lista | Abra uma unidade para ver turmas, locais e equipe. |
| 9 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

### Turmas (`groups`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Turmas | Os grupos de crianças ou alunos dentro de cada unidade, com seus educadores. |
| 2 | `directory.search` | Buscar por nome | Encontre uma turma pelo nome. |
| 3 | `directory.filters` | Filtros | Instituições, Unidades e Tipo da turma. "Limpar filtros" volta ao início. |
| 4 | `directory.view` | Cards ou tabela | Cards mostram unidade, tipo, alunos, atividades e professores; a tabela agrupa por unidade. |
| 5 | `directory.files` | Importar e exportar | Importe turmas de uma planilha ou exporte em CSV ou XLSX. |
| 6 | `directory.tabs` | Situação | Filtre pela situação da turma. |
| 7 | `directory.create` | Criar turma | Abre o formulário de uma nova turma. |
| 8 | `directory.body` | A lista | Abra uma turma para ver alunos, atividades e professores. |
| 9 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

### Atividades (`activities`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Atividades | Aulas, oficinas e projetos vinculados a unidades e turmas. |
| 2 | `directory.leading` | Modelos ou atividades | "Modelos de atividade" são a base reutilizável; "Atividades" são as instâncias em turmas. |
| 3 | `directory.search` | Buscar | Busque por nome ou descrição. |
| 4 | `directory.filters` | Filtros | Instituições, Unidades, Turmas e Origem. Em modelos: Origem e Categorias. |
| 5 | `directory.view` | Cards ou tabela | Na tabela, veja Agrupado, Por Unidades ou Por Turmas. |
| 6 | `directory.files` | Importar e exportar | Importe de planilha ou exporte em CSV ou XLSX. |
| 7 | `directory.tabs` | Situação | Todos, Ativos, Rascunhos, Inativos; modelos têm também Arquivados. |
| 8 | `directory.create` | Criar atividade | Abre o formulário. Num modelo, "Começar a partir deste modelo" já preenche a atividade. |
| 9 | `directory.body` | A lista | Abra uma atividade para ver turmas, configuração avaliativa e lançamentos. |
| 10 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

### Lançar avaliações (`assessment-entry`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Lançar avaliações | Registre resultados e acompanhe as pendências da turma. |
| 2 | `form.navigation` | Etapas do lançamento | Contexto, Notas e competências, Comentários e Revisão e envio. Cada etapa libera a seguinte. |
| 3 | `assessment.context` | Contexto do lançamento | Escolha instituição, unidade, turma e Atividade. O diário só abre com o contexto completo. |
| 4 | `assessment.period` | Período avaliativo | O período vigente da configuração da Atividade. Período fechado não aceita lançamento. |
| 5 | `assessment.toolbar` | Aluno, situação e modo | Busque um aluno, filtre por situação e escolha o modo de lançamento (tabela ou aluno a aluno). |
| 6 | `assessment.gradebook` | O diário | Uma linha por aluno, uma coluna por instrumento com seu peso. A média sugerida é calculada na hora. |
| 7 | `form.footer` | Salvar e avançar | "Salvar rascunho" guarda sem publicar; o botão de avançar leva à próxima etapa até a revisão e o envio. |

### Fechamento de avaliações (`assessment-closing`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Fechamento de avaliações | Revise pendências e publique resultados autorizados. |
| 2 | `page.actions` | Importar e exportar | Exporte os fechamentos em CSV ou XLSX. |
| 3 | `directory.search` | Buscar turma ou Atividade | Encontre o envio pelo nome da turma ou da Atividade. |
| 4 | `directory.body` | Envios pendentes | Cada linha é um envio: turma, período e quantas pendências restam. Clique para abrir e completar o que falta. |
| 5 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

## Lote Acompanhamento

### Assiduidade (`attendance`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Assiduidade | Visão consolidada de presença e chamadas no seu escopo. |
| 2 | `attendance.actions` | Nova chamada e exportar | "Nova chamada" abre o lançamento de hoje; Exportar gera CSV ou XLSX do que está na tela. |
| 3 | `attendance.filters` | Granularidade e período | Escolha o contexto (instituição, unidade, turma), o período e a granularidade dos indicadores. |
| 4 | `attendance.kpis` | Indicadores | Presença geral, chamadas pendentes, faltas no período e itens em revisão. |
| 5 | `attendance.attention` | Atenção necessária | Pendências que precisam de ação: chamadas atrasadas e correções aguardando. |
| 6 | `attendance.ranking` | Desempenho por contexto | Ranking de presença por unidade ou turma. "Ver todos" abre a lista completa. |
| 7 | `attendance.chart` | Presença no período | Gráfico do período atual comparado ao anterior. |
| 8 | `attendance.recent` | Últimas chamadas | Busque, filtre por status, ordene e abra qualquer chamada recente. |

### Nova chamada (`attendance-create`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Lançar chamada | Selecione o contexto antes de registrar a presença. |
| 2 | `attendance-create.context` | Contexto da chamada | Instituição, unidade, turma e atividade na turma. A data padrão é hoje. |
| 3 | `attendance-create.participants` | Participantes esperados | Quem deve estar presente segundo os vínculos ativos. Atividades sem chamada obrigatória avisam aqui. |
| 4 | `form.footer` | Lançar chamada | "Lançar chamada" cria a chamada e abre a lista de participantes para marcar presença. Cancelar volta sem criar. |

### Histórico (`attendance-history`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Histórico de chamadas | Chamadas lançadas no seu escopo; abra uma para ver o detalhe. |
| 2 | `directory.leading` | Chamadas ou rotina | "Chamadas" lista as presenças; "Lançamentos de rotina" lista o diário do dia enviado às famílias. |
| 3 | `directory.filters` | Filtros | Instituição, Unidade, Turma, Atividade e Situação. |
| 4 | `directory.body` | A lista | Cada linha tem data, contexto e situação. "Abrir chamada" mostra participante a participante. |
| 5 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

### Rotina diária (`daily-routine`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Rotina diária | Modelos, versões e alcances do registro cotidiano (sono, alimentação, higiene). |
| 2 | `directory.tabs` | Modelos ou rotinas | "Modelos" são a base; "Rotinas" são as versões aplicadas a cada unidade ou turma. |
| 3 | `directory.search` | Buscar | Encontre um modelo ou rotina pelo nome. |
| 4 | `directory.filters` | Status e tabela | Filtre por status e alterne para a tabela com nome, origem, versão e ações. |
| 5 | `directory.files` | Configuração | Importe ou exporte a configuração completa da rotina. |
| 6 | `directory.create` | Criar | Abre o editor de um novo modelo ou rotina. |
| 7 | `directory.body` | A lista | Cada item mostra versão, origem e vigência. Nas ações: editar, arquivar, restaurar ou publicar. |
| 8 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

### Acompanhamento de alunos (`students`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Acompanhamento | A visão da família por aluno, contexto e período, como o responsável vê. |
| 2 | `students.selectors` | Aluno, contexto e período | Escolha o aluno, o vínculo escolar e o período que quer ver. |
| 3 | `students.tabs` | Abas | Visão geral, Assiduidade, Avaliações, Competências e Boletins. |
| 4 | `students.body` | O conteúdo | Só o que já foi publicado aparece aqui. Presenças, faltas, notas e recomendações da professora. |

## Lote Acessos

### Pessoas (`people`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Pessoas | O cadastro único de cada pessoa: responsáveis, equipe e alunos, com seus vínculos. |
| 2 | `directory.search` | Buscar por nome | Encontre uma pessoa pelo nome. |
| 3 | `directory.filters` | Filtros | Tipo, instituição, unidade, turma, papel, localidade e situação de acesso. |
| 4 | `directory.view` | Cards ou tabela | Cards mostram vínculos e crianças; a tabela mostra papel contextual e acesso. |
| 5 | `directory.files` | Importar e exportar | Importe pessoas de uma planilha ou exporte em CSV ou XLSX. |
| 6 | `directory.tabs` | Segmentos | Filtre por tipo de pessoa: responsáveis, equipe, alunos. |
| 7 | `directory.create` | Criar pessoa | Abre o formulário de uma nova pessoa. |
| 8 | `directory.body` | A lista | Abra uma pessoa para editar dados, vínculos e acesso. |
| 9 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

### Segurança da criança (`safety`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Segurança da criança | Quem está autorizado a buscar cada criança, com revisão auditada pela unidade. |
| 2 | `directory.search` | Buscar | Nome ou identificação interna da criança. |
| 3 | `directory.view` | Cards ou tabela | Escolha ver cards por criança ou a tabela agrupada. |
| 4 | `directory.files` | Importar e exportar | Importe autorizações ou exporte em CSV. |
| 5 | `directory.tabs` | Segmentos | Cada aba mostra a contagem: com autorização, em análise, sem autorização. |
| 6 | `directory.create` | Criar segurança | Abre o assistente de nova autorização: criança, pessoa autorizada, relação, capacidades e validade. |
| 7 | `directory.body` | A lista | Cada card mostra autorizações ativas e solicitações em análise. Clique para gerenciar. |
| 8 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

### Usuários internos (`internal-users`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Usuários internos | A equipe do Coelo que opera este painel. |
| 2 | `directory.search` | Buscar | Nome, e-mail, CPF, celular ou cargo. |
| 3 | `directory.filters` | Filtros | Perfil, Vínculo e Alcance. "Limpar filtros" volta ao início. |
| 4 | `directory.create` | Criar usuário interno | Abre o formulário de um novo acesso interno. |
| 5 | `directory.body` | A lista | Perfil, escopo, situação do convite e última revisão de cada usuário. |

### Perfis e permissões (`profiles`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Perfis e permissões | Modelos de acesso por módulo, tela e ação. Um perfil define o que cada pessoa vê e faz. |
| 2 | `directory.leading` | Perfis ou capacidades | Alterne entre os perfis e a lista de capacidades do Principal. |
| 3 | `directory.search` | Buscar | Busque um perfil pelo nome ou uma capacidade. |
| 4 | `directory.filters` | Escopo | Filtre pelo escopo máximo do perfil. |
| 5 | `directory.files` | Importar e exportar | Importe perfis de uma planilha ou exporte em CSV ou XLSX. |
| 6 | `directory.tabs` | Domínio | Superadmin, instituição, unidade… cada aba mostra os perfis daquele domínio. |
| 7 | `directory.create` | Criar perfil | Abre o formulário de um novo perfil. Em perfis existentes você pode duplicar. |
| 8 | `directory.body` | A lista | Perfil, descrição, escopo máximo, vínculos e tipo. Abra para editar as permissões. |

## Lote Saúde e Cuidado

### Perfis de cuidado (`health-care-profiles`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Perfis de cuidado | Alergias, restrições e o que fazer em caso de contato, por criança. |
| 2 | `directory.search` | Buscar criança | Encontre o perfil pelo nome da criança. |
| 3 | `directory.view` | Cards ou tabela | A tabela agrupa por unidade. |
| 4 | `directory.files` | Importar e exportar | Importe perfis ou exporte em CSV ou XLSX. |
| 5 | `directory.tabs` | Situação | Todos, Ativos, Em implantação ou Inativos. |
| 6 | `directory.create` | Criar perfil de cuidado | Abre o formulário: criança, alimentos, restrições e orientações. |
| 7 | `directory.body` | A lista | Criança, alergias e restrições. Só quem cuida da criança vê o perfil. |
| 8 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

### Planos de medicação (`health-medication-plans`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Planos de medicação | Medicamentos autorizados, horários e o registro de cada dose aplicada. |
| 2 | `directory.search` | Buscar | Nome da criança ou do medicamento. |
| 3 | `directory.filters` | Filtros | Status do plano e situação da dose. |
| 4 | `directory.view` | Cards ou tabela | A tabela agrupa por criança ou por horário. |
| 5 | `directory.files` | Importar e exportar | Importe planos ou exporte em CSV ou XLSX. |
| 6 | `directory.create` | Criar plano de medicação | Abre o formulário: criança, medicamento, vigência e horários. |
| 7 | `directory.body` | A lista | Criança, medicamento, vigência, horários e contexto responsável. |
| 8 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

## Lote Operação

### Cardápios (`meal-plans`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Cardápios | Modelos de cardápio e a publicação semanal para as famílias. |
| 2 | `directory.leading` | Modelos ou cardápios | "Modelos" são a base; "Cardápios" são as publicações com abrangência e período. |
| 3 | `directory.search` | Buscar cardápio | Encontre pelo nome. |
| 4 | `directory.filters` | Filtros | Origem, Conflito e Revisão. |
| 5 | `directory.view` | Cards ou tabela | A tabela mostra abrangência, período, origem e conflito. |
| 6 | `directory.files` | Importar e exportar | Importe ou exporte cardápios. |
| 7 | `directory.create` | Criar cardápio | Abre o assistente de um novo cardápio ou modelo. |
| 8 | `directory.body` | A lista | Nas ações de cada item: Editar, Enviar revisão, Publicar, Arquivar ou Excluir. |
| 9 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

### Formulários (`forms`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Formulários | Crie perguntas, escolha quem responde e acompanhe as respostas. |
| 2 | `directory.search` | Buscar formulários | Encontre um formulário pelo nome. |
| 3 | `directory.filters` | Situação | Rascunho, publicado, encerrado. |
| 4 | `directory.files` | Importar e exportar | Importe ou exporte formulários. |
| 5 | `directory.create` | Criar formulário | Abre o editor: perguntas, público, agendamento e teste. |
| 6 | `directory.body` | A lista | Situação, contexto, público, respostas e agendamentos. Nas ações: editar, testar, monitorar e ver respostas. |
| 7 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

### Importações (`import`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Importações | Cada arquivo importado, com entidade, destino e quantidade de registros. |
| 2 | `directory.search` | Buscar por arquivo | Encontre uma importação pelo nome do arquivo. |
| 3 | `directory.filters` | Filtros | Entidade e tipo de arquivo. |
| 4 | `directory.files` | Importar e exportar | Importe um novo arquivo ou exporte o histórico. |
| 5 | `directory.create` | Nova importação | Abre o assistente: escolha a entidade, envie o arquivo, confira e confirme. |
| 6 | `directory.body` | A lista | Arquivo, entidade, destino, registros, data e responsável de cada importação. |
| 7 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

### Agenda (`agenda`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Agenda institucional | Calendário, eventos e respostas por contexto. Criar evento, Solicitações e Aprovações ficam no menu. |
| 2 | `agenda.month` | Navegar no mês | Use as setas para ir ao mês anterior ou ao próximo. |
| 3 | `agenda.search` | Buscar e contexto | Busque eventos pelo nome e filtre pelo contexto: instituição, unidades, turmas ou atividades. |
| 4 | `agenda.view` | Visualização | Alterne entre o calendário mensal e a lista. |
| 5 | `agenda.grid` | O calendário | Cada dia mostra seus eventos; clique num dia para abrir o detalhe. |
| 6 | `agenda.today` | Hoje | Volta ao mês atual. |

### Criar evento (`agenda-create`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Criar evento | Um evento novo na Agenda institucional, como uma publicação numa única tela. |
| 2 | `agenda-create.basics` | Título, data, local e público | Nome do evento, data e horário, local, descrição, categoria e quem vê: instituição, unidade ou turma. |
| 3 | `agenda-create.options` | Mais opções | Dia inteiro, fuso, recorrência, prioridade, modo de resposta (ciência, presença, autorização) e lembretes. |
| 4 | `agenda-create.questions` | Perguntas do evento | Adicione perguntas que a família responde ao confirmar. |
| 5 | `publish.preview` | Prévia na Agenda | Como o evento aparece no calendário do público escolhido. |
| 6 | `form.footer` | Salvar ou publicar | "Salvar rascunho" guarda sem publicar; "Publicar evento" (ou "Solicitar publicação") envia. Cancelar descarta. |

### Solicitações (`agenda-requests`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Solicitações e retornos | Pedidos de ciência, presença e autorização enviados às famílias e o que cada uma respondeu. |
| 2 | `directory.files` | Importar e exportar | Importe ou exporte as solicitações. |
| 3 | `agenda-requests.list` | A lista | Solicitação, tipo e política, estado e retorno. O primeiro retorno válido encerra a pendência dos demais. |
| 4 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

### Aprovações (`agenda-approvals`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Aprovações de publicação | Eventos aguardando decisão antes de aparecer para as famílias. |
| 2 | `directory.files` | Importar e exportar | Importe ou exporte as aprovações. |
| 3 | `agenda-approvals.table` | A lista | Evento, solicitação, estado e histórico. "Decidir" abre a decisão: aprove ou recuse com justificativa, registrada no histórico. |
| 4 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

## Lote Comunicação

### Conversas (`conversations`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Conversas | Comunicação institucional privada e contextual. |
| 2 | `chat.search` | Buscar conversas | Encontre uma conversa pelo nome ou contexto. |
| 3 | `chat.create` | Criar grupo | Abra um grupo com pessoas do seu escopo. |
| 4 | `chat.list` | Lista | Cada conversa mostra tipo, contexto e não lidas. Clique para abrir. |
| 5 | `chat.thread` | A conversa | Mensagens, anexos e ações (editar, revogar). Role para carregar as anteriores. |
| 6 | `chat.composer` | Escrever | Digite a mensagem, anexe arquivos e envie. |

### Convites (`invites`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Convites | Convites de acesso enviados a responsáveis e equipe. |
| 2 | `directory.search` | Buscar destinatário | Encontre pelo nome ou contato do destinatário. |
| 3 | `directory.filters` | Canal | E-mail, WhatsApp ou link. "Limpar filtros" volta ao início. |
| 4 | `directory.files` | Importar e exportar | Importe destinatários ou exporte a lista. |
| 5 | `directory.tabs` | Todos os convites | Filtre por situação do convite. |
| 6 | `directory.create` | Novo convite | Abre o formulário: destinatário, perfil, contexto e canal. |
| 7 | `directory.body` | A lista | Situação de cada convite; "Copiar link" copia o link de acesso. |
| 8 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

### Comunicações (`notices`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Comunicações | Avisos e comunicados enviados às famílias e à equipe. |
| 2 | `directory.search` | Buscar comunicação | Encontre pelo título. |
| 3 | `directory.filters` | Estado | Rascunho, publicado, pausado ou inativo. |
| 4 | `directory.files` | Importar e exportar | Importe ou exporte comunicações. |
| 5 | `directory.tabs` | Tipo | Cada aba é um tipo de comunicação. |
| 6 | `directory.create` | Nova comunicação | Abre o formulário: conteúdo, público e agendamento. |
| 7 | `directory.body` | A lista | Nas ações: Editar, Publicar, Pausar, Reativar ou Inativar (com motivo para a auditoria). |
| 8 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

## Lote Governança

### Suporte e implantação (`support`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Suporte e implantação | Acompanhe os chamados e solicitações da operação. |
| 2 | `directory.search` | Buscar chamados | Encontre um chamado pelo texto. |
| 3 | `directory.filters` | Filtros | Menu, Responsável, Leitura e Tela. "Limpar filtros" volta ao início. |
| 4 | `directory.view` | Kanban ou tabela | Alterne entre o quadro por etapa e a tabela. |
| 5 | `directory.files` | Exportar | Exporte os chamados em CSV ou XLSX. |
| 6 | `directory.create` | Criar suporte | Abre um novo chamado. |
| 7 | `directory.body` | O quadro | Arraste ou use "Mover para" para mudar a etapa; escolha responsáveis no card. |
| 8 | `support.detail` | O chamado | Selecione um chamado para ver mensagens, anexos e responder. |

### Auditoria (`audit`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Auditoria | Tudo o que foi feito no painel: quem, quando e o quê. |
| 2 | `directory.search` | Buscar na auditoria | Filtre os eventos por texto. |
| 3 | `directory.files` | Exportar | Exporte os eventos em CSV ou XLSX. |
| 4 | `directory.body` | Eventos | Cada linha é um evento; clique para ver o detalhe. |
| 5 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

### Catálogo (`catalog`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Catálogo | Fundamentos, componentes e padrões aprovados da interface. |
| 2 | `page.actions` | Abrir em nova aba | Abra o catálogo numa aba própria do navegador. |
| 3 | `catalog.frame` | O catálogo | Navegue pelos componentes aqui mesmo. |

## Lote Coelo (Principal)

### Acontece (`principal-happens`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `principal.nav` | O app das famílias | Aqui você vê o Coelo como a família vê. Home, Para você, Momentos, Publicar e Mensagens. |
| 2 | `principal.context` | Trocar contexto | Veja o app como outra instituição, unidade ou pessoa do seu escopo. |
| 3 | `happens.now` | Agora | A faixa de conteúdos temporários de 24 horas. "Publicar agora" cria um novo. |
| 4 | `happens.feed` | O feed | Publicações da instituição: comente, compartilhe ou retire uma publicação. |
| 5 | `happens.side` | Ao lado | Próximos eventos, avisos importantes e aniversariantes. |

### Publicar no Acontece (`principal-happens-publish`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `publish.media` | Mídia | Adicione fotos ou vídeos; arraste para reordenar. |
| 2 | `publish.caption` | Legenda | O texto do post. |
| 3 | `publish.audience` | Público e contexto | O contexto da publicação e quem vê: famílias, equipe ou ambos. |
| 4 | `publish.schedule` | Agendamento e opções | Marque data e hora para agendar; "Salvar como rascunho" guarda automaticamente. |
| 5 | `publish.preview` | Prévia | Como o post vai aparecer no feed do Acontece. |
| 6 | `form.footer` | Publicar | "Publicar no Acontece" envia (ou agenda); "Salvar rascunho" guarda; Cancelar volta. |

### Para você (`principal-for-you`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `principal.nav` | Para você | A página da família com o resumo do dia dos filhos. |
| 2 | `for-you.shortcuts` | Atalhos essenciais | Os acessos mais usados pela família. |
| 3 | `for-you.summary` | Resumo do dia | Presença, rotina e recados de hoje. |
| 4 | `for-you.context` | Seu contexto atual | A visão geral ou por criança e vínculo. "Trocar contexto" muda. |

### Momentos (`principal-moments`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `principal.nav` | Momentos | Registros em vídeo e foto que merecem ser lembrados. |
| 2 | `moments.feed` | O feed | Cada momento tem autor, contexto e legenda. Comente, compartilhe ou retire. |
| 3 | `moments.create` | Enviar momento | Publique um momento novo. |

### Publicar em Momentos (`principal-moments-publish`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `publish.media` | Mídia e capa | Adicione a mídia e escolha a capa do momento. |
| 2 | `publish.caption` | Legenda | Conte o que torna este momento especial. |
| 3 | `publish.audience` | Público e contexto | Quem vê o momento. |
| 4 | `publish.schedule` | Agendamento e opções | Publique agora, agende ou salve como rascunho. |
| 5 | `publish.preview` | Prévia | Como o momento vai aparecer. |
| 6 | `form.footer` | Publicar | "Publicar em Momentos" envia; "Salvar rascunho" guarda; Cancelar volta. |

### Agora (`principal-now`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `now.viewer` | O Agora | Conteúdo institucional privado e temporário: fica 24 horas. |
| 2 | `now.navigation` | Anterior e próximo | Passe de um Agora para outro. |
| 3 | `now.options` | Opções | Audiência, compartilhar, publicar novo ou remover este Agora. |
| 4 | `now.reply` | Resposta privada | A família responde em particular à instituição. |

### Publicar no Agora (`principal-now-publish`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `publish.media` | Mídia | Adicione ou troque a mídia. O Agora fica disponível por 24 horas. |
| 2 | `now-publish.tools` | Texto, música, cortar e capa | Ajuste o conteúdo sobre a mídia. |
| 3 | `publish.caption` | Contexto opcional | Uma frase curta que acompanha a mídia. |
| 4 | `publish.audience` | Público e contexto | Quem vê o Agora. |
| 5 | `publish.schedule` | Agendar | Publique agora ou marque data e hora. |
| 6 | `form.footer` | Publicar | "Publicar no Agora" envia; "Salvar rascunho" guarda; Cancelar volta. |

### Chat (`principal-chat`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `chat.search` | Buscar conversas | Encontre uma conversa. |
| 2 | `chat.list` | Lista | As conversas da família, com não lidas. |
| 3 | `chat.thread` | A conversa | Mensagens e anexos. Role para carregar as anteriores. |
| 4 | `chat.composer` | Escrever | Digite e envie. |

### Perfil (`principal-profile`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `profile.header` | O perfil | Nome, brasão, campus e verificação da instituição. |
| 2 | `profile.actions` | Acompanhar, mensagem e editar | Siga o perfil, envie mensagem ou edite (quando permitido). |
| 3 | `profile.highlights` | Destaques e vínculos | Conteúdos em destaque e as pessoas vinculadas. |
| 4 | `profile.tabs` | Abas | Acontece, Momentos, Circulares e Sobre. |

### Circulares (`circulars`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Circulares | Comunicados formais com texto, mídia e perguntas. |
| 2 | `directory.search` | Buscar circular | Encontre pelo título. |
| 3 | `directory.filters` | Contexto | Filtre pela instituição, unidade ou turma. |
| 4 | `directory.files` | Importar e exportar | Importe ou exporte circulares. |
| 5 | `directory.tabs` | Situação | Cada aba é uma situação da circular. |
| 6 | `directory.create` | Nova circular | Abre o compositor. |
| 7 | `directory.body` | A lista | Título, resumo e status. Clique para abrir. |
| 8 | `directory.pagination` | Paginação | Avance de página e escolha quantos itens ver por vez. |

### Publicar Circular (`circular-create`)

| # | Âncora | Título | Texto |
|---|---|---|---|
| 1 | `page.header` | Publicar Circular | Uma circular nova: comunicado formal com texto, mídia e perguntas. |
| 2 | `circular.title` | Título | O assunto da circular. |
| 3 | `circular.blocks` | Conteúdo | Adicione texto, mídia (PDF, imagem ou vídeo) e perguntas na ordem de leitura; mova ou exclua blocos. |
| 4 | `publish.audience` | Público e contexto | Quem recebe a circular e a resposta esperada. |
| 5 | `publish.schedule` | Agendamento e opções | Publique agora, agende ou salve como rascunho. |
| 6 | `publish.preview` | Prévia | Como a circular aparece para a família. |
| 7 | `form.footer` | Publicar | "Publicar" envia; "Salvar rascunho" guarda; Cancelar volta. |
