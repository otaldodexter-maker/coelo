---
title: "Auth R06 — cleanup obsoleto durante recovery"
source: "Reserva focal R06 do Coordenador; testes Auth; revisão account_review"
status: "local-green; sdk-and-production-gates-open"
generated_at: "2026-09-07"
---

## Correção focal

Login e bootstrap restaurado não encerram recovery que chegou enquanto
aguardavam bootstrap interno, desde que o estado atual seja recovery com
ID não nulo, a sessão tenha observado recovery e sua revisão tenha mudado.
Nenhum contexto interno antigo é aplicado a recovery. ID ausente, contexto
negado atual e substituição arbitrária de ID continuam acionando cleanup.
Logout explícito, shell, navegação, mídia e contratos remotos não mudaram.

## Provas locais

- RED observado: callback recovery válido no bootstrap restaurado provocava
  `signOutCalls=1`, esperado 0; negativo ID nulo já passava.
- RED observado: login com callback recovery no mesmo ID e em novo ID também
  provocava revogação indevida; negativo ID nulo já passava.
- GREEN: 42/42 em quatro suítes — auth scope 14, login 13, logout 3, sessão 12.
- Analyzer dos quatro arquivos alterados: sem diagnósticos.
- Revisão estática independente `account_review`: sem bloqueios no recorte.

São controladores reais com gateways controlados; não demonstram SDK real,
SMTP, rede produtiva, revogação no servidor ou E2E.

## Pendências separadas preservadas

R07: getter do adapter Supabase diverge do evento `passwordRecovery` quando o
callback chega após inicialização e pode perder classificação no refresh.
Dois testes com SDK instalado e HTTP simulado reproduziram getter não-recovery,
com e sem assinante externo. Correção/lifecycle ainda em andamento.

Outro RED exploratório confirmou que A rejeitado apaga B ainda aguardando
bootstrap (signOutCalls 1 versus 0). Essa prova não faz parte da suíte verde
R06; será refeita no nível SDK. Não aplicar early-return por mera diferença de
ID: falta ownership nominal de tentativa concorrente ou garantia equivalente.

SDK instalado gotrue 2.26.0 captura JWT e remove sessão antes do await em
signOut local; a revogação usa o JWT capturado. Isso delimita a investigação,
mas não prova sobrevivência da sessão em produção.

Nenhuma regra nova de produto foi criada para Knowledge: a correção preserva
recovery separado da autorização interna conforme fontes canônicas existentes.
