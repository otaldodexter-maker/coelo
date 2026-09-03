---
title: "Pessoas, papéis contextuais e contextos familiares"
source: "decisão do Owner Coelo em 2026-09-03; auditoria Supabase read-only; docs/data/data-model.md"
status: "approved-for-spec"
generated_at: "2026-09-03"
---

# ADR 0033 — Pessoas, papéis contextuais e contextos familiares

`people` é a identidade global. `institution_memberships` é o vínculo
institucional genérico (não apenas funcionário): pode representar funcionário,
professor, direção, responsável ou outro papel contextual, sempre com role e
escopo. O vínculo de responsável–criança continua em `guardian_links` e suas
permissões; o vínculo de aluno continua em `child_contexts`,
`child_unit_links` e `child_group_links`.

Crianças ligadas a atividades usam os vínculos de turma/atividade existentes
(`activity_group_participants`/`activity_group_assignments`); professores e
funcionários usam memberships e atribuições profissionais/administrativas.
Nenhum papel vira coluna booleana na pessoa.

Pronome de tratamento é contextual, curto e opcional, escolhido em lista
suspensa pesquisável. Catálogo inicial:

- **Familiar/social:** Senhor, Senhora, Seu, Dona, Senhorita, Doutor, Doutora;
- **Educacional:** Professor, Professora, Educador, Educadora, Instrutor,
  Instrutora, Monitor, Monitora;
- **Gestão/equipe:** Diretor, Diretora, Coordenador, Coordenadora, Supervisor,
  Supervisora, Gestor, Gestora, Secretário, Secretária;
- **Outros profissionais:** Enfermeiro, Enfermeira, Psicólogo, Psicóloga,
  Terapeuta, Auxiliar, Estagiário, Estagiária.

A busca filtra o catálogo sem texto arbitrário no primeiro momento; novos termos
podem ser adicionados por catálogo governado. O valor fica no perfil do
vínculo/contexto, permitindo que uma pessoa híbrida tenha “Senhora” no contexto
familiar e “Professora” no contexto profissional.

Uma pessoa pode salvar vários contextos nomeados e visíveis conforme escopo:
por exemplo, “Família Coelho” em uma unidade, uma cópia independente em outra,
ou “Coelho Natação” com subconjunto de membros. Contextos são agrupadores de
seleção e filtragem, não autorização automática. O responsável pode misturar
explicitamente filhos e pessoas de relacionamentos diferentes no mesmo contexto
ou separá-los; o sistema nunca infere nem mistura membros sozinho. Devem possuir
owner, instituição/unidade, membros explícitos, visibilidade e auditoria. O usuário
deve ser avisado de que o nome do contexto fica salvo e pode ser visto pelos
perfis autorizados. Listagens oferecem sempre três modos: todos os vínculos
permitidos, um contexto e uma pessoa individual.

Antes de migration, a spec deve definir entidades físicas para contexto,
membros, subgrupos opcionais, ciclo de vida, RLS por hierarquia e regra para
famílias com crianças de relacionamentos diferentes. Nenhuma tabela nova é
criada nesta decisão.
