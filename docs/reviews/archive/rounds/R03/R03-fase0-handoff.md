---
title: "Rodada 3 — handoff da Fase 0 (composto de diretório)"
source: "R03-prompts.md (P0); R03-plano.md; goldens-claro-decisoes-2026-09-10.md; commits 60747d57b..1adb070c9 em dev"
status: "base-published; directories-migrated"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# Fase 0 — handoff

**Base publicada:** `base.fase0Head = 1adb070c9` (dev, 10/09/2026 ~18:40). As
frentes criam a worktree a partir desse SHA. Commits posteriores da Fase 0
continuam em `dev` como lotes pequenos; rebase normal.

## O que fechou (em dev)

- **Composto** `CoeloAdminDirectory` em `packages/coelo_ui_admin/lib/src/directory/`
  (60747d57b): toolbar (busca 300/216/100 %, filtros 160 px ou largura própria,
  toggle Cards/Tabela, Arquivos configurável e `null` esconde), abas de status
  (`CoeloAdminDirectoryStatusTabs` Todos/Ativos/Rascunhos/Inativos ou abas
  próprias), grade 340 px com card **Criar primeiro em todos os estados**,
  banner Criar acima da tabela, card de estado, rodapé fixo de paginação
  (compacto < 600 px), `bodyOverride`, paginação por cursor. Abas lineares,
  toggle e rodapé migraram do `shared` com typedefs de compatibilidade.
  Goldens do composto por largura/tema em `packages/coelo_ui_admin/test/directory/goldens/` (22).
- **Shell e menu (MENU/MENU-M):** Bug sempre presente (aviso honesto quando o
  envio não está conectado); seção ancestral em `primaryPressed`, item ativo em
  `primary`; menu completo fora do shell hospedeiro; Pesquisar mantido.
- **Diretórios migrados:** Instituições, Atividades (Atividades e Modelos),
  Turmas (card na altura da família), Unidades, Formulários (cursor), Perfis de
  cuidado, Planos de medicação, Planos, Cardápios, Circulares, Comunicações
  (toggle no compacto, prévia inline ao lado da tabela em telas largas),
  Pessoas, Convites e Perfis de acesso (fa404db39). A grade do composto tem
  cards da mesma altura por linha (Table intrinsicHeight; IntrinsicHeight
  travava a suíte com cards que usam LayoutBuilder). Goldens desses diretórios regravados após as
  observações do Owner (MENU, CRIAR, TABS, DADOS, ARQUIVOS nos Modelos).
- **Teste de arquitetura** `apps/superadmin/test/architecture/directory_composition_test.dart`:
  falha em Table/Toolbar/Pagination/PageHeader/Directory novos em feature e em
  enum local de cards/tabela; allowlist datada que só diminui.
- **SDK** fixado em `.fvmrc`/`.flutter-version` (3.44.2). Fonte de ícones vem do
  SDK fixado; vendorizar não foi necessário.
- **ARQUIVOS-CHAT:** Conversas sem botão Arquivos (1adb070c9).

## O que ficou aberto (primeiro gate)

| Item | Estado | Gate |
| --- | --- | --- |
| Planos, Cardápios, Circulares, Comunicações | migrados e publicados (8fafbe16c, 850ba1838) | ARQUIVO já decidido pelo Owner em 10/09 (conceito do card de modelo de atividade); implementado sem teste na branch `wip/fase0-arquivo-chat` (91e011dc6); testes e regravação dos goldens de Cardápios/Planos ao reativar |
| Agenda eventos | não migrado (`_EventTable` na allowlist) | grupo publicacoes-agenda ao tocar a tela |
| Suporte, Auditoria | workspace com painel de detalhe; toolbar/tabela na allowlist | grupo operacoes: toolbar de filtros no padrão do composto |
| Chat: Criar grupo, Fixar, sinalizadores | existiam até 54f2dfb69 (inbox local); exigem backend | grupo principal-chat-sistema |
| CHAT (balão) | decisão do Owner de 10/09 (mais recente que 01/09): seguir a referência guardada em todas as larguras. Launcher reescrito na branch `wip/fase0-arquivo-chat` (pill "Mensagens" com contagem e iniciais; círculo claro no mobile) sem teste | ao reativar: merge, testes do launcher, regravação dos goldens de shell após observação |
| Chip Destaque (orange950 16 %) | alterado no checkout compartilhado junto do WIP do grupo principal-chat-sistema; não commitado | quem fechar `principal_for_you_preview_page.dart` |
| Confirmação de saída de Instituições | não reproduzida nesta fase (testes `cancel-changed`/`destination-changed` não estão em dev) | grupo estrutura |
| Bug em produção | router não passa `supportController`; botão abre e avisa | grupo operacoes |
| Goldens de formulário/detalhe (Atividades, Perfis de cuidado) | preservados; RODAPÉ pendente | grupos estrutura e formularios-cuidado-rotina |

## Corte das 17:10 (10/09)

Ordem do Owner via coordenação: parar às 17:10 e não retomar por conta própria. Suíte completa sobre 01849ec2c interrompida às 16:56 (6432 P, 15 S; 30 falhas reais, 10 delas do teste das abas sublinhadas movidas para coelo_ui_admin: a chave da faixa foi corrigida, 7 casos seguem vermelhos e ficam para a Fase 0; o resto em áreas de outros grupos ou goldens preservados). O WIP da Fase 0 está inteiro na branch publicada `wip/fase0-arquivo-chat`; dev fica limpo nos caminhos da Fase 0.

## Próximo passo

Os 13 diretórios da Fase 0 e os quatro adicionais estão no composto. Restam,
fora do recorte de diretório: Suporte e Auditoria (workspaces com painel;
toolbar de filtros a alinhar pelo grupo operacoes), Agenda eventos, Assiduidade
e Segurança (renomear `*Table`/`*Toolbar` para `*Rows`/`*Filters` ao tocar a
tela). Grupos que rebasearem sobre fa404db39 devem trocar `SuperadminUnderlineTabs`,
`SuperadminDirectoryViewToggle` e `SuperadminListingPaginationFooter` (typedefs
de compatibilidade) pelos nomes de `coelo_ui_admin` quando tocarem o arquivo.
