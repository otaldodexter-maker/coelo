---
name: coelo-fullstack
description: Use when a Coelo task crosses Flutter and Supabase (tela + RPC/RLS/Edge), or needs an end-to-end check.
metadata:
  status: "active"
  updated_at: "2026-09-18"
---

# Coelo ponta a ponta (modo de construção, ADR 0045 §7)

Carregue `coelo-backend` para o servidor e `coelo-frontend` para a tela. Ordem:
contrato (RPC/RLS + pgTAP) → aplicar em produção → cliente → `flutter test` →
abrir a tela na rota real e ver funcionar. Sem evidência, handoff ou rodada.
Versão anterior em `docs/archive/skills-20260918/`; `references/review-scope.md` só para
consulta histórica de identidades e rotas medidas.

## Regras que não mudam

- Invariantes de segurança do AGENTS.md.
- Contrato novo nasce no servidor; o cliente não inventa campo nem regra.
- Uma migration por mudança de contrato, forward-only, com pgTAP de caminho feliz e negativa (cross-tenant, versão defasada `PT409`).
- Produção é o único remoto; QA usa as identidades `qa-r06-*` e `qa-r15-responsavel`.
