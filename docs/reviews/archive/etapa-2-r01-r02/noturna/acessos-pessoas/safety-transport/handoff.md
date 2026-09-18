---
source: "E2-noturna-transversal-por-dono-20260909.md, secao 2; SupabaseChildSafetyRepository e consumidores; base c526307ddf"
status: "local-green 5P; publicacao pelo pai pendente"
generated_at: "2026-09-09"
---

# Safety: fronteira tipada de falha de transporte

Recorte apps/superadmin -> Acessos -> Seguranca da crianca -> leitura de detalhe e fronteira comum RPC -> child-safety.child/list. A verificacao de comando reutiliza apenas o contrato local do adapter; nao habilita child-safety.create/edit/suspend nem exportacao adiada.

O achado transversal era estatico: _rpc no adapter legado capturava somente PostgrestException. A inspecao dos consumidores limita sua gravidade: ChildSafetyController._load e _runCommand ja capturam erros genericos e fecham o estado; fetchChild/searchChildren propagam ao chamador, e as paginas tambem possuem tratamento generico. Portanto nao foi demonstrado crash de UI nem vazamento de dados. A lacuna concreta e que um ClientException HTTP atravessa a fronteira do repository em vez de virar ChildSafetyUnavailableException, prevista no contrato de dominio.

Mudanca aplicada minima: importar ClientException do package:http/http.dart e capturar somente esse tipo ao final de _rpc, convertendo-o em ChildSafetyUnavailableException. Os mapeamentos PostgrestException de Unauthorized, NotFound, Conflict e Validation permanecem intactos; erros de programacao nao recebem captura ampla. Nenhuma mudanca no decoder, controller, UI, router, suporte de mutacao, SQL ou composicao.

Prova focal: leitura fetchChild e comando saveAuthorization com MockClient que falha por ClientException; tres casos de preservacao dos codigos 42501, 40001 e 23505. Nenhum dado real ou chamada remota. O arquivo possuia quatro casos nominais de payload; nao ha cobertura ClientException anterior nos testes Safety, e os quatro verdes nominais nao foram repetidos. Os cinco novos casos sao contados uma vez, sem somar RED/rerun.

Fontes: apps/superadmin/lib/features/safety/data/supabase_child_safety_repository.dart:105 (_rpc); application/child_safety_controller.dart:91/107 (busca/detalhe), 173 (_load), 209 (_runCommand); presentation/safety_pages.dart:1002/1010, 1151/1159 e 1466/1474 (tratamentos na UI); domain/child_safety_contract.dart:216/224/232 (excecoes de dominio). Todos os caminhos application/presentation/domain sao sob apps/superadmin/lib/features/safety.

Proximo passo do pai: revisar os dois arquivos e evidencias, publicar e manter qualificacao produtiva pendente. Nenhuma promocao FE/BE/E2E ou mudanca de politica/MFA. Nenhum conhecimento duravel aprovado novo para projecao.

Resultado: RED **3P/2F**, ambos ClientException crus; GREEN **5P/0F/0S**, exit 0. Logs red.txt/green.txt. Casos unicos: read normalizes a transport failure as unavailable; command normalizes a transport failure as unavailable; transport boundary preserves database error 42501/40001/23505. Adapter +3 linhas; testes +39 linhas. Nenhuma captura ampla. diff --check limpo.

Analise estatica dos dois caminhos: No issues found, exit 0 (analyze.txt). Todos os processos proprios encerrados: RED38544, GREEN51580 e analyze72833. Nenhum servidor, Docker, recurso remoto ou novo filho criado. WIP nominal: somente adapter legado, teste correspondente e safety-transport/. Commit/push pelo pai pendentes.
