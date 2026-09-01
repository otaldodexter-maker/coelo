---
title: "Gestão produtiva de Planos no Superadmin"
source: "ordens explícitas do Owner Coelo na conversa Finalização de Telas Operações em 2026-09-01; specs/022-superadmin-plans-ui.md; docs/product/prd-superadmin.md; decisions/0016-unit-type-and-plan-inheritance.md"
status: approved
generated_at: "2026-09-01"
---

# Gestão produtiva de Planos no Superadmin

## Objetivo

Promover o catálogo manual de planos para persistência produtiva, preservando a
experiência aprovada e sem introduzir cobrança automática.

## Escopo

- listar, criar, editar, arquivar e restaurar planos;
- capacidades comerciais fechadas e limites de unidades, memberships,
  armazenamento e mídia;
- vínculos de instituições somente leitura;
- busca, filtros e paginação server-side;
- concorrência otimista, idempotência, motivo e recibo de auditoria.

## Permissões e segurança

Leitura exige `platform.read`; mutações exigem `plan.change` e MFA AAL2. O
cliente não recebe grants diretos nas tabelas. RPCs `SECURITY DEFINER` validam
Auth, pessoa global ativa, membership de plataforma, permissão, MFA, payload,
versão e request ID. Tabelas expostas usam RLS habilitada e forçada.

## Regras

- código é único, normalizado e imutável após criação;
- criar, editar, arquivar e restaurar exigem motivo não vazio;
- plano em uso não é excluído; não há exclusão permanente;
- entitlements são allowlist: as nove capacidades visuais e os quatro limites;
- valores e contagens são inteiros não negativos com limites server-side;
- preço, cobrança e assinatura automática permanecem fora de escopo.

## Critérios de aceite

- CRUD persiste após recarga e request ID repetido não duplica efeito;
- versão desatualizada retorna conflito sem sobrescrever;
- `anon`, ator sem permissão, sessão sem AAL2 e ID direto não autorizado falham;
- a UI produtiva usa repository Supabase e `/dev` mantém fixtures;
- testes SQL, Flutter, cross-tenant e advisors relevantes passam.

