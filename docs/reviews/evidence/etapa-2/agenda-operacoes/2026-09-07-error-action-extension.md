---
title: "E01 — extensão nominal das ações de retorno"
source: "apps/superadmin/lib/app/router/superadmin_router.dart"
status: "local-green; sem promoção E2E"
generated_at: "2026-09-07"
---

Extensão aprovada: studentManage, Support sem controller, profile e
devStudentManage. Somente actionLabel Voltar ao início, preservando callbacks,
guards e composição. Três REDs confirmaram Support/profile/preview com label
incorreto. Depois, 33 testes incluindo oito goldens verdes; analyzer limpo;
review independente sem achados.

Limite importante: studentManage produtivo é interceptado pelo guard anterior.
O teste confirma retorno pelo guard, não execução do builder específico; esse
label foi verificado estaticamente. Nenhuma autorização foi relaxada para teste.
Nenhum SQL, ambiente remoto ou action_id promovido. Memória no-op; contrato
de ação explícita existente. Gate de conhecimento geral: validator e testes PASS.
