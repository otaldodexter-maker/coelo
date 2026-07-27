---
source: "solicitacao aprovada do usuario; docs/product/prd-superadmin.md; docs/design/design-system.md"
status: "approved-design"
generated_at: "2026-07-27"
---

# Protótipo local de suporte do Superadmin

## Objetivo e problema

Validar, no Superadmin, o fluxo local de abertura e acompanhamento de solicitações de suporte. A equipe interna precisa visualizar contexto, mensagens e estado do atendimento sem transformar este recorte em sistema persistente ou em acesso a dados privados.

## Escopo

Entra neste recorte:

- tickets de sessão somente em memória, com identificador estável durante a sessão;
- abertura de relato com menu, tela, assunto, descrição, solicitante e anexo demonstrativo opcional;
- listagem, seleção, leitura de mensagens recebidas, resposta local e encerramento;
- filtros por busca, status, menu, tela e mensagens não lidas;
- quatro estados de UX: `Novo`, `Em andamento`, `Aguardando solicitante` e `Concluído`.

Fica fora de escopo: UI, rotas, shell, catálogo e componentes compartilhados; repositório, persistência, estado assíncrono, banco, Supabase, R2, Realtime e auditoria implementada; acesso a contexto privado, impersonação, permissões de outros apps ou APIs compartilhadas.

## Superfície afetada e permissão

O protótipo pertence exclusivamente a `apps/superadmin`. O limite de permissão é Superadmin: nenhum Admin institucional, usuário do app principal ou pacote compartilhado recebe acesso, contrato ou dependência deste estado. Em uma entrega persistente, o acesso continuará condicionado a cargo interno, escopo autorizado e auditoria conforme o PRD Superadmin.

## Entidades e dados

`SupportTicket` contém id, assunto, menu, tela, descrição, solicitante, datas de criação/atualização, estado, anexos e mensagens. `SupportAttachment` representa metadados locais de um anexo demonstrativo. `SupportMessage` identifica autor solicitante ou suporte, estado de entrega/leitura e leitura pelo suporte. `SupportFilters` mantém busca, estados, menus, telas e opção de não lidos. `SupportReportDraft` representa o relato ainda não convertido em ticket.

Todas as coleções expostas pelo domínio e controller são imutáveis. Os fixtures locais cobrem os quatro estados, anexos, mensagem de solicitante não lida e resposta do suporte já lida.

## Estados de UX previstos

- Sem filtros: exibe todos os tickets da sessão.
- Com filtros: aplica todos os critérios em interseção; busca ignora maiúsculas/minúsculas e procura id, assunto, descrição, solicitante, menu e tela.
- Selecionado: abre o ticket escolhido e marca mensagens do solicitante como lidas pelo suporte.
- Sem resultados: a lista filtrada fica vazia sem alterar os dados locais.
- Relato enviado: cria ticket em `Novo` e permanece disponível até o reload.
- Resposta vazia: é ignorada; resposta válida é aparada e criada como mensagem do suporte em estado enviado.

## Eventos locais

O controller emite apenas notificações locais de mudança para criação de relato, mudança de status, seleção, encerramento, envio de resposta, marcação de leitura, atualização e limpeza de filtros. Não há evento remoto, log de auditoria, notificação externa ou gravação neste recorte.

## Critérios de aceite

- O controller expõe tickets, tickets filtrados, filtros, ticket selecionado e indicação de filtros ativos.
- Um relato cria ticket `Novo` com id determinístico de sessão e a hora fornecida pelo relógio injetado.
- Mudar status e encerrar atualiza somente o ticket-alvo.
- Abrir ou selecionar um ticket lê as mensagens do solicitante para o suporte.
- Respostas vazias não alteram o ticket; respostas válidas são aparadas e enviadas pelo suporte.
- Busca e filtros de status, menu, tela e não lidos se cruzam.
- Limpar filtros restaura a listagem completa.
- Nenhum dado sobrevive ao reload do app.

## Testes exigidos

Teste unitário do controller deve cobrir criação de relato, exposições imutáveis, interseção de filtros, troca de status, seleção e leitura, aparo/ignoração de resposta e limpeza de filtros. Não são exigidos testes de integração, banco ou UI neste recorte.

## Riscos e pergunta aberta

O estado local não é trilha de auditoria, não autoriza acesso privado e não substitui o suporte auditado previsto no PRD. A semântica dos quatro estados de UX ainda não possui mapeamento decidido para o enum persistente `public.support_session_status`; a lacuna está registrada em `docs/open-questions.md` e não deve ser resolvida por esta implementação.
