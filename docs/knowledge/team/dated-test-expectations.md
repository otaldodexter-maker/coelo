---
title: "Dois testes podem afirmar contratos opostos, e o vermelho não diz qual está certo"
knowledge_id: "dated-test-expectations"
source: "docs/reviews/etapa-2-operacao/handoffs/E2-noturna-operacoes-sistema.md"
status: "draft"
generated_at: "2026-09-10"
updated_at: "2026-09-10"
audience: "team"
surfaces: [frontend, documentation, integration]
visibility: "internal"
review_owner: "Coelo Owner"
---

# Dois testes podem afirmar contratos opostos, e o vermelho não diz qual está certo

Quando uma decisão de produto muda, o teste escrito junto com a decisão passa a
afirmar o novo contrato — e um teste mais antigo sobre a mesma superfície pode
continuar afirmando o anterior. A partir daí existe um vermelho permanente que
**não é defeito e não é deriva aleatória**: é uma contradição entre duas
asserções, e a falha sozinha não informa qual das duas vale.

O caso que originou esta regra: uma rota de Formulários foi declarada
fail-closed por um teste de 01/09 e, em 08/09, a decisão mudou para leitura
autorizada, com um teste novo exigindo exatamente uma chamada de backend naquela
rota. Os dois conviveram sete dias. Três leitores independentes — dois agentes e
o dono do recorte de sistema — diagnosticaram defeito de composição, e uma
correção chegou a ser atribuída. Ela teria quebrado a suíte verde e revertido a
decisão de produto.

## Por que o erro é fácil

Três mecanismos se somam, e nenhum é descuido:

**A leitura estática prova o mecanismo e não prova a infração.** Rastrear a
cadeia no código mostra que a chamada acontece, que a exceção é engolida e que o
ramo da interface mudou. Todo passo é verdadeiro. O que não está no código lido é
se aquilo é *permitido* — e isso não mora na página nem na rota, mora numa
decisão registrada em outro arquivo.

**O número medido não tem denominador.** Uma chamada é violação contra um
contrato e conformidade contra o outro. Medir é necessário e não é suficiente:
antes de chamar qualquer número de defeito, é preciso saber qual asserção encoda
a decisão vigente.

**A falha aponta para o lugar errado.** O caso morre na primeira asserção, então
quem lê a mensagem conclui que a invariante inteira quebrou. No mesmo recorte,
outro teste de fronteira falhava por overflow de layout antes de qualquer
asserção ser avaliada, e também parecia defeito de fronteira. Mesmo sintoma
vermelho, causas sem relação.

## O que fazer

Ao encontrar um teste vermelho que afirma uma invariante de segurança ou de
fronteira, antes de corrigir produto:

1. procurar outro teste que fale da mesma rota ou superfície;
2. datar as duas asserções por `git log` do arquivo, não por leitura;
3. identificar qual commit carrega a decisão de produto — a mensagem dele
   normalmente diz, como em "bind normal routes and media lifetime to
   authorization";
4. só então decidir se o vermelho é defeito ou expectativa superada.

Ao corrigir a expectativa superada, **ajustar a asserção é melhor que remover a
rota do teste**: o teste continua afirmando algo sobre aquela rota, e um
comentário com as duas datas dá ao próximo leitor o que faltou a três leitores
desta vez, o que torna muito mais difícil "consertar" de volta em um mês.
Corrigir não é desligar: se a asserção antiga era um literal que hoje seria
falso, substituí-lo por um valor lido antes da ação preserva a força da
verificação em vez de enfraquecê-la.

E o nome do caso faz parte da correção. Um nome que descreve metade do
comportamento como fail-closed, quando metade passou a ler de forma autorizada, é
a primeira coisa que o próximo leitor vê — e foi um nome desatualizado que levou
três pessoas à conclusão errada.

## A variante que o autor não enxerga

O mesmo envelhecimento acontece em registro de bloqueio. Uma linha que diz
"bloqueado por X" é uma hipótese que ninguém testou, e é mais perigosa que um
achado errado, porque parece informação e não pergunta. Nesta rodada, o autor de
uma linha de bloqueio **já sabia a razão correta**, havia corrigido isso em
conversa horas antes, e a linha no próprio registro continuava com a razão
antiga: ela nunca foi relida depois que o conhecimento mudou. Cada linha de
bloqueio deve vir com o teste que a sustenta nomeado, ou marcada explicitamente
como não testada — e quem confere não deve ser quem escreveu.
