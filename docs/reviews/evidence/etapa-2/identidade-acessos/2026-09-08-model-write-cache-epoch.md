---
title: "Modelos — escrita tardia não contamina cache do novo contexto"
source: "Reserva nominal do Coordenador; hipótese realm_audit; RED/GREEN do adapter na base 6700ca83"
status: "local-green; backend-not-executed"
generated_at: "2026-09-08"
---

## Defeito e RED

AccessProfileModelRepositoryAdapter guardava epochs nas leituras, mas não
antes de salvar em _details os resultados de save/duplicate. Uma resposta A
retida podia chegar após B ter carregado o mesmo ID, sobrescrevendo o cache
usado para preservar efeitos deny no próximo comando.

Fixture pública controlada model_write_cache_epoch_test.dart:

1. A carrega target-model com platform.read deny e inicia save, ou duplicate
   com source-model distinto do target-model que será retornado.
2. Muda a revisão para B; B lê target-model com allow/version 3.
3. Entrega a resposta antiga A, deny/version 2.
4. B desmarca a permissão e salva com expectedVersion 3.
5. Asserção observa o payload público encaminhado ao source: não pode conter
   o deny antigo. Não depende de acesso ao mapa privado.

Antes do patch: **2 PASS / 2 FAIL**, exit1. Os casos com troca (save e
duplicate) enviaram deny quando o esperado era coleção vazia. Os dois
controles sem troca preservaram o deny legítimo e passaram. Não se executou
SQL; a evidência é contaminação do payload cliente, não escrita indevida no BD.

## Correção mínima

Quatro linhas no adapter: capturar revisão ao entrar em save/duplicate;
conferir a mesma revisão após await e antes de _details/retorno. Reutiliza
_requireCurrentRevision existente; resposta stale gera unauthorized local
sem apagar o snapshot B. Save cobre criação e atualização por seu caminho
existente; o RED direto de cache exercita update e duplicate.

Não modifica request, draft, expectedVersion, motivo, SQL, grants, router,
capabilities ou política de autorização. Não adiciona retry, RPC auxiliar ou
rollback. Uma escrita A já enviada pode ter sido persistida no servidor;
descartar sua resposta local não a cancela. Sem callback de revisão injetado,
o comportamento opcional prévio continua igual.

## Verificação

Comandos via RTK, cwd apps/superadmin:

- RED: flutter test --no-pub
  test/features/access_profiles/data/model_write_cache_epoch_test.dart.
- GREEN: mesmo teste mais access_profile_model_repository_adapter_test.dart,
  access_profile_model_context_test.dart no mesmo diretório e
  test/app/router/model_save_completion_routes_test.dart: **24/24 PASS**,
  exit0. Inclui controles de cache, contrato adapter, epochs READ e seis
  cenários de create/update em rota normal; não somar com rodadas históricas.
- Analyzer do adapter e novo teste: sem problemas, exit0.
- Review realm_audit sem bloqueantes no patch/controles. A fixture de cópia
  usa ID de destino conhecido e estados v1/v3 injetados; não reproduz a
  criação e concorrência no backend. O controle isola o comportamento do cache.

Testes exigem resposta stale rejeitada e novo payload B intacto, com request
IDs, expectedVersion e motivo preservados. O caso de duplicate carrega o ID
da cópia em B, não confunde esse ID com o modelo-fonte.

Primeiro gate externo segue runtime/backend nominal e produção. A prova não
cobre limpeza de todo cache já concluído antes da troca, errors antigos ou
concorrência de dois writes dentro da mesma revisão. Não promover E2E.
Plano atualizado; gate de memória no-op, correção de isolamento de estado
existente sem nova regra de produto. Sem alteração dos rastreadores oficiais.
