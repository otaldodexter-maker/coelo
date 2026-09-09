---
source: "AGENTS.md; correção da auditoria das skills autorizada pelo Owner em 2026-09-08"
status: "active"
generated_at: "2026-09-09"
---

# Recorte, leitura e evidência de revisão

Aplicar a profundidade necessária ao pedido, preservando as exigências de
segurança e os critérios de conclusão. A escolha do modelo não altera gates.

As skills orientam o agente ao trabalhar no projeto e na entrega do app real;
não são componentes executados pelo aplicativo. A branch Git `dev` é a base de
versionamento atual, não um ambiente de testes nem um limite de uso das skills.
As mesmas regras se aplicam à implantação/verificação remota no escopo autorizado.
Todo remoto Supabase/Cloudflare Coelo continua sendo produção.

## Entrada

Primeiro localizar a base e o checkpoint corretos, conforme a retomada abaixo.
Antes de editar, registrar brevemente objetivo, apps/ações, pendências conhecidas,
incluído/fora, ordem, parada e evidências esperadas. Estimar após inventariar;
se não houver base, declarar a incerteza. Não usar faixas fixas como promessa.
Escopo e autorizações já dados pelo usuário dispensam repetição de perguntas.
Perguntar somente quando a ambiguidade material impedir uma decisão segura;
continuar trabalho independente. Não perguntar tempo como requisito de entrada.

| Pedido | Leitura e entrega |
| --- | --- |
| Explicação ou skill/documentação | Fontes canônicas e trechos necessários; rastreador se a explicação depender de estado/progresso. Não inaugurar auditoria de app ou produção. |
| Correção localizada | Cabeçalho, regras de estado e linhas das ações no rastreador da camada, com dependências e evidências. Entregar a correção verificada; sem percentual do backlog inteiro por inferência. |
| Auditoria ampla ou conclusão de camada | Ler integralmente o rastreador da camada, inventariar IDs e reconciliar evidências. Ler as fontes apontadas conforme risco. |
| Alteração ou certificação ponta a ponta | Coordenar as camadas afetadas. Para conclusão ampla, ler os três rastreadores integralmente; para ação específica, cruzar os mesmos IDs e seus gates. |

Ler cada skill/referência uma vez e reutilizar o contexto, salvo mudança do arquivo.
Frontend e Backend chamam integração apenas quando o contrato atravessa as camadas;
integração coordena essas autoridades sem reiniciar dependências em ciclo.
Mencionar Auth, Supabase ou Cloudflare não significa alterar essas camadas.

## Retomada entre conversas e worktrees

- Conferir `git worktree list`, branch/HEAD e mudanças locais. O diretório
  principal e seu `dev` local não são automaticamente a base mais recente.
  Localizar o protocolo da rodada, fechamento mais recente e handoff atribuído;
  conferir data, revisão e SHA. O nome `current-task-handoff.md` sozinho não
  comprova atualidade. Se a fonte vive noutra worktree, lê-la nessa origem.
- Reutilizar o handoff existente: tela/subtela, correção solicitada, action_ids,
  referência aprovada, código já integrado, provas válidas, falhas abertas,
  próximo passo e autorizações. Processo de teste ainda ativo inclui sessão e
  comando; consultar seu resultado antes de iniciar outro. Não reler toda a
  conversa nem reconstruir um inventário que já possui fonte preservada.
- Uma rodada encerrada não é retomada automaticamente. Usar seu fechamento
  como contexto para o novo pedido e respeitar ownership vigente. Quando houver
  escritor central, executor registra deltas no próprio handoff; o integrador
  atualiza inventário/matrizes. Esta skill não transfere essa responsabilidade.
- Antes de validar integração, materializar e registrar o SHA conjunto no
  checkout de validação pelo responsável autorizado. Teste numa branch isolada
  não prova o conjunto. Informar separadamente código integrado, push e deploy.
- Mudança de skill numa worktree não se propaga às demais. Conferir versões das
  skills e referências no destino e incluir seu delta na integração autorizada.
  Não copiar todo o checkout nem sobrescrever instruções locais divergentes.

## Fechamento Git e continuidade

