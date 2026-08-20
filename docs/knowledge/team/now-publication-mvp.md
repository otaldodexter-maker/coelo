---
title: "Publicação do Agora no MVP"
knowledge_id: "now-publication-mvp"
source: "specs/036-principal-now-publication-mvp.md"
status: "validated"
generated_at: "2026-08-20"
audience: "team"
surfaces: [principal, agora, superadmin-preview, supabase, authorization]
visibility: "internal"
review_owner: "Coelo Product e Segurança"
---

# Publicação do Agora no MVP

O Agora possui composer próprio, separado de Acontece, Momentos e do viewer. Ele publica uma imagem ou vídeo vertical com texto curto, edição leve, áudio próprio, público/contexto, rascunho e agendamento. O plano-base permite vídeos de até 30 segundos; capacidades superiores são resolvidas e validadas no backend.

No MVP, mídia e áudio usam temporariamente o bucket privado `coelo-now-mvp` do Supabase conforme ADR 0026. O upload transitório é limitado a 25 MB. O cliente não escolhe paths, não recebe segredo e não concede autorização. Metadados, contexto, versão, auditoria, idempotência e expiração de 24 horas ficam no Postgres, atrás de um repositório independente do provedor; unidade e grupo são sempre revalidados contra a instituição.
