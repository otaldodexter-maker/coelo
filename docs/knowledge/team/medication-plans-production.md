---
title: Planos de medicação produtivos
knowledge_id: medication-plans-production
source: specs/029-superadmin-medication-plans-production.md
status: validated
generated_at: 2026-08-12
audience: team
surfaces: [superadmin, health-care, medication, permissions, storage]
visibility: internal
review_owner: Coelo Product
---

# Planos de medicação produtivos

O contrato produtivo separa plano, agenda e execução. Cada plano pertence a uma
criança imutável; trocar de criança apenas navega, e nenhum dado é herdado entre
crianças. Dose, unidade, via, datas civis, fuso IANA, dias da semana e horários
formam a agenda. Responsáveis são múltiplos, adicionados um por vez e únicos no
plano.

Somente profissional com vínculo contextual e capability efetivos administra
dose. Administração, omissão, recusa, suspensão e correção são auditadas;
correção preserva o evento original. Autorização é recalculada no servidor por
requisição, com RLS/RPC, idempotência e proteção cross-tenant/cross-child.

Foto do medicamento e prescrição usam Supabase Storage privado, com metadados no
Postgres, path gerado no servidor, validação do arquivo e acesso temporário. A
preparação técnica é aprovada, mas o tratamento com dados reais permanece
fail-closed até aprovação de `legal_basis_and_retention`.
