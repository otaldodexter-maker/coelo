---
title: Diretório de Pessoas do Superadmin
knowledge_id: superadmin-people-directory
source: specs/019-superadmin-people-directory.md
status: validated
generated_at: 2026-07-29
updated_at: 2026-09-07
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

As fontes históricas exigiam MFA em AAL2. No realm interno do Superadmin,
durante a validação do MVP, o aditivo de 2026-09-01 da
[ADR 0019](../../../decisions/0019-superadmin-internal-identity.md) supersede essa
exigência: AAL1/AAL2 são aceitos, com sessão, capability e escopo revalidados.
Isso não afirma alteração das RPCs people-based legadas nem autoriza seu uso
no caminho interno. Em adultos, a
unidade de mudança é o `institution_role_assignment`, separado da membership;
em crianças, são o `child_context` e seus links identificados. Vínculos não
citados permanecem intactos.

Adultos e crianças são criados em `draft`. Criar pessoa nunca cria Auth,
convite ou login. A API do formulário aceita `first_name`, `last_name`,
`display_name`, `legal_name` opcional e vínculos contextuais. Tipo, status,
CPF, nascimento, contatos, Auth, foto, membership de plataforma e vínculos de
responsável permanecem fora da edição.
Atividade pode aparecer na leitura e nos filtros de vínculos, mas o draft e a
atualização não aceitam `activity_id`. O formulário não oferece seletor de
atividade enquanto o contrato server-side e as validações de escopo de OQ-036
não forem aprovados.


Vínculos são patches explícitos: operações citadas são aplicadas e as demais
permanecem intactas. Instituição, unidade e grupo precisam formar o mesmo
contexto. A edição usa `expected_updated_at` e rejeita gravação concorrente.

Listagem e detalhe administrativos exigem RPCs server-side minimizadas e
autorizadas; MFA segue a política de realm vigente acima. Mesmo `people.read` não enumera `people`,
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

Conforme a [spec 046](../../../specs/046-superadmin-internal-person-detail-v2.md),
a representação de leitura/filtro preserva `draft`, `active`, `inactive`,
`suspended` (`Suspensa`) e `archived`. Status cadastral não substitui autorização
nem se confunde com suspensão de vínculo. Isso não cria uma ação para mudar o
status nem certifica implantação ou fluxo E2E.
