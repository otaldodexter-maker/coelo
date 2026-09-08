---
title: "Mídia — inventário remoto somente leitura"
source: "GETs Cloudflare pela conexão provisionada; catálogos PostgreSQL pelo conector Supabase em 2026-09-07"
status: "observed; no-remote-mutation; not-e2e-complete"
generated_at: "2026-09-07"
---

# Recorte

Configurações de infraestrutura e metadados de schema. Não foram consultadas
linhas de usuários, mídias, mensagens ou formulários. Nenhum segredo, URL
assinada, dado pessoal ou resposta bruta de credenciais é registrado aqui.
Este inventário descreve o estado observado, não garante que permaneça igual.

## Cloudflare

Conta da conexão: `2363eb1eadce9b73279d3c8ce46eb424`.

- `coelo-media-prod`, `coelo-documents-prod` e `coelo-transient-prod` existem.
  Datas de criação retornadas: 2026-09-03 14:24:02.867Z, 14:24:04.225Z e
  14:24:06.112Z, respectivamente. Não criar/recriar.
- Em cada bucket, URL pública gerenciada r2.dev desabilitada e lista de
  custom domains vazia.
- GET CORS retornou código 10059, configuração inexistente.
- Lifecycle possui somente `DefaultMultipartAbortRule` habilitada,
  maxAge 604800: aborta multipart incompleto, não comprova expiração/exclusão
  de objetos ou exports.
- GET Workers scripts retornou HTTP 200, lista vazia nesta conta.
- Consulta de zonas por conta e nome coelo.me retornou lista vazia. Não é
  prova de ausência global da zona, nem autorização para criar/mover DNS.

Credencial S3 de runtime, permissão Stream Edit e capacidade de deploy não
foram validadas. Não houve upload, DELETE, criação de recurso ou deploy.

## Supabase

Projeto `coelo`, referência `evvbomzejfijozbtgvpt`, observado ACTIVE_HEALTHY,
PostgreSQL 17.6.1.127. Todas as consultas remotas foram de metadados:
pg_class/pg_namespace, information_schema.columns, pg_constraint e pg_proc.

- Encontradas com RLS e FORCE RLS: `public.circular_media_assets`,
  `public.form_assets`, `public.form_file_jobs`, `public.meal_plan_image_assets`
  e `public.media_assets`.
- `public.platform_notices` encontrada com RLS, sem FORCE RLS.
- Não encontradas pelos nomes exatos consultados nos schemas public e
  app_private: `now_media_assets`, `moments_media_assets`,
  `chat_attachment_metadata` e `notice_publication_jobs`. Não inferir ausência
  de equivalentes com outro nome.
- `media_assets` mantém instituição/post/owner pessoa obrigatórios, FK do post
  com cascade e MIME restrito a JPEG/PNG/WebP/MP4. Não é ainda o catálogo comum
  projetado na ADR 0032.
- Forms mantém asset com pessoa ou hash anônimo, limite 10 MiB, três MIME de
  imagem e path hexadecimal de dois caracteres/UUID. Jobs ainda aceitam
  CSV/XLSX/ZIP/anonymous_participation, solicitante pessoa obrigatório e path
  legado. Não significa aprovação desses formatos para o MVP vigente.
- Na busca exata de assinaturas, encontrada
  `public.form_media_authorize_for_worker(uuid, uuid, text)`.
  Não encontradas as RPCs internas Notices v2 nem claim/run/materialize do
  pipeline nos schemas consultados.

## Consequência operacional

Código/migration local não prova recurso implantado. O transporte extraído
M02, catálogo compartilhado, autorização interna Forms, jobs de Avisos e
integração real permanecem gates distintos. Supabase não recebe mídia nova:
R2 privado continua a autoridade de storage conforme ADR 0032; Supabase guarda
catálogo, metadados, RLS, autorização e auditoria.

Gate de memória: evidência operacional somente; nenhuma decisão nova de produto.
