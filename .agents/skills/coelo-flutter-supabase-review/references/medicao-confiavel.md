---
title: "Medição confiável: como um número de revisão fica errado sem ninguém errar"
source: "Defeitos de instrumento medidos na rodada noturna E2-NOTURNA-20260909, em seis frentes paralelas mais o coordenador"
status: "measured"
generated_at: "2026-09-10"
---

# Para que serve este arquivo

Toda revisão do Coelo termina em número: quantos testes passam, o que está
íntegro em `dev`, o que ainda falta. Numa única noite, seis frentes e o
coordenador produziram números errados sem que ninguém tivesse errado o
raciocínio. O erro estava no **instrumento**, e em todos os casos ele falhou em
silêncio: nenhum comando devolveu erro de sintaxe, nenhum log ficou vermelho.

Este arquivo não é sobre disciplina. É sobre ferramentas que mentem baixinho, e
sobre o único método que as pega.

## A lei

> Um controle que depende de quem está sendo controlado não é controle.

Ela surgiu do relógio — uma frente falsificou a saída crua do `date` sem
perceber, na mesma mensagem em que propunha colar a saída crua como controle,
porque digitar o número é mais rápido que chamar o comando e o texto fica
idêntico. Mas ela vale para todo instrumento:

> Confira o instrumento contra algo que ele **não** produziu.

O parser de teste foi pego comparando-o com o contador que o próprio relatório
imprime — um número que o parser não calculou. Se tivesse sido conferido contra
outra execução do mesmo parser, o erro teria sido **confirmado**.

E o corolário, que já custou uma noite:

> Uma verificação que nunca passa não está rigorosa, está quebrada. Teste-a
> contra um caso que você SABE que deveria passar, antes de confiar nela.

Todo script de conferência deste repositório deve imprimir, junto do resultado,
um controle positivo que **passa** e um negativo que **recusa**.

## As três armadilhas medidas

### 1. O relatório `expanded` trunca, e o denominador encolhe

`flutter test -r expanded > arquivo` corta o nome do caso na largura do
terminal. Um parser sobre esse arquivo reconstrói casos distintos do mesmo
arquivo cujo nome compartilha o prefixo truncado como **um só**.

Medido: contador oficial da corrida `+6390 ~14 -144`; a reconstrução deu
**589 passando e 144 falhando**. As falhas batem exato, porque falha imprime um
bloco `[E]` próprio e não colapsa.

É a pior forma de erro possível: **acerta a metade que se confere**. Quem
validar a lista de falhas vai vê-la bater, e a confiança transborda para o
denominador furado.

Correção: `flutter test --file-reporter json:<caminho>`, que emite um evento por
caso com o nome inteiro e o arquivo de origem. Combina com o `expanded` na mesma
corrida.

### 2. `json:C:/...` não gera arquivo nenhum, e não reclama

No Windows, `--file-reporter json:C:/caminho/arquivo.json` faz o parser da flag
cortar no primeiro dois-pontos: o `C` vira o nome do arquivo. A corrida roda
inteira, imprime o resultado normal, devolve o código de saída certo, e o JSON
simplesmente não existe. Custo medido: uma corrida de dezenove minutos perdida.

Correção: caminho **relativo**, a partir do diretório do pacote —
`--file-reporter json:recorte.json`. O arquivo cai dentro do repositório, então
**apague depois**: senão entra artefato de instrumento no residual.

### 3. `git cat-file -e origin/dev:<caminho>` afirma que trabalho sumiu

No Git Bash em Windows, a conversão de caminho do MSYS transforma o argumento e
o dois-pontos vira ponto-e-vírgula. O erro cru:

```
fatal: Not a valid object name origin\dev;.agents\skills\...\arquivo.md
```

Código 128 — indistinguível de "arquivo ausente". O arquivo estava em `dev`.

**Esta é a pior das três**, e a hierarquia importa: as duas primeiras fazem
confiar em *menos* do que se tem; esta faz **agir**. No fechamento de uma
rodada, "este artefato não chegou a dev" dispara republicação, cherry-pick, ou
alguém tentando recuperar o que nunca se perdeu, sobre uma base que já o tem.

**O gatilho é o ponto inicial no caminho**, e isolá-lo custou duas medições
contraditórias. Quatro casos, mesmo shell, mesmo repositório:

| caminho | resultado |
| --- | --- |
| `apps/superadmin/pubspec.yaml` | OK |
| `docs/reviews/inventario-etapa-2.json` | OK |
| `AGENTS.md` | OK |
| `.agents/skills/coelo-knowledge/SKILL.md` | **convertido** |
| `.gitignore` | **convertido** |

`.gitignore` não tem barra alguma, então a barra não é o gatilho; `AGENTS.md`
está na raiz e passa. É o **ponto inicial**, e só ele.

Isso importa porque uma frente mediu com caminhos de aplicativo e não
reproduziu, dezessete vezes seguidas, enquanto outra mediu com um caminho em
`.agents/` e viu falhar sempre. As duas observações estavam certas e eram
incompatíveis só na aparência. Causa que não reproduz numa segunda medição vira
lenda técnica; a condição é o que a torna utilizável.

