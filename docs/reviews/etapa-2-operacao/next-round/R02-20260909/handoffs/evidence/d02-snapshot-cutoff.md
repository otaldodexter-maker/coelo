---
title: "D02 — reporte do corte de 16:30"
source: "prompts/D02.md; escopo.json canônico; handoff D02 r29; assignment D00 r35; commits e provas locais"
status: "reported; consolidation-only-until-1715"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

Reporte do corte materializado às 16:32 BRT. O snapshot estava publicado
antes do corte; uma falha de quoting impediu a primeira atualização de status.
Após 16:30, somente correções concretas da consolidação até 17:15.
Rodada E2-R02-20260909, executor D02, thread
`01a086d7-ffa5-7593-99e7-0c2729e0ce59`, root GPT-6 (variante/esforço não
expostos), três filhos gpt-5.6-sol médio. Worktree
`C:/Users/adrie/Documents/Coelo.worktrees/e2-r02-d02-estrutura`, branch
`codex/e2-r02-d02-estrutura`, baseline
`56eb3f19de23e364ea5f7e4f73a6fbd9a851e230`. HEAD/remoto apurados antes desta atualização documental:
42a3647504eaae3ff00dd090fe107b96665fcc02, iguais em consulta local e
ls-remote de 16:27:54 BRT. Diff rastreado e staged
vazios; stash vazio. Os 23 auxiliares locais constam de
[d02-retained-local-files.json](d02-retained-local-files.json).
A integração em dev pertence exclusivamente ao D00.

## Avanço por tela

Todas as linhas pertencem à Etapa 2 → apps/superadmin. Ações citadas são
subaceites locais; nenhuma ação inteira foi promovida por D02.

| Menu/tela/subtela | IDs diretamente afetados | Entrega local | Primeiro aceite ainda aberto |
| --- | --- | --- | --- |
| Instituições / editar / salvar e retry | institutions.edit, institutions.error | c3fb1d2c impede descarte silencioso de 25 strings fora do writer core, mantém rascunho e tentativa; 35 repository + 6 lifecycle P. Integrado b648379b. | Writer completo de contato e demais campos fora da spec042; salvar/reabrir completo não certificado. |
| Unidades / diretório / paginação | units.list | 85f82c88+00e69e3a invalidam contexto antigo preservando pageSize; 1 caso ampliado P. | Contrato dos RPCs produtivos e reconciliação OQ032. |
| Unidades / criar-editar / sessão | units.create, units.edit, units.access-denied | ebec60e0 remonta dois builders na revisão de autorização; 09f3885b corrige expectativas do gate indisponível. Arquivo final 6 P inclui os 2 remount, sem somar. | Criação/edição persistida, 15 nomes RPC ausentes e contrato nominal. |
| Turmas / criar-editar / salvar | groups.create, groups.edit | 2e563e8a resultado agregado sem cinco sucessos fictícios (3 P), 583bfd0d recovery Error (1 P). | Concluir vínculos e atomicidade do aggregate; integração de reserva não entregue. |
| Atividades / criar / rascunho | activities.create, activities.location | 233+b736+86+59: tentativa estável, retry pós-aggregate/About, proteção do local selecionado e saída da rota CREATE após sucesso; integrado até839570cd7. | Edit/publish e reserva atômica; criação completa não certificada pelo callback isolado. |
| Atividades / backend / concorrência | activities.create, activities.edit | D00 Clock57SQL: TAP46 P0F e 3 cenários causais P, incluindo revogação; r26 confirmou cleanupzero. | Não certifica toda criação/edição Activities nem reserva integrada. |
| Avaliações / configuração / salvar | activities.assessment | 5d77b506 recovery Error, 4 P; integrado1c09cb7a. | Não certifica assessments.entry/gradebook/close/reopen/detail, que não receberam prova integral. |
| Instituição-Unidade / Locais / catálogo-detalhe | institutions.locations-map, units.locations-map, units.copy-institution-location, locations.list, locations.create-edit, locations.detail-links | 1345af29f quatro rotas owner-scoped + parâmetros app/main + links de formulário; 7 casos únicos com prova incremental. Granularidade capability/footer7d68+9131 e guardas modal7777+192+b5a+42ad. | Catálogo57 aplicado; 165P0F0B no plano local, conforme r31. Mídia/vínculos completos e deploy remoto continuam pendentes. |
| Locais / mapa-fotos / detalhe | locations.create-edit, locations.detail-links | cd03b9e30 seção de mapas; 80f28824 identifica prévia ilustrativa e indisponibilidade de mídia real. | Binding de location-map/photo no gateway/R2 privado compartilhado, conforme e92f4220. |
| Locais / horário semanal | locations.schedule | 3b4f982a seletor administrativo, 19 P e gate visual P. | Janela semanal não equivale a reserva datada. |
| Locais / reservas datadas | locations.schedule, groups.location, activities.location | Domínio3e97048a (13 P), DTO753fbd33 (21 P), gateway34d2 (7 P), painel4ac+9cad+d2f (16 casos únicos com provas incrementais; sucessor r30 publicado para revisão). Motor7dae/TAP49/perfil64 preparados com correção r24. | SQL64 aplicado, 49TAP e 2 causais PASS na base integrada535b, cleanupzero. Composição dos consumidores e atomicidade com seus saves ainda abertas. |

