---
fonte: rodada noturna Etapa 2, grupo formularios-cuidado
status: ferramentas de verificacao, reproduziveis
data: 2026-09-10
---

# Tres verificacoes que renderam, em forma executavel

Os documentos irmaos descrevem estes metodos. Aqui eles estao em forma que se
roda, porque metodo descrito e metodo que ninguem repete.

Todos assumem execucao a partir da raiz da worktree e tem caminhos absolutos no
topo, que precisam ser ajustados para outra maquina ou outro grupo.

## `verificar-citacoes.py`

Testa se os hashes e caminhos citados nas evidencias do grupo existem — **a
partir da raiz do repositorio e por tipo de objeto**, nunca por nome de arquivo.

A pergunta que ele responde nao e "o comando acusou", e *o leitor copiando isto
chega ao objeto?*.

Duas armadilhas ja pagas estao evitadas no codigo, e as duas erram em direcoes
opostas:

- `git cat-file -e <sha>^{commit}` com shell no Windows **come o circunflexo** e
  reprova TODO objeto, inclusive o SHA da base. Um resultado que reprova tudo
  merece a mesma desconfianca que um que aprova tudo.
- exigir tipo `commit` reprova **blobs**, que sao citacoes legitimas de objeto de
  arquivo. Rigor que reprova o correto nao e rigor.

## `dependencias-nao-fornecidas.py`

Para cada pagina publica do recorte, lista os parametros de construtor que
**nenhum arquivo de `lib/` fornece**. Foi assim que apareceu uma funcionalidade
inteira construida, testada e inalcancavel.

A restricao a paginas publicas e essencial: aplicado a todos os parametros o
script devolve ruido, porque componente interno e construido dentro do proprio
arquivo e "ninguem de fora fornece" e o estado normal dele. Com a restricao, o
recorte inteiro devolveu duas paginas.

## `auditar-campos-de-estado.py`

Reconfere cada campo de ESTADO do JSON do grupo contra medicao feita na hora:
HEAD, divergencia com o remoto, integracao de cada SHA, residual, numeros
superados sobrevivendo sem marca, arvore e stash.

A pergunta que funciona nao e "isto esta correto?", e **"quando isto foi medido,
e o que mudou desde entao?"**. Campos de estado apodrecem por acao de terceiros,
sem ninguem tocar no arquivo — por isso reler o campo nao acha o problema: o
campo nao mudou, o mundo mudou.

Na ultima execucao ele achou cinco campos podres num arquivo que eu vinha
mantendo com cuidado, e nenhum campo de conteudo.

## O que nao esta aqui

A bateria de mutacao nao virou script publicavel porque cada mutacao depende do
codigo que se quer testar; automatiza-la sem cuidado produz mutantes
equivalentes, que passam sem que haja lacuna. O procedimento esta descrito em
`../2026-09-10-metodo-e-autocorrecao.md`, junto das **tres formas de um "nao
pegou" enganar** — mira errada, lacuna real e estado inalcancavel.
