---
title: "Teste local comportamental cross-tenant do Agora"
source: "ADR 0040; packages/coelo_database/supabase/tests/now_publication_removal_cross_tenant_test.sql"
status: "validated"
lifecycle: "current"
generated_at: "2026-09-15"
updated_at: "2026-09-15"
audience: "team"
action_id: "agora.remove"
---

# Escopo

Foi criado um teste pgTAP transacional com dois usuários e duas instituições
isoladas. O ator B, com membership/capacidade somente no tenant B, tenta
remover uma publicação publicada no tenant A.

O teste exige `42501` e confirma, após a negativa, status publicado, versão,
`removed_at`, auditoria de sucesso e fila de purge preservados. O teste termina
com `ROLLBACK` e não depende de Auth recovery, SMTP, Stream ou dados produtivos.

# Execução

O arquivo foi revisado e passou `git diff --check`. A execução pgTAP não foi
possível neste host porque o Postgres Supabase local não está disponível em
`127.0.0.1:54322`; não foi executado contra produção. O aceite produtivo
cross-tenant continua pendente para R16.
