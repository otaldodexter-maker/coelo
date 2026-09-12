---
source: R08 G6 implementation; focused Flutter tests in the authorized global slot
status: local-green
generated_at: 2026-09-12
---

# Verificacao Flutter focal

Janela concedida pelo C0: ate 11:46 BRT, concorrencia 1. O slot foi liberado
imediatamente apos a execucao.

## Execucao inicial

Arquivos:

- `circular_composer_controller_test.dart`
- `superadmin_circular_pages_test.dart`
- `principal_circular_reader_test.dart`
- `production_circular_attachments_test.dart`
- `circular_routes_test.dart`

Resultado: 66 passaram e 1 falhou. A falha era apenas da expectativa nova de
reordenacao: o controlador insere o primeiro bloco de midia depois do primeiro
texto, portanto o deslocamento correto para chegar entre pergunta e segundo
texto e `+1`. Leitor, anexos e rotas passaram nessa execucao.

## Correcao e reexecucao

O teste de reordenacao foi corrigido e o chip do preset passou a ser trazido
para a area visivel antes do toque. Reexecucao dos dois arquivos afetados:
43/43 PASS, exit code 0. Combinando a reexecucao com os tres arquivos que ja
haviam passado, o recorte atual fica em 67 testes verdes e zero falhas abertas.

Analise estatica dos dois testes apos a correcao: `No issues found!`.

## Recertificacao dos multiplos blocos de midia

Apos o ajuste para que cada upload crie um bloco proprio na ancora escolhida,
foram recertificados, com concorrencia 1:

- controlador: 20/20 PASS;
- compositor produtivo: 23/23 PASS;
- leitor do Principal: 8/8 PASS;
- anexos produtivos: 7/7 PASS.

Total final do delta multimidia: 58/58 PASS. A primeira passagem revelou duas
falhas apenas no harness: o botao de envio do leitor precisava ser trazido para
a area visivel e o teste de quota ainda esperava `OutlinedButton`, embora o
componente vigente seja `TextButton`. Corrigidos os testes, os lotes focais
passaram sem falha aberta.

## Estados A+

Foram regravados exclusivamente os tres estados autorizados:

- `circular_composer_light_375.png`;
- `circular_composer_light_375_text_200.png`;
- `circular_composer_light_1440_text_200.png`.

A inspecao visual confirmou a ordem `texto -> midia -> pergunta -> texto`, o
rodape fixo sem overflow e o conteudo rolavel em 200%. Nenhum dos seis R web
`{light,dark}_{768,1024,1440}` foi alterado. Analise estatica final dos tres
arquivos de teste: `No issues found!`.

Esta e prova local. Nao promove E2E nem substitui a prova de
`circulars.attach` pela UI no runtime 3014.
