---
title: O @ é a identidade pública de toda entidade
knowledge_id: coelo-handles
source: decisions/0034-mvp-remote-application-and-acceptance-bar.md
status: validated
generated_at: 2026-09-11
updated_at: 2026-09-11
audience: team
surfaces: [superadmin, institutions, units, groups, activities, people, principal]
visibility: internal
review_owner: Coelo Product
---

# O @ é a identidade pública de toda entidade

Decisão do Owner em 11/09/2026 (ADR 0034, Decisão 16): toda entidade do Coelo
(usuário, instituição, unidade, turma, atividade, e também funcionários,
responsáveis e crianças sem perfil de acesso) nasce com um @ único. Não existe
"slug técnico separado do @": o campo Identificador das telas é o campo do @,
mantém o ícone @ e mostra o padrão gerado pelo servidor como valor editável.

Padrões hierárquicos gerados pelo servidor: unidade `@unidade.instituicao`,
turma `@turma.unidade`, atividade no mesmo conceito dentro de instituição e
unidade. Unidade e turma sem @ explícito recebem o padrão normalizado (sem
hífen) e truncado antes do ponto para caber em 30 caracteres, com o sufixo
inteiro; colisão ganha segmento menor e sufixo curto.

Regras de troca: o @ pode ser alterado depois, com verificação de
disponibilidade enquanto o usuário digita (RPCs
`superadmin_structure_handle_availability_v1` e
`superadmin_person_handle_availability`), no máximo uma vez a cada 30 dias por
entidade (`handle_last_changed_at`; erro `SAI_HANDLE_COOLDOWN` com
`next_allowed_at`). Unicidade é global entre pessoas, instituições, unidades,
turmas e atividades.

Quem edita o @ de quem não tem login: a instituição para funcionários; os
responsáveis para a criança; sempre com auditoria.

Reservados: `coelo` e `coelo.me` (tabela `reserved_handles`) pertencem ao
perfil Coelo, que segue e é seguido por todos. A lista de palavras proibidas
como @ e a lista de @ exclusivos do Owner serão definidas por ele no
encerramento do MVP.