Em entrega que inclua integração/publicação, conferir a branch de destino real,
commits do recorte, alterações sem commit, stash e divergência local/remota.
Integrar somente o delta revisado, incluir skills/referências necessárias no
mesmo fluxo e verificar o SHA publicado. Não deixar a regra nova apenas na
worktree do autor. Um checkpoint local continua válido como checkpoint; não o
chamar de entrega integrada quando commit/push ou aplicação ainda faltarem.

Worktrees encerradas são consolidadas ou arquivadas com origem, SHA, motivo e
próximo passo antes da remoção autorizada. Preservar arquivos não rastreados e
evidências ignoradas. WIP retido continua pendência identificada; não fazer
merge que apenas declare ancestralidade, descartar código ou zerar contadores
para aparentar integração. Branch histórica arquivada não é frente ativa.

Usar o checkout consolidado por padrão na retomada. Criar outra worktree somente
quando o trabalho exigir isolamento e registrar destino e responsável pela
integração. Rodada encerrada não exige novas worktrees para editar uma skill.
Apresentar estado Git separado de avanço funcional, com pendências reais.

## Prioridade das correções visuais

Quando o Owner indicar suas referências como escopo, resolver **as correções
registradas por tela/subtela e sua integração**. Abrir o anexo e a descrição
da correção antes de alterar o comportamento; preservar composição aprovada e
mapear cada correção aos aceites/IDs afetados. Não substituir esse trabalho por
redesign ou por uma auditoria genérica. `coelo-ui` aponta baselines e manifestos
dos anexos de Principal/Publicar e Estruturas. Imagem de defeito é evidência do
problema, não modelo aprovado. Anexo preservado não significa correção feita.

## Ciclo de resolução de pendências

Decisão do Owner em 09/09/2026: uma chamada destas skills para trabalhar no
projeto tem modo padrão **resolver**, incluindo correção local e verificação.
Uma solicitação explícita de explicação, auditoria/diagnóstico somente leitura
ou manutenção documental preserva esse limite. A presença do nome da skill
num pedido para editá-la não autoriza implementar o app.

1. **Escolher a pendência:** seguir telas/ações já indicadas. Na chamada sem
   novo recorte, retomar o último checkpoint válido. Se não houver, escolher
   um action_id ativo executável, priorizando a dependência que desbloqueia a
   subtela mais próxima de entrega. Informar Etapa 2, app/tela/subtela, objetivo
   e primeiro gate; não devolver um menu de opções como etapa obrigatória.
   Recorte amplo solicitado continua amplo: uma primeira ação não encerra as
   demais. Itens pós-MVP não entram por conveniência.
2. **Encontrar o delta real:** ler linhas afetadas, código, testes e evidências;
   reproduzir falha ou conferir o aceite faltante. `pending-verification` pede
   reconciliação, não reimplementação automática. Reutilizar a implementação
   aprovada e identificar a causa antes de editar.
3. **Resolver e provar:** corrigir o código/contrato local autorizado, executar
   o teste que cobre a causa e as regressões pertinentes. Se o aceite já está
   atendido, provar e reconciliar seu estado. Após um teste vermelho, corrigir
   e repetir o teste afetado; não encerrar apenas relatando o erro enquanto a
   correção continuar executável no recorte. Documentos, commits, testes de
   ferramenta documental e percentuais não substituem provas do produto.
4. **Tratar bloqueios concretos:** distinguir decisão, dependência técnica,
   ambiente e autorização. Preparar diagnóstico reproduzível, pacote/diff,
   testes locais e recuperação antes de solicitar decisão remota que falte.
   Nomear exatamente o que falta, responsável e próximo comando/ação seguro.
   Continuar trabalho independente; não pedir de novo autorização já válida
   nem usar um bloqueio como motivo para refazer auditoria global.
5. **Encerrar pelo aceite:** FE termina em `verified`; BE em `done`; integrada
   em `verified-e2e`, conforme os gates reais. Se algum gate continuar bloqueado,
   manter o estado intermediário e documentar o resultado obtido. Atualizar
   inventário/matrizes por ID, respeitando o escritor da rodada, e informar o delta: pendência resolvida, evidência,
   testes P/F/B/S/U, primeiro gate ainda aberto e ação seguinte. Não avançar
   contador sem prova nem inventar mudança de código para parecer produtivo.

