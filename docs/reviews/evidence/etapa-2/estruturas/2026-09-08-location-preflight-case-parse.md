---
title: "LOC-PARSE02 — CASE de ACL no preflight candidato"
source: "repasse LOC50 do Engenheiro 1 e reserva pontual da coordenação em 2026-09-08; candidato LOC-ACL01 98d166d2"
status: "static-correction-awaiting-nominal-replay"
generated_at: "2026-09-08"
---

# RED observado e limite da prova

Engenheiro 1 reportou replay LOC50 do snapshot6cd030f4: CLI informou aplicação
dos49 arquivos anteriores, incluindo bootstrap030959, e falhou no target31000,
statement4/DOpreflight, SQLSTATE42601, syntax error at end of input. Expressão:
`is distinct from case when expected.client_execute ... end then`.
Nenhum pgTAP foi executado e os checks desse DO não chegaram a executar.
O log não é prova independente do ledger nem valida ACL/fingerprints.

Início2026-09-08T04:41:53.7367045Z, identidade local
coelo_safe_e0e5139d375049a983c1101b632c9, criação04:42:00.5718221Z com marcador
lido. Exit CLI/wrapper1. Cleanup independente reportado04:44:41.7542373Z:
containers/volumes/redes próprios0 e staging ausente; histórico preservado.
São resultados executados pelo Engenheiro 1, não pelo root desta worktree.

## Correção nominal

Somente dois caracteres adicionados no SQL candidato ainda não aplicado:
parênteses envolvendo o CASE da comparação de ACL do helper legado.
Nenhum valor ACL, fingerprint, grant, permissão ou semântica foi alterado.
Guard estático nominal reproduziu RED antes do patch e passou depois com os
17 gates e guards existentes. Isso não equivale a parse PostgreSQL executado.

SHA256 anterior da migration:
7C7CA4DA2AA4EECE06F386AEE9ADA7C52DB69EECD996BCA18ED434A922F90538.
SHA256 novo:
EC886DCBFBE88BE54FB99F233E01395A8632388B2DB94761F4A49B611E93AD2F.

Próximo gate: review central e novo pin do perfil pelo Engenheiro 1, com replay
autorizado. Nenhum SQL/Docker/remote executado nesta tarefa. A correção não
promove Local SQL GREEN ou qualquer action_id E2E. Memória de produto: no-op.
