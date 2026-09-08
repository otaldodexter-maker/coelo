---
title: "M03 — contrato local de leitura privada"
source: "ADR 0032; reserva local M03; testes coelo_api e duas revisões independentes"
status: "local-green; not-e2e"
generated_at: "2026-09-07"
---

# Recorte e resultado

Contrato neutro de app em `coelo_api`, sem dependência nova, Flutter, HTTP,
SQL, composition root ou mutação remota. `MediaReadRequest` envia somente
ativo/rendição. `MediaReadResult` distingue available, processing, expired e
unavailable; somente available pode portar ticket temporário imutável.
`SessionMediaReader` usa MediaSession existente, rejeita ativo divergente,
ticket expirado e resposta tardia depois da invalidação. Não há retry implícito.

## Evidência local

- RED inicial: tipos ausentes no teste focal, antes da implementação.
- Uma falha intermediária foi da fixture Dart inferida como Map não nullable;
  corrigida explicitamente para `Map<String, Object?>`, sem relaxar produção.
- GREEN final em 2026-09-07 21:23 BRT: `rtk proxy
  C:/src/flutter/bin/dart.bat test`, cwd `packages/coelo_api`: **59/59**.
- `dart analyze`: sem apontamentos; formatter dos quatro arquivos Dart.
- 36 testes do novo arquivo cobrem protocolo, UUID, URL, calendário/UTC,
  headers, estados, correlação, expiração, sessão, cópia e falha sem retry.
- Reviews read-only `review_media_session` e `crosswalk_media`: sem bloqueante
  no recorte puro; não executaram testes nem acessaram produção.

## Limites e próximos gates

Nenhum action_id promovido a verified, done ou verified-e2e. Supabase, R2 e
Stream não executados nesta fatia. Chat ainda não recebe asset_id universal
da metadata legada; não converter ChatAttachment.id por suposição.

O futuro gateway precisa resolver bindings e reautorizar cada leitura. O
parser HTTPS não impõe allowlist de origem. A resposta correlaciona somente
ativo, não declara rendição. O consumidor deve revalidar expiração ao usar um
ticket retido e purgar tickets/bytes na invalidação. URL temporária é bearer:
não registrar/persistir e não prometer revogação instantânea da URL emitida.
Ocultar a chave dentro da URL requer entrega opaca pelo gateway.

Próxima etapa: catálogo nominal, transporte autorizado e consumidor Chat;
prepare/finalize/discard, validação real de bytes e integração continuam abertos.
Gate de memória: no-op, sem mudança de política aprovada ou nova projeção.