E tem consequência direta neste repositório: as **skills vivem em
`.agents/skills/`**. Qualquer conferência de presença que use `cat-file` com
esses caminhos reporta AUSENTE para artefato que está lá — exatamente a família
de arquivo que uma rodada de revisão entrega.

Correção preferida: `git ls-tree -r --name-only origin/dev | grep -qxF <caminho>`
— não passa caminho como argumento, então não há conversão. `MSYS_NO_PATHCONV=1`
também resolve, mas depende de lembrar de uma variável de ambiente.

### A regra que fecha as três

> Neste shell, argumento que contém `:`, `^` ou `{` chega convertido com
> frequência, e a falha se apresenta como **resultado negativo**, nunca como
> erro de sintaxe. Prefira o comando que não recebe o caminho como argumento.

Vale também para `git cat-file -e <sha>^{commit}`, que quebra pelo mesmo motivo.
Para perguntar se um commit está integrado, use
`git merge-base --is-ancestor <sha> origin/dev`.

## O denominador: três perguntas, não uma

Conferir que os caminhos declarados **existem** só responde a primeira. Rodar
`ls` neles antes de confiar no total continua obrigatório — `flutter test` conta
caminho inexistente como uma falha e o total mente sem barulho —, mas não basta.

1. **Os caminhos existem?** Verificação óbvia.
2. **A lista cobre tudo do domínio nas outras árvores?** Quem organiza teste por
   *feature* perde os de **rota**, **shell**, **menu**, **core/config**,
   **shared** e **outros pacotes do monorepo**, que moram noutra árvore por
   serem de integração.
3. **A lista veio do recorte atribuído ou da lembrança?** Lista escrita de
   memória erra nos **dois sentidos ao mesmo tempo**, e a conferência de
   existência só pega a primeira metade.

O método que funciona é cruzar duas varreduras: por **nome** de arquivo e por
**import** do domínio. Nenhuma sozinha fecha — nome perde arquivo cujo nome não
menciona o domínio; import pega dependência sem ser sujeito. Casar **diretório
de domínio**, nunca menção no texto: casar `feed` pega `feedback`, e casar
`child` pega quase todo teste de widget, porque `child:` é parâmetro de rotina.

Quando a inversão rende, o resultado se confere por aritmética: se o número
antigo mais os casos recuperados dá exatamente o número novo, a varredura
recuperou escopo em vez de inventá-lo.

## Sobreposição: somar dois números certos dá um total errado

Ao declarar mais de um número, declare também o que está contido em quê. Um
lote do recorte que é subconjunto próprio da suíte do app não pode ser somado a
ela. O total inflado é o erro mais difícil de ver, porque parece bom.

A melhor solução medida: rodar a suíte **completa**, que é superconjunto de
tudo, e extrair o número do recorte **da mesma corrida**, por arquivo. Assim o
recorte está contido por construção e não há aritmética de sobreposição — desde
que a corrida use o relatório JSON, pelo defeito 1.

E o denominador da suíte completa é o **monorepo**, não um app. Sete conjuntos
de teste fora de `apps/superadmin` ficaram fora de toda medição da rodada, com
894 casos e duas falhas que ninguém tinha visto.

## Campos que apodrecem sozinhos

Num handoff acumulado ao longo de uma rodada, o apodrecimento atinge campos de
**estado** e nenhum campo de **conteúdo**. Escopo, critérios fechados,
evidências e perguntas abertas descrevem o que foi feito e não mudam. Número,
SHA e pendência descrevem como as coisas estão, e mudam sem ninguém tocar no
arquivo.

Medido: cinco campos podres em setenta e seis, num arquivo reescrito trinta e
oito vezes na mesma noite. Um deles descrevia como aberto um problema já
corrigido — a mesma classe de defeito encontrada no relatório do Owner horas
antes.

Duas consequências práticas:

- Todo campo que carrega número, SHA ou pendência carrega **também a hora em que
  foi medido**. Sem carimbo não dá para saber se envelheceu, e um número sem
  data ao lado de números com data é lido como atual.
- Na revisão, a pergunta que funciona não é "isto está correto?", e sim
  **"quando isto foi medido, e o que mudou desde então?"**. Nenhum dos cinco
  campos parecia errado na leitura.

## Um número assustador que não é

`git diff origin/dev <branch>` devolvendo centenas de arquivos parece uma branch
carregando meio app. Mede o contrário: `dev` **menos** branch, tudo que a branch
não tem por estar atrás. Num caso medido foram 452 arquivos e 518 commits de
atraso, e a branch não carregava conteúdo algum — o commit era **vazio**, porque
a correção já tinha entrado por outro caminho.

Antes de tratar "fora de dev" como trabalho perdido, pergunte se há trabalho
ali: `git diff --numstat <c>^ <c>` sem nenhuma linha de saída é commit vazio.

A rodada catalogou muitos números que parecem bons e não são. Este é o inverso:
um número que parece assustador e não é. Quem se assusta apaga a decisão certa
por medo.

## Conferência que só vale antes da ação tem de acontecer antes da ação

Uma verificação encomendada para o fechamento, cujo propósito é decidir se algo
pode ser apagado, não pode ser feita depois do apagamento. Antecipe-a assim que
tiver os insumos.
