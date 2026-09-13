---
source: Owner 2026-09-13 — normal99%, reserva Luna99%, concluir viável R13/Etapa2, manter skills e preparar R14 Claude Opus médio
status: retomada R13 autorizada; substitui cortes antecipados anteriores
generated_at: 2026-09-13
---

# R13 — Retomada explícita no mesmo thread

## Papel do processo e falha da tentativa anterior

**Você é o único executor C0 de produto.** O supervisor Python apenas inicia
e acompanha o SEU processo Codex. `status=running`, heartbeat e eventos
item.started/completed no diretório de controle referem-se a VOCÊ; não são
outro agente entregando produto. `child.json.pid` é seu processo. Não passar
a vez ao supervisor, não monitorar a si mesmo e não encerrar dizendo que
outro escritor continuará. Não há outro escritor trabalhando nesta retomada.

A tentativa387b9bdf leu/monitorou seus próprios eventos e saiu sem mudar código,
checkpoint ou HEAD0c30407c. Não houve avanço de produto, apesar do processo vivo.
Essa tentativa é falha operacional, não aceite nem cobertura de implementação.
Executar trabalho concreto agora; ausência de ação/persistência/teste pertinente
não pode ser substituída por contagem de eventos ou relato de PID ativo.

Primeiro trabalho concreto: retomar o avanço parcial `chat.attach`/R12-52,
inspecionar a referência aprovada e o delta f8c209a17, aproveitar os29 testes
verdes válidos, construir o código atual e provar o ajuste pela rota normal
quando pertinente. Corrigir o primeiro aceite viável ainda faltante sem enviar
mensagens a terceiros. Se surgir bloqueio externo específico, registrar e
implementar o próximo item independente do catálogo; não voltar à monitoração.
Depois continuar os demais gates R13/Etapa2 até o corte autorizado.

O Owner estará ausente e autorizou usar o computador e Chrome para executar o
trabalho e manter esta conversa em andamento. Usar recursos existentes e
supervisor serial; autorização de uso do computador não revoga gates remotos
de segurança nem autoriza enviar mensagens a terceiros. Não deixar a execução
parada por depender de confirmação já dada. Todo bloqueio real deve isolar só
as dependências afetadas e levar à próxima fatia executável.

Aplicar explicitamente as skills locais pedidas: `.agents/skills/rtk/SKILL.md`,
`.agents/skills/coelo-supabase/SKILL.md`,
`.agents/skills/coelo-flutter-review/SKILL.md`,
`.agents/skills/coelo-tutor/SKILL.md`,
`.agents/skills/coelo-flutter-supabase-review/SKILL.md`,
`.agents/skills/coelo-knowledge/SKILL.md` e
`.agents/skills/ponytail/SKILL.md`; coelo-ui permanece autoridade visual.
Reutilizar leituras; Tutor orienta explicações claras, não transforma esta
execução em aula/quiz nem inventa aprendizagem na ausência do Owner.

Preservar tudo que foi feito da R01 à R13: fontes, commits, branches,
backups/ignorados e provas válidas. Nunca reset/clean/merge artificial para
zerar divergência. Atualizar os MDs respectivos por camada/tela e datas; aumentar
percentuais apenas ao fechar aceites com evidência real e denominador explícito.

O Owner reabriu a R13 após o fechamento parcial5b4ac2756. Continuar no thread
`01a09bd2-3ba1-7761-96a5-0ef1c4a33eba`, cuja conversa foi aberta e conferida
na interface do ChatGPT/Codex. Não iniciar R14 nem Etapa3.

A instrução final do Owner é **usar a cota normal até99%, depois passar
automaticamente para reserva Luna**. Substitui o corte histórico96/98% e a
instrução intermediária de esgotar100%. Normal usa gpt-5.6-luna, medium;
reserva usa gpt-reserve associado a gpt-5.6-luna, medium. Não comprar créditos,
usar chave API paga ou resgatar resets. Registrar a leitura real de cada bucket.

Reutilizar correções/provas R12 e R13. Os50 compromissos continuam no catálogo;
chat.attach tem avanço local, não aceite E2E. Priorizar primeiro gate executável,
incluindo build/rota normal do código já entregue quando pertinente. PITR/SMTP
e autorizações remotas bloqueiam somente seus dependentes: **não encerrar a
rodada por um bloqueio isolado enquanto houver trabalho independente viável**.
Não gastar cota com reruns verdes, auditorias repetidas ou atividade artificial.

