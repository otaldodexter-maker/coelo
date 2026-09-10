---
title: "Rodada 3 — handoff da Fase 0 (composto de diretório)"
source: "R03-prompts.md (P0); R03-plano.md; goldens-claro-decisoes-2026-09-10.md; commits 60747d57b..1adb070c9 em dev"
status: "base-published; migration-in-progress"
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
  cuidado, Planos de medicação. Goldens desses diretórios regravados após as
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
| Planos (`plan_directory_page.dart`) | migrado no checkout, 7 testes vermelhos | Fase 0 continua (próximo lote) |
| Cardápios, Comunicações, Circulares, Agenda eventos | não migrados | Fase 0 continua; scripts prontos para Cardápios |
| Pessoas, Convites, Perfis de acesso | não migrados (na allowlist) | Fase 0 ou grupo acessos-pessoas ao tocar a tela |
| Suporte, Auditoria | workspace com painel de detalhe; toolbar/tabela na allowlist | grupo operacoes: toolbar de filtros no padrão do composto |
| Chat: Criar grupo, Fixar, sinalizadores | existiam até 54f2dfb69 (inbox local); exigem backend | grupo principal-chat-sistema |
| CHAT (balão) | referência de agosto mostra o balão antigo "Mensagens"; atual é o círculo "Mens." aprovado em 01/09 | decisão do Owner com imagens lado a lado |
| Chip Destaque (orange950 16 %) | alterado no checkout compartilhado junto do WIP do grupo principal-chat-sistema; não commitado | quem fechar `principal_for_you_preview_page.dart` |
| Confirmação de saída de Instituições | não reproduzida nesta fase (testes `cancel-changed`/`destination-changed` não estão em dev) | grupo estrutura |
| Bug em produção | router não passa `supportController`; botão abre e avisa | grupo operacoes |
| Goldens de formulário/detalhe (Atividades, Perfis de cuidado) | preservados; RODAPÉ pendente | grupos estrutura e formularios-cuidado-rotina |

## Próximo passo

Fechar Planos, Cardápios, Comunicações e Circulares no composto; depois Pessoas,
Convites e Perfis de acesso; a cada lote verde, commit e push em `dev` e este
handoff atualizado.
