---
title: "Etapa 2 — diagnóstico de entrega e correção das métricas"
source: "Pedido do Owner de 2026-09-09; AGENTS.md; snapshot do dev local; fechamento R01 na worktree e2-c00; manifestos de anexos citados"
status: "diagnóstico corrigido após comparação de worktrees — não certifica o app"
generated_at: "2026-09-09"
---

# Entrega da Etapa 2

> Atualização posterior: checkout e regras consolidados na branch Git dev;
> worktrees R01 retiradas de operação. Ver [recibo da consolidação](2026-09-09-consolidacao-git.md).
> Os estados de sincronização local descritos abaixo são históricos.

**Correção de fonte em 09/09:** a primeira versão deste diagnóstico usou somente
o `dev` local (`84985b54`). Isso não descrevia toda a rodada atual. A worktree
`e2-c00` estava em `ed37c04d`, com 235 commits alcançáveis que não estavam nesse
`dev` local. Essa contagem não mede ações entregues nem implica código perdido.
O fechamento registra push da consolidação em `origin/dev`; o checkout local
original foi preservado por conter mudanças não integradas. Não confundir
`dev` local, branch integrada e ponta remota.

A fonte mais recente inspecionada é o
[fechamento R01](C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/reports/R01-fechamento-20260909.md),
com complemento às 08:57:29 de 09/09. Ele registra:

- sete handoffs finais recebidos e preservados, com código integrado seletivamente;
- FE certificado 2/219 (0,91%), somente import/export de Perfil honestamente
  indisponíveis; FE ativo 0/194, BE 0/212 e E2E ativo 0/187;
- 198/219 FE e 63/212 BE com algum critério examinado, inclusive falhas/análise
  estática: esses percentuais **não medem implementação pronta nem testes aprovados**;
- lote integrado 288/288 aprovado; lote C07 em outra base com 144/169 aprovados
  (85,21%) e 25/169 falhos (14,79%). São campanhas diferentes, não somáveis.
  A revalidação conjunta ficou pendente porque C00 não materializou a base na
  worktree C07. Não tratar as 25 falhas antigas como resultado da base integrada;
- produção/deploy: nenhum. Rodada encerrada parcialmente; não retomar as
  conversas antigas. O contexto preparado para a próxima rodada permanece em
  [R02-contexto-consolidado](C:/Users/adrie/Documents/Coelo/docs/reviews/etapa-2-operacao/next-round/R02-contexto-consolidado.md).

O erro desta análise inicial foi usar a fonte desatualizada como retrato geral.
Também se confirmou que alterações das três skills no diretório principal não
haviam chegado às nove worktrees adicionais. As referências visuais, por outro
lado, estavam preservadas na base integrada. Repetir testes em bases diferentes
sem fechar integração/implantação contribui para atividade sem entrega E2E;
os registros não permitem atribuir a cada causa as três semanas mencionadas.

## Referências enviadas pelo Owner

Conferência material por SHA-256 em `Coelo` e `e2-c00`: **12/12 anexos do
Principal e 15/15 de Estruturas íntegros**, sem faltas nesses conjuntos.

- [Principal: manifesto por tela, incluindo Publicar](evidence/etapa-2/coelo-principal-superadmin/manifest.md).
- [Publicar no Acontece: imagem](evidence/etapa-2/coelo-principal-superadmin/publicar-acontece-responsive-reference.png).
- [Publicar em Momentos: referência final v2](evidence/etapa-2/coelo-principal-superadmin/publicar-momentos-responsive-v2.png).
- [Estruturas: 15 anexos com as correções descritas](evidence/etapa-2/estruturas-superadmin/README.md).
- [Matriz das 32 baselines administrativas aprovadas](../../.agents/skills/coelo-ui/references/approved-superadmin-visual-baselines.md).

Os dois manifestos preservam fonte, tela/finalidade e hashes. As baselines mais
antigas usam regras, código, testes e goldens como referência canônica; não
afirmar que os 32 anexos temporários originais também foram preservados. Esta
conferência não cobre todas as mensagens de todas as conversas nem comprova
implementação de cada correção. As referências da `coelo-ui` agora apontam
diretamente os dois manifestos. Prioridade reafirmada pelo Owner: **corrigir
o que apontou por tela/subtela e completar sua integração**.

## Cloudflare e execução proporcional

O plugin/MCP Cloudflare está disponível nesta sessão. Descoberta de schema de
Workers/R2 e documentação oficial funcionaram; não foi verificado acesso à
conta nem realizada implantação. A skill manager local exigia Bun e scripts
TypeScript inexistentes no pacote; foi corrigida para descoberta de MCP,
Wrangler/scripts reais do projeto e aplicação nominal já autorizada.

Havia ainda uma falha de distribuição: `cloudflare-manager/SKILL.md` estava
ignorado pelo Git e ausente na `e2-c00`. A exceção no `.gitignore` agora inclui
somente esse Markdown; o instalador legado continua fora do pacote versionável.

