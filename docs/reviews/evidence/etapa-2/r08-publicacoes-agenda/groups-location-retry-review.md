---
source:
  - commit 0fcd66dc4
  - commit caebaf6f9
  - commit 34aa368c9
  - commit 988038de8
status: reviewed-no-concrete-defect-dynamic-inconclusive
generated_at: 2026-09-12T12:50:36-03:00
---

# Revisao read-only do retry de `groups.location`

Recorte recebido do C0: depois de a criacao atomica retornar recibo confirmado,
uma falha em `saveComposition` nao pode provocar uma segunda criacao; edicoes e
tentativas de mudar unidade/local nao podem fazer a selecao anterior atravessar
escopo.

## Resultado

Nenhum defeito concreto permaneceu na analise estatica. A implementacao retém
`GroupLocationCreateResult` depois da criacao confirmada e usa o mesmo
`groupId` e `managementVersion` no retry. A mudanca de nome invalida apenas o
request de composicao; a tentativa de trocar instituicao, unidade ou local apos
o recibo e bloqueada e exige reabrir o registro.

O primeiro teste publicado nao tentava uma troca real de unidade depois da
falha e usava um `locationId` incoerente no recibo falso. O commit `988038de8`
corrigiu ambos os pontos e agora afirma:

- criacao de local chamada uma unica vez;
- comando original no escopo e local da Unidade B;
- tentativa real de Unidade B para Unidade A bloqueada;
- Unidade B e local B preservados;
- retry com o mesmo `groupId` e `managementVersion` e com o nome editado.

## Limite da prova

O G1 informou que o runner focal percorreu os 28 casos, mas o processo nao
encerrou. O checkpoint `d90041fa9` registra corretamente o resultado como
inconclusivo, apesar da analise estatica verde. Esta revisao nao converte esse
evento em PASS e nao executou Flutter.

Nenhum arquivo do G1 foi alterado por G6.
