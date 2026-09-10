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
buckets e Workers do Cloudflare continuam exigindo autorização nominal, exceto
o pacote da Decisão 5 da ADR 0034 (CORS, lifecycle do transitório, token R2
mínimo, migração das três funções de mídia e spike), executado só pelo
coordenador da rodada.

Em 10/09/2026 a coordenação da Rodada 3 mediu que o backup por ponto no tempo
do projeto estava **desligado** (`pitr_enabled: false`). Pela Decisão 8 da
ADR 0034 o PITR pago fica dispensado até existir cliente real: a condição
passa a ser um `supabase db dump` lógico local (fora do Git), tirado pelo
coordenador antes de cada lote SQL e registrado em `coordenacao.json`.

Na mesma decisão o versionamento do banco ganhou uma **baseline**: o dump
schema-only de produção de 10/09/2026 é a migration inicial, o catálogo de
permissões é seed versionado e a cadeia anterior fica arquivada como
histórico. Todo pacote novo é provado por `supabase db reset` sobre a baseline
mais pgTAP, e esse replay é o preflight antes de produção. O ledger
`supabase_migrations.schema_migrations` não espelha os arquivos locais, então
a aplicabilidade de um pacote antigo é decidida por presença de objeto em
`pg_proc`/`pg_class`, nunca pelo carimbo.
