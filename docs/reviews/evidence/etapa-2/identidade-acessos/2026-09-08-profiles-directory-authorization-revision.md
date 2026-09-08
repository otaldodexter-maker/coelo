---
title: "Perfis e Modelos — invalidação do diretório por autorização"
source: "reserva nominal do Coordenador; router produtivo; testes locais da E2E 1"
status: "local-green; E2E pendente"
generated_at: "2026-09-08"
---

# Recorte e evidência

Somente os builders normais `/profiles` e `/profile-models` no Superadmin.
Um `ListenableBuilder` observa a sessão e uma chave baseada em
`authorizationInvalidationRevision` descarta o estado anterior do diretório.
Preservados paths, callbacks, repositories e fallback de composição indisponível.
Nenhuma alteração de capability, autorização server-side, layout ou mídia.

O teste `access_profile_authorization_revision_test.dart` usa o router real,
`SupabaseAccessProfileRepository` e SDK Supabase, com transporte HTTP sintético.
Para cada diretório, reproduziu RED e confirmou GREEN em dois cenários:

- Snapshot já carregado desaparece antes de terminar a nova resposta negada.
- Resposta permitida tardia do contexto anterior não reaparece após redução.

Controle positivo: reautorizar contexto equivalente não aumenta a revisão,
não remove o snapshot e não dispara consulta extra. A redução mantém a sessão
autenticada, distinguindo invalidação de autorização de simples logout.

## Verificações

- Quatro testes de regressão: 4/4 PASS após a correção.
- Regressão conjunta: 149/149 PASS em data/domain/view-model/pages de Perfis,
  rotas normais/preview/invalidação de Perfis, rotas e detalhe de Usuários,
  router geral e sessão.
- Analyzer do router e teste novo: PASS, sem issues.
- `git diff --check`: PASS.
- Review independente `realm_audit`: sem bloqueadores; somente dois hunks
  produtivos, controle de resposta capturado antes da espera assíncrona.

## Limites e próximo gate

Estado exclusivamente local-green. Nenhuma RPC remota executada, mutation,
migration ou lease de produção utilizado. Não comprova Front-end verified,
Back-end done ou verified-e2e.

Detalhe/formulário, cache do adapter e navegação de abertura para edição
permanecem fora desta reserva e exigem diagnóstico/reserva próprios. Também
permanecem pendentes os gates SQL/replay e a cadeia no Superadmin com backend
real, nova sessão/reload, negativos e cleanup.

Memória: restauração técnica de contrato existente; nenhuma decisão de produto
nova ou entrada de conhecimento durável criada. Rastreadores oficiais são
atualizados exclusivamente pelo Coordenador a partir deste handoff.
