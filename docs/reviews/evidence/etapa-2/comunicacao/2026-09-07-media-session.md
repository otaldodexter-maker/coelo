---
title: "M01: limite local de sessão de mídia privada"
source: "ADR 0032; plataforma compartilhada de mídia aprovada em 2026-09-03; reserva E2E3-M01"
status: "local-green-partial"
generated_at: "2026-09-07"
---

# Contrato consumidor

`package:coelo_api/coelo_api.dart` exporta `MediaSession`:

- Construir uma instância por sessão/realm/contexto autorizado pelo servidor.
- `run<T>(Future<T> Function())`: verifica a validade antes da chamada e antes
  de entregar o resultado. Não salvar estado dentro do callback; publicar apenas
  o valor retornado pelo wrapper.
- `registerPurge(FutureOr<void> Function())`: registrar limpeza de tickets,
  bytes, cache e player; retorna função idempotente para desregistrar um
  consumidor já descartado. Callbacks não devem aguardar `invalidate()`.
- `invalidate()`: marca imediatamente, inicia todas as limpezas e compartilha a
  mesma Future entre chamadas. É terminal; nova autorização cria outra instância.
- `isInvalidated`: indica o estado local. Exceções públicas não carregam PII,
  URL, token ou erro bruto do consumidor.

E2E1 conecta logout, revogação e troca de contexto ao hook e aguarda limpeza
antes de liberar o contexto seguinte. Gateway/cache/player devem consumir a
mesma instância. Isso não implementa revogação server-side, HTTP, R2 ou TTL de
tickets; estes permanecem gates separados.

## Evidência e rastreadores

RED: contrato inexistente impedia carregar o teste. GREEN: 23/23 testes Dart do
coelo_api (14 preexistentes + 9 novos); `dart analyze` sem issues. Review
independente read-only aprovado, incluindo reentrância e limpeza concorrente.
Nenhuma dependência nova; export aditivo sem alterar contratos Forms.

IDs consumidores E2E3: `chat.attach`, `chat.open`, `agora.view`,
`agora.create`, `momentos.view`, `momentos.create`, `principal.profile-view`,
`principal.profile-edit`. Deltas para os três rastreadores: registrar fundação
local testada sem promover nenhum ID. Front-end depende de integração Auth e
consumidores; Back-end/Supabase/R2/Stream sem alteração; E2E sem prova remota.

Gate de conhecimento: no-op na projeção; o hook implementa contrato já aprovado
na fonte canônica e este documento registra integração técnica/evidência.
