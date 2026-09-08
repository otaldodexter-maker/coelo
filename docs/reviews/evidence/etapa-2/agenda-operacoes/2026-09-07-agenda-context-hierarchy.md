---
title: "Agenda — validação da hierarquia recebida pelo RPC"
source: "packages/coelo_database/migrations/20260901193717_superadmin_agenda_contexts.sql"
status: "local-partial; sem promoção E2E"
generated_at: "2026-09-07"
---

# agenda.permissions — parser local

Nove REDs demonstraram aceitação de hierarquia inválida. Parser agora exige
strings, IDs únicos, raiz institucional coerente, pai existente da mesma
instituição e relações do RPC canônico: unidade→instituição, grupo→unidade,
atividade→unidade ou instituição. Duas passagens permitem ordem arbitrária;
relações estritamente ascendentes impedem ciclos. Payload inválido não substitui
snapshot aprovado anterior, e marca o canal como failure.

Positivo cobre árvore fora de ordem com seis contextos e duas instituições.
Negativos adicionais cobrem raiz com pai e atividade sob grupo.
Regressão Agenda selecionada: 124/124 antes desses dois negativos adicionais;
repository final 46/46.
Analyzer focado limpo; review independente sem incompatibilidade com o SQL.

Limite explícito: contextos injetados diretamente no construtor não passam por
este parser; não se afirma proteção de qualquer árvore artificial injetada.
Nenhum BD local/remoto foi executado; validação do cliente não autoriza acesso
nem substitui backend/RLS. Sem mudança de domínio ou nova decisão; memória no-op.
Persistência, autorização produtiva, reload e demais gates E2E permanecem abertos.
