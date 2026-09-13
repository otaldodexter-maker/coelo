---
source: Owner e sete anexos na conversa de 2026-09-13; specs/021-superadmin-daily-routine-prototype.md; specs/038-attendance-responsive-dashboard.md
status: backlog R12; decisões de direção registradas; implementação não iniciada
generated_at: 2026-09-13
---

# R12 — Modelos, rotina e chamada

Registro para discussão e futura R12, expressamente fora da implementação da R11.
Host: apps/superadmin. Família visual: administrativa. Responsável de execução:
C0 da R12, após abertura explícita. Admin e funcionário têm diretriz de contrato,
sem autorizar implementar seus apps agora. Nenhuma prova funcional ou aumento de
percentual resulta deste registro. Anexos 1 a 7 estão na conversa: descrição e
ordem preservadas abaixo; os binários não foram exportados para o repositório.

## Apontamentos e aceites futuros

| ID | Tela/subtela e action_ids existentes | Observado / direção aprovada pelo Owner | Primeiro gate R12 |
|---|---|---|---|
| R12-01 | Acompanhamento > Rotina diária > Modelos; daily-routine.list | Anexo 1: alturas e rodapés desalinhados; um card mostra Arquivar e outro não. Usar o card de modelos de atividades do anexo 2 como referência; alinhar criação e existentes. | Comparar estados, origem, permissões e componente compartilhado; ausência de ação não deve desalinhar o grid. |
| R12-02 | Estrutura > Atividades > Modelos e Rotina diária > Modelos; activities.list, daily-routine.list | Anexo 2: padronizar Duplicar e Arquivar nos dois tipos de modelo; card de atividade é a referência, mas falta Arquivar. | Mapear ações/contrato de arquivo e duplicação, origens imutáveis e capacidades antes de habilitar mutação. Preservar tipo, versão e histórico; não arquivar registros em massa. |
| R12-03 | Estrutura > Atividades > Diretório; activities.list | Anexo 3: abas abaixo dos filtros, nomeadas Modelos de atividade e Atividades. | Revisar composição toolbar/abas/estados e responsividade com o componente canônico. Não inventar novos filtros. |
| R12-04 | Acompanhamento > Rotina diária > Diretório e Assiduidade > Histórico; daily-routine.list, attendance.dashboard | Anexo 4: Modelos de rotina e Rotinas, como em Atividades. Retirar Lançamentos deste diretório. Chamadas lançadas em tela separada Histórico de chamadas, tabela e filtragem simples. | Mapear rota/histórico já existentes e reaproveitar contrato de leitura. Nome interpretado como Histórico de chamadas; não criar action_id nem mudar denominador sem mapeamento aprovado. Não remover o dashboard aprovado por inferência. |
| R12-05 | Acompanhamento > Assiduidade > Nova chamada > Contexto; attendance.create | Anexo 5: tornar Nova chamada visualmente mais claro e distinguir níveis do menu; aplicar a regra aos demais níveis equivalentes. Contexto Turma ou Atividade acima dos campos dependentes. Somente atividades configuradas para chamada são elegíveis. | Desenhar a cascata Contexto → hierarquia autorizada → turma/atividade, preservando instituição/unidade e vínculos reais. Superadmin/Admin selecionam dentro do seu alcance; funcionário vê somente opções permitidas. Servidor revalida tudo. |
| R12-06 | Nova chamada > Contexto / Rotina diária; attendance.create, daily-routine.apply | Anexo 6: eliminar a etapa separada Rotina diária do wizard. Depois da seleção, o Contexto mostra a rotina diária vinculada à turma/atividade, somente leitura. Não permitir trocar rotina ao lançar chamada. | Propor Contexto → Chamada, resolver rotina efetiva e versão no servidor, preservar snapshot. Remoção é da etapa do wizard, não do diretório de gestão Rotina diária. |
| R12-07 | Assiduidade > Chamada > Erro ao salvar; attendance.mark, attendance.correct, attendance.finish | Anexo 7: alerta encostado na borda do contêiner, sem respiro. Mensagem e ação de recuperação precisam do espaçamento padrão. | Comparar com baseline administrativa de erro/rodapé, inclusive mobile e texto ampliado; evitar perda de edição ao recarregar. |
| R12-08 | Assiduidade > Chamada > editar/salvar/sentimento/detalhe; attendance.mark, attendance.correct, attendance.finish, daily-routine.apply | Relato anterior do Owner: salvar falhava, alteração difícil; inserir sentimento depois de um primeiro lançamento sem sentimento não salvava; detalhes de rotina não apareciam. Não conseguiu repetir agora por poucos alunos/turmas. Anexo 7 confirma apenas mensagem de falha, não a causa. | Preparar massa sintética suficiente e rotina com seções/campos realmente vinculada. Reproduzir primeiro salvar, editar, adicionar sentimento posteriormente, campos de rotina, concluir e reload. Investigar payload/versão/repository/erro sanitizado e RLS. Não concluir que o backend é a causa antes da prova. |

