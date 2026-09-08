---
title: "Modelos — envelope produtivo nas três leituras do cliente"
source: "Reserva LOCAL do Coordenador; dispatcher SQL 20260901170731 e wrappers nominais 193000; RED Flutter/HTTP real no SDK; review realm_audit"
status: "client-read-local-green; remote-e2e-open"
generated_at: "2026-09-08"
---

## Falha reproduzida

`SupabaseAccessProfileRepository._modelRpc` devolvia `{ok,data,error}` inteiro
para parsers que esperavam o conteúdo. Lista/catalog viravam vazios, detalhe
lançava TypeError e negações SAI em HTTP 200 não eram erro de acesso tipado.
Os mocks anteriores de READ devolviam payload cru e não detectavam o problema.

RED executado antes da correção: 45/45 casos falharam (três positivos,
21 negações e 21 payloads inválidos). Review independente pediu alinhamento
dos status internos 401/403 e correlation_id com SQL; mensagem adulterada foi
mantida intencionalmente como controle de sanitização. Mais três casos
`data:{}` falharam isoladamente antes da implementação.

## Mudança nominal

Helper privado `_modelReadRpc<T>` atende somente list/detail/catalog: exige
envelope válido, extrai data e decodifica dentro da proteção contra falha de
formato/cast. Sete códigos de Auth/realm/membership/capability/MFA viram
`AccessProfileUnauthorizedException`; outras falhas usam mensagem local
genérica. Não renderiza mensagem remota nem aceita fallback de payload cru.

List/catalog exigem `items` explícito do tipo lista. `items:[]` autorizado é
aceito; `data:{}` incompleto não é confundido com vazio. O mapeamento de erro
PostgREST existente é preservado por subtipo.

Não muda `_modelRpc`, comandos de escrita, import/export, Perfis legados,
router, grants, MFA, banco ou dados remotos. O teste antigo foi alinhado ao
envelope somente no caso READ; mocks de escrita continuam como antes e não
constituem prova de integração desses comandos.

## Evidência fresca e limites

- Camada de dados inicial: 62/62 PASS (48 novos e 14 existentes).
- Após acrescentar dois controles de vazio válido, regressão combinada:
  **96/96 PASS**, incluindo data, domain, view model, páginas e rotas normais/
  preview de Perfis/Modelos.
- Analyzer dos três arquivos: sem issues; format aplicado sem mudança de
  contrato; `git diff --check` passou.
- Review final `realm_audit`: sem bloqueante; unwrap, decodificação, erros
  seguros e preservação dos caminhos fora da reserva conferidos.

```text
flutter test --no-pub
  test/features/access_profiles/data
  test/features/access_profiles/domain
  test/features/access_profiles/presentation/access_profile_view_model_test.dart
  test/features/access_profiles/presentation/access_profile_pages_test.dart
  test/app/router/access_profile_routes_test.dart
  test/app/router/access_profile_preview_routes_test.dart
```

SDK Supabase real com transporte HTTP simulado, não servidor remoto. Não
inclui goldens. Invalidação de contexto, cache do adapter, navegação READ até
detalhe e dependência do catálogo de plataforma permanecem recortes abertos.
Nenhum SQL, Docker, deploy ou promoção E2E por esta frente.
Gate de memória: no-op; restaura consumo do contrato canônico existente.
