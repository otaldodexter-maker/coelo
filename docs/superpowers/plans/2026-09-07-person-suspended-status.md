---
title: "PERS-STATUS01 — representação do status suspended"
source: "specs/046-superadmin-internal-person-detail-v2.md"
status: "local-verified-not-e2e"
generated_at: "2026-09-07"
---

# Recorte aprovado

Enum e representação de leitura/filtro do status cadastral `suspended`, já
existente no banco e no contrato 046. Rótulo `Suspensa`, tokens warning
existentes. Nenhuma ação de suspensão, comando, permissão, SQL ou rota nova.
Não confundir estado cadastral da pessoa com estado do vínculo de autorização.

- [x] Quatro RED: enum e leitura de adulto/criança/serviço suspensos.
- [x] Enum/decoder/switch, testes de representação e filtro.
- [x] Regressores, analyzer, review independente e evidência (duas falhas golden preexistentes preservadas).
- [x] Memória: registrar representação aprovada e supersessão MFA ADR0019set1.

O teste de indisponibilidade do decoder anterior passa a testar representação
correta. Evidências históricas daquele pacote permanecem preservadas; esta
fatia remove apenas a limitação explicitamente registrada.

Estimativa local 20–40 minutos. Não representa Pessoas/E2E completo.