## Separação FE / BE / E2E

- FE pendente R12: composição dos cards e ações, ordem e rótulos das abas,
  hierarquia visual do menu, histórico simples, wizard em duas etapas, rotina
  somente leitura no contexto, espaçamento do erro e recuperação sem perda.
- BE a verificar R12: elegibilidade de atividade para chamada, hierarquia,
  capacidades/ownership de duplicar e arquivar, resolução da rotina efetiva,
  snapshots, atualização posterior de sentimento/campos e versionamento. Não
  existe falha backend nova confirmada neste registro.
- E2E a reproduzir R12: rota normal, leitura/duplicação/arquivo autorizados,
  salvar/editar/concluir chamada com e sem sentimento segundo o contrato,
  persistência após reload e negação de outro tenant. Certificados históricos
  não certificam estes novos apontamentos; não apagar o histórico.

## Decisões já dadas e questões ainda abertas

A direção visual do card de atividade, abas abaixo do filtro, nomes das abas,
retirada de Lançamentos da gestão de rotina, histórico em tabela, chamada
restrita a turma/atividade habilitada, contexto anterior aos seletores dependentes,
rotina vinculada sem troca no wizard e espaçamento do alerta foram solicitados
explicitamente pelo Owner. Ainda não há render corrigido aprovado.

1. **Arquivar modelos Coelo:** a spec 021 mantém cinco modelos fornecidos pelo
   Coelo imutáveis e duplicáveis. A padronização visual não resolve se Arquivar
   deve valer para esses modelos e quem pode fazê-lo, nem se arquivamento é
   global ou contextual. Decisão pendente; não conceder permissão por inferência.
2. **Sentimento ausente:** não assumir obrigatoriedade ou opcionalidade nova.
   Conferir contrato vigente; perguntar ao Owner apenas se persistir lacuna.
   Adicionar sentimento posteriormente é caso obrigatório de reprodução.
3. **Sem rotina vinculada:** definir a mensagem/continuidade conforme regra
   canônica; não criar rotina padrão silenciosa nem liberar campo obrigatório.
4. **Histórico:** novo pedido acrescenta tela simples; spec 038 já aprova
   dashboard e últimas chamadas. Preservar dashboard até decisão contrária.
5. **Etapas:** projeção histórica superadmin-attendance-daily-routine ainda
   descreve Contexto → Rotina diária → Chamada. O requisito futuro deste registro
   é Contexto → Chamada; não atualizar ajuda de recurso disponível antes da entrega.

## Handoff e proteção da R11

Na captura, R11-checkpoint.md declara escritor central C0, T0 10:47:39 BRT,
execução em andamento, mesma worktree dev. Inventário, três MDs e entrega-atual.json
já tinham alterações da R11. Este pacote não os sobrescreve nem incorpora WIP alheio.

Deltas por action_id/camada estão em R12-apontamentos-delta.json, ainda NÃO
aplicados. Antes de incorporar, o escritor central deve reler as notas atuais,
acrescentar as notas deste pacote sem substituir avanços R11, preservar certificações
históricas e aplicar por apply-tracker-delta.cjs. Sincronização central permanece
pendência explícita do integrador; não chamar registro isolado de matrizes atualizadas.
R12-owner-items.json fornece compromissos para integrar ao manifesto central.
Atualizar docs/open-questions.md com as questões ainda relevantes acima ao assumir
posse central; não sobrescrever seu conteúdo concorrente.

Não iniciar implementação, SQL, testes pesados, build, runtime ou R12 por este registro.
