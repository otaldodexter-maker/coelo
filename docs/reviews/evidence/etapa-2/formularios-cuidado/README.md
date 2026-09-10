---
fonte: rodada noturna Etapa 2, grupo formularios-cuidado
status: indice de leitura
data: 2026-09-10
---

# Por onde comecar

Sao quarenta documentos nesta pasta e a maioria e prova pontual de uma correcao
especifica, escrita no dia em que a correcao foi feita. Quem chega aqui sem
indice enfrenta uma parede de nomes de arquivo, entao esta pagina diz o que ler
conforme o que se quer saber.

## Se voce quer o estado do recorte

**`2026-09-09-round-handoff.md`** — comece por ele. O cabecalho traz o estado
final medido, e o corpo descreve a rodada. Passagens superadas estao marcadas no
ponto onde o leitor as encontra, com o numero original preservado.

Numero valido em 2026-09-10: **1081 PASS / 3 SKIP / 14 FAIL** no recorte
corrigido, sobre a base integrada `3fb200dab`. Doze das catorze sao deste grupo
e **todas sao comparacao de golden**; as duas restantes tem dono fora daqui.

## Se voce vai decidir alguma coisa

**`2026-09-10-regras-de-publico-perdidas.md`** — a pergunta sobre quem recebe um
formulario quando a aplicacao tem varias regras de publico. Levantada como
pergunta e nao como achado, de proposito: a correcao aparentemente obvia escolhe
um comportamento de produto sem que ninguem tenha escolhido.

As outras duas perguntas ao Owner estao no JSON do grupo, em
`docs/reviews/etapa-2-operacao/comunicacao/formularios-cuidado.json`: o autosave
do editor, construido e inalcancavel, e de onde vem uma definicao com limites de
selecao se nenhum autor os define pela interface.

## Se voce vai mexer nos goldens

**`2026-09-10-triagem-goldens.md`** — as falhas triadas imagem a imagem, com a
causa nomeada por commit. Contem o achado que inverte o risco do rebaseline:
**dois goldens protegem hoje o estado errado**, e quem lesse o vermelho como
defeito desfaria uma mudanca correta ou apagaria uma acao.

**`2026-09-09-golden-divergence-measurement.md`** — a medicao de dispersao e o
gradiente de largura que sustentam a triagem.

## Se voce vai auditar, medir ou revisar

**`2026-09-10-metodo-e-autocorrecao.md`** — o registro de metodo. As tres
perguntas que acharam todos os defeitos, as hipoteses desfeitas por medicao, os
erros proprios e o que cada um ensinou, a bateria de mutacao com as tres formas
de um "nao pegou" enganar, e o padrao de camada pronta sem superficie.

**`ferramentas/`** — as tres verificacoes em forma executavel, com as armadilhas
ja pagas evitadas no codigo e nao apenas descritas.

## O resto

Os documentos de `2026-09-07` e `2026-09-08` sao provas pontuais de correcoes
daquelas datas — contexto de editor, isolamento de resposta, pacotes de autoria,
round trips de ramificacao, medicao. Sao uteis quando se investiga uma correcao
especifica; nao sao leitura de entrada.

Uma ressalva que vale para todos eles: sao datados e descrevem o estado de
quando foram escritos. Numeros ali nao foram atualizados, exceto onde ha marca
explicita de superacao.
