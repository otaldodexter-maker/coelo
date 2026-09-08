---
title: "A01 — assertions independentes das ACLs pgTAP do cliente"
source: "packages/coelo_database/supabase/tests/superadmin_internal_auth_context_test.sql"
status: "prepared; revisão estática; SQL não executado"
generated_at: "2026-09-07"
---

Eng2 identificou risco do harness: pgTAP é instalado após replay e os hardenings
20260827214000 e 20260831231645 restringem EXECUTE padrão de novas funções.
Chamadas is/ok sob authenticated poderiam abortar antes do contrato. Evidência
estática, não inspeção de ACL runtime.

A01 adota o padrão canônico auth_context_test: captura RPC e current_user em
TEMP sob authenticated; RESET ROLE; assertions somente sobre valores capturados.
Não concede grants novos ao pgTAP, não executa RPC privilegiada como postgres
para simular cliente. AAL1 duplicado removido. Review independente confirmou
nenhum is/ok sob authenticated e nenhuma reexecução de RPC em assertion pós-RESET.

Base mínima54 segue revisão central; nenhum replay local/remoto executado nesta
frente. Este ajuste não declara RED/GREEN de banco nem promove ação E2E.
