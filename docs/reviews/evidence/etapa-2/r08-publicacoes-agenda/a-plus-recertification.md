---
source: R08 G6 A+ follow-up requested by C0
status: local-green-inspected
generated_at: 2026-09-12
---

# Recertificacao A+ do compositor produtivo

## Recorte

Defeito observado pelo C0 em `circular_composer_light_375_text_200.png`:
o rotulo `Texto` quebrava entre `Text` e `o` porque as tres acoes ocupavam a
mesma linha. `_BlockActions` agora mede o rotulo com o `TextScaler` vigente e
usa uma segunda linha de acoes somente quando o conjunto nao cabe.

O teste focal verifica, em 375 px e texto a 200%, que o rotulo permanece um
unico widget com o valor integral e que a linha de acoes fica abaixo dele.

## Imagens protegidas

Hashes antes da recertificacao dos seis R do compositor legado, que nao podem
ser regravados:

| arquivo | git hash-object |
| --- | --- |
| `principal_circulars/.../circular_composer_light_768.png` | `337fb636db13d9e3733ec4e09de9c7182a951f6b` |
| `principal_circulars/.../circular_composer_light_1024.png` | `7aa2084ae7885becd6a2852804eb1793a7a11b90` |
| `principal_circulars/.../circular_composer_light_1440.png` | `a859d49ecf5f5a383823f00913f1ddbed7764836` |
| `principal_circulars/.../circular_composer_dark_768.png` | `2a659de7360a9936ce8b9080adc2ad3a40f4f594` |
| `principal_circulars/.../circular_composer_dark_1024.png` | `dec24993023afc95b9fd37f7056851a706d2b27d` |
| `principal_circulars/.../circular_composer_dark_1440.png` | `0b2aa0113de373d48e371257741127c9c2bdb22d` |

Hash anterior do unico A+ a regravar:
`circulars/.../circular_composer_light_375_text_200.png` =
`01ad18f9f8859ada8dd687fc1b4de320aefac648`.

## Resultado

O lote exclusivo concluiu:

- teste focal do rotulo integral: 1/1 PASS;
- atualizacao nominal somente de `composer A+ light 375 text 200`: 1/1 PASS;
- verificacao do mesmo golden sem `--update-goldens`: 1/1 PASS;
- analyze focal final: `No issues found!`.

A primeira passagem revelou overflow de `Agendamento` em 200% no uso local de
`PublicationRow`; foi corrigido no compositor com titulo e valor em duas linhas
nesse text scale, sem editar o componente compartilhado reservado a G3. Duas
expectativas intermediarias do teste foram calibradas para medir a altura real
de uma unica linha (40 px). Nao restou falha aberta.

O PNG final foi inspecionado: `Texto` aparece inteiro, as acoes ficam na linha
seguinte e nao ha faixa de overflow. Hash final do A+ afetado:
`ffbda86acf2aca53c3661244d0003a4f66a54dc7`.

Os seis hashes R acima permaneceram identicos depois da execucao.
