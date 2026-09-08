---
title: "C04 — estado medido das 47 ações atribuídas"
source: "auditoria própria + três subagentes de leitura; verificações pontuais refeitas por mim"
status: "medido em 2026-09-08 19:30 -03:00, ponta ecd29cda"
generated_at: "2026-09-08T19:30:00-03:00"
timezone: "America/Sao_Paulo"
---

# Como ler esta tabela

Isto não é declaração de conclusão. É o que eu consigo **provar** hoje, por
família, com o caminho do arquivo na mão.

Três avisos que mudam a leitura de quase tudo abaixo:

1. **Bloqueio deliberado.** `structureMutationsEnabled` é `false` fixo nos dois
   ramos da composição (`superadmin_auth_scope.dart:313` e `:382`), com o motivo
   escrito no próprio código citando **OQ-032/OQ-043**. Criar e editar
   Instituição, Unidade e Turma **não são alcançáveis em produção**, e isso é
   decisão registrada, não defeito.
2. **RPCs legadas de Unidade.** Sete funções que o Dart chama não existem nas
   migrations do repositório. A OQ-032 diz que o **remoto** as materializou e
   que o HEAD canônico não as reproduz. Portanto: ausentes do repositório,
   provavelmente presentes no banco. Não afirmo mais do que isso.
3. **Goldens congelados.** As 77 imagens de Estruturas já divergiam no baseline
   `479d1bd1`, antes de qualquer coisa desta rodada. A C07 rastreou até
   `d9232a94`. Onde eu digo "verde", quero dizer verde fora dessas imagens.

Legenda: **E** entregue e provado · **P** parcial · **B** bloqueado por decisão
registrada · **A** ausente · **D** adiado por decisão do Owner

# Instituições (13)

| action_id | Estado | Evidência |
|---|---|---|
| `institutions.list` | **E** | RPC `superadmin_institution_directory_v2` existe e é chamada; paginação servidor-side testada. Corrigido nesta rodada: teclado (um ponto por controle, todo ponto age) e seis colunas de métrica que eram hash do id |
| `institutions.filter` | **E** | `superadmin_institution_filter_options_v2` existe; filtros aplicados no `p_filters` |
| `institutions.detail` | **P** | RPC e tela existem e são testadas; **sem entrada em produção** — a única porta é `onEdit`, que o router passa nulo |
| `institutions.create` | **A** | O repositório lança antes de qualquer rede. Não existe `superadmin_institution_create*`. Assistente de 7 passos sem backend |
| `institutions.edit` | **P** | `superadmin_institution_edit_core_v2` existe e é bem testada, **mas persiste 7 de ~45 campos** e descarta o resto sem sinal. Bloqueada em produção |
| `institutions.status` | **A** | Único controle é um dropdown desabilitado com aviso; o servidor recusaria `status` na allowlist. Cercado dos dois lados de propósito |
| `institutions.files` | **D** | Botões visíveis e inertes, com cerca de fonte. `Esc` coberto no teste do componente compartilhado |
| `institutions.import` | **D** | idem |
| `institutions.export` | **D** | idem |
| `institutions.error` | **E** | Cobertura nova nesta rodada: cada tipo de falha diz a frase certa, a mensagem do servidor não vaza, negação não oferece repetir |
| `institutions.access-denied` | **E** | Dirigido pelo repositório, com as palavras conferidas |
| `institutions.reload` | **E** | Prova contando leituras, não a existência do botão |
| `institutions.locations-map` | **E** | Seção montada no passo de endereço; prova falsa minha corrigida nesta rodada |

# Unidades (12)

| action_id | Estado | Evidência |
|---|---|---|
| `units.list` | **B** | Repositório de produção é `Unavailable`; RPC `list_units_for_superadmin` ausente do repositório (ver aviso 2). Corrigido nesta rodada: quatro colunas de métrica inventadas |
| `units.filter` | **B** | `unit_directory_filter_options` na mesma situação |
| `units.create` | **B** | `create_unit_for_superadmin` idem; uma migration chega a **chamá-la sem defini-la** (`20260825180500:55`) |
| `units.edit` | **B** | `update_unit_for_superadmin` idem. Corrigido nesta rodada: passo de gestão local não inventa mais linhas |
| `units.status` | **A** | Não existe ação de ativar/desativar/arquivar em lugar nenhum, nem RPC de transição |
| `units.import` | **D** | Cercado: implementação adiada existe e nenhum arquivo de produção a compõe |
| `units.export` | **D** | idem |
| `units.people-export` | **D** | **Entregue nesta rodada**: era a única ação adiada sem superfície. Botão visível, inerte, com cerca |
| `units.error` | **E** | **Entregue nesta rodada**: `unit-detail-unavailable` era chave de produção com zero cobertura |
| `units.access-denied` | **E** | Palavras conferidas; id malformado cai em negado de propósito, fixado com o motivo |
| `units.reload` | **E** | Conta leituras; desabilitado enquanto uma está em voo |
| `units.copy-institution-location` | **E** | **Entregue nesta rodada**: trazer local da instituição para a unidade, com painel próprio |
| `units.locations-map` | **P** | Leitura existe e é testada; **sem entrada no app** e sem a metade de mapa/mídia |

