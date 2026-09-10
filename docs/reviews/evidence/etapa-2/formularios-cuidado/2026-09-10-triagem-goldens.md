---
fonte: rodada noturna Etapa 2, grupo formularios-cuidado
status: triagem de goldens vermelhos
data: 2026-09-10
base: b4d0e6af7
---

# Triagem dos goldens vermelhos de Formularios

Oito casos de teste falham no recorte, e eles cobrem **23 imagens**. A imagem e
a unidade util da triagem, nao o caso de teste: um unico caso captura ate oito
larguras e temas.

Metodo: a imagem diz ONDE olhar, o codigo diz O QUE aconteceu. Comparei
elemento a elemento entre a referencia e a captura atual, em vez de olhar o que
acende no diff.

## Resposta curta

**Nenhuma das 23 e regressao de produto, e nenhuma e perda de cobertura.**

Todas se explicam por duas causas reais, ambas de mudancas deliberadas feitas
FORA deste recorte, mais um amplificador que e propriedade do proprio teste.

## Causa 1 — cabecalho compacto do shell mudou de altura

`c4a7feff8`, "fix(superadmin): align compact header and reserve action space",
de 2026-09-08. O cabecalho compacto deixou de ser hamburguer com logo
centralizado e passou a ser logo com trilha "Coelo >". Ele ficou cerca de 16
pixels mais alto.

Isso empurra TODO o conteudo abaixo. Em `forms_directory_light_375` a
referencia e a captura sao identicas elemento por elemento — mesma busca, mesmos
filtros, mesmo cartao de criar, mesma tabela, mesma paginacao — apenas
deslocadas.

Imagens nesta categoria, deslocamento em bloco puro:

| imagem | divergencia |
| --- | --- |
| forms_directory_dark_375 | 27,01% |
| forms_directory_light_375 | 22,24% |
| forms_directory_dark_768 | 20,73% |
| forms_directory_light_768 | 18,61% |
| forms_directory_no_results_light_375_v4_19 | 13,85% |
| forms_directory_empty_light_375_v4_19 | 13,39% |
| form_response_light_375 | 12,78% |
| forms_directory_unauthorized_light_375_200_v4_19 | 9,87% |

## Causa 2 — mudancas deliberadas de produto que ninguem regravou

Tres mudancas reais, nenhuma minha, todas de 2026-09-08.

**O rotulo do painel de ramos.** `c0b20ccd6`, "fix(forms): preserve explicit
no-answer branches", trocou `Se Sim` por `Ramos por resposta`. O painel passou a
mostrar os ramos das DUAS respostas, entao "Se Sim" tinha ficado errado. O
golden `forms_editor_dark_1440_text_200` diverge em 0,16% e a divergencia e
exatamente esse texto: tudo o mais e identico pixel a pixel.

Vale registrar o que esse golden esta fazendo hoje: ele exige o rotulo ANTIGO,
que o produto abandonou de proposito. Vermelho, ele nao protege nada; ele afirma
um comportamento que a equipe removeu.

**O painel de ramos ganhou controles.** O mesmo commit acrescentou o seletor
"Resposta que revela o proximo ramo" e o botao "Adicionar pergunta ao ramo". Sao
elementos novos, e por isso os goldens largos do editor divergem entre 3,7% e
13,2%.

**A barra de acoes saiu da folha fixa e virou rodape embutido.** Na referencia,
"Salvar formulario / Salvar rascunho / Cancelar" era uma folha ancorada que
cobria o conteudo. Na captura atual e um rodape alinhado a direita no fim do
conteudo. Verificado em `forms_editor_light_1440`, onde os tres botoes aparecem
inteiros.

## O amplificador — `ensureVisible` re-rola quando a altura muda

O caso responsivo do editor chama
`tester.ensureVisible(find.byKey(const ValueKey('extra-point')))` antes de
capturar. A rolagem resultante depende da altura do conteudo. Como o painel de
ramos ficou mais alto, a mesma chamada rola mais, e em 375 pixels a lista de
SECOES sai do viewport.

Isso produz o unico achado que parecia grave e nao e, tratado na secao seguinte.
Imagens desta categoria, causa 2 amplificada pela causa 1 e pela rolagem:

| imagem | divergencia |
| --- | --- |
| forms_editor_dark_375 | 43,94% |
| forms_editor_light_375 | 38,99% |
| forms_editor_light_375_text_200 | 28,82% |
| forms_editor_dark_768 | 17,01% |
| forms_editor_light_768 | 14,38% |

