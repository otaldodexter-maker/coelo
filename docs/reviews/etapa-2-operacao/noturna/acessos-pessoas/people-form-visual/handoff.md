---
source: "coordenacao r12 GOLDEN-REBASELINE-CRITERIO; censo integrado; historico Git"
status: "local-green; nenhuma certificacao FE/BE/E2E"
generated_at: "2026-09-09"
---

# Pessoas: referencias nominais do formulario

`apps/superadmin -> Acessos -> Pessoas -> criar375 claro / editar1440 escuro -> people.create, people.edit`.
Base f4ac658fb sobre d784462c1. O censo identificou o teste vermelho; a autorizacao de reconciliar vem do criterio nominal do coordenador, aplicado com causas e inspecao de cada render antes da regeneracao.

Somente duas referencias alteradas:

- `apps/superadmin/test/goldens/people/person_form_create_light_375.png`
- `apps/superadmin/test/goldens/people/person_form_edit_dark_1440.png`

As duas referencias antigas e os dois renders atuais foram abertos antes de executar `--update-goldens`. Os pares `*-before.png` e `*-inspected.png` preservam essa revisao. Os arquivos regenerados sao byte-identicos aos renders inspecionados, conforme manifest.json. Nenhum Dart, widget compartilhado, router, main ou contrato mudou neste lote.

| Diferenca observada | Causa integrada especifica |
| --- | --- |
| Marca Coelo com chevron e altura64 no mobile | d9232a94d |
| Footer compacto dentro da rolagem, fora do viewport inicial; desktop continua fixo | d4374e399b5b02c4d03fd02df7b6dd290e289d09, keep compact form actions reachable |
| Edicao hidrata os nomes sinteticos da pessoa ao trocar original no mesmo State | 0cfec240e4, didUpdateWidget reinicializa viewmodel/controllers |
| Referencia aproximada do municipio abaixo do endereco | 7000ff9f8a3039c28aba31a2b98d053bdf7aa260 |
| Launcher ausente quando nao existe callback | 91d1ffbff3 |
| People/Safety sem setas filhas, Usuarios internos normal e Modelos unificado | d27c307fc2, d019c109a, 320a6f09f |

As referencias antigas vieram de f546561d4. Os commits causais sao ancestrais de d784462c1; nao foi atribuida causa a alteracoes que nao afetam estes estados iniciais. A edicao escura manteve geometria/cores observaveis; suas diferencas foram dados corretamente hidratados, mapa e navegacao ja integrados. Nao se autorizou deriva escura generica.

## Prova focal

`person_golden_test.dart --plain-name 'matches critical create mobile and edit desktop forms'`: RED1F, depois comparador sem update1P/0F. Criacao diferia18.12%; edicao1.26% (16308pixels). RED/update/rerun contam como um unico caso, nao tres.

O footer mobile passou a aparecer apenas apos rolagem; por essa preocupacao concreta foi executado o teste existente `person_form_page_test.dart --plain-name 'create form has three responsive steps and no sensitive fields'`:1P/0F. Ele preenche nomes, usa ensureVisible no continuar, toca e verifica a proxima etapa. A prova confirma alcance do fluxo compacto com a composicao atual. Nao foram repetidos diretorio, lote inteiro do formulario ou texto200%.

Resultado unico deste lote:2P/0F/0S/0U. Logs red.txt, update.txt, green.txt e reachability.txt em UTF8. Avisos RTK de hook ausente sao stderr do wrapper; os resultados Flutter estao registrados no fim dos logs. O comparador informa All tests passed; a prova funcional encerrou com exit0.

As acoes continuam pending-verification: persistencia/recarga e identity repository internos permanecem nos gates de residuals.md e composicao-produtiva.md. Nenhuma escrita habilitada, nenhum envio ou mutacao remota. Memoria: nenhuma decisao nova de produto; apenas referencias reconciliadas contra fontes ja aprovadas.
