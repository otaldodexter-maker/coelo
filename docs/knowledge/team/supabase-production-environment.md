---
title: Ambiente Supabase de produção
knowledge_id: supabase-production-environment
source: docs/open-questions.md
status: validated
generated_at: 2026-09-01
audience: team
surfaces: [supabase, database, auth, storage, edge-functions]
visibility: internal
review_owner: Coelo Product
---

# Ambiente Supabase de produção

O projeto Supabase `coelo`, identificado por `evvbomzejfijozbtgvpt`, é o
ambiente de **produção**. Deploys e mutações remotas devem seguir gate de
produção, reconciliar o ledger, limitar-se a contratos aprovados e produzir
evidência de segurança e rollback.

Essa classificação não aprova specs em draft, não resolve divergências de
proveniência e não autoriza restaurar migrations históricas. Cada pacote ainda
precisa satisfazer seus próprios gates de contrato, RLS, privilégios, replay e
validação negativa.
