---
source: R10 C0; SQL61/63; rota normal Superadmin
status: verified no recorte MVP de alunos
generated_at: 2026-09-13
---

# Turmas / Pessoas da turma ? groups.members

apps/superadmin > Estrutura > Turmas > Turma R05 Estrutura > Pessoas da turma > Buscar por identificador crianca.qar04 > Selecionar > Incluir usuario > Convites > Salvar turma. UI voltou a lista sem erro. Reabrir pela lista, reload completo, Pessoas mostrou Crianca QA R04 (groups-member-linked-reload.png).

Remover > Convites > Salvar turma: UI voltou a lista; banco marcou o mesmo child_group_link inactive. Reabrir e reload mostrou Nenhuma pessoa associada (groups-member-unlinked-reload.png). Reinclusao pela mesma rota reativou o mesmo link, sem duplicacao. Banco final: link0ba74b41-aaf4-4e6b-873f-8c58e74d453d active; unitlink6427c9a4-27c7-4048-a7ad-4ebe08a58a0d active; childcontextb1520810-ca23-4632-8b53-cc36e558013c. Pessoa/contextos antigos preservados.

Activity_group_link41e161da-ebaa-4fed-b0ba-132640e6a59f permaneceu active/participation_mode all. Correcao932ec41 preserva activity_ids quando inheritActivities=true; antes enviava lista vazia, desativava vinculo e a constraint P36 rejeitava o save (23514). SQL63 passa a aceitar people.assign_children de plataforma limitado ao escopo real, mantendo contexto institucional, unidade/turma e crianca ativos.

Build conjunto B3F3C8C80606A6367B1B7CD69178C1A18C4036E8AF7D4A890DBBBB06D40FED42; localhost3000; repository produtivo; Supabase evvbomzejfijozbtgvpt. SQL61 e63 aplicados uma vez apos provas locais e backups por lote; ledger63=20260913045039, gateMD5f0a5452062d3a4ca35a3030a5de32d78.

Provas atuais: student-link-real-scoped.sql/log23PASS0FAIL com helper real has_scoped_platform_permission (MD5igualprod168be6e9557e84828bd6c75d29b9f3a6), papel/capacidade/membership restrita A; B negada, revogacao negada, hierarquia adulterada negada. Resolver current_person_id e caminho contextual controlados apenas dentro da transacao rollback; nao equivale a segunda sessao tenantB. Adapter unlink14PASS do auxiliar e testes Flutter repository12PASS/form30PASS; base conjunta anterior36PASS pertinente e build release56.6sPASS.

consumer-negatives-post63.json:6PASS (inclui Auth/logout), hierarquia institucional real estrangeira negada P0002 HTTP500; nenhuma mutacao bem-sucedida por API. A UI realizou todas as escritas positivas. Nao usar Owner com outroID como tenantB. Aceite MVP de vincular/reler/remover/reincluir aluno alcancado; revisao exaustiva de perfis profissionais/guardian fora desta prova, sem mapear responsavel para professor.
