---
source: R10 /root/terra_members; specs/012-superadmin-mvp.md; specs/015-contextual-people-access-attendance.md
status: candidato-local-testado-nao-integrado
generated_at: 2026-09-13
---

# groups.members — cadeia canônica de aluno

Autor: `/root/terra_members`.

## Causa

O formulário de Turmas serializa os rótulos de função `student`, `guardian`,
`professional` e `admin` como `local_people[].role_code`. O RPC
`app_private.superadmin_group_save` resolve esse valor apenas em
`public.institution_roles`. Assim, um responsável ativo é recusado como
`unknown role_code`; a tentativa não pode ser corrigida mapeando-o para
`teacher` ou criando membership/perfil implícito.

O contrato aprovado separa as cadeias: aluno usa `child_contexts` e
`child_group_links`; responsável deriva o acesso de `guardian_links` e
`guardian_context_permissions`; profissional usa membership e atribuição de
perfil institucional reais.

## Reuso e candidato

Existe `app_private.superadmin_student_link`, que já reautoriza
`people.assign_children`, deriva a instituição do contexto infantil, valida
unidade/turma, grava recibo e auditoria, e cria/reativa `child_group_links`.
Ele exige `child_context_id`, mas o resolvedor atual da tela entrega somente
`person_id` e `person_type`.

O candidato `20260913023000_superadmin_group_student_link_v1.sql` cria um
adaptador público de Turmas. Ele recebe pessoa e turma, resolve somente o
`child_context` ativo na instituição de uma turma ativa e delega a escrita ao
comando canônico. Não cria `institution_memberships`, não cria
`institution_role_assignments` e não escreve vínculos de responsável.

## Provas locais

Espelho exclusivo `supabase_db_coelo_baseline:57322`, sem reset/rebuild.

| prova | resultado |
| --- | --- |
| RED: `to_regprocedure(public.superadmin_group_student_link(uuid,uuid,uuid)) is null` | `true` |
| GREEN: candidato + pgTAP em transação | 7 PASS / 0 FAIL |
| pós-rollback: função ausente | `true` |

O baseline estava vazio para contextos e vínculos de criança; a prova atual é
de contrato/isolamento. Ainda falta a prova comportamental com fixture local
autorizada e, depois da integração, rota normal, persistência/reload e
negação cross-tenant.

## Limites e primeiro gate UI

O candidato não está em `migrations/`, não foi aplicado remotamente e não há
mudança Flutter integrada. Profissionais continuam dependendo de seletor de
perfil institucional real. Responsáveis não são membros diretos de turma.

Primeiro gate: C0 revisar/integrar o candidato; a tela seleciona uma criança
elegível, usa o adaptador e relê o `child_group_link` depois do reload. A UI
deve explicar que responsável tem acesso derivado da criança e que profissional
exige perfil institucional ativo.

## Atualizacao R10-dev-senior

- Resultado SQL: candidato e pgTAP em transacao/rollback, 13 PASS e 0 FAIL.
  A fixture comprova criacao de `child_unit_link` e `child_group_link` ativos;
  tambem nega cross-tenant, hierarquia invalida pelo comando canonico e
  `people.assign_children` ausente.
- Resultado Flutter: `flutter test test/features/groups/data/supabase_group_directory_repository_test.dart`
  passou 6/6; `dart analyze` dos dois arquivos ficou sem issues.
- Consumidor: uma falha de aluno agora retorna etapa parcial de Pessoas e tenta
  os demais. Alunos seguem fora de `local_people`; profissionais continuam no
  comando de turma e seus perfis reais nao sao descartados.
- Estado: candidato nao integrado e `verified-e2e` continua aberto para C0,
  incluindo integracao, migration serializada, UI normal, persistencia/reload e
  negativa real. Sem aplicacao remota ou deploy.
- Memoria: consulta de cadeia infantil/responsavel executada; no-op, pois nenhuma
  regra de produto aprovada mudou.
