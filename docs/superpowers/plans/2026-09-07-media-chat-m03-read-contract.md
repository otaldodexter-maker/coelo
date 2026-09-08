---
title: "M03 — contrato consumível de leitura de mídia"
source: "ADR 0032; spec compartilhada aprovada; reserva local M03 do Coordenador em 2026-09-07"
status: "approved-scope; implementation-plan"
generated_at: "2026-09-07"
---

# M03 Read Contract Implementation Plan

> Execução inline pelo writer desta branch; subagentes fazem review read-only.

**Objetivo:** fornecer a primeira fronteira tipada de leitura temporária de
ativo para o consumidor Chat, sem habilitar anexos produtivos antecipadamente.

**Arquitetura:** contrato puro em coelo_api. `MediaReader` recebe assetId e
rendição explícita; resposta discriminada não confunde processing com
available. `SessionMediaReader` usa MediaSession existente e verifica a
correspondência do ativo. Transporte HTTP, backend e injeção pertencem ao
próximo pacote nominal, não a este contrato.

**Stack:** Dart/test já existentes; nenhuma dependência nova.

## Restrições

- Somente coelo_api e testes nesta fatia; sem Scope/main/router ou migration.
- Domínio Chat canônico reconciliado pelo Coordenador: communication/chat-message.
- Nenhum bucket/key permanente, ator/capability local ou credencial no DTO.
- URL temporária é segredo bearer; não renderizar em toString/erros.
- Servidor reautoriza toda leitura; validação cliente não substitui RLS/gateway.
- Estados de upload/finalização/envio não fazem parte do resultado de leitura.

## Tarefa: protocolo e sessão

Arquivos: `packages/coelo_api/lib/src/media/media_read_contract.dart`,
`media_reader.dart`, export aditivo em `coelo_api.dart` e
`packages/coelo_api/test/media/media_reader_test.dart`.

- [x] RED: `MediaReadResult.fromJson` disponível exige UUID, URL HTTPS sem
  userinfo/fragmento, expiração válida e headers string/string; estados
  não disponíveis não podem carregar ticket. Rejeitar ID/status/timestamp
  inválidos com erro constante, sem ecoar payload.
- [x] GREEN: implementar DTOs imutáveis e parser estrito. Requisição serializa
  somente asset_id e rendition, nunca tenant/ownership inferidos.
- [x] RED: reader com sessão invalidada não chama delegate; resposta pendente
  depois de invalidate é rejeitada; assetId diferente e ticket expirado são
  rejeitados antes de entregar o resultado ao consumidor.
- [x] GREEN: `SessionMediaReader(delegate, session, now)` envolve o delegate
  em MediaSession.run e valida correlação/expiração, sem cache ou retry.
- [x] Verificar: `rtk proxy dart test test/media/media_reader_test.dart`,
  suíte coelo_api completa, `dart analyze`, formatter, diff/secret review.
- [ ] Review independente e commit atômico; depois contratos de upload e
  finalização, catálogo nominal, processamento e integração real por seus gates.

Exemplos mínimos do teste:

```dart
expect(() => MediaReadResult.fromJson({'state': 'available'}),
    throwsA(isA<MediaProtocolException>()));
await session.invalidate();
await expectLater(reader.read(request),
    throwsA(isA<MediaSessionInvalidatedException>()));
expect(delegate.calls, 0);
```

Este plano não aprova formato/limite de arquivo, decoder, schema, endpoint
remoto ou mecanismo de revogação de URLs já emitidas. URL de acesso é
temporária; ocultação da chave dentro dela depende de entrega opaca pelo
gateway e não é prometida por um parser cliente.