## O candidato a perda de cobertura, e por que ele nao e

Em `forms_editor_light_375` a captura atual **nao mostra** a lista de SECOES nem
a barra de acoes. Essa e exatamente a forma da perda de cobertura de
Instituicoes, onde a afordancia continuava no produto e o golden deixara de
protege-la. Fui atras disso especificamente.

Nao e perda de cobertura, por duas razoes independentes:

1. Os dois elementos existem e sao capturados em 1440, na mesma execucao. Nao
   sumiram do produto nem do teste; sairam do viewport porque `ensureVisible`
   rolou mais.
2. As duas afordancias sao exercidas por testes que PASSAM. As provas de autoria
   desta rodada acionam "Salvar rascunho" e "Salvar formulario" pelo caminho
   produtivo, e a navegacao entre secoes tem cobertura propria. Se o golden fosse
   a unica protecao, a perda seria real; ele nao e.

## Uma imagem que muda de categoria

`forms_directory_actions_light_1440`, com 0,72%, e a menor divergencia larga do
recorte, e por isso a mais facil de descartar como ruido. Ela nao e.

O menu de acoes da linha ganhou o item **Duplicar**. A referencia tem seis
itens; a captura tem sete: Editar, Duplicar, Copiar para instituicao, Mover para
instituicao, Agendamentos, Arquivar, Excluir. O deslocamento de uma linha nos
itens seguintes e consequencia, nao causa.

O risco aqui e o oposto do rebaseline: este golden afirma um menu SEM Duplicar.
Quem tentasse fazer o produto voltar a passar no golden apagaria uma acao.

## O chevron, resolvido pelo codigo

A amostragem externa reabriu estes diffs e levantou uma ressalva que a imagem
sozinha nao fecha: um chevron aparece como `v` de um lado e `^` do outro. Pelo
criterio de forma e cor, isso NAO seria deslocamento — seria estado de expansao
diferente, a mesma classe da perda de Instituicoes.

Nao e estado. Sao dois controles diferentes, em posicoes diferentes.

O `v` pertence ao seletor "Resposta que revela o proximo ramo", acrescentado por
`c0b20ccd6`. Ele aparece UMA vez no diff, numa regiao onde a referencia nao
tinha nada, que e a assinatura de elemento novo e nao de elemento movido.

O `^` e o controle de recolher a pergunta. Quem define o estado inicial dele e o
PRODUTO, nao o teste: `_expandedQuestionId` recebe a ultima pergunta da primeira
secao na carga da pagina. O teste nao fornece nem sobrescreve esse estado, entao
nao ha como o `_goldenApp` te-lo mudado. E nas duas capturas a pergunta expandida
e a mesma, "Tem ponto extra?".

Conclusao: elemento novo de um lado, controle inalterado do outro. A ressalva
esta fechada e nao muda a classificacao.

## Contra-exemplo a heuristica de escala

A rodada vinha usando a assinatura do toggle de barra lateral — 837 pixels, ou
0,058% numa tela de 1440 — como referencia de deslocamento, e concluindo que
divergencias de dois digitos indicam conteudo.

Os numeros deste recorte mostram que a heuristica nao se sustenta sozinha.
`forms_directory_light_375` diverge 22,24% e e deslocamento puro, sem UM
elemento diferente. O que muda nao e a natureza da causa, e a densidade: um
empurrao vertical de 16 pixels num viewport de 375 por 900, cheio de linhas de
texto, atinge quase toda linha da tela; o mesmo empurrao em 1440 encontra muito
mais espaco vazio.

Por isso o gradiente de largura e a assinatura confiavel, e nao o valor
absoluto. No editor a mesma causa da 43,94% em 375, 17,01% em 768 e 4,08% em
1024. Percentual alto em tela estreita nao e evidencia de conteudo; percentual
que CAI com a largura e evidencia de deslocamento.

## Consequencia para a decisao do rebaseline

Das 23 imagens, 8 sao deslocamento puro, 5 sao deslocamento amplificado e 10
carregam mudanca de produto real e deliberada. Nenhuma exige correcao de produto
antes de regravar.

Duas delas — o rotulo do painel de ramos e o menu sem Duplicar — estao hoje
protegendo o estado ERRADO. Enquanto seguirem vermelhas sem regravacao, o risco
nao e perder cobertura: e alguem interpretar o vermelho como defeito e desfazer
uma mudanca correta.
