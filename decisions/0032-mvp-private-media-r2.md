---
title: "Mídia privada do MVP no Cloudflare R2"
source: "decisão explícita do Owner Coelo em 2026-09-03; anexos de discovery R2/Stream"
status: "approved"
generated_at: "2026-09-03"
supersedes: "decisions/0030-mvp-private-media-supabase-storage.md"
---

# ADR 0032 — Mídia privada do MVP no Cloudflare R2

R2 é o storage principal de todos os binários privados novos do MVP (fotos,
vídeos, thumbnails, variantes, documentos e anexos de Chat/Formulários).
Supabase/Postgres continua como fonte oficial de identidade, tenant, ownership,
autorização, metadados, retenção e auditoria. Não há mídia existente a migrar.

## Hierarquia

Criar somente DEV no spike: `coelo-media-dev`; `coelo-media-stage` e
`coelo-media-prod` apenas na promoção autorizada. Não criar buckets por tenant,
usuário ou tela. Chaves opacas, sem PII, definidas pelo servidor:

```text
<domain>/<tenant_uuid>/<asset_uuid>/original/<random>.<ext>
<domain>/<tenant_uuid>/<asset_uuid>/variant/<name>/<random>.<ext>
<domain>/<tenant_uuid>/<asset_uuid>/thumb/<size>/<random>.<ext>
<domain>/<tenant_uuid>/<asset_uuid>/tmp/<upload_uuid>.<ext>
```

`domain` é allowlist: `profile`, `happens`, `now`, `moments`, `routine`, `chat`,
`forms`, `exports`. Stream não replica pastas: `stream_video_id` fica no
Postgres; Stream é cópia HOT removível e o master permanece no R2.

## Escopo e segurança

R2 Standard no piloto (10 GB-month, 1M Class A e 10M Class B incluídos; egress
direto gratuito). Infrequent Access fica para depois. O master sempre é salvo
primeiro no R2. A política de distribuição é por produto:

- **Agora:** promover vídeo para Stream por até 24 horas quando a publicação
  exigir reprodução adaptativa; enquanto a cópia codifica, tocar o MP4 do R2 ou
  mostrar estado de processamento. Ao expirar, remover somente Stream e manter
  o master no R2.
- **Momentos:** R2 é padrão; Stream apenas para conteúdo novo/popular ou que
  ultrapasse um limiar de tráfego medido. A janela inicial não é fixada em 30
  dias; será decidida após métricas do piloto. Pode promover novamente depois.
- **Acontece:** fotos e vídeos curtos começam no R2; Stream somente se métricas
  de tamanho, compatibilidade ou tráfego justificarem. Não usar Stream para
  todo o feed.
- **Chat:** anexos e vídeos ficam no R2; Stream não é requisito do MVP.

Video Transformations, tiering automático e transcoding complexo ficam para
spikes posteriores. Import/export geral é adiado; somente
`forms.responses.export` exporta um arquivo Excel com as respostas do
formulário; a exportação geral do Superadmin continua adiada.
No Superadmin, os botões de importação/exportação permanecem visíveis por
composição e descoberta, mas não abrem picker, não geram arquivo e informam a
indisponibilidade de forma honesta.

Flutter chama Media Gateway server-side (Edge Function Supabase inicialmente).
O gateway valida sessão, tenant, capability, audiência, MIME, tamanho e
checksum, emite presigned PUT/GET curto, finaliza, limpa órfãos e audita.
Nenhuma chave R2 ou `service_role` entra no cliente; bucket privado, CORS
restrito e negativos cross-tenant/IDOR/revogado/expirado fail-closed.

Esta ADR supersede ADR 0030. Não autoriza ainda bucket, token, migration,
deploy ou alteração de produção; a próxima atividade é o spike DEV autorizado.
