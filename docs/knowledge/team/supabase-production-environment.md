---
title: Ambiente Supabase de produção
knowledge_id: supabase-production-environment
source: decisions/0034-mvp-remote-application-and-acceptance-bar.md
status: validated
generated_at: 2026-09-01
updated_at: 2026-09-10
audience: team
surfaces: [supabase, database, auth, storage, edge-functions]
visibility: internal
review_owner: Coelo Product
---

# Ambiente Supabase de produção

O projeto Supabase `coelo`, identificado por `evvbomzejfijozbtgvpt`, é o
ambiente de **produção** e, em 10/09/2026, ainda não tem clientes reais.

Desde a ADR 0034 o integrador tem autorização permanente do Owner para aplicar
migrations forward-only nesse projeto quando o pgTAP local passou, a ordem
serializada da fila foi respeitada e o backup por ponto no tempo está ligado.
Não é preciso pedir autorização por pacote. O que ficar aberto depois da
aplicação vai para os rastreadores, e o Owner revisa em ciclo semanal ou
quinzenal.

Cada pacote ainda precisa de contrato aprovado, RLS deny-by-default,
privilégios mínimos e pgTAP verde, incluindo negação de outro tenant. Segredos,
buckets e Workers do Cloudflare continuam exigindo autorização nominal.
