---
title: "Publicação do Acontece no MVP"
knowledge_id: "happens-publication-mvp"
source: "docs/superpowers/specs/2026-08-20-coelo-happens-publication-design.md"
status: "validated"
generated_at: "2026-08-20"
audience: "team"
surfaces: [principal, acontece, superadmin-preview, supabase, authorization]
visibility: "internal"
review_owner: "Coelo Product e Segurança"
---

# Publicação do Acontece no MVP

O composer do Acontece cria posts com até seis fotos ou vídeos, legenda, contexto institucional, audiência, rascunho, agendamento e prévia. A rota executável atual é `/dev/principal-happens/publish`, integrada ao callback opcional do botão Criar do preview.

Autorização é server-side, deny-by-default, com versão otimista e capabilities `happens.posts.create` e `happens.posts.publish`. A mídia usa temporariamente Supabase Storage privado conforme ADR 0026; bucket público é proibido e a migração ao R2 deve ocorrer antes de piloto/produção.
