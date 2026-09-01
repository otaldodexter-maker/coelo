---
title: "Chat contextual do Coelo Principal no Superadmin"
knowledge_id: "principal-chat-integration"
source: "specs/050-principal-ui-ux-closure.md"
status: "validated"
generated_at: "2026-09-01"
audience: "team"
surfaces: [superadmin, principal-preview, chat, conversations]
visibility: "internal"
review_owner: "Coelo Product e Engenharia"
---

# Chat contextual do Coelo Principal no Superadmin

`Coelo (Principal)` identifica uma familia de superficies dentro de
`apps/superadmin` nesta etapa; nao autoriza materializar `apps/principal`. O
launcher Mensagens e a acao Mensagem do Perfil abrem uma UI propria do
Principal para inbox, thread e composer, com retorno contextual e estados de
carregamento, vazio, busca sem resultado, offline, falha e sem permissao.

A UI consome o `ChatRepository` mantido pela frente Comunicacao. Ela nao importa
widgets `SuperadminChat*`, `coelo_ui_admin`, nem cria outro repository Supabase,
RPC, migration ou backend. IDs de conversa nao concedem acesso: inbox, thread,
envio, leitura e refresh continuam revalidados pelo servidor.

Em `/dev`, a composicao usa a fixture deterministica compartilhada. Fora de
`/dev`, usa o repository produtivo compartilhado ou falha fechada quando a
capacidade nao estiver disponivel. Abertura de conversa, envio idempotente,
retorno, reload e negacao precisam de evidencia propria antes de qualquer
conclusao E2E.
