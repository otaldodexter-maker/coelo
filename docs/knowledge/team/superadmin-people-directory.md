---
title: Diretório de Pessoas do Superadmin
knowledge_id: superadmin-people-directory
source: specs/019-superadmin-people-directory.md
status: validated
generated_at: 2026-07-29
audience: team
surfaces: [superadmin, people, database]
visibility: internal
review_owner: Coelo Product
---

# Diretório de Pessoas do Superadmin

Pessoas usa identidade global e vínculos contextuais independentes. O
Superadmin lista adultos, crianças e serviços com `people.read`; serviços são
somente leitura. Criação e edição usam `people.create`, `people.update`,
`people.memberships.manage` e `people.child_contexts.manage`. Inicialmente,
somente Owner recebe essas capacidades.

Todas as cinco capacidades exigem MFA em AAL2 no servidor. Em adultos, a
unidade de mudança é o `institution_role_assignment`, separado da membership;
em crianças, são o `child_context` e seus links identificados. Vínculos não
citados permanecem intactos.

Adultos e crianças são criados em `draft`. Criar pessoa nunca cria Auth,
convite ou login. A API do formulário aceita `first_name`, `last_name`,
`display_name`, `legal_name` opcional e vínculos contextuais. Tipo, status,
CPF, nascimento, contatos, Auth, foto, membership de plataforma e vínculos de
responsável permanecem fora da edição.

Vínculos são patches explícitos: operações citadas são aplicadas e as demais
permanecem intactas. Instituição, unidade e grupo precisam formar o mesmo
contexto. A edição usa `expected_updated_at` e rejeita gravação concorrente.

Listagem e detalhe administrativos existem somente em RPCs server-side
minimizadas e protegidas por AAL2. Mesmo `people.read` não enumera `people`,
memberships ou tabelas contextuais por SELECT direto; esses caminhos permanecem
self/own-context. Responsável lê contexto infantil somente com
`guardian_context_permissions` ativo, vigente, `can_view` e do mesmo contexto.
A própria criança preserva o caminho self.

Mudanças em memberships, assignments, contextos e links atualizam
`people.updated_at`, portanto invalidam edições concorrentes antigas. Reativar
um contexto infantil reutiliza seus IDs canônicos quando não há ambiguidade, e
o detalhe retorna somente contextos e links ativos. Auditoria registra cada
vínculo criado individualmente e o resumo da operação, sem copiar nomes,
contatos, CPF ou payload integral.

A cardinalidade definitiva entre pessoa e Auth continua aberta em OQ-033. O
schema impede uma credencial ativa em várias pessoas, mas ainda não impede
várias credenciais ativas para a mesma pessoa.