As três skills e o contrato comum passaram a exigir fonte atual entre worktrees,
reutilização do handoff, referência da correção, testes pelos aceites, motivo
para repetir/ampliar e avanço ao próximo gate após o verde. O checkpoint mostra
falhas resolvidas/novas e aceite alcançado. A estimativa usa o delta inspecionado
e tempo medido comparável, sem extrapolar horas por tela. Estes são ajustes de
instruções, não prova de que as próximas execuções já cumpriram o novo fluxo.

## Estado material das alterações desta manutenção

Foram sincronizados **14 arquivos nominais de instruções/referências** entre
este diretório e a worktree `e2-c00`, com conferência de HEAD e hashes antes da
cópia e igualdade após ela. O [manifesto da sincronização](evidence/2026-09-09-skill-maintenance/instruction-sync.json)
registra cada arquivo e sua origem. São alterações **locais, sem commit/push**;
uma nova worktree criada apenas de uma branch ainda não as herda. Incluir esse
delta na próxima integração autorizada antes de iniciar a nova rodada. As
worktrees dos executores antigos continuam preservadas; nenhuma tarefa foi
retomada e nenhum rastreador central de produto foi alterado por esta cópia.

Verificação final deste delta: quatro entradas de skill válidas, 34 links locais
existentes, 14 pares idênticos, 54 artigos de conhecimento válidos e diff da
integração sem erros de whitespace. As regras duráveis de retomada, correções,
testes e estimativa foram projetadas para `team` a partir de AGENTS.md. Não foi
executada suíte do app nem aplicado recurso remoto nesta manutenção. Esses
checks validam instruções e preservação, não a entrega das telas.

## Recorte deste trabalho

Ajustar as três skills Front-end, Back-end e integrada; explicitar Etapa 2 por
tela/subtela; tornar cálculo e prova de testes verificáveis; diagnosticar o
atraso pelos registros existentes. Ordem: fontes, lacunas, contrato, validação
e painel. Parada: regras coerentes e verificadas, com dados faltantes explícitos.
Apps, migrations, produção, merge e certificação funcional ficaram fora.
Não há base para estimar a entrega total; é preciso medir o delta de uma fatia
completa e as esperas de seus gates. Percentual de ações não se converte em horas.

## Histórico: números do dev local usados na primeira leitura

**Tabela abaixo superada como retrato geral pelo fechamento R01 acima.**
Foi preservada para explicar os números anteriormente comunicados.

| Medida registrada | Resultado | Limite |
|---|---:|---|
| E2E ativo certificado | 0/187 = 0,00% | Certificação registrada do inventário conhecido; não percentual de implementação. |
| E2E incluindo gate formal | 0/190 = 0,00% | Três ações MFA separadas do trabalho ativo pela política vigente. |
| Front-end certificado, todos os escopos | 0/219 = 0,00% | Inclui UI de indisponibilidade e ações apenas cliente. |
| Backend certificado, todos os escopos aplicáveis | 0/212 = 0,00% | Exclui sete ações apenas cliente; inclui adiadas/formais separadas. |
| Testes atuais aprovados/falhos | Não calculável globalmente | Faltam campanha, casos únicos, revisão/ambiente e reconciliação dos resultados. |
| Implementação já feita | Sem percentual atual confiável | Readers, controllers, adapters e provas locais estão preservados. |

Base: inventário gerado em 08/09, inspecionado localmente em 09/09. Os três
rastreadores passaram na verificação estrutural com 219 IDs e 38 famílias.
Nenhuma ação foi promovida. O [painel por tela/subtela](etapa-2-painel-2026-09-09.md)
expõe as 219 linhas sem inventar resultados de testes.

Circulares ainda não tem mapeamento próprio fechado, e o inventário combina
tela/subtela em um rótulo sem menu estruturado para todos os IDs. Portanto, o
denominador é o **inventário conhecido**, não cobertura comprovadamente completa
do app. A [reconciliação de 08/09](evidence/etapa-2/coordenador/reconciliacao-pendencias-2026-09-08.md)
já identifica essa lacuna. Ela não foi preenchida por suposição.

## Histórico: impedimentos encontrados no snapshot local

Os itens abaixo descrevem a reconciliação de 08/09. Antes de executá-los,
reconciliar com as integrações e o residual do fechamento R01; não reaplicar
commits nem reproduzir falhas antigas por esta tabela.

