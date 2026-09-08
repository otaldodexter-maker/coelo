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

## R08 — falhas visíveis e composição normal

Reserva central restrita a controller/tela/testes, init load e callback de
tema do App e load da rota normal `/settings`. Nenhuma alteração de shell,
Auth, FREAD/D01, dependências ou backend.

REDs observados: load falho deixava spinner sem retry; save falho produzia
Future não tratado sem aviso; init/rota e callback global também propagavam
falhas sem tratamento; erro antigo de tema exibia aviso após escolha nova.
O controller conserva erro sanitizado e propaga a falha ao chamador; UI e
composição consomem o Future apresentado, oferecem retry e não exibem dados
do erro original. Retry de save usa snapshot atual pela mesma fila serial.
Callback global confere estado atual e context mounted antes do aviso.

Oito cenários de erro (375/1440px × claro/escuro × load/save, texto 200%)
detectaram overflow no bloco de carga e no banner. Scroll no primeiro e ação
abaixo do conteúdo no segundo fecharam os oito cenários, sem mudar layout
global nem reduzir tamanho de texto.

Provas: 29/29 focais (controller 7, UI 13, repository 1, App 3, rotas Conta 5);
regressão conjunta Auth/Usuários/Conta 148/148. Analyzer inicialmente pediu
checagem do mounted do próprio contexto; após ajuste, 6 arquivos sem
diagnósticos e os 3 testes do App novamente PASS. Review independente
`account_review` aprovado no recorte. Nenhuma alegação de frontend global
verificado, pipeline produtivo de Conta ou E2E completo.

A prova browser de persistência anterior está no registro específico
`2026-09-07-settings-browser-persistence.md`; falhas de armazenamento nesta
fatia foram injetadas somente nos testes locais.

## R08 P2 — identidade da tentativa, não valor do tema

Revisão central reteve o incremento ao identificar Escuro A → Claro B →
Escuro C: falha tardia de A passava na comparação por valor. RED reproduzido
com três intenções e um único primeiro save pendente. O controller agora
numera intenções de ambos os setters e de retrySave antes do await, sem
alterar dispose ou a fila; o App correlaciona a conclusão com essa revisão.
Uma escolha nova que retorna ao valor antigo não reabilita o erro obsoleto.
30/30 focais PASS após a correção (App 4, demais 26).
