---
title: "Triagem de falhas de golden: três assinaturas, três causas"
source: "docs/reviews/evidence/etapa-2/formularios-cuidado/2026-09-09-golden-divergence-measurement.md; medições próprias em apps/superadmin na rodada noturna de 2026-09-09"
status: "active"
generated_at: "2026-09-10"
---

# Triagem de falhas de golden

Uma suíte de golden vermelha não é um diagnóstico. Na rodada noturna de
09/09/2026, três frentes chamaram o próprio conjunto de falhas de "deriva de
golden pré-existente" e as três estavam descrevendo causas diferentes. Nenhuma
delas se resolve regravando a referência sem decisão.

Antes de classificar qualquer falha de golden, medir. Antes de regravar
qualquer golden, ter decisão do Owner — regravar é apagar a evidência.

## Medir antes de abrir imagem

O comando abaixo extrai a magnitude de cada falha. O `tr` que junta as linhas
**não é opcional**: quando o caminho do golden é longo, o Flutter quebra a
mensagem em duas linhas e um `grep` de linha única devolve nada. Numa medição
real isso fez uma suíte com 31 falhas aparecer com zero, que é o pior tipo de
erro de medição porque parece confirmação.

```bash
flutter test <arquivo_golden_test.dart> 2>&1 \
  | tr '\n' ' ' \
  | grep -oE 'Pixel test failed, +[0-9.]+%, +[0-9]+px' \
  | tr -s ' ' | sort -u
```

Ler os dois números por variante: o **percentual** e o **absoluto**. O
percentual sozinho não distingue nada; a relação entre o absoluto e a área é
que separa as causas.

Quando a medição não bastar, decodificar os pares `*_masterImage.png` e
`*_testImage.png` em `failures/` e medir também **dispersão** — percentual de
linhas e de colunas atingidas — e o **gradiente por largura**. A frente
formularios-cuidado escreveu um decodificador de PNG em Python puro para isso
em `docs/reviews/evidence/etapa-2/formularios-cuidado/measure-golden-divergence.py`.

## As três assinaturas

### 1. Renderização global

Absoluto **cresce com a área**; a gravidade **cai conforme a largura cresce**; a
diferença atinge praticamente **toda linha e toda coluna**. Nenhuma mudança de
produto atinge literalmente 100% das linhas e 100% das colunas.

Medido em `access_profile_cards_dark_375` (91,90% dos pixels, 100% das linhas e
100% das colunas), `forms_editor_dark_375`, `forms_directory_dark_375` e
`group_directory_cards_dark_375`.

Não é defeito de produto e não se corrige no código da tela.

### 2. Mudança de conteúdo

Absoluto **quase constante entre larguras**, com percentual variando só porque a
área varia. Um elemento de tamanho fixo entrou ou saiu.

Medido em `principal_profile`: 0,73% a 1,35% em 768, 1024 e 1440, com absoluto
entre 11.128 e 11.708 pixels nas três; e 22,1% em 375, porque no layout compacto
a remoção desloca tudo que vem abaixo. Confirmado por imagem: a referência
aprovada tem um botão "Acompanhar" e seis métricas (Seguidores, Seguindo,
Publicações, Localização, Fundação, Colaboradores) e o código atual tem só
"Mensagem" e três (Publicações, Momentos, Circulares).

Medido também em `principal_happens`, com absoluto entre 2.122 e 2.436 pixels e
percentual de 0,15% a 0,65%. **Percentual baixo engana**: essa suíte parecia
renderização global até o absoluto ser lido.

Aqui o golden vermelho está protegendo alguma coisa. A pergunta ao Owner é
binária: a composição atual é a aprovada? Se sim, regravar é consequência
administrativa. Se não, o código removeu capacidade aprovada e é defeito grave.

### 3. Mudança de geometria

Percentual perto de **100%** com o conteúdo **idêntico**. Cada pixel se desloca
porque o enquadramento mudou.

Medido em `principal_moments`: 99,17% a 100% nas onze variantes. Confirmado por
imagem: a referência renderiza o viewer com letterbox, barras pretas nas
laterais, e o código atual renderiza full-bleed. Mesma foto, mesmos contadores,
mesma legenda.

## Duas armadilhas que custaram tempo real

**Uma suíte pode ter duas causas ao mesmo tempo.** `superadmin_chat_page_golden`
tem dois casos com absoluto constante em 1.849 pixels e quatro entre 12 mil e
39 mil crescendo com a área. Quem tratar essa suíte pelo agregado decide errado
em uma das duas metades.

**Diferença medida fora da base conjunta não autoriza conclusão nenhuma.** Uma
frente estava a ponto de regravar um golden com autorização na mão, foi medir na
base integrada antes e o golden **já passava** — as duas componentes que ela
tinha medido na própria branch desapareceram na integração. O espelho disso é o
`principal_profile`, onde o diff escondia mudança de produto. Nos dois casos a
medição sobre a branch isolada teria levado à ação errada.

## Ordem de trabalho

1. Medir magnitude e absoluto com o comando acima, na **base conjunta**.
2. Classificar pela assinatura antes de abrir qualquer imagem.
3. Abrir imagem só do domínio do próprio recorte; para domínio alheio, entregar
   medição e método, não palpite. Em alguns ambientes a leitura de imagem falha
   por timeout — nesse caso a medição numérica é o que se tem, e ela basta para
   classificar.
4. Nunca regravar golden para fechar vermelho. Registrar a decisão necessária.

## Fio barato para goldens administrativos

O outlier de **837 pixels** aparece idêntico em `agenda_calendar_golden` e em
`activity_golden`. Duas features diferentes com exatamente o mesmo absoluto só
pode ser um componente compartilhado divergindo do mesmo jeito nas duas. Quem
for tratar goldens administrativos começa por aí: um único componente pode
explicar dois arquivos.
