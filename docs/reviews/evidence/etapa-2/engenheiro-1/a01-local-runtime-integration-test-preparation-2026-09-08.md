---
source:
  - "Coordenador Etapa 2 / root: contrato nominal de integração A01, 2026-09-08"
  - "docs/reviews/evidence/etapa-2/engenheiro-1/a01-local-http-window-proposal-2026-09-08.md"
  - "packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1"
  - "packages/coelo_database/scripts/Test-LocalA01Runtime.ps1: Assert-A01Client, Get-A01Inputs e guarda de dot-source"
status: testes_preparados_red_integracao_pendente
generated_at: "2026-09-08"
---

Esta preparação adiciona somente **scripts/tests/A01LocalRuntimeIntegration.Tests.ps1** e esta nota. A implementação do wrapper pertence ao root. Prepare, helper, seed, SQL, cliente e perfis não foram alterados. O objetivo é testar a integração nominal sem iniciar mutex, staging real, Docker, SQL, HTTP ou Flutter.

O contrato exige switch **RunA01LocalRuntime** e string **A01ClientRoot**. A janela só aceita NominalProfile **A01DirectoryAuditGreen**, alvo **20260907222911**, incluindo casing canônico, minúsculo e maiúsculo. Rejeita FoundationOnly, AuthOnly, AdditionalMigration, RunAuthLifecycle, RunActivityV2Concurrency, TestPath e RunLint; rejeita cliente sem opt-in, perfil ausente/RED, alvo anterior e cliente vazio.

Antes da fronteira de recursos, o wrapper deve verificar o hash fechado do helper e o seed **758e6b4b3c8ad237ec709acd17c0fe59c9d554f6c789c76bbb81ab13a67adf99**, dot-source do helper com ProjectRoot/ProjectId futuros e ClientRoot, chamar Assert-A01Client e Get-A01Inputs. O helper continua responsável por validar o checkout f0be734ac3210c84523a61700f73feaba5150368 limpo e a seleção real Green55; os stubs desta suíte provam encaminhamento e propagação de falhas, não substituem sua suíte funcional.

O hash final do helper ainda depende de revisão. O teste não inventa esse valor: exige no prefixo do wrapper exatamente uma ocorrência literal do SHA256 UTF-8/CRLF calculado para o helper presente. A revisão central precisa aprovar esse arquivo e o literal correspondente antes de executar. Essa igualdade não constitui aprovação automática de um helper alterado.

Há dois níveis de verificação:

- **AST do wrapper:** parâmetros tipados, pins anteriores ao mutex, dot-source e checks com argumentos, matriz de serviços (DB-only quando ambas flags falsas; authLifecycleExcludes quando RunAuthLifecycle ou A01), chamada única sob a flag A01, argumentos fixos, posição após o guard completo de sucesso do reset e dentro do try cujo finally contém stop, reparse e remoção dos recursos próprios. Não basta encontrar texto dentro de uma branch de falha.
- **Prefixo isolado no TestDrive:** a cópia termina fisicamente antes da primeira construção do mutex e lança sentinela. Usa resolver nominal inerte, seed copiado sem executar e helper inerte observável. Somente nessa cópia o literal do hash real do helper é substituído pelo hash do stub; o fonte do wrapper não é modificado. Casos negativos adulteram/removem apenas arquivos da fixture. Erros ParameterBinding/NamedParameterNotFound ou a própria sentinela são rejeitados como falsos positivos.

As falhas de configuração esperadas usam mensagem iniciada por A01, ou a mensagem nominal existente de combinação proibida. Falhas delegadas de cliente e inputs têm sentinelas próprias. O teste não impõe uma nova taxonomia de erros do domínio. O stub proíbe invocação normal de runtime antes do mutex; somente dot-source importa as funções. Globals observáveis são removidos em AfterEach e os diretórios pertencem ao TestDrive do Pester.

Resultado focal com **Pester3.4.0**, Path + PassThru, sem suíte compartilhada:

| Evidência | Resultado |
| --- | --- |
| Parser PowerShell do novo teste | PASS |
| Primeiro RED observado | 31 testes: 3 PASS / 28 FAIL / 0 SKIP; 3.8360437s; exit1 |
| RED final, após exigir fim do guard reset em AST | 31 testes: 3 PASS / 28 FAIL / 0 SKIP; 3.3131591s externos / 2.9576351s Pester; exit1 |
| Sessão pendente | Nenhuma; execuções focais encerraram diretamente |

Os três PASS são as combinações de serviços já atendidas pelo wrapper anterior. Os seis FAIL de AST refletem parâmetros, pins, dot-source, seleção A01 e chamadas ausentes. Os 22 FAIL dinâmicos refletem os parâmetros ainda inexistentes; os negativos não aceitam essa falha de binding como prova de guard correto. Uma repetição intermediária preservou o RED, mas teve a saída resumida truncada; o último comando capturou somente o resumo final acima.

| Arquivo | SHA256 UTF-8/CRLF |
| --- | --- |
| scripts/tests/A01LocalRuntimeIntegration.Tests.ps1, 336 linhas / 17992 bytes | 6b88a4057b897ab078ec21461f60c88677dd05f8fe3ee5e2fe71df4e384bdd5d |
| scripts/Invoke-SafeLocalMigrationReplay.ps1, preservado | a6511eb6e8e03d0dd51d9740030437ffb89c519cffbbd2fa8d44cac63c96f539 |
| scripts/Prepare-SafeMigrationReplay.ps1, preservado | 3e5cab9d6fbc0285474d47f97c8efd8614e0e37dde5f3b6c5962ce00ca84ccbe |

Próximo gate: root implementa o wrapper com pin final revisado do helper, mantém Prepare intacto e executa esta suíte até GREEN, além da regressão reservada por ele. A chamada normal Test-LocalA01Runtime.ps1 deve receber ProjectRoot, ProjectId e ClientRoot dentro do try após reset55, antes de finally; não há keepalive. Esta preparação não executa nem autoriza a janela real, e não prova a ligação PostgREST/banco, autorização real, auditoria ou navegação Flutter.

Atualização do root: integração31/31 PASS e smoke Windows do helper final ab894730 PASS (stdin65.536, stdout/stderr, timeout com descendente e cleanup próprio em2,0485704s; cliente f0 limpo). Detalhes e limites em [a01-local-http-window-proposal-2026-09-08.md](a01-local-http-window-proposal-2026-09-08.md). A regressão compartilhada e o gate de serviços permanecem separados.