# Turmas (7)

| action_id | Estado | Evidência |
|---|---|---|
| `groups.list` | **B** | `superadmin_group_directory` existe, mas o view model exige também as opções de filtro, que passam pelas RPCs de unidade ausentes, com `eagerError` |
| `groups.create` | **B** | `superadmin_group_save` existe; contexto do formulário depende das mesmas RPCs |
| `groups.edit` | **B** | idem, mais `superadmin_group_get` |
| `groups.members` | **P** | Payload real dos dois lados. **Entregue nesta rodada**: teste de contrato e registro do risco de esvaziamento silencioso |
| `groups.location` | **E** | **Corrigido nesta rodada**: o seletor descartava a escolha; agora o passo diz a verdade, cercado dos dois lados |
| `groups.import` | **D** | Cercado |
| `groups.export` | **D** | Cercado |

# Pessoas (5)

| action_id | Estado | Evidência |
|---|---|---|
| `people.list` | **P** | Busca, ordenação, paginação e sete filtros são reais ponta a ponta. Atividade, UF, Município e Bairro **não existem no servidor**: em produção ficam vazios, e só parecem funcionar sob o repositório falso |
| `people.create` | **B** | `superadmin_people_create_draft` existe e é testada; rota bloqueada |
| `people.edit` | **B** | `superadmin_people_update` existe; rota bloqueada |
| `people.links` | **P** | Leitura entregue e composta. **Corrigido nesta rodada**: quatro pessoas fabricadas foram retiradas do formulário de produção. Escrita existe mas está bloqueada e **sem teste no contrato** |
| `people.reload` | **E** | Prova de segunda leitura no detalhe. O **diretório** não tem recarregar, só "Tentar novamente" no estado de falha |

# Alunos (5)

| action_id | Estado | Evidência |
|---|---|---|
| `students.list` | **E** | Leitura real em produção, com recarregar provado por cursor e caminho de teclado |
| `students.link` | **A** | Nenhum controle. Há teste afirmando a ausência de propósito |
| `students.transfer` | **A** | idem |
| `students.edit` | **A** | idem |
| `students.revoke` | **A** | idem |

# Locais (4)

| action_id | Estado | Evidência |
|---|---|---|
| `locations.list` | **P** | Leitura e adapter prontos e testados; **sem entrada no app** e sem os filtros que a spec pede |
| `locations.create-edit` | **P** | Criar já existia. **Entregues nesta rodada** como suboperações: editar, status e duplicar, no cliente e na tela. Falta endpoint aplicado |
| `locations.detail-links` | **A** | Não existe dos dois lados: o payload do servidor não tem vínculo e o domínio não tem campo |
| `locations.schedule` | **P** | Disponibilidade semanal entregue ponta a ponta no cliente. **Insuficiente para a spec de 02/09**; contrato mínimo de reservas publicado como peça separada |

# O que preciso de decisão para destravar

| # | Decisão | Destrava |
|---|---|---|
| 1 | Nome de migration para ampliar a edição de Instituição, ou tirar da tela o que não persiste | `institutions.edit` |
| 2 | Nome de migration para criar Instituição | `institutions.create` |
| 3 | Uma linha no router compondo `onOpenLocationCatalog` no detalhe de Unidade | `locations.list`, `units.locations-map` |
| 4 | Reserva do `SuperadminDirectoryCreateBanner`, compartilhado com Atividades | teclado em três diretórios |
| 5 | Critério de foco: "um ponto por card" ou "todo ponto age" | fechamento do caso C07 |
| 6 | O que fazer com salvamento de turma sem membros carregados | risco em `groups.members` |
| 7 | `GroupDirectorySaveResult`, que sintetiza sucesso | honestidade em `groups.create/edit` |
| 8 | As visões de tabela Turmas e Atividades, que montam linhas sintéticas | `institutions.list`, `units.list` |
| 9 | Os quatro filtros de Pessoas sem servidor: implementar ou retirar | `people.list` |
| 10 | Lease de banco para o replay dos três pacotes de Locais | prova de `locations.create-edit` e `.schedule` |

# Como isto foi levantado

Auditoria própria mais três subagentes de leitura, despachados conforme a I010.
Onde um subagente afirmou algo que mudaria uma decisão — a ausência das RPCs de
Unidade, a allowlist de campos de Instituição, o payload de membros de Turma —
**refiz a verificação por conta própria** antes de escrever aqui. Uma das
conclusões deles eu corrigi: as RPCs ausentes não são descoberta, são a OQ-032.
