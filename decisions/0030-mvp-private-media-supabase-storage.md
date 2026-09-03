---
title: "Mídia privada do MVP no Supabase Storage"
source: "decisão explícita do Owner Coelo em 2026-09-01; decisions/0010-private-media-r2.md; decisions/0022-superadmin-activities-and-identity-storage.md; decisions/0026-happens-mvp-private-supabase-storage.md"
status: "superseded"
generated_at: "2026-09-01"
superseded_by: "decisions/0032-mvp-private-media-r2.md"
---

# ADR 0030 — Mídia privada do MVP no Supabase Storage (histórica)

> Supersedida em 2026-09-03 pela ADR 0032; preservada apenas para proveniência.

## Decisão

Durante todo o MVP, a mídia privada do Coelo usa Supabase Storage. Cloudflare
R2 não existe no ambiente atual, não será implantado para fechar o MVP e não é
gate de conclusão da Etapa 2.

Buckets permanecem privados. Autorização, escopo, ownership, tenant, audiência,
MIME, tamanho, checksum, expiração, retenção, remoção e limpeza continuam
validados no backend. O Flutter nunca recebe `service_role`, segredo, caminho
livre ou URL pública permanente. Postgres permanece a fonte de verdade dos
metadados e da auditoria.

## Evolução depois do MVP

No gate formal de encerramento do MVP, o Coordenador deve perguntar ao Owner se
deseja avaliar migração ou expansão para Cloudflare R2. Não criar bucket,
credencial, gateway, worker ou contrato R2 antes dessa confirmação.

Se a evolução for aprovada, uma nova ADR deve definir migração, compatibilidade,
custos, segurança, observabilidade e rollback sem exigir alteração do domínio ou
da UI.

## Supersessão

Esta decisão substitui, para o MVP, qualquer exigência anterior de R2 em
`decisions/0010-private-media-r2.md`, `decisions/0022-superadmin-activities-and-identity-storage.md`,
`decisions/0026-happens-mvp-private-supabase-storage.md`, specs, projeções de
conhecimento e rastreadores. Circulares continua usando Supabase Storage conforme
a ADR 0027.
