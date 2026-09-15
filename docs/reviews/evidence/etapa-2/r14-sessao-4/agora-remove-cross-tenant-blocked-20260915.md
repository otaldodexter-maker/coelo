---
title: "Tentativa de prova cross-tenant do Agora — bloqueada"
source: "Sessão E; ADR 0040; contrato/Edge agora.remove integrados no dev"
status: "validated"
lifecycle: "current"
generated_at: "2026-09-15"
updated_at: "2026-09-15"
audience: "team"
action_id: "agora.remove"
---

# Resultado

A negativa cross-tenant específica de `agora.remove` permanece bloqueada e foi
destinada à R16. Não há certificação produtiva desta prova.

## Escopo executado

- Instituições sintéticas confirmadas no projeto vinculado: `qa-r04-chat` e
  `qa-r04-cuidado-sintetico`.
- Nenhuma alteração nos MDs centrais, contadores, Stream, Account residual,
  H10/H11 ou Auth recovery.
- Nenhuma publicação ou mídia foi criada nas tentativas que chegaram a falhar
  antes do login do ator de origem.

## Tentativas e limpeza

1. A criação da identidade QA falhou com `HTTP 400` por senha acima do limite
   do provedor; nenhum usuário foi criado.
2. A criação seguinte respondeu `HTTP 200`, mas a função versionada
   `app_private.seed_qa_r14_chat_cross_tenant_user` não existe no schema remoto
   vinculado, conforme consulta de metadados sem mutação. O usuário foi
   removido pelo Admin API.
3. A tentativa de preparação direta via SQL vinculado também falhou antes da
   publicação. O Auth user temporário foi removido; não houve fixture ativa.

As tentativas não produzem evidência de negativa. Não foram impressos tokens,
credenciais, URLs assinadas, PII, IDs de publicação ou bytes privados.

## Bloqueio para R16

Para certificar, a coordenadora precisa disponibilizar no projeto vinculado um
caminho de fixture autorizado e verificável para identidade/membership
cross-tenant, ou fornecer outra rota formal equivalente. A prova pendente deve
então cobrir publicação real em A, tentativa autenticada de `agora.remove` por
B com `422 publication_remove_denied`, auditoria sem mutação, remoção legítima
de limpeza e reload sem publicação.
