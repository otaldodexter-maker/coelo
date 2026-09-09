---
source: "../manifest-after.json; ../handoff.md; packages/coelo_database/replay/profiles/ChildDirectoryEnvelope"
status: "proposal-dry-run-pass; not-integrated; sql-not-executed"
generated_at: "2026-09-09"
---

# Proposta de perfil SafetyInternalReads53

Escopo: `apps/superadmin -> Acessos -> Seguranca infantil -> diretorio/detalhe`
(`child-safety.list`, `child-safety.child`; dependencia de
`child-safety.create`). Este filho preparou somente a selecao local do replay.
O pai conserva SQL/Safety Dart, integracao, commits e coordenacao do slot.

`profile.json` e `Resolve-SafetyInternalReads53.ps1` destinam-se a
`packages/coelo_database/replay/profiles/SafetyInternalReads53/`.
`wrappers.patch` propoe somente os registros ValidateSet/resolver em Prepare e
Invoke, e o gate de contagem LocalBridges em Prepare. Nao altera os wrappers
reais; aplicar somente sob reserva coordenada. Nao copiar o bridge para este
perfil: o resolver referencia diretamente o arquivo revisado no perfil
`ChildDirectoryEnvelope` e conserva as guardas de origem, hashes e MD5 do corpo
do helper. Nenhuma migration Forms ou adaptacao historica de Forms e usada.

A selecao e exatamente `manifest-after.json`: Auth45 mais cinco migrations
Safety, dois preflights herdados e um bridge, total53. Target unico
`20260909190000`. As cinco adicoes sao schema/read/security de
20260812002000/2100/2200, lint hardening20260825193116 e o candidato interno
20260909190000 com seu guard atualizado. O descriptor possui hash fixado no
resolver; fontes divergentes, links/reparse points, versoes duplicadas, count
inesperado ou proveniencia de bridge divergente sao recusados.

## Prova de preparacao

`Test-Proposal.ps1 -RepositoryRoot <worktree>` cria um sandbox temporario,
copia as entradas nominais e guardas, aplica o patch somente nessa copia,
valida parser e executa o Prepare real modificado sobre diretorio vazio
externo. Compara nomes e SHA256 raw de todos os53 arquivos com o manifesto e
remove seu sandbox por caminho absoluto verificado. Nenhum Docker, SQL,
credencial ou acesso remoto e usado.

`dry-run.json`: 7P/0F para parser dos tres scripts, selecao50+2+1, negativa de
target errado, negativa de descriptor alterado, negativa de migration alterada,
materializacao dos53 nomes/bytes e wrappers reservados inalterados. Sandbox
removido. Sao verificacoes de preparacao, nao testes de produto. Runtime Safety
permanece nao executado: interno43, legado63 e guard2 conforme handoff do pai.

## Integracao e primeiro passo

Coordenador/pai reserva os dois wrappers, revisa/aplica `wrappers.patch` e copia
os dois arquivos de perfil para seu destino acima. Depois executa o replay
serializado com `-NominalProfile SafetyInternalReads53 -TargetVersion
20260909190000`, informando os testes nominais Safety pertinentes. Sem
AuthOnly, FoundationOnly ou AdditionalMigration: o perfil ja seleciona tudo.
`../prepare.py` agora materializa o preflight em
`packages/coelo_database/supabase/tests/ap_safety_internal_preflight_test.sql`,
sob a raiz canonica aceita pelo wrapper. A proposta nao afrouxa essa guarda de
caminho. Selecionar esse teste2 e os testes internos43/legado63.

Os7 checks nao demonstram dependencias runtime, dados, RLS, grants, resultados
SQL43/63, HTTP/UI, FE/BE/E2E ou producao. Nao existe autorizacao remota neste
artefato. Gate de memoria no-op: nenhuma regra nova de produto foi aprovada.