| Impedimento observado | Evidência e consequência | Próxima ação útil |
|---|---|---|
| Camadas avançam sem fechar a mesma ação | A reconciliação preserva provas locais de Usuários internos, Modelos, Atividades e Forms, mas mantém UI/HTTP/reload ou pacote nominal abertos. | Selecionar um action_id, reaproveitar o existente e fechar o primeiro gate real até o retorno à UI. |
| Parte do trabalho não chegou à base integrada | Agenda teve o view revertido por quatro diferenças golden; Forms f84d1dd7 está preservado fora de dev com +101/-1. | Corrigir e validar o delta na base de destino; preservar o restante já integrado. |
| Resultados de testes têm bases incompatíveis | Preflight Forms teve +48/-23 no central e 71/71 com Pester 3.4.0 no autor. Locais usava assertions de script, não casos descobertos por Pester. | Reproduzir com versão e invocação registradas antes de atribuir defeito ou somar resultados. |
| Backend e mídia têm dependências reais | Matrizes mantêm replay nominal, ledger, RLS/grants, runtime HTTP e cleanup; mídia exige gateway e R2 privado da finalidade. | Preparar somente o pacote necessário à fatia, com prova local e evidência revisável; aplicar após autorização nominal vigente. |
| Existem decisões que não podem ser substituídas por código | Perguntas abertas registram reader da própria Conta e conflito Planos 051 versus identidade interna 039. | Formular a decisão concreta com impacto e opções; continuar ações que não dependem dela. |
| A medição mistura progresso, certificação e histórico | A reconciliação rejeitou 104/219 local-green e 3/38 famílias como medição atual; o índice de coordenação ainda expunha números de 01/09. | Manter histórico datado e avanço válido visível, usando a mesma base por camada e subtela. |

As evidências dos quatro primeiros itens estão nas seções “Correções materiais”
da [reconciliação](evidence/etapa-2/coordenador/reconciliacao-pendencias-2026-09-08.md)
e “Pacotes preservados e gates transversais” das matrizes. As decisões estão em
[perguntas abertas](../open-questions.md). Esses registros sustentam os
impedimentos, mas não permitem atribuir quantas horas cada um consumiu.

Também foi encontrada uma falha concreta no controle documental:
`validate-trackers.cjs` fixava totais e resumo zerado e rejeitava qualquer
`verified-e2e`. Isso preservava um snapshot e impediria validar futuras promoções.
Foi corrigido para aceitar avanço com certificação e rejeitar divergência entre
inventário, estados, cabeçalhos e resumo. Não há evidência de que esse script
explique atrasos anteriores à sua criação; ele era um impedimento futuro.

## Mudança de condução nas skills

Invocar uma das três skills para trabalhar no projeto agora assume resolução:
retomar a subtela pendente ou selecionar a próxima ação executável, localizar
a causa, corrigir localmente, testar e atualizar o aceite. A chamada sem recorte
não termina devolvendo uma lista para o Owner escolher obrigatoriamente.
O critério de parada é resolver o recorte ou demonstrar o impedimento após o
trabalho independente; plano/relatório sozinhos não encerram uma correção.
Os prompts de invocação das três skills também foram alinhados a esse modo.
Pedido explícito somente leitura ou de manutenção das skills continua nesse
escopo, e aplicação de produção preserva autorização nominal.

O [contrato vigente](../superpowers/specs/2026-09-01-coelo-review-progress-metrics-design.md)
passa a exigir Etapa 2, app, menu, tela, subtela e IDs; FE/BE/E2E separados;
taxas de aprovação/falha junto da execução do plano; casos bloqueados,
ignorados e não executados; revisão, ambiente, runner e evidência; primeiro
gate aberto, responsável e próxima ação. Reruns não multiplicam casos, e dados
históricos não viram resultados atuais sem análise de compatibilidade.

Na retomada, usar as correções do Owner por tela e o residual do fechamento
mais recente. A indicação anterior de `activities.list` baseada apenas em
97/97 locais de 08/09 não define a próxima prioridade. Medir uma fatia real
completa permite estimar o delta seguinte com base observada.

## Validação e memória

- Validador estrutural na base atual: PASS; 219 IDs, 38 famílias e três matrizes.
- Suíte do validador: 10/10 aprovados, 0 falhos, 0 ignorados; cobre promoção
  futura, outro denominador, certificação ausente, divergência de estados,
  resumo desatualizado e independência FE/BE. São testes da ferramenta documental.
- Exercício independente das skills: a versão anterior exigia inventar uma
  convenção para testes; a atual produziu fórmulas por campanha, agregação por
  IDs únicos, Circulares não mapeada e instrução de certificação. Um exercício
  sintético não certifica testes nem telas do Coelo.
- Revisão do modo resolver: confirmou retomada/correção local sem confirmação
  repetida, continuidade durante bloqueio remoto e manutenção da skill sem
  implementar produto. Duas ambiguidades foram corrigidas: preparação/replay
  local de migration dentro do contrato aprovado e continuidade das ações
  independentes quando o primeiro gate estiver bloqueado.
- Memória durável: regras de recorte e medição projetadas para a audiência
  interna `team`; números temporários permanecem somente neste diagnóstico e
  no painel datado. Nenhum dado de produção foi usado.
- Estrutura das três skills válida. Base de conhecimento: 54 artigos válidos;
  suíte de memória com 12 aprovados, zero falhos e um ignorado porque o host
  não permite criar symlink. Esse caso continua sem prova neste ambiente.
  O diff do recorte passou na verificação de whitespace.
