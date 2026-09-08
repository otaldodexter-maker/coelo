---
title: "Auth — login remontado e exclusão de operações concorrentes"
source: "reserva nominal do Coordenador; SDK Supabase real com transporte HTTP sintético; diff e testes locais"
status: "local-green; produção e verified-e2e pendentes"
generated_at: "2026-09-08"
---

# Recorte

Somente a action de login compartilhada pelo SuperadminAuthScope. Sem alteração
de gateway, sessão, guards R06/R07, recuperação, router ou backend remoto.

## RED e correção

O teste `login_remount_sdk_test.dart` monta SuperadminApp com Scope, SDK e
bootstrap gateway reais, substituindo apenas HTTP e persistência de sessão.
Submete A, mantém bootstrap pendente, navega para recuperação e volta ao login,
comprova novo elemento de tela e submete B pela mesma action.

Antes da correção, a negativa falhou: o endpoint logout recebeu o session_id
sintético de B durante cleanup de A. Revisão independente de account_review
aceitou o RED antes da implementação. Problemas iniciais de fixture foram
corrigidos antes dessa prova: Response.request do PostgREST e drenagem das
filas assíncronas. Nenhum acesso remoto foi feito.

A action agora recusa outra chamada enquanto credenciais, bootstrap e cleanup
estiverem em andamento. O guard é anterior ao primeiro await e é liberado em
finally. Nenhum guard de identidade/revisão foi removido ou flexibilizado.

O mesmo teste passou: B não é revogada, somente uma credencial ocorre durante
A, A negada mantém o portal fechado e uma nova tentativa posterior autentica B.
O botão de retry usa ensureVisible após a mensagem de erro; a conclusão do SDK
é aguardada explicitamente. Nenhuma asserção negativa foi removida.

## Verificação

- Teste de composição router/SDK: 1/1 PASS.
- Regressão Auth domain/data/view_models/widgets, telas login/forgot/reset,
  matriz responsiva, Scope, Session e novo teste: 154/154 PASS, sem goldens.
- flutter analyze dos dois arquivos alterados: sem problemas.
- Revisão independente de código e teste: aprovada, sem bloqueios.

Isso prova a corrida no cliente com SDK real e transporte sintético; não prova
revogação persistida no GoTrue, entrega de email ou execução em produção.
Esses gates continuam abertos e dependem do pacote nominal serializado.
