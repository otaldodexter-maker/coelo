---
title: "Chat — referência canônica de ativo sem inferência legada"
source: "reserva M03 DTO/mapper do Coordenador; contrato MediaReader; testes locais"
status: "local-green; not-e2e"
generated_at: "2026-09-07"
---

# Resultado da fatia

`ChatAttachment.assetId` opcional é distinto de `id` da metadata. O mapper
v2 aceita UUID explícito e normaliza casing; legado sem campo permanece null.
Valor vazio/malformado/tipo incorreto falha sem inferir referência de id/key/
download_url. Nenhuma requisição adicional, leitura automática ou alteração do
send textual. Não há conexão HTTP MediaReader nem migration nesta fatia.

## Prova

- RED inicial: getter assetId inexistente.
- RED adicional: string vazia e malformada foram aceitas antes do validador.
- GREEN adapter: 16/16, incluindo cinco casos novos de referência.
- GREEN Chat sem arquivos golden: **62/62**, comando `flutter test --no-pub`
  com lista `rg --files test/features/chat -g *.dart` filtrada por não-golden.
- `flutter analyze --no-pub` nos três arquivos: sem apontamentos; formatter.
- Review independente read-only `review_media_session`: aprovado, sem achado.
- Ambiente local; fixtures HTTP sintéticas. Zero Supabase/R2/Stream executado.

## Gate aberto

Backend v2 atual ainda não projeta asset_id. É preciso evoluir catálogo/binding,
projeção autorizada, gateway, consumidor e lifecycle antes do E2E. Os goldens
preexistentes divergentes não foram atualizados nem incluídos na contagem.
Nenhum action_id foi promovido a verified/done/verified-e2e.
Memória: no-op, implementação de decisão já aprovada, sem nova política.
