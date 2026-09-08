---
title: "Modelos de Acesso — autorização antes de lookup"
source: "Reserva local do Coordenador; spec 039 e aditivo MFA MVP; migrations 171731/193000; revisão realm_audit"
status: "nominal-red-test-prepared; not-executed"
generated_at: "2026-09-07"
---

## Recorte

Somente leituras list/detail/catalog de Modelos no Superadmin e o helper de
detalhe. Preservar autorização `${domain}.role_models.read`, Owner/escopo
platform, envelopes/argumentos PostgREST e auditoria interna. Não alterar
mutações/import/export, `require_profile_authority`, histórico de migrations,
Perfis legados ou aplicativos Admin/Principal/Site. Remoto sem lease: read-only.

## Reprodução preparada

`packages/coelo_database/supabase/tests/access_profile_models_read_authorization_test.sql`
tem 11 asserts e fixture transacional descartável. Owner interno AAL1 sem
pessoa, conta global com pessoa e sessão válida, três modelos por domínio.
As chamadas usam `authenticated`; TAP e inspeção de audit após `RESET ROLE`.

Os asserts 5/7 comparam detalhe de ID existente e inexistente sob sessão
inválida/realm global: o código atual consulta antes de autorizar e retorna
`SAI_PERMISSION_DENIED` para ID desconhecido, em vez do erro de sessão/realm.
RED esperado por inspeção, ainda não executado. Positivos list/detail/catalog,
negação por capability institucional, contraprova de plataforma e audit
identificável impedem confundir erro de ambiente com a correção.

SHA-256 UTF-8/LF do teste:
`fa1b23feb4089ae597b6cc4592ff66d51bb6d6f7ae11d3a7b6ad32e8e8d2b81b`.
Review independente `realm_audit`: sem bloqueante estático, plano 11 coerente.

## Dependências e próximo gate

Core de templates `20260811215451`, fundação interna/audit reconciliada,
default EXECUTE privado, Models `20260901170731`, wrappers `20260901193000`
e exceção AAL1 `20260901200206`. A ordem/bridges nominais pertencem ao Engenheiro
1 e ao Coordenador; não aplicar cauda histórica nem improvisar bridge.

Engenheiro 1 é o único operador de replay. Primeiro obter RED comportamental;
depois preparar migration forward-only nominal e repetir positivos/negativos.
Estimativa da fatia de código/teste: 45–90 minutos após baseline executável;
produção/E2E dependem do pacote coordenado, sem ETA confirmada neste registro.
Nenhuma SQL executada ou migration corretiva escrita nesta evidência.

Knowledge: sem decisão nova de produto; o gate conserva fontes existentes.