## Testes e métricas

P/F/B/S/U referem-se a casos do plano declarado, não à porcentagem de produto.
Resultados locais Flutter/Dart e Pester têm seus SHAs e lotes no handoff; não
somar reruns locais e integrados. O histórico Activity40P6F foi superado pelo
Clock46P0F, não representa seis falhas atuais. Catálogo atual: 165 casos planejados, 165P0F0B, combinando 56 casos
focais revalidados e 109 casos dos cinco arquivos anteriores preservados.
As duas falhas de overload TAP e o aborto de fixture foram resolvidos. Motor: 49 casos pgTAP P e dois cenários causais P no segundo replay
integrado, sem falhas ou bloqueios restantes nesse plano. Sucessor35b
resolveu somente o grant do helper pg_temp; sem ampliar grants produtivos.
Pester do perfil6P é prova estática
revalidada após sucessor r24 e pins do pai21b0, sem somar seis casos anteriores.

Lotes SQL atuais, sem somar execucoes repetidas:

| Plano | P | F | B | S | U | Executados / plano |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Catalogo local | 165 | 0 | 0 | 0 | 0 | 165 / 165 |
| Atividades Clock pgTAP | 46 | 0 | 0 | 0 | 0 | 46 / 46 |
| Atividades concorrencia | 3 | 0 | 0 | 0 | 0 | 3 / 3 |
| Reservas pgTAP, resultado r35 | 49 | 0 | 0 | 0 | 0 | 49 / 49 |
| Reservas concorrencia | 2 | 0 | 0 | 0 | 0 | 2 / 2 |

Base D02 selecionada em escopo.json canônico: 49 IDs, 42 MVP E2E, 7 adiados.
Promoção integral desta frente: FE0/49, BE0/49, E2E0/42. Os sete IDs de
importação/exportação adiados continuam fora de implementação real. Nenhum
deploy remoto, aceite de produção ou percentual global recalculado por D02.

Geral conhecido, fonte D00 de 15:58 BRT: FE7/230, BE0/223 e E2E0/198.
Nao foi recalculado nem revalidado por D02; nao substituir pelos denominadores
do nosso recorte nem tratar numero de testes como avanco de produto.

## Dependências e continuidade

D00 mantém SQL serializado, wrappers e integração central; r26 liberou a fixture corrigida21b0 e r28 concedeu a preparação do harness
causal exclusivo, publicado em037516922 com 7PesterP e revisão independente.
O formatador de claims foi corrigido pelo D00 emd350, recebido como5da
com8PesterP (um caso executa a função real). Dois cenários causais P no
segundo replay; hook46d integrado pelo D00, sem execução paralela D02. Mídia segue dependência L01/D00,
sem catálogo paralelo. Motor/perfil corrigidos em7dae têm64DDL aplicados,49TAP e2causaisP;
a prova ponta a ponta no app e em produção continua aberta.
Não converter limites defensivos/DST/janela semanal em decisão de produto.

Nenhum SQL/container/app server próprio ativo nesta apuração. Recursos de
outras frentes não foram encerrados. Sem agendamentos criados. Filhos concluíram as subtarefas e liberaram
recursos; a parada final da frente deve ser registrada até17:15.
Gate de memória: nenhuma regra durável aprovada foi alterada; não houve nova
projeção artificial de conhecimento.

## Próximo passo e critério de parada

O próximo gate concreto é a revisão/integração de d2f8ecce0 pelo D00,
fechando as retenções conhecidas do painel r30. Isso não injeta o painel nem amplia
contratos de Group/Activity. Readers atuais não fornecem binding canônico
suficiente, e save+reserva exige transação backend única.

Reporte do corte emitido. Somente correções concretas da consolidação
até 17:15. Sem retomada noturna ou no dia seguinte.
Todos os filhos terminaram suas subtarefas e liberaram arquivos/runners
nesta apuração; podem receber apenas causas concretas ainda dentro do corte.

Atualização D00 r36: painel 4ac/9cad/d2f integrado como
2252d508/c8edcd3f/c1b2a076, com retenções r30 fechadas. Continua sem
consumidor real. Próxima integração concreta: cd03b9e30 (seção de Locais nos
formulários), 1345af29f (quatro rotas e composição) e 42ad0467 (segunda
ativação da cópia), ainda sem equivalentes em dev na apuração de 16:28.
Estimativa restante não fechada: depende de conflitos reais da base central
e de contratos nominais de bindings, mídia e pacote remoto.
