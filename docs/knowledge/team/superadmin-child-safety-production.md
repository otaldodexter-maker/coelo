---
title: Segurança da criança produtiva
knowledge_id: superadmin-child-safety-production
source: decisions/0032-mvp-private-media-r2.md
status: validated
generated_at: 2026-08-12
updated_at: 2026-09-03
audience: team
surfaces: [superadmin, child-safety, permissions, storage]
visibility: internal
review_owner: Coelo Product
---

# Segurança da criança produtiva

Pessoa autorizada é uma pessoa global reutilizada em um vínculo contextual com
a criança e a unidade. Solicitações nascem bloqueadas; somente ator com
`authorized_people.manage` no escopo exato da unidade e AAL2 aprova ou rejeita.
Decisão e ciclo de vida são estados separados, e autorização individual nunca
herda.

O navegador não recebe `SELECT` nas tabelas sensíveis: usa RPCs agregadas com
AAL2. Responsável edita somente a própria solicitação e não pode vincular UUID
global arbitrário nem restaurar uma suspensão/revogação decidida pela unidade.

As tabs são exclusivas: aguardando aprovação, atenção, autorizadas e sem
autorização, nessa precedência. Rejeição fica no histórico. Busca, contagens,
cursor e decisões são server-side, com RLS, idempotência, versão, auditoria e
testes cross-tenant/cross-child. Exportação real está fora do MVP pela ADR 0031;
o botão permanece visível e informa disponibilidade futura.

Evidência usa o bucket privado `coelo-documents-prod` via Media Gateway,
conforme a supersedência da ADR 0032. A chave é gerada no servidor e o objeto
fica bloqueado em `draft` até o scanner confirmar MIME real, tamanho, limites e
SHA-256.
