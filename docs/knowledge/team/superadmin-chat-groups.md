---
title: Grupos e envios do chat do Superadmin
knowledge_id: superadmin-chat-groups
source: [decisions/0012-contextual-experiences-and-conversation-history.md, docs/open-questions.md, docs/superpowers/specs/2026-07-28-superadmin-chat-local-redesign-design.md]
status: validated
generated_at: 2026-07-29
audience: team
surfaces: [superadmin, conversations]
visibility: internal
review_owner: Coelo Product
---

# Grupos E Envios Do Chat Do Superadmin

Na demonstracao local do Superadmin, a inbox de Conversas nasce em `Todos` e
oferece as facetas `Institucional` e `Pessoas`. `Institucional` substitui
`Academico` e `Contextos` somente nesta experiencia; a nomenclatura normativa
entre superficies continua aberta na OQ-030.

Um grupo manual e um fio coletivo. No prototipo local, o Superadmin pode
selecionar membros de instituicoes diferentes; o grupo preserva membros,
papeis, instituicoes e contextos de origem e aparece nas facetas representadas
por seus membros. Um Admin futuro permanece limitado a propria instituicao.

Conversas de criancas sao contextos, nao destinatarios: a demonstracao resolve
os responsaveis autorizados simulados e mostra o nome de quem escreveu. Nova
mensagem para varias criancas cria um fio privado por crianca; somente Criar
grupo pode combinar criancas.

Envio em massa nao cria grupo nem historico coletivo. A selecao e deduplicada
e cada destinatario recebe uma entrega privada independente.

Tudo isso esta implementado somente como demonstracao em memoria. Nao existe
envio, persistencia, midia, auditoria ou autorizacao real. Producao permanece
bloqueada pela OQ-029 ate existir spec tecnica aprovada para autorizacao,
auditoria, revogacao, convites/aceite, administracao de grupos, derivacao de
responsaveis autorizados a partir de criancas, notificacoes e retencao
cross-tenant.
