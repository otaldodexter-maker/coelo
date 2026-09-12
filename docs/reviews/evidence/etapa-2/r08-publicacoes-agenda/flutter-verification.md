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

Esta e prova local. Nao promove E2E nem substitui a prova de
`circulars.attach` no runtime 3014.
