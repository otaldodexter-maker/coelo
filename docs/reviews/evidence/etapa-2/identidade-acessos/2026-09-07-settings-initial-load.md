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
falhas de gravação continuam fora deste incremento.
Não declarar o controller integralmente resiliente a falhas nem
Configurações verified-e2e.

## Follow-up P2 da revisão central

A revisão central identificou que o cache de `_loading` conservava Future
rejeitado. Dois REDs reproduziram retry bloqueado e erro tardio após dispose.
O handler agora limpa a referência em falha; mantém leitura compartilhada
enquanto pendente e cache após sucesso. Falha live continua propagada com
stack para o chamador; falha após dispose é encerrada sem evento/erro tardio.
Chamadas depois de dispose não iniciam leitura ou gravação.

Regressão atual: 9/9 (controller 5, SettingsPage 3, repository 1), analyzer
sem diagnósticos. Inclui primeira carga falha → segunda funciona → ambos os
setters salvam; duas cargas pendentes compartilham leitura; cache de sucesso;
dispose com erro sem notificação ou erro não tratado naquele fluxo.

Knowledge: nenhuma decisão nova de produto; preserva o contrato canônico já
projetado em `docs/knowledge/team/superadmin-profile-settings.md`.

## Ordenação de gravações

RED reproduzido: duas gravações entravam no repository enquanto a primeira
permanecia pendente. A segunda podia concluir primeiro e a primeira restaurar
o snapshot antigo. O controller agora serializa snapshots sem bloquear a
atualização visual. Falha chega ao chamador, mas não envenena a fila seguinte.
Gravações já solicitadas terminam após dispose sem notificações; novos setters
continuam sem iniciar IO após dispose.

11/11 PASS (controller 7, SettingsPage 3, repository 1), analyzer sem
diagnósticos e review independente `account_review` sem bloqueantes.
O teste remonta o controller e relê armazenamento controlado; não constitui
SharedPreferences/browser real. Feedback visual de falha e persistência real
permanecem gates separados, ainda abertos.
