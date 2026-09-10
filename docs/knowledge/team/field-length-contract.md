---
title: "Limite de tamanho de campo é contrato, e quando falta no cliente o erro chega como queda de rede"
knowledge_id: "field-length-contract"
source: "docs/reviews/etapa-2-operacao/handoffs/E2-noturna-operacoes-sistema.md"
status: "draft"
generated_at: "2026-09-10"
updated_at: "2026-09-10"
audience: "team"
surfaces: [frontend, backend, integration]
visibility: "internal"
review_owner: "Coelo Owner"
---

# Limite de tamanho de campo é contrato, e quando falta no cliente o erro chega como queda de rede

As colunas do Coelo restringem tamanho: título de evento de agenda entre 1 e 240,
local até 500, descrição até 10000; nome de plano entre 1 e 160, descrição de plano
entre 1 e 2000, código até 80, motivo de auditoria entre 1 e 1000. As RPCs
revalidam os mesmos limites e recusam com `22023` ou `check_violation`.

Quando o formulário valida apenas presença, a sequência é esta: o usuário escreve
um texto que lhe parece válido, salva, e o cliente traduz a recusa para a sua
mensagem genérica de indisponibilidade — porque o `catch` que fecha falha de
transporte é o mesmo que recebe a violação de regra. A tela diz "não foi possível,
tente novamente". **O usuário nunca descobre que o problema é o tamanho, e a
mensagem o convida a repetir exatamente o que não pode funcionar.** É regra de
servidor chegando à tela com a aparência de instabilidade de rede.

Nenhum teste acusa, pelo mesmo motivo das outras divergências de contrato: a carga
de teste é escrita à mão, com valores curtos.

## A implementação de referência

Circulares resolve isso do jeito certo e serve de modelo. `CircularLimits` declara
`titleCharacters = 120`, `bodyCharacters = 10000`, `questionCharacters = 240` e
`optionCharacters = 120`, e os campos consomem essas constantes. Do outro lado,
`circular_revisions` restringe título entre 1 e 120, corpo a 10000, enunciado de
pergunta a 240 e rótulo de opção a 120 — e a RPC de rascunho revalida as mesmas
fronteiras. Os três lugares concordam, e existe **um nome** para cada limite em vez
de um número solto repetido em cada campo.

## Como corrigir sem estragar outra coisa

Duas escolhas que parecem detalhe e não são:

**Use `inputFormatters` com `LengthLimitingTextInputFormatter`, não `maxLength`,
quando a tela tiver referência visual pendente.** `maxLength` acrescenta contador e
muda a altura do campo, o que invalida golden de uma tela que talvez esteja
esperando rebaseline nominal — trocar um problema de dado por um problema visual não
é progresso. O formatador impede a digitação além do limite sem alterar o desenho.

**O formatador age apenas na digitação, e isso é vantagem, não limitação.** Um valor
herdado mais longo que o limite, gravado antes de a restrição existir, continua
carregado no formulário sem truncamento silencioso. Truncar dado existente para
agradar a uma validação nova é perda de informação do usuário.

Validação com mensagem explícita é melhor ainda, porque explica em vez de só
impedir — e ela não é opcional, por uma razão que eu mesmo deixei passar ao escrever
a primeira versão deste artigo. As duas afirmações acima se contradizem se lidas
juntas: se o formatador **não** trunca um valor herdado mais longo que o limite, então
esse valor herdado continua sendo enviado no salvamento, e o servidor continua
recusando com a mesma mensagem genérica. O formatador garante que o usuário não
**crie** um texto inválido; não garante que nenhum payload inválido seja montado.

Então o caso residual é nominalmente este: registro antigo, acima do limite, aberto
para edição e salvo sem que o usuário mexa no campo. Para ele, só validação com
mensagem resolve — e ela é a única que consegue dizer "este título tem 310
caracteres e o máximo é 240", que é a informação que falta hoje. As duas medidas se
somam, e a primeira sozinha cobre o caso comum, não todos.

## Como encontrar o resto

Extraia de `packages/coelo_database` toda restrição `char_length(<coluna>)` com
`between` ou `<=`, e compare com os `maxLength` e formatadores do formulário
correspondente. Dois avisos de medição, aprendidos errando:

- a restrição também pode vir de `alter table ... add constraint`, e não só do corpo
  do `create table`. Medir apenas a criação subconta — foi assim que uma varredura
  minha contou 82 colunas onde havia 93;
- o nome da coluna por si não identifica a tela. `description` aparece com 2000,
  4000 e 10000 em tabelas diferentes, e `name` com 120 e 160. Amarrar o limite à
  tabela que aquele formulário escreve é parte da medição, não um detalhe.

Tabela sem restrição de tamanho também é resultado: as tabelas de cardápios não
limitam nenhuma coluna de texto, então ali não há contrato a cumprir — e inventar um
limite no cliente seria regra nova, não correção.

## Número espelhado sem afirmação é número que ninguém vê mudar

Declarar o limite numa constante do cliente resolve metade do problema: dá nome ao
número e tira a duplicação entre campos. A outra metade é que essa constante é uma
**cópia** do que o servidor exige, e cópia silenciosa envelhece. Outra frente mediu
isso por mutação no mesmo dia: baixou um limite espelhado do servidor de 1000 para
999 e **nenhum teste caiu**. O número existia, estava correto, e não havia nada
afirmando que ele correspondia ao servidor.

Então o contrato completo tem três partes, e a terceira é a que costuma faltar:

1. a coluna e a RPC restringem — é a autoridade;
2. o cliente impede a entrada além do limite — é a experiência honesta;
3. **algum teste afirma que o número do cliente é o número da coluna** — é o que
   impede a cópia de derivar sem aviso.

A terceira parte não precisa ser caríssima: ler a restrição do SQL versionado e
comparar com a constante do cliente é o mesmo instrumento usado para os enums, e cabe
num teste que roda em menos de um segundo, sem binding de Flutter. Sem ela, a próxima
migration que afrouxar ou apertar um limite passa por um cliente que continua
acreditando no número antigo — e a primeira notícia disso chega como "não foi
possível, tente novamente".
