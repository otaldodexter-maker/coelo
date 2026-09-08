---
title: "Circulares — detalhe acompanha ID e contexto de leitura"
source: "AGENTS.md; SuperadminCircularDetailPage; revisão review_chat_receipt"
status: "local-green; E2E aberto"
generated_at: "2026-09-07"
---

Somente detalhe administrativo e seus testes. Mudança de ID/repository no
mesmo State agora limpa o conteúdo anterior, inicia nova leitura e ignora
sucesso/negação tardios de gerações anteriores. Nenhuma alteração visual,
permissão backend ou nova superfície.

RED: quatro novos testes falharam; o título anterior permanecia e a nova
leitura não ocorria. GREEN: 17/17 detalhe/composição e recuperação; 83/83
Circulares + principal_circulars sem arquivos golden. Analyzer dos dois
arquivos, formatter, validador visual e diff check passaram. Review estático
independente sem bloqueante. O teste de loading foi ajustado ao spinner real
do CoeloStatePanel, que não renderiza título nesse estado.

Não comprova revogação remota, persistência ou E2E. Hosts produtivos e callbacks
do composer têm pendências de troca de contexto separadas; não estão corrigidos
por este commit. Não houve SQL, Supabase, Cloudflare ou atualização de PNG.
