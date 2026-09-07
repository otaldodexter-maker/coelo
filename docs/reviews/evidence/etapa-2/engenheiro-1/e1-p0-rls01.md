---
title: E1-P0-RLS01 — endurecimento local de tabelas privadas de perfis
source: Reserva nominal do Coordenador; migrations canônicas; execução local desta tarefa
status: validado localmente; revisão central pendente
generated: 2026-09-07
---

# E1-P0-RLS01

Escopo: ENABLE ROW LEVEL SECURITY e FORCE ROW LEVEL SECURITY em app_private.access_profile_catalog_versions, app_private.access_profile_command_receipts e app_private.access_profile_command_receipts_v2. Sem políticas, grants ou owners novos na migration. Pacote exclusivamente local nesta reserva; nenhuma aplicação remota ou alteração de ledger.

Arquivos nominais: packages/coelo_database/migrations/20260908000500_harden_access_profile_private_tables_rls.sql e packages/coelo_database/supabase/tests/access_profile_private_tables_rls_test.sql. A E2E 1 confirmou ausência de pacote equivalente antes da escrita.

## Baseline e revisão

- Worktree e1-replay-harness; runner baseado em 0fc17d38, com ajuste de teste separado e9fa9463.
- Supabase CLI fixada em 2.116.0; PostgreSQL local 17.6.1.165; seed de produto desabilitado.
- AuthOnly: 45 migrations canônicas + dois preflights. Manifesto normalizado SHA256 4279E67C9651F4049329591B6E8AAD82E3A9052506C1A4E16BA8BBB693249D59.
- Snapshot do pgTAP pré-RED: SHA256 2D3B3CBF88201E4551BDEEA4583CFBAD0D6D6F19B74A079A5C690B3FCAFD2B89, 284 linhas. Revisão independente de replay_runner e leitura do root sem bloqueador.
- O hash do teste acima é o bruto com LF durante RED/GREEN. Para comparar checkouts que normalizam CRLF, SHA256 normalizado do teste: F32259C045AA1A4FE7AF1840667AAA4F5F5472183C5257EFE2F50A5A147254E1.
- A migration corretiva estava ausente durante o RED.

## RED executado

Início anunciado por clock: 2026-09-07T23:17:44Z (20:17:44 BRT). Identidade: coelo_safe_5e07e1d8798047158ee7ead2271c5. Staging criado em 2026-09-07T23:18:06.7249167Z, com marcador correspondente.

Comando: Invoke-SafeLocalMigrationReplay.ps1 -TargetVersion 20260901200206 -AuthOnly -TestPath packages/coelo_database/supabase/tests/access_profile_private_tables_rls_test.sql.

Replay das 47 migrations passou. pgTAP executou 88 asserções: 70 PASS e 18 FAIL esperadas; exit 1. Falhas exatas: 5–10 (ENABLE/FORCE nas três tabelas) e 76–87 (SELECT, UPDATE, DELETE e INSERT do papel NOBYPASS). Os três INSERTs eram válidos e tiveram SQLSTATE nulo no baseline: a falta de RLS permitiu a escrita.

Os controles de owner/ACL, triggers por statement, receipt v2, exclusão/replay v1, auditoria e restauração de papel passaram. Não houve erro de fixture que interrompesse o teste. Todo o conteúdo de teste usa fixtures sintéticas e rollback.

Após a falha esperada, consultas independentes confirmaram ausência de containers, volumes e redes com essa identidade; o staging próprio estava ausente. O staging histórico alheio coelo_safe_af5bdf571cff41309f5b6845b713a permaneceu presente e intocado.

## GREEN e fechamento

Migration criada somente após o RED, com seis ALTER TABLE. SHA256 normalizado e bruto: 78EF014EABD9426A204B7CEBB5785F14A171509685AAD84BBEB14BDF20A0826F. O pgTAP manteve exatamente o hash do RED. Revisão independente do teste e da migration por replay_runner: nenhum bloqueador.

GREEN anunciado por clock em 2026-09-07T23:24:20Z (20:24:20 BRT). Identidade coelo_safe_0600ff2a732342308eb33dd386515; staging criado em 2026-09-07T23:24:32.4777644Z. Auth45 + uma adição nominal por nome/hash + dois preflights = 48 migrations. Alvo20260908000500.

Resultado: pgTAP P0 88/88 PASS e contexto Auth30/30 PASS; total118/118, exit0. SQL da migration, nome/hash da adição e ordem alvo foram validados pelo harness. Não foi necessário alterar o teste depois do RED.

Às 2026-09-07T23:26:44Z, a verificação independente posterior confirmou zero containers, volumes e redes da identidade GREEN, staging próprio ausente e staging histórico alheio preservado. O runner também concluiu com zero recursos residuais da própria identidade.

A entrega contém somente migration nominal, pgTAP, esta evidência e atualização do plano próprio. Nenhum manifesto, mirror de migrations, ledger, política, grant, owner, função, cliente ou backend remoto foi alterado. Memória: não foi criada projeção de produto para atividade local; fontes canônicas e evidência do pacote registram o conhecimento pertinente.

## Limites

- postgres tem BYPASSRLS; FORCE não o restringe. A role sintética NOLOGIN/NOBYPASS com DML temporário é a prova independente da barreira RLS.
- As tabelas não têm tenant_id. A prova de receipts é por ator e não substitui isolamento de tenant/realm nos gateways de produto.
- ACL preexistente dos wrappers v2 e entradas nulas de helpers privados permanecem fora desta migration; nenhum grant foi relaxado para produzir PASS.
- O teste v1 usa o consumidor legado real delete_and_reassign, com duas identidades de fixture legadas separadas do realm interno.
- Nada neste documento certifica tela E2E ou produção. A atualização dos rastreadores centrais pertence ao coordenador.