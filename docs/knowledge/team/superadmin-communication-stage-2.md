---
title: "Limite da Etapa 2 de Comunicação no Superadmin"
knowledge_id: "superadmin-communication-stage-2"
source: "docs/superpowers/specs/2026-09-01-superadmin-communication-finish-design.md"
status: "validated"
generated_at: "2026-09-01"
updated_at: "2026-09-01"
audience: "team"
surfaces: [superadmin, communication, chat, invites, notices, circulars]
visibility: "internal"
review_owner: "Coelo Product e Engenharia"
---

# Limite da Etapa 2 de Comunicação no Superadmin

A Etapa 2 de Comunicação altera somente `apps/superadmin` e os pacotes ou o
backend indispensáveis ao funcionamento dessa aplicação. Neste programa,
`Coelo (Principal)` nomeia uma superfície do menu do Superadmin; não é
autorização para implementar ou alterar `apps/principal`, `apps/admin` ou
`apps/site`.

O núcleo funcional de Chat/Conversas pertence à frente Comunicação e pode ser
consumido pela opção Chat exibida na superfície `Coelo (Principal)` do
Superadmin sem depender de UI administrativa específica. Circulares pertence à
frente responsável por essa superfície do Superadmin. O shell e o cabeçalho
mobile globais continuam compartilhados; cada feature não deve duplicá-los.

Avisos/Comunicações preserva dados fake somente sob `/dev`. O localhost sem
`/dev` usa o gateway Supabase da identidade interna: Owner em AAL2 cria, edita,
publica, pausa, reativa e inativa conteúdo textual; Conteúdo e Operações globais
podem ler. Os estados são rascunho, agendado, ativo, pausado, expirado e
inativo; expirado/inativo são terminais. Os estados legados publicado/arquivado
são convertidos para ativo/inativo. Mídia permanece indisponível de modo seguro
até o gateway R2 aprovado, sem bloquear o CRUD textual.
