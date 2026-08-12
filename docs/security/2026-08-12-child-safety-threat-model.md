---
title: "Threat model - Segurança da criança"
source: "specs/030-superadmin-child-safety-production.md; OWASP ASVS 5.0 níveis 2 e 3; Supabase RLS e Storage"
status: implementation
generated_at: "2026-08-12"
---

# Threat model - Segurança da criança

Baseline geral: OWASP ASVS L2. Sobem a L3 autorização infantil, aprovação,
administração privilegiada, evidência, exportação, auditoria e chaves.

| Ameaça | Controle | Evidência |
| --- | --- | --- |
| IDOR/BOLA por UUID, pessoa global, ownership, filtro ou cursor | query parte do conjunto autorizado; responsável edita/reutiliza somente vínculo próprio; hierarquia validada; erro uniforme | RPCs e pgTAP negativos |
| aprovação por instituição ou unidade errada | membership ativa, capability e scope exato da unidade; AAL2; lock | `child_safety_has_exact_unit_review` |
| troca cross-child de subject | trigger valida instituição, unidade e criança de autorização/restrição/alerta/evidência | `validate_child_safety_context` |
| replay ou corrida | lock transacional da idempotency key, receipt com hash, versão não nula e `FOR UPDATE` | testes de contrato e concorrência |
| upload ativo/MIME falso/path traversal | path server-side, allowlist, bucket privado, scanner e estado draft | ADR 0024 e policies Storage |
| vazamento por export/CSV | capability+AAL2, job auditado, filtros allowlist e escape de fórmula | job versionado v1 |
| segredo/PII em cliente ou log | publishable key+RLS; auditoria guarda IDs/status, não documento ou contato | secret scan e revisão do diff |
| bypass de AAL2 por Data API | sem grants de `SELECT` nas tabelas; somente RPCs agregadas e minimizadas | teste de privilégio e chamada direta |

Risco residual: antivírus, retenção jurídica e destruição física são operações do
worker/infra. A ausência dessas operações mantém evidência em `draft`, nunca
libera acesso e deve gerar alerta operacional.

O status volta a `validated` somente depois de executar a matriz comportamental
com atores A/B, AAL1/AAL2, unidades e crianças distintas no banco local limpo.
