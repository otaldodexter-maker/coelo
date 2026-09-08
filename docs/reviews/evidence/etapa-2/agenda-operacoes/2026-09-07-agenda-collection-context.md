---
title: Agenda — contexto de solicitações e decisões pendentes
source: Inspeção dos dois clientes; sete RED locais; revisão de navegação
status: Correção local verificada; sem promoção E2E
generated: 2026-09-07
---

Seis testes iniciais falharam antes da correção: troca de repository não carregava
solicitações nem aprovações; diálogo antigo sobrevivia à troca de repository ou
negação no mesmo repository; duplo clique disparava duas decisões; exceção de
transporte escapava e mantinha a decisão sem recuperação.

Os dois clientes agora recarregam ao mudar sua fonte/modo. Aprovações captura fonte
e revisão de contexto no início, revalida antes/depois da decisão e remove sua
rota específica ao invalidar o contexto. Listener é removido ao trocar a fonte
e no dispose. A invalidação não faz pop da rota que estiver no topo.

A revisão independente encontrou um segundo caminho de pop indevido no sucesso
do próprio diálogo. Um sétimo RED empilha uma rota sentinela durante a decisão:
antes, a conclusão fechava a sentinela; agora fecha apenas a rota da decisão,
preservando a animação normal quando ela ainda é a rota atual.

O diálogo também impede execução simultânea antes do rebuild do botão e converte
Exception de transporte em estado local recuperável sem mostrar a mensagem bruta.
Não tenta novamente automaticamente, não altera autorização de backend e não
habilita novos caminhos de produção. Argumentos de autoria existentes não foram
redefinidos neste pacote.

Nove novos testes: sete casos com RED reproduzido e mais duas conclusões tardias
(sucesso/erro) após trocar A por B e abrir outra decisão. B permanece aberta e
decide pelo próprio repository, sem write cruzado. Regressão final68/68 PASS:
contexto, páginas de solicitações/aprovações, estados HTTP e goldens das superfícies
adicionais. Nenhum golden foi atualizado. Analyzer dos três Dart, validator visual
e diff check PASS.

Recorte apenas lifecycle/interação destes clientes. Não valida backend real,
persistência, audit remoto ou as demais operações de Agenda. Auditoria A01 continua
no fluxo SQL nominal separado. Skills Coelo integrada/UI, TDD e revisão orientaram
os guards e a prova da rota exata. Gate de memória sem projeção nova: correção de
invariantes existentes, sem nova regra de domínio.
