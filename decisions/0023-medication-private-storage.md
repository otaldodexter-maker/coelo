---
title: "Storage privado para foto de medicamento e prescrição"
source: "decisão explícita do produto em 2026-08-12; decisions/0010-private-media-r2.md; decisions/0020-backend-authorization-application-security.md; specs/029-superadmin-medication-plans-production.md"
status: approved
generated_at: "2026-08-12"
---

# ADR 0023 - Storage privado de medicação

## Contexto

A regra-mãe separa conteúdo operacional de Happens, Now e Moments no Cloudflare
R2 e identidade/perfil no Supabase Storage. Foto de medicamento e prescrição
não pertenciam inequivocamente a nenhuma família. A decisão de produto desta
entrega classifica ambas como assets privados do registro de medicação.

## Decisão

Foto de medicamento e prescrição usam **Supabase Storage privado**. A ADR 0023
substitui, somente para esses dois tipos de asset, a inferência de destino único
R2 da ADR 0010 e a referência R2 da proposta futura de Saúde e Cuidado. Happens,
Now e Moments continuam no R2; esta decisão não autoriza outros anexos
administrativos a escolher Storage por analogia.

Postgres é a fonte de verdade para owner, criança, contexto, tipo, versão,
checksum, MIME, tamanho, estado, retenção e auditoria. Objetos são manipulados
pela API de Storage; o schema gerenciado `storage` não recebe tabelas/funções
customizadas nem escrita SQL direta.

## Controles obrigatórios

- bucket privado e RLS/policies separadas por operação em `storage.objects`;
- autorização por usuário, tenant, instituição, unidade, turma, criança,
  membership, capability, ownership, objeto e estado em toda requisição;
- intent e path opaco gerados no servidor, sem nome/ID confiado do cliente;
- validação de extensão, MIME declarado/real, assinatura, tamanho e conteúdo
  ativo; SVG e URL pública/permanente são proibidos;
- leitura autenticada ou URL assinada curta emitida após nova autorização;
  expiração é obrigatória porque URL assinada não é revogada por rotação do JWT;
- nenhuma service role, secret key ou credencial de Storage entra no Flutter,
  bundle, log, fixture, screenshot ou Git;
- substituição cria nova versão; exclusão física, limpeza de órfãos e backups
  obedecem à retenção aprovada e são auditados;
- ativação continua fail-closed até aprovação de `legal_basis_and_retention`.

## Consequências

O frontend não faz fallback para R2, bucket público, arquivo local ou sucesso
simulado. A implementação posterior precisa de intents server-side, policies,
testes cross-child/cross-tenant, advisors e secret scan. A decisão reduz a
ambiguidade arquitetural, mas não resolve base legal nem prazos de retenção.

## Referências verificadas

- Supabase Storage Access Control:
  https://supabase.com/docs/guides/storage/security/access-control
- Supabase Storage Buckets:
  https://supabase.com/docs/guides/storage/buckets/fundamentals
- Supabase Serving assets:
  https://supabase.com/docs/guides/storage/serving/downloads
- Supabase Storage schema:
  https://supabase.com/docs/guides/storage/schema/design
- Supabase changelog consultado em 2026-08-12:
  https://supabase.com/changelog?tags=storage
