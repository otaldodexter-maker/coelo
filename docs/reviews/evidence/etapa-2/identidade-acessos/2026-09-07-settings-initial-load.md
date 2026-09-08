---
title: "Configurações — carga inicial e descarte"
source: "Escopo original Identidade e Acessos; design aprovado de Perfil/Configurações 2026-07-28; revisão realm_audit"
status: "local-green; settings-e2e-open"
generated_at: "2026-09-07"
---

## Correção focal

O controller compartilha uma única carga inicial. Edições aguardam essa carga
antes de aplicar e salvar a escolha; o snapshot tardio não sobrescreve o tema
escolhido nem perde a preferência de movimento já armazenada. Após dispose,
retornos pendentes não notificam nem alteram o estado do controller.

Não muda UI, router, backend, conta, tenant ou semântica de persistência:
as preferências continuam pertencendo ao dispositivo. Perfil produtivo,
e-mail, senha e avatar não são entregues por esta correção.

## Prova

Dois REDs observados: tema esperado dark retornava light após load tardio;
load após dispose lançava `used after being disposed`.

Após correção: 6/6 — controller 2, SettingsPage 3, repository 1.
Analyzer de controller/teste sem diagnósticos; revisão estática independente
sem bloqueio no recorte. A persistência dos testes é em memória, não prova
SharedPreferences real ou reload no navegador.

## Pendências preservadas

Persistência/reload real, ordenação de gravações concorrentes, tratamento de
falhas de gravação e retry após falha da carga continuam fora deste incremento.
Chamadas iniciadas após dispose não publicam estado, mas ainda podem iniciar
leitura. Não declarar o controller integralmente resiliente a falhas nem
Configurações verified-e2e.

Knowledge: nenhuma decisão nova de produto; preserva o contrato canônico já
projetado em `docs/knowledge/team/superadmin-profile-settings.md`.
