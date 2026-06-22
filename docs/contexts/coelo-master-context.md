---
title: "Coelo Master Context"
status: "planning-context"
generated_at: "2026-06-22"
---

# Coelo Master Context

## Funcao

Contexto agregador para planejamento e revisao global do Coelo. Deve manter coerencia entre produto, arquitetura, dominio, dados, seguranca, design e specs.

## Fontes primarias

- `docs/product/product-vision.md`
- `docs/product/prd-master.md`
- `docs/architecture/macro-architecture.md`
- `docs/architecture/domain-map.md`
- `docs/design/design-system.md`
- `docs/security/auth-multitenant-permissions.md`
- `docs/security/lgpd-security-media.md`
- `docs/data/data-model.md`

## Regras

- Preserve a visao original dos documentos oficiais.
- Use ADRs apenas para decisoes aprovadas ou propostas explicitamente marcadas.
- Conflitos vao para `docs/open-questions.md`.
- Nao criar agente por PRD.
- Qualquer implementacao futura precisa de spec SDD aprovada.
