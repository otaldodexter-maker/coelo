---
title: "Storage privado para evidências de segurança da criança"
source: "decisão explícita do produto em 2026-08-12; decisions/0010-private-media-r2.md; decisions/0020-backend-authorization-application-security.md; specs/030-superadmin-child-safety-production.md"
status: approved
generated_at: "2026-08-12"
---

# ADR 0024 - Storage privado de evidências de segurança da criança

> **Complemento supersedente do MVP:** a ADR 0032 define
> `coelo-documents-prod` no Cloudflare R2 como destino privado de documentos e
> evidências novas. Qualquer menção abaixo a Supabase Storage permanece apenas
> histórica.

## Contexto

Evidências de autorização, restrição ou alerta não são conteúdo operacional de
Happens, Now ou Moments. Elas sustentam uma decisão administrativa crítica e
precisam acompanhar o registro transacional, com acesso privado e auditável.

## Decisão

Evidências de Segurança da criança usam **Supabase Storage privado**. Esta é uma
exceção específica à regra-mãe de mídia operacional no Cloudflare R2; não altera
o destino de Happens, Now ou Moments e não autoriza outras features por analogia.

Postgres mantém contexto, sujeito, path opaco, MIME, tamanho, SHA-256, estado e
auditoria. O servidor gera o path. O upload nasce `draft` e somente um scanner
server-side pode torná-lo `active` após confirmar MIME real, tamanho e hash.

## Controles obrigatórios

- bucket privado, limite de 10 MiB e allowlist JPEG, PNG e PDF;
- policies separadas de INSERT e SELECT; sem UPDATE/DELETE pelo navegador;
- autorização recalculada por instituição, unidade, criança, membership,
  capability, owner e AAL2 em cada operação;
- objeto `draft` não pode ser baixado nem usado como evidência;
- sem SVG, conteúdo ativo, path/nome confiado do cliente, bucket público,
  URL permanente, `service_role` ou segredo no Flutter;
- retenção, descarte e antivírus seguem política jurídica aprovada e auditoria.

## Consequências

A UI não oferece fallback local ou sucesso simulado. Falha de scanner mantém o
objeto bloqueado; falha de autorização não revela se o objeto existe.