O critério de parada é o recorte resolvido, um impedimento demonstrado após
concluir o trabalho independente, ou um limite explícito do usuário. Relatório
é o registro da execução; produzir relatório não é um critério de conclusão
de uma tarefa de correção.

## Ferramentas e prova proporcional

Carregar skills técnicas conforme o trabalho: UI para composição/interação,
responsividade quando layout muda, revisão Dart quando código Dart é revisado,
Astro para Site, Supabase/Cloudflare quando usados. Não impor uma pilha completa
para correção textual. Preferir a menor mudança que resolve a causa.

Defeito funcional: reproduzir, escrever teste que falha pela causa, corrigir e
verificar. Mudança documental/visual simples: links, schema, consulta, inspeção
ou golden pertinente podem ser mais adequados; não criar teste de frase para
simular prova de comportamento. Executar os checks obrigatórios do recorte.

Antes do lote, definir os aceites e os testes necessários à correção e às
regressões afetadas. Depois de verdes, seguir para integração/próximo gate.
Repetir ou ampliar somente por mudança relevante, nova falha, evidência
insuficiente identificada ou verificação obrigatória na base integrada; registrar
o motivo. Troca de conversa ou mudança apenas documental não invalida toda a
suíte. Falha de runner/configuração pede diagnóstico da invocação, sem repetir
o mesmo comando inalterado. Não rodar duas cópias do mesmo lote simultaneamente.

Cada lote relata o delta de casos únicos e do aceite: falhas resolvidas/novas,
P/F/B/S/U e gate fechado ou ainda aberto. Exemplo de formato, não resultado real:
`2 falhas anteriores → 0; salvar local comprovado; reload remoto pendente`.
Não somar reruns nem apresentar testes de ferramenta como avanço do app.

Estimativa cobre o delta inspecionado, distinguindo correção, testes necessários,
integração/implantação e espera externa. Usar duração medida de uma fatia
comparável quando existir e recalibrar ao fechar a primeira fatia. Não repetir
estimativa histórica de 100 horas, multiplicar horas fixas por tela ou criar
faixa ampla sem decomposição. Se só a correção local foi estimada, não a chamar
de prazo ponta a ponta; não estimar auditoria global que não foi solicitada.

UI administrativa e Principal têm contratos próprios mesmo no mesmo app.
Ausência de teste não cria decisão de produto; ausência de definição visual
exige proposta antes de oficializar novo padrão. Goldens não se aprovam sozinhos.

## Estados e limites

Para entrega/progresso, aplicar o [contrato comum de métricas da Etapa 2](../../../../docs/superpowers/specs/2026-09-01-coelo-review-progress-metrics-design.md).
O painel nomeia app, menu, tela, subtela e action_id; separa percentuais de
conclusão das taxas de testes e de sua execução. Manutenção destas skills não
executa nem certifica testes do app. O geral conhecido usa snapshot datado;
uma correção localizada não exige nova auditoria global para preencher o painel.

Usar denominadores e evidências atuais do inventário/rastreadores, sem números
fixos nas skills. Separar resultado da tarefa, progresso do recorte e progresso
geral quando este for medido. `pending-verification` não significa código ausente;
`local-green` histórico não significa certificado atual. Não refazer por contagem.

Atualizar somente rastreadores afetados no mesmo turno da mudança de estado,
bloqueio ou estimativa. Auditoria de skill não certifica ações do produto. Frontend
`verified`, Backend `done` e `verified-e2e` continuam provas distintas.

Todo recurso remoto Coelo é produção. Permissão para corrigir localmente não
autoriza pacote remoto; manter autorização nominal, testes locais, aplicação
forward-only serializada, recuperação e cleanup. Um bloqueio remoto retém
somente o trabalho dependente. Não exigir commit/push, deploy ou worktree limpa
como condição para relatar uma correção local testada; integração/publicação
recebem declaração e evidências próprias quando fizerem parte do pedido.
