---
title: "Agenda READ039 — controller isolado e invalidação"
source: "recorte A aprovado pelo Coordenador; plano 2026-09-08-agenda-read039-presentation; testes locais"
status: "controller local-green; view e composição em andamento"
generated_at: "2026-09-08"
---

Base `6bcabe054453f0e408de842507cd0956e2f87f42`.
Arquivos: `agenda_read_controller.dart` e `agenda_read_controller_test.dart`
na feature Agenda do Superadmin. Nenhum router/DI/shared ou backend alterado.

O controller recebe uma chave opaca de fronteira. A futura composição deve
trocá-la em mudança de sessão, escopo autorizado ou revisão de capability;
essa chave não autoriza no backend. Chave nula impede dispatch. Troca limpa
página, contextos, detalhe, query de retry e invalida completions anteriores.
Negativa ativa limpa tudo e bloqueia novas leituras até nova fronteira.

List/contextos publicam snapshot conjunto. Cada RPC observa negativas de
forma independente: falha transitória anterior do irmão não oculta negação
posterior. Erros transitórios permanecem seguros e têm retry explícito.
Detalhe404 não apaga diretório autorizado; fechar detalhe invalida callbacks.
Guards também ocorrem após notificação e antes do dispatch, cobrindo listeners
que invalidam contexto de forma reentrante. Dispose pendente não notifica.

## TDD e revisão

- RED inicial: 2 controles PASS e 12 FAIL contra stub.
- Primeira implementação: 14 PASS.
- Review independente encontrou ordem falha transitória → negativa tardia:
  2 RED reproduzidos e corrigidos.
- Review de reentrância encontrou dispatch após invalidação na notificação:
  RED em page/logout, detail/logout e negativa síncrona. Controle de troca
  de escopo incluído; não se provoca dispose dentro de notifyListeners,
  operação que o próprio ChangeNotifier proíbe.
- Final controller: **20 PASS**, exit0; analyzer dos dois arquivos sem issues.
- Rodada anterior conjunta: 16 controller + 49 reader =65 PASS; não somar
  aos 20 finais como testes distintos.
- Review final `activities_contract_read`: achados encerrados no controller.
- Knowledge validator PASS, projeção no-op; nenhum novo comportamento de
  produto disponível ao usuário foi publicado.

Comando em apps/superadmin:

```powershell
rtk proxy flutter test --no-pub test/features/agenda/agenda_read_controller_test.dart
rtk proxy flutter analyze --no-pub lib/features/agenda/presentation/agenda_read_controller.dart test/features/agenda/agenda_read_controller_test.dart
```

## Limites

View isolada e sua evidência visual são a próxima fatia. Composição real,
vinculação automática da fronteira à sessão, HTTP real, SQL GREEN54 e remoto
continuam gates separados. Não há claims de autorização/RLS/E2E com estes mocks.
