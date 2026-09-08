---
title: "NAV-LOGOUT01 — navegação e descarte da sessão"
source: "reserva nominal do Coordenador; reprodução local e testes Flutter; go_router16.3.0 instalado"
status: "local-green; not-verified-e2e"
generated_at: "2026-09-07"
---

# Recorte autorizado

Somente estado de `CoeloNavigationContent` em `superadmin_navigation.dart` e
teste dedicado. Sem shell, guards, Session, topologia ou autorização nova.
Extensão para listener lifecycle autorizada após getter-only falhar no gate URI.

## Evidência

- RED: teste dedicado de logout1440 não termina após signOut; processo próprio
  interrompido. Reproduz o bloqueio de layout previamente isolado na Home.
- Getter-only usando routeInformationProvider resolve logout839/840/1440 e
  fallback sem router, mas falha produção→dev com o mesmo Element: não assina URI.
- Listener agora acompanha provider, troca por identidade e remove no dispose.
  `Router.maybeOf` registra dependência de configuração; o
  `InheritedGoRouter.updateShouldNotify` instalado retorna sempre false.
  O callback não modifica URI e só solicita rebuild enquanto mounted.
- Teste novo:7GREEN. Logout839/840/1440; sem router; produção→dev→produção
  mantendo Element; troca real de MaterialApp.router mantendo Element;
  reparenting entre providers, remoção e descarte sem listener residual.
- Inspeção de listeners usa helper somente de teste, com ignore pontual da
  anotação protected; os providers standalone começam sem listeners e voltam
  a esse estado depois do detach. Não há ignore no código produtivo.
- Regressão com superadmin_navigation_test e superadmin_router_test:49GREEN.
- Analyzer dos dois arquivos: zero issues. Review estático independente:
  sem bloqueadores concretos, sem testes paralelos.

O teste inicialmente consultava Planos, que também encontra Planos de medicação
em produção. Fixture corrigido para Cardápios, com resultado limitado à lista;
não houve mudança de regra de disponibilidade para adequar o teste.

## Limites

Resultados locais; nenhuma sessão real, produção ou BD foi exercitado. Isto
desbloqueia uma regressão compartilhada, não encerra E2E2. Nenhum baseline
visual foi sobrescrito. Conhecimento: no-op, correção de comportamento existente.
