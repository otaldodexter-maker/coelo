---
title: "LOC-DTO01 — leitura tipada preparada"
source: "LOC-CATALOG01 ce318d05; reserva nominal da coordenação em 2026-09-07"
status: "approved-local-prepared-contract-not-replayed"
generated_at: "2026-09-07"
---

# Location Read DTO Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use executing-plans inline, preserving the single writer. Steps use checkboxes for tracking.

**Goal:** Decodificar somente as respostas de leitura do candidato Locais, sem conectar consumidores.

**Architecture:** Modelo Dart puro em coelo_domain; validação de transporte em coelo_api. LocationScope e LocationKind são reutilizados sem alterar snapshots. Integridade de IDs e proprietário não substitui autorização server-side.

**Tech Stack:** Dart >=3.8, package:test; sem dependências novas.

## Global Constraints

- Estado PREPARED até replay do contrato SQL; sem UI, RPC wire, SQL, builder de criação ou bridge.
- Nome/andar 120 codepoints, descrição 500; btrim remove somente espaço comum.
- Endereço country Brasil; demais chaves opcionais ou null; limites UTF8 80/64/240 bytes do candidato.
- Timestamps com timezone e calendário válido; versão positiva dentro do inteiro seguro web.
- Scope XOR institution/unit, cinco record_status, quatro visibilidades explícitas.
- Erros locais não incorporam dados ou mensagens do payload.

## Arquivos nominais reservados

- Criar `packages/coelo_domain/lib/src/locations/location_catalog_entry.dart`: modelos imutáveis de leitura e enums próprios visibility/status.
- Alterar `packages/coelo_domain/lib/locations.dart`: somente export do modelo novo.
- Criar `packages/coelo_api/lib/locations.dart`: barrel dedicado, sem tocar barrel geral.
- Criar `packages/coelo_api/lib/src/locations/location_catalog_dto.dart`: dois decoders de envelope.
- Criar `packages/coelo_api/test/locations/location_catalog_dto_test.dart`: positivos, negativos, Unicode, timestamps, imutabilidade.
- Criar `packages/coelo_domain/test/locations/location_catalog_entry_test.dart`: cópia defensiva dos containers.
- Criar `docs/reviews/evidence/etapa-2/estruturas/2026-09-07-location-read-dto.md`: resultados e limites, sem atualizar rastreadores compartilhados.

## Task 1: modelos e leitura estrita

Interfaces públicas:

```dart
LocationCatalogEntry decodeLocationDetailV2(Object? value, {required String requestedId});
LocationDirectoryResult decodeLocationDirectoryV2(Object? value, {required LocationScope requestedScope});
```

Os decoders retornam somente os 14 campos do payload e items/totalCount. Endereço
é mapa string/null copiado defensivamente, preservando ausente versus null.
O modelo não oferece canAccess, toSnapshot, toJson, builder ou execução remota.

- [x] Escrever testes que chamam os decoders com envelope `{ok:true,data:...,error:null}` e verificam ID, proprietário, enums e UTC. Negativos alteram um campo por caso; mensagens de falha devem ser genéricas.
- [x] Executar `rtk proxy C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe test test/locations/location_catalog_dto_test.dart` em coelo_api; confirmar RED por API ausente antes da implementação.
- [x] Implementar modelos, barrels e decoders. Validar mapas por igualdade de conjuntos de chaves; valores numéricos sem coerção; UUID canônico; referências de owner consistentes; campos já normalizados, sem transformação silenciosa.
- [x] Executar testes focais até GREEN; executar as suítes integrais de coelo_api e coelo_domain em sequência, analyzer dos arquivos novos e gates de memória.
- [ ] Solicitar revisão readonly, corrigir cada achado com RED focal; publicar commit nominal e evidência PREPARED, sem alegação E2E.

## Matriz executável esperada

```dart
expect(() => decodeLocationDetailV2(null, requestedId: id), throwsFormatException);
expect(() => decodeLocationDetailV2(envelope, requestedId: otherId), throwsFormatException);
expect(entry.scope, isA<InstitutionLocationScope>());
expect(() => entry.address!['city'] = 'mutated', throwsUnsupportedError);
expect(() => result.items.clear(), throwsUnsupportedError);
```

Cobertura obrigatória: 14 chaves exatas, endereço parcial/null, owner XOR,
UUID/ID divergente, enums desconhecidos e suspended válido, limites com emoji,
NBSP preservado, UTF8 de endereço, número fracionário/inseguro, data impossível,
offset válido, retorno de erro seguro, diretório cross-owner/duplicado e mutação.

Estimativa local: 1–2 horas incluindo revisão; não inclui replay ou UI.
Critério de parada desta fatia: testes/revisão e handoff nominal, mantendo o
trabalho original E2E em andamento.