Medir normal na abertura, após cada fatia/checkpoint e antes de teste/build
caro. Antes de99%, continuar trabalho autorizado; não pedir needs_reserve só
por margem ou por estar em95/96/98%. Em99% (ou bloqueio real de uso anterior),
preservar checkpoint/WIP, concluir comandos em andamento e gravar no NOVO
diretório de controle `continuation.json` com `{"status":"needs_reserve"}`.
O supervisor consulta a cota e só então retoma este mesmo thread em reserva.
Não iniciar outro CLI/supervisor. Se o serviço interromper antes do checkpoint,
o supervisor preserva o checkout e passa o estado ao mesmo thread.

Na reserva, o pedido posterior do Owner substitui também o teto U0+8/95 e
o prazo3h+30min: continuar trabalho útil até99% do bucket gpt-reserve ou
pedido de parada. Deadline epoch0 significa sem corte de relógio nesta retomada.
Registrar progresso a cada fatia; ao se aproximar de97%, concentrar o saldo na
consolidação, pendências, skills, R14 e gates para concluir antes de99%.
Não deixar documentação e push para depois de esgotar o serviço.
Bloqueio isolado não é motivo de parada global. Encerrar antes do corte apenas quando todo trabalho autorizado estiver entregue
ou todos os próximos gates viáveis estiverem concretamente bloqueados; documentar
a lista, não presumir. Nenhuma promessa de gastar saldo sem trabalho útil.

Depois de todo trabalho viável da R13, localizar os primeiros gates ainda
executáveis da Etapa2 e continuar nesta extensão autorizada, registrando o
recorte antes de cada fatia. Não iniciar Etapa3, não ampliar autorização remota
nem reabrir aceites válidos sem regressão. Aplicar as quatro skills pedidas
explicitamente: coelo-backend, coelo-frontend, coelo-frontend-backend e
coelo-knowledge. Atualizar suas referências/estado vigente conforme avanço,
com detalhes e evidências nos rastreadores/catálogos; corrigir instruções
obsoletas, sem converter skills em logs nem declarar funcionalidades não provadas.

Ao fechar, preparar `R14-prompt-unico.md`, `R14-plano-de-rodada.md`,
`R14-pendencias.md` e catálogo correspondente para **Claude, Opus, esforço
médio**, sem disparar R14 automaticamente. Owner informou cerca de12% de
utilização no Claude: é estimativa não verificada, não saldo prometido;
medir o bucket e confirmar o identificador Opus disponível na abertura real.
Handoff inclui checkout/SHA, worktrees/WIP, recursos sintéticos, primeiro gate
por ação/camada, correções já entregues, provas válidas, bloqueios e autorização
remota efetiva. Conferir instruções no checkout que o Claude usará; não instalar
ou consumir Claude para testar preparação.

Checkpoint/commit/push frequentes, inventário e três matrizes sincronizados,
sete métricas, testes únicos P/F/B/S/U, memória e delivery gate continuam
obrigatórios. Não promover screenshot/teste local a E2E. O fechamento anterior
é histórico; registrar a retomada antes de alterar produto e o novo fechamento
ao terminar. Escritor serial e um Chrome QA/um flutter test por vez.

## Preparação verificada

Supervisor atualizado com `arm --resume-thread ID --normal-threshold 99`;
aceita somente o thread da execução anterior terminada, preserva seu contexto e
reinicia em normal. Pedido antecipado de reserva em98% retorna ao normal uma vez;
em99% ou negação de uso real permite a passagem. Um novo processo só inicia
depois do anterior sair. Quinze testes do supervisor PASS; RED reproduziu perda
do thread e troca antecipada antes da correção. Nenhum teste de produto refeito.

Escopo desta preparação é operacional, sem alteração de regra de produto,
permissão, SQL ou Cloudflare. Memória no-op: decisão de orçamento desta retomada
fica nesta fonte, sem criar regra permanente. Captura da janela foi somente
leitura, sem logs de conteúdo/credenciais no repositório.
