---
title: "Agenda READ039 — estado e apresentação isolados"
source: "recorte A aprovado pelo Coordenador em 2026-09-08; cliente 35b531f3"
status: "aprovado para controller/view isolados; composição não reservada"
generated_at: "2026-09-08"
---

# Agenda READ039 Implementation Plan

> Execução inline com executing-plans, TDD e review independente read-only.

**Goal:** consumir a projeção parcial sem converter omissão em audiência vazia.
**Architecture:** controller dedicado recebe repository READ039 e chave opaca
de fronteira de sessão/contexto/revisão; widget isolado consome seu estado.
**Tech Stack:** Dart, Flutter, componentes Coelo e testes Flutter locais.

## Restrições globais

Somente arquivos da feature Agenda e testes. Sem router, auth_scope, main,
superadmin_app, DI, HTTP real, SQL ou comandos. Caminho DEV legado preservado.
Sem bridge para AgendaItem/AgendaAudience legado. Reusar apresentação aprovada;
qualquer lacuna visual permanece bloqueante antes de código visual.

## 1. Controller independente

Criar `apps/superadmin/lib/features/agenda/presentation/agenda_read_controller.dart`
e `apps/superadmin/test/features/agenda/agenda_read_controller_test.dart`.
Consome `AgendaReadRepository.fetchEvents/fetchEvent/fetchContexts`.
Produz `AgendaReadController`: page, contexts, detail, pageStatus/detailStatus;
`loadPage`, `openDetail`, `closeDetail`, `setBoundary`, `retryPage`, `retryDetail`.
Chave nula nega leitura. Troca de chave invalida dados, query e requests antigos.

- [x] RED: estado inicial, paginação ecoada, falha/empty, detalhe/404, negação
  imediata apesar de RPC irmão pendente, invalidação de boundary e dispose.
- [x] Implementar epochs independentes de página/detalhe e boundary global;
  publicar página/contextos somente após ambas as leituras aceitas.
- [x] Negativa unauthorized limpa todas as projeções e bloqueia novas leituras
  até nova boundary; erro transitório nunca expõe erro bruto.
- [x] Executar `rtk proxy flutter test --no-pub test/features/agenda/agenda_read_controller_test.dart`
  em apps/superadmin; exigir PASS após RED reproduzido.
- [x] Review independente e analyzer. Commit atômico desta etapa.

## 2. Visualização isolada

Mapear baseline Instituições e detalhe aprovado Agenda antes de criar widget.
Consumir DTO parcial diretamente. Exibir indisponibilidade da audiência
individual, nenhum comando, loading/empty/retry/denied/not-found e paginação.
Mudança de controller e boundary não conserva conteúdo do contexto anterior.

- [ ] Ler índice e contratos visuais aplicáveis e validar matriz de estados.
- [ ] Testes widget RED para estado, detalhe, retry e conteúdo parcial.
- [ ] Reusar componentes canônicos sem alterar API compartilhada.
- [ ] Testar 375/1440, light/dark, texto200%, teclado e alvos de interação.
- [ ] Validador visual, review, evidência e commit; gaps visuais pedem decisão.

## 3. Handoff

- [ ] Atualizar plano vivo/evidência com estado real e gatilhos ausentes.
- [ ] Gate de memória no-op se não houver decisão durável nova.
- [ ] Não conectar produção: GREEN54, review e reserva nominal continuam
  requisitos separados, assim como o suplemento e runtime real.
