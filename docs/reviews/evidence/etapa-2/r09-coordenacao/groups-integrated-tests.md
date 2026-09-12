---
source: "G1 f519eabef; G1 1a5f4fa4c; terminal C0 52870"
status: "local-green-ui-pendente"
generated_at: "2026-09-12"
---

# Turmas — base conjunta R09

apps/superadmin -> Estrutura -> Turmas -> Pessoas da turma -> groups.members.
C0 revisou e integrou por merge o resolvedor de identidade global, a injecao
nas duas rotas e a leitura de profile_id/code/name no envelope management.
Nao foram alterados SQL/grants. Cadastro manual que exige identificador UUID
nao recebe aceite funcional; a prova seguinte usa a busca normal de identidade.

Na worktree C0, apos merges G1/G5 e QA9eb24fbf1:
`flutter test test/features/groups/presentation/group_form_page_test.dart test/features/groups/data/supabase_group_directory_repository_test.dart --reporter expanded`
terminou exit0, **35PASS/0FAIL/0SKIP**,12s no reporter. Terminal52870.
Esta e a verificacao exigida da base conjunta; nao somar os mesmos testes
aos30+5 autorais como cobertura unica nova. Os dois REDs autorais estao
resolvidos. Nenhuma prova UI nova nesta suite.

Primeiro registro da reserva do teste falhou por cwd incorreto; C0 corrigiu
o caminho na raiz enquanto a unica suite executava. G1 havia liberado o slot
apos seus5PASS; nao havia outro flutter test medido. Nenhuma segunda suite
foi iniciada. Slot devolvido ao final; nenhum teste verde sera repetido sem
mudanca pertinente. C0 transfere Chrome/build a G1 na revisao101 para
materializar este codigo no runtime antes da prova de groups.location/members.
