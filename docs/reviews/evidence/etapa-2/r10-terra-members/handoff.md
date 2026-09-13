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

## Revisao de integracao R10

### Achado que bloqueia aceite

O vinculo salvo sobrevive a uma atualizacao: `superadmin_group_save` somente
altera `institution_role_assignments` recebidos em `local_people` e nao toca
`child_group_links`. Isso preserva o aluno existente quando a tela e salva sem
novo `studentPersonIds`.

Mas `public.superadmin_group_get` delega a `group_management_payload`, cujo
`effective_access` vem somente de `institution_memberships` e
`institution_role_assignments`. Ele nao le `child_group_links`,
`child_unit_links` ou `child_contexts`. `_hydrateLocalAccess` recebe assim zero
alunos no reload: o vinculo permanece no banco, mas o formulario nao mostra o
id/nome infantil e nao permite revisar essa associacao. `studentCount` tambem
nao resolve a hidratacao, pois nao transporta identidade/contexto.

Nao ha correcao local segura sem expandir o contrato de leitura do backend. C0
precisa compor uma leitura autorizada por turma de `child_group_links` ->
`child_unit_links` -> `child_contexts` -> `people`, expondo pelo menos
`child_context_id`, `person_id`, `display_name` e estado. O consumidor deve
hidratar somente essas entradas como `aluno`; responsavel continua derivado e
profissional continua em perfil institucional.

### Checklist para a prova UI normal de C0

1. Entrar normalmente como ator com `people.assign_children`, abrir a Turma
   ativa autorizada e selecionar uma crianca ativa da mesma instituicao/unidade.
2. Salvar uma vez e confirmar pelo detalhe/leitor autorizado que existe um
   `child_group_link` ativo para a mesma turma, com o contexto e pessoa certos.
3. Recarregar a rota e reabrir a edicao: conferir o mesmo aluno por nome/ID
   mascarado e contexto; salvar uma alteracao de nome ou profissional sem tocar
   alunos e confirmar que o mesmo vinculo continua ativo apos outro reload.
4. Tentar crianca de outro tenant ou turma/unidade fora da hierarquia: a UI deve
   falhar sem enumerar dados e sem criar `child_unit_link`/`child_group_link`.
5. Repetir com ator sem `people.assign_children`: erro honesto, nenhuma escrita
   e nenhum profissional existente removido.

### Riscos concretos antes da integracao

- Sem a leitura acima, o aluno persistido fica invisivel no formulario apos
  reload, apesar de continuar na turma.
- A falha parcial por aluno nao recarrega o estado salvo; C0 deve confirmar que
  a tela reabre o detalhe autoritativo antes de orientar nova tentativa.
- Um payload de profissionais incompleto continua sendo autoritativo para
  `local_people`; a prova deve manter profissionais existentes visiveis no
  formulario antes de salvar a edicao.

## Correcao de leitura/reload autorizada por C0

O candidato `20260913024500_superadmin_group_students_payload_v1.sql` adiciona
`students` as respostas publicas de `superadmin_group_get` e
`superadmin_group_save`. A projecao privada exige grupo, vinculo de turma,
vinculo de unidade, contexto infantil e pessoa ativos, todos na unidade e
instituicao da turma. Ela devolve somente `child_context_id`, `person_id`, nome
e estado; nao mistura responsavel com aluno nem inclui perfil profissional.

O consumidor mapeia a projecao para `GroupDirectoryStudentBinding` e hidrata a
lista de Pessoas da turma apenas como aluno, usando `person_id` nas chamadas de
vinculo posteriores. Profissionais permanecem em `local_people`. A remocao de
aluno continua fora deste pacote: salvar sem um aluno nao encerra seu
`child_group_link`, e editar com ele visivel reaplica o vinculo canonico ativo.

Prova SQL local: candidato e pgTAP em transacao/rollback, 6 PASS / 0 FAIL:
leitura positiva com ids de pessoa/contexto, exclusao de filho de outro tenant,
funcao privada sem EXECUTE do cliente e negativa `groups.read`. O espelho ficou
sem o candidato apos rollback. Foi preparado teste focal Flutter de parsing da
projecao para reload; sua execucao esta pendente do slot exclusivo de C0.

## Correcao de remocao enganosa

O formulario nao oferece mais editar ou remover um aluno que foi hidratado de
`students`: ele permanece visivel com a indicacao de que a remocao por turma
ainda nao esta disponivel. A protecao tambem existe no callback local, para que
um acionamento futuro nao esconda um vinculo que o salvamento preservaria.

Foi conferido o contrato canonico em
`20260910220200_student_link_commands_v1.sql`. Nao existe desvinculacao por
turma; `superadmin_student_revoke` encerra o vinculo da unidade e todas as suas
turmas ativas. Ele nao pode ser usado para esta tela sem remover associacoes
fora do escopo. Alunos novos, ainda nao persistidos, continuam removiveis antes
do salvamento. Responsaveis e profissionais nao foram alterados.

Resultado desta correcao: `git diff --check` PASS. O slot Flutter estava em
uso por outro executor, portanto nenhum `flutter test`, build ou analyze foi
executado neste delta. O teste focal de parsing e a prova normal de UI/reload
seguem como gate de C0. O CRUD de remocao de aluno nao esta completo ate existir
um comando canonico, autorizado e restrito a `child_group_link`.
