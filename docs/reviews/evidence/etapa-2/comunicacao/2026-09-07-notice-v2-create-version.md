---
title: "Avisos — versão inicial v2 e interação mobile dos testes"
source: "superadmin_notice_save_draft_v2; NoticeFormController; DevelopmentNoticeRepository; testes Flutter"
status: "local-green; not-e2e-complete"
generated_at: "2026-09-07"
---

# Versão inicial

A RPC v2 cria management_version=1, mas o controller aceitava somente versão
0 para criação. Isso convertia persistência bem-sucedida em erro local.
A validação agora exige 1 na criação e incremento exato de uma unidade na edição.
Development e fakes foram alinhados, sem aceitar simultaneamente as duas bases.
Previews/objetos não persistidos não tiveram seu modelo alterado.

- RED: os dois testes novos demonstraram versão 1 rejeitada e versão 0 aceita.
- GREEN: ambos passaram; negativo de receipt impossível e testes de
  reconciliação/idempotência permanecem ativos.
- Teste controller → adapter com HTTP injetado confirma create sem versão
  esperada, receipt 1, publish esperando 1 e receipt scheduled 2. Não é HTTP
  remoto nem prova de persistência real.
- Teste dedicado de Development confirma criação 1 e edição 2.

## Interação mobile

Os dois testes mobile antes falhos agora aguardam layout, rolam até o alvo,
conferem hitTestable e usam tap normal. Não chamam callbacks diretamente nem
suprimem hit misses. O frame compacto aprovado rola conteúdo e footer juntos;
nenhum frame, shell ou estilo de produção foi alterado.

Primeira tentativa de ensureVisible antes de estabilizar o layout ainda
falhou; pumpAndSettle antes da rolagem resolveu a geometria invalidada pelo
preenchimento do campo. Página: 9/9. Essas duas pendências de teste registradas
na evidência anterior de feedback estão resolvidas, sem promoção visual/E2E.

## Verificação

- 31/31 testes focais controller, adapter, Development e fake.
- 99/99 de Avisos, excluindo explicitamente os arquivos *_golden_test.dart.
- Analyzer dos oito arquivos alterados sem problemas; formatter aplicado;
  validador administrativo passou.
- Reviews independentes de versão/retries e interação mobile aprovados.

Continuam abertos: replay SQL N01, execução real do worker, catálogo/mídia,
goldens e o caso de edição após publicação ambígua/agendada, identificado
separadamente. Gate de memória: no-op; reconciliação com contrato v2 existente.
