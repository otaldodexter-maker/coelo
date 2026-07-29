---
title: Grupos e envios do chat do Superadmin
knowledge_id: superadmin-chat-groups
source: decisions/0012-contextual-experiences-and-conversation-history.md
status: validated
generated_at: 2026-07-28
audience: team
surfaces: [superadmin, conversations]
visibility: internal
review_owner: Coelo Product
---

# Grupos E Envios Do Chat Do Superadmin

Na experiência do Superadmin, a inbox de Conversas nasce em `Todos` e oferece
as facetas `Institucional` e `Pessoas`. `Institucional` é o termo oficial e
substitui `Acadêmico` e `Contextos`.

Um grupo manual é um fio coletivo. No protótipo local, o Superadmin pode
selecionar membros de instituições diferentes; o grupo preserva os membros,
papéis, instituições e contextos de origem e aparece nas facetas representadas
por seus membros. Um Admin futuro permanece limitado à própria instituição.

Envio em massa não cria grupo nem histórico coletivo. A seleção é deduplicada
e cada destinatário recebe uma entrega privada independente.

Tudo isso está implementado somente como demonstração em memória. Não existe
envio, persistência, mídia, auditoria ou autorização real. Produção permanece
bloqueada pela OQ-029 até existir spec técnica aprovada para autorização,
auditoria, revogação e retenção cross-tenant.
