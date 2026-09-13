---
fonte: R10 C0; UI normal e Supabase producao
status: verificado no recorte
data: 2026-09-13
---

# Perfis / Excluir ? access-profiles.delete

apps/superadmin > Acessos > Perfis e permissoes > Criar perfil (modelo Auditor) > Detalhe > Excluir > motivo > Excluir e realocar > lista > reload.

Build conjunto B3F3C8C80606A6367B1B7CD69178C1A18C4036E8AF7D4A890DBBBB06D40FED42, localhost3000, repository produtivo, Supabase evvbomzejfijozbtgvpt, sessao QA R06 Estrutura. Primeira prova criou/excluiu 424d4d15-009f-4e32-911c-9ae37c056bd1. Apos SQL62, segunda prova criou/excluiu 80cf70c6-f2e3-4088-82eb-97df303e5aa2 (QA R10 RLS). Ambos sem atribuicoes; nenhum perfil de sistema alterado. Banco confirmou zero perfis e zero memberships pelos dois IDs. Reload apos segunda exclusao mostra somente os cinco perfis existentes.

Evidencias: access-profile-created.png, access-profile-deleted-reload.png, access-profile-post-rls-deleted-reload.png; profile-delete-negatives.json (anon401, detalhe removido P0002); profile-delete-denial-green.sql (7PASS, sem identidade/sem capacidade/recurso preservado/sem receipt indevido/RLS).

SQL62 forward ativou ENABLE/FORCE RLS nas tres tabelas privadas. Pre/postflight em lote62-preflight.json e coordenacao.json; grants authenticated diretos negados. Hashes atuais do gateway e guard iguais no espelho/producao. Suite historica88: baseline67PASS21FAIL; candidato82PASS6FAIL, 15 falhas RLS resolvidas, seis divergencias legadas mantidas sem novas falhas. Nao declarar suite88 verde.

Aceite MVP de excluir perfil sem atribuicoes pela UI e reload alcancado. Recorte plataforma: nao representa prova de realocacao com atribuicoes, nem sessao de outro tenant institucional. Negativas sem identidade/capacidade sao as pertinentes ao perfil de plataforma. Nao inferir tenantB a partir de Owner.
