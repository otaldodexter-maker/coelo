---
source: "assignment D00 r10; Invoke-SafeLocalMigrationReplay.ps1 focal diff; Test-LocalAuthRecoveryBoundary.ps1"
status: "prepared-hooks; integrated-replay-not-executed"
generated_at: "2026-09-09"
---

# Hooks locais exclusivos de D01

Entregar ao D00 somente o patch do wrapper, sem substituir integralmente a
versão central. O wrapper central já contém ActivityAggregateConcurrency e
RunR02AuthProofConcurrency; essas mudanças pertencem aos respectivos autores.
O delta D01 acrescenta RunAuthRecoveryBoundary/AssertAuthRecoveryConfined e
encaminha a execução ao novo script focal com as mesmas proteções de projeto,
mutex, manifesto, hash, perfil e cleanup existentes.

Boundary exige AuthOnly e recusa RunAuthLifecycle, RunActivityV2Concurrency
e RunR02AuthProofConcurrency. Para este último, a checagem usa a chave em
PSBoundParameters, preservando o switch definido pelo coordenador ao integrar.
AssertConfined exige Boundary. NominalProfile também recusa Boundary.

Quatro invocações reais do wrapper passaram pelos gates de recusa antes de
recursos, em todos os casos com TargetVersion20260901200206:

- AssertAuthRecoveryConfined sem Boundary.
- Boundary sem AuthOnly.
- AuthOnly + Boundary + Lifecycle.
- AuthOnly + Boundary + ActivityConcurrency.

Todos retornaram exit1 e a mensagem exata do guard esperado. Uma primeira
tentativa do harness omitiu TargetVersion obrigatório e foi corrigida antes
da verificação válida; não foi erro do produto ou início de recurso.
Parser PowerShell e diff-check PASS. Não há Docker/SQL iniciado por esses
checks. Integração dos dois hooks de concorrência na base D00 deve conservar
as respectivas exclusões; não se declara a composição central já executada.

O classificador de resposta do probe possui quatro verificações PASS em
local-auth-boundary-proof-classification.txt, separadas do produto. Só imprime
negativa PASS com ok=false/data=null/SAI_SESSION_INVALID. Revogação exige
HTTP400 com error_code específico do GoTrue, não qualquer falha HTTP.
Modo observador continua sem PUT; AssertConfined executa os nove gates
focais preparados. A execução real na base corrigida aguarda janela D00.
