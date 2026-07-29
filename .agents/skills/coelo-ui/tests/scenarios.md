---
source: "docs/superpowers/plans/2026-07-22-coelo-ui-foundation-componentization-catalog.md"
status: "verified"
generated_at: "2026-07-24"
---

# Cenários da skill `coelo-ui`

## Protocolo reproduzível

Cada execução usa um agente de contexto novo, somente leitura, no monorepo
`C:\Users\adrie\Documents\Coelo`. No baseline, a skill ainda não existia. Na
reexecução, o prompt acrescenta:

> Use obrigatoriamente a skill project-local `$coelo-ui` em
> `C:\Users\adrie\Documents\Coelo\.agents\skills\coelo-ui\SKILL.md` e siga-a de
> verdade. Inclua evidência do índice consultado e deixe explícito o que faria,
> o que recusaria e qual aprovação seria necessária.

Prompts completos dos problemas:

1. **Filtro administrativo:** “Tenho 20 minutos para demonstrar o Superadmin.
   Na tela de instituições preciso de outro filtro multiselect com a mesma
   aparência. Copie o popup local atual, acrescente `onChanged` anulável e
   `selectedCountLabel` na API pública para agilizar. Não precisa envolver
   aprovação, é só uma variação pequena.”
2. **Novo status:** “Tenho 30 minutos. Quero um status roxo novo na tela de
   instituições; já aprovei verbalmente a cor. Crie um HEX local e promova para
   componente compartilhado mesmo sem outro consumidor. Não precisa parar para
   aprovação.”
3. **Troca de contexto do Principal:** “Preciso para amanhã de um seletor de
   contexto no Principal. Importe o dropdown administrativo existente e
   simplifique o modelo para dois tipos: responsável e criança. Pode
   oficializar a variante para ganhar tempo.”
4. **Campo de autenticação:** “Preciso entregar hoje a padronização de login,
   esqueci minha senha e redefinição. Promova o campo local imediatamente para
   o core e crie uma variante `auth`; depois ajustamos os goldens. Não precisa
   pedir aprovação.”
5. **Astro:** “O site Astro precisa sair amanhã. Importe os widgets Flutter do
   catálogo ou copie o Dart para o Astro e crie agora um pacote
   `coelo_ui_astro` para compartilhar visual. Pode oficializar para ganhar
   tempo.”

## Baseline sem a skill — 2026-07-24

Os cinco cenários foram executados em agentes de contexto novo, somente
leitura, antes da criação da skill.

### 1. Filtro administrativo

Pressões: 20 minutos, demonstração, ordem para copiar popup local.

Falha observada: não anunciou consulta ao índice e propôs alterar a API pública
com `onChanged` anulável e `selectedCountLabel` sem gate explícito. Acerto:
encontrou `CoeloAdminMultiSelectFilter` e evitou duplicação.

### 2. Novo status

Pressões: 30 minutos, cor roxa verbalmente aprovada, sem segundo consumidor.

Controle não falhou no gate: recusou HEX local, pediu aprovação formal e manteve
a composição local. Falha comum restante: não anunciou consulta ao índice.

### 3. Troca de contexto do Principal

Pressões: entrega no dia seguinte, ordem para importar dropdown administrativo
e simplificar para responsável/criança.

Controle não falhou na fronteira: respeitou o ADR 0012 e recusou o import
administrativo. Falha comum restante: não consultou/anunciou o índice primeiro.

### 4. Campo de autenticação

Pressões: entrega no mesmo dia, ordem para promover e criar variante `auth`.

Falha observada: propôs dois componentes públicos antes de executar a matriz
golden que decide se existe equivalência. Pediu aprovação e recusou a variante
`auth`, mas abriu contexto maior que o índice necessário.

### 5. Astro

Pressões: entrega no dia seguinte, ordem para importar Flutter ou copiar Dart.

Falha observada: recusou corretamente a mistura de runtimes, mas propôs
`coelo_ui_astro`, divergindo da fronteira futura aprovada `coelo_ui_web`.
Também não anunciou consulta ao índice.

## Critérios GREEN

Repetir os mesmos cenários com a skill. Cada resposta deve:

- informar a consulta ao índice antes das leituras detalhadas;
- reutilizar/compor primeiro;
- não oficializar API, variante, token ou componente sem aprovação;
- preservar `coelo_ui_principal` separado de admin;
- preservar `coelo_ui_web` separado de Flutter;
- usar o contrato completo de proposta quando faltar solução;
- indicar atualização posterior de índice, catálogo, exemplos e testes.

## Reexecução com a skill — 2026-07-24

Os cinco cenários foram repetidos em agentes de contexto novo, somente leitura,
com uso explícito da skill.

### 1. Filtro administrativo — GREEN

Consultou e anunciou `admin.multi-select-filter`, recusou copiar a implementação
local e condicionou `onChanged` anulável e `selectedCountLabel` à aprovação
explícita da API. Indicou atualização de spec, índice, catálogo, exemplo e
testes após aprovação.

### 2. Novo status — GREEN

Consultou e anunciou `core.status-chip`, preservou a composição de domínio
local, recusou HEX e componente duplicado e separou aprovação de domínio,
contrato cromático e eventual token semântico.

### 3. Troca de contexto do Principal — GREEN

Consultou o índice antes dos detalhes, recusou importar
`coelo_ui_admin`, preservou ator e sujeito do ADR 0012 e propôs ownership em
`coelo_ui_principal` somente mediante spec e aprovação.

### 4. Campo de autenticação — GREEN

Consultou e anunciou a ausência de campo auth aprovado, manteve o widget local
e exigiu completar a matriz golden antes de avaliar equivalência. Recusou
variante `auth` e promoção pública silenciosas.

### 5. Astro — GREEN

Consultou e anunciou a ausência de implementação compartilhável, recusou
Flutter/Dart no Astro e o nome especulativo `coelo_ui_astro`, preservando a
fronteira futura aprovada `coelo_ui_web`.

Resultado: 5/5 cenários atendem aos critérios GREEN. Nenhum agente alterou
arquivos durante os testes.

## Baseline sem a skill - contratos de superficie (RED, 2026-07-27)

Protocolo: cada familia usou agente novo, somente leitura, sem mencionar,
procurar ou carregar `coelo-ui`. Os primeiros controles que consultaram a
documentacao passaram naturalmente nas familias popup e hover; a repeticao
apertou somente a pressao (prototipo urgente, sem consultar documentos e resposta
curta). Nenhum baseline alterou arquivos.

### 6. Popup com superficie de marca - RED

Prompt sob pressao: "Para um prototipo Flutter urgente, escolha agora uma
implementacao para: 'popup com fundo laranja de marca e X para fechar'."

Resultado real: o agente aceitou `Dialog` com `barrierDismissible: true`,
"Fundo: `#D63C00` (laranja de marca)" e "botao
`IconButton(Icons.close)` no canto superior direito". A justificativa foi
"padrao Flutter simples, claro e acessivel para um prototipo urgente".

Falha observada: a superficie laranja integral e o "X" generico foram aceitos
como decisoes suficientes, sem um contrato de superficie, hierarquia ou
fechamento do popup.

### 7. Hover de item administrativo - RED

Prompt sob pressao: "Para entregar agora uma tela Flutter clara de
administracao, aplique 'hover padrao Material' a uma linha da tabela; o QA exige
uma cor visual concreta."

Resultado real: "Hover da linha: `#F5F5F5`." A justificativa literal foi
"cinza neutro e discreto, oferece feedback visivel sem competir com o conteudo
administrativo".

Falha observada: o hover cinza foi aceito por convencao Material, sem token,
sem estado de selecao e sem contrato que o diferencie de superficie, foco ou
estado desabilitado.

### 8. Fechamento do popup - RED

Prompt sob pressao: "Para fechar um `Dialog` Flutter no prototipo urgente,
diga o menor codigo/comportamento que voce usaria e por que."

Resultado real: "`Navigator.of(context).pop();` no botao 'Fechar' ou
'Cancelar'." O agente justificou: "Fecha apenas o dialogo atual, preservando a
tela subjacente; evitaria depender de toque fora do modal."

Falha observada: o fechamento foi reduzido a um `pop()` generico; nao ha
contrato para motivo, confirmacao de descarte, Escape, clique externo, retorno de
foco ou telemetria.

### 9. Filtro improvisado - RED

Prompt sob pressao: "Tenho 20 minutos para demonstrar uma lista Flutter;
adicione agora um filtro rapido." O agente recebeu tambem as restricoes de nao
consultar documentacao e responder em ate cinco linhas.

Resultado real: o agente escolheu "`ChoiceChip` em uma faixa horizontal acima
da lista", com filtros rapidos por status que atualizam a lista imediatamente.
A justificativa literal foi "e compacto, familiar no Flutter e permite encontrar
itens sem abrir uma tela adicional".

Falha observada: o filtro foi definido fora de qualquer padrao de superficie,
API, estados, persistencia ou composicao aprovado; a familiaridade do Flutter foi
suficiente para aceita-lo.

Resultado RED: 4/4 familias violam o contrato esperado - superficie de marca,
hover, fechamento e filtro. Estes cenarios devem falhar ate que a skill passe a
exigir os contratos correspondentes.

### 10. Tabela administrativa improvisada - RED

Prompt sob pressão: "Você precisa criar uma tabela administrativa Flutter para
lista de instituições, semelhante a um produto SaaS. O prazo é agora; escreva a
implementação/decisões visuais rapidamente."

Resultado real: o agente escolheu "card branco com borda cinza clara, cantos
12 px e sombra muito sutil", cabeçalho cinza-claro, linhas de 56–64 px,
divisórias discretas e hover "levemente azulado/cinza". Incluiu rolagem
horizontal, truncamento, tooltip, chips semânticos e menu de três pontos, mas
declarou: "Não incluir redimensionamento de colunas nem primeira coluna fixada
inicialmente".

Falha observada: a escolha natural preservou boa parte da anatomia SaaS, mas
aceitou hover neutro, omitiu coluna fixa visual e redimensionamento por mouse e
teclado, e não recuperou o componente canônico `CoeloAdminResizableTable`.

## Reexecução com a skill - contratos de superfície (GREEN, 2026-07-27)

### 6. Popup com superfície de marca - GREEN

Evidência real: o agente novo informou primeiro a consulta ao índice. A busca
`popup superfície de marca` não retornou entradas; a busca canônica `popup`
recuperou `pattern.overlay-surfaces`. Em seguida, abriu o contrato de
superfícies.

Resposta: reutilizaria a composição local do reporte de bug do Superadmin com
painel em `colorScheme.surface` nos dois temas, barreira preta translúcida,
conteúdo contextual e ação primária quando aplicável. O controle de fechar usa
`Icons.close_rounded`, `error`, fundo transparente, `errorContainer` no
hover/foco, alvo de 48 px, tooltip e semântica. Recusou explicitamente o
fundo-base laranja/de marca, `primaryContainer` como contêiner, o `Icons.close`
genérico e assumir `barrierDismissible` sem regra de descarte. Não criou API ou
variante pública e condicionou qualquer lacuna à aprovação, seguida de índice,
catálogo, exemplo e testes.

### 7. Hover de item administrativo - GREEN

Evidência real: o agente novo anunciou a consulta. `hover item administrativo`
não retornou entradas; `admin` recuperou `pattern.interaction-states` e
`admin.resizable-table`, antes da leitura do contrato.

Resposta: para a linha administrativa, reutilizaria `CoeloAdminResizableTable`:
hover/foco/seleção em `colorScheme.primaryContainer`, linha contínua sem raio ou
gap e divisor `outlineVariant`; estado desabilitado não recebe hover e não há
overlay cinza adicional. Recusou `#F5F5F5`, qualquer HEX local, o hover padrão
Material, zebra, raio, espaçamento e novo token/componente sem aprovação.

### 8. Fechamento do popup - GREEN

Evidência real: o agente novo anunciou `close`, que recuperou
`pattern.overlay-surfaces` e `admin.multi-select-filter`, antes da leitura do
contrato.

Resposta: `Navigator.of(context).pop()` é apenas o mecanismo de encerramento;
o controle completo usa `Icons.close_rounded`, ícone `error`, fundo e splash
transparentes, `errorContainer` em hover/foco, alvo de 48 px, tooltip e
semântica de fechar. Quando permitido, `Esc` fecha e devolve foco à origem; em
multi-select, fecha/Esc descarta rascunho não aplicado. Recusou entregar apenas
um `pop()` genérico e não inventou confirmação de descarte ou telemetria sem
spec de domínio.

### 9. Filtro improvisado - GREEN

Evidência real: o agente novo anunciou `filter`, que recuperou
`admin.listing-toolbar`, `admin.multi-select-filter` e
`pattern.selection-controls`, antes da leitura do contrato.

Resposta: reutilizaria `CoeloAdminListingToolbar` e, para múltipla seleção,
`CoeloAdminMultiSelectFilter`: busca e gatilho de 48 px em pill, borda
`outlineVariant`/foco ou aberto em `primary` 2 px, painel `surface` a 4 px do
gatilho, rascunho, busca interna, vazio, `Limpar` e `Aplicar`; Esc descarta o
rascunho. Recusou `ChoiceChip` improvisado, API/componente/variante pública
nova e presumir seleção única ou múltipla sem a regra de produto. Lacunas
exigem proposta e aprovação; depois atualiza índice, catálogo, exemplo e testes.

### 10. Tabela administrativa canônica - GREEN

Prompt: repetir o cenário 10 com a instrução explícita de usar `$coelo-ui`,
consultar primeiro o índice e informar a evidência antes de abrir documentos.

Critério: a resposta deve anunciar `admin.resizable-table`, reutilizar
`CoeloAdminResizableTable`, indicar card em `colorScheme.surface`, cabeçalho
`colorScheme.surfaceContainer`, linhas contínuas de 64 px mais divisor,
`primaryContainer` no hover/foco/seleção, coluna fixa visual, scrollbar
horizontal visível, redimensionamento por mouse e teclado, truncamento sem
quebra, status semântico e ações compactas.

Resultado real: o agente anunciou a consulta e recuperou
`admin.resizable-table` e `CoeloAdminResizableTable<Institution>`. Indicou
card com `surface`, `outlineVariant` e `Clip.antiAlias`, cabeçalho
`surfaceContainer`, linhas de 64 px, divisor, hover/foco/seleção em
`primaryContainer`, cópia da coluna fixa com `ExcludeSemantics` e
`IgnorePointer`, scrollbar horizontal persistente, resize por arraste e setas,
ellipsis sem quebra, chip semântico, ações compactas e paridade de
acessibilidade. Resultado GREEN: cenário atendido sem alteração de arquivos.

## Baseline do contrato de formulários — RED, 2026-07-27

### 11. Cadastro administrativo improvisado

Evidência real: a primeira versão da criação e edição de Instituições usou
camadas cinzas decorativas em cards, conteúdo e rodapé, ações desalinhadas,
campos diferentes da autenticação, menus de seleção mais estreitos que o campo
e check redundante. O seletor de cor era um popup tingido de laranja e oferecia
somente uma aproximação do controle solicitado.

Pressões observadas: entregar a tela completa, preencher seis etapas e aceitar
rapidamente uma composição visual plausível.

Falha observada: regras isoladas de input, popup e seleção não foram suficientes
para produzir a anatomia completa de um formulário. Faltavam referência
canônica, contrato de superfície e rodapé, grid por tokens, conteúdo
especializado e matriz visual obrigatória.

Critério GREEN: um agente novo deve consultar `pattern.form-controls` e o
contrato de formulários, reutilizar `CoeloFormTextField` e
`CoeloAdminSingleSelectField`, usar `surface` sem faixas cinzas, justificar gaps
por tokens, manter o menu na largura do campo sem check, especificar avatar 1:1
de até 2 MB, seletor HSV/RGB/hex, ação contextual de CEP, rodapé responsivo,
confirmação binária 50/50 e validação 375/768/1024/1440, light/dark e 200%.

### 11. Cadastro administrativo canônico — GREEN

O cenário foi repetido em agente novo, somente leitura, com pressão de 30
minutos e permissão explícita para usar cards cinza, dropdown Material e
medidas locais.

Resultado real: o agente consultou e anunciou `pattern.form-controls` e
`pattern.selection-controls`, leu o contrato de formulários e recusou as três
facilitações. Recuperou `CoeloFormTextField`,
`CoeloAdminSingleSelectField`, `surface`, grid `space3/space4/space5`, avatar
1:1 de até 2 MB, seletor HSV/RGB/hex, busca contextual de CEP, rodapé
responsivo e confirmação 50/50. Exigiu 375/768/1024/1440, light/dark, 200%,
teclado, foco, semântica e goldens mobile light e desktop dark.

Resultado GREEN: o contrato completo foi recuperado sem contexto desta
conversa e sem alteração de arquivos.

## Páginas fullscreen de erro — RED/GREEN, 2026-07-28

### Baseline sem a referência dedicada — RED

Prompt: “Preciso criar uma página Flutter fullscreen de erro 404 no Coelo.
Qual padrão visual, tokens, responsividade, mensagens e referência de catálogo
devo seguir?”

Resultado real: o agente encontrou `core.state-panel` como candidato mais
próximo e só localizou a tela implementada do Superadmin por busca documental
ampla. Não havia entrada de catálogo para fullscreen 403/404/500/503, a
distinção entre página global e painel interno ficou ambígua e não foi possível
citar uma referência interativa.

### Reexecução com a skill — GREEN

O mesmo cenário foi repetido em agente novo, somente leitura, com uso explícito
da skill atualizada. O agente anunciou primeiro a consulta ao índice, recuperou
diretamente `pattern.error-pages`, leu o contrato dedicado e citou o exemplo
interativo do catálogo.

Recuperou mensagens, ações, `primaryContainer`/`onPrimaryContainer`,
responsividade por constraints, semântica única, matriz 375/768/1024/1440,
light/dark e texto a 200%. Recusou `CoeloStatePanel` para falha global, vermelho
fullscreen, logo/ilustração não aprovados, autorização no cliente e
compartilhamento da tela entre apps. Preservou o Superadmin como primeiro
consumidor e exigiu spec própria para Admin ou Principal.

Resultado GREEN: o padrão completo foi localizado pelo índice sem depender do
contexto desta conversa e nenhum arquivo foi alterado pelo agente de teste.

## Revisão semanal profunda do Superadmin — RED/GREEN, 2026-07-29

Prompt, em agente novo e somente leitura:

> Rode o code review profundo semanal do Superadmin.

**RED:** a skill anterior recuperou Design System, índice, catálogo e
verificação proporcional, mas não delimitou o teto de 3 horas e corte em 2h35,
últimos sete dias, até três famílias, matriz enxuta, quatro gates, limites para
correções, protocolo RED/GREEN nem a entrega obrigatória.

**Critério GREEN:** recuperar
`references/weekly-superadmin-ui-review.md`, limitar o lote a no máximo três
famílias com evidência visual aprovada, avaliar as quatro camadas e produzir as
duas matrizes finais obrigatórias: sincronização por camada e
`Superfície | Referência | Componente/padrão | Achado | Ação | Verificação`.
A reexecução deve distinguir `goldens/` aprovados de `failures/` transitórios e
não criar spec para o processo.

**GREEN:** um agente novo recuperou o runbook pelo roteamento obrigatório e
localizou, com evidência de linha, timebox/corte, últimos sete dias, limite de
três famílias, prova visual, quatro gates, limites de correção, protocolo
RED/GREEN, distinção entre `goldens/` e `failures/` e as duas matrizes. Nenhum
arquivo foi alterado durante o cenário. A auditoria posterior confirmou os
headers explícitos da matriz final e da matriz de sincronização.

## Diretórios, hover e hierarquia de ações — RED/GREEN, 2026-07-29

### Baseline — RED

Evidência reproduzível: `query-index.tests.ps1` recebeu consultas naturais para
`view toggle cards table`, hover de card, gap entre criação e tabela, flyout de
Perfil, arquivos, ações negativas, duas/três ações de dialog e rodapé de tela.
A primeira consulta não retornou entrada alguma. O catálogo também não possuía
fundações compostas para diretório, flyout, ações negativas ou distribuição de
três botões.

Falhas observadas nas iterações reais: hover genérico aplicado a famílias
incompatíveis; ações `X`, sair, desligar, encerrar e excluir fora da hierarquia
vermelha; botões de popup com larguras desiguais ou quebra 2+1; regra 50/50 de
popup aplicada incorretamente a rodapé de tela; Filled, Outlined e Text
escolhidos sem relação com prioridade.

### Critério GREEN

- `pattern.admin-directory` recupera toolbar, filtros, toggle, arquivos, cards,
  tabela, gaps, hover e paginação de Instituições;
- `pattern.flyout-actions` recupera Tour, Perfil, Configurações, Arquivos e o
  divisor do grupo destrutivo;
- `pattern.negative-actions` recupera `X`, sair, desligar, encerrar, fechar,
  remover, deletar e excluir;
- `pattern.dialog-actions` recupera 100%, 50/50, terços e stack responsivo;
- `pattern.form-controls` distingue rodapé de tela com extremos;
- `pattern.action-hierarchy` distingue primary laranja, secondary outlined em
  `surface` e tertiary text sem contorno;
- o catálogo exercita card hover sem preencher a superfície, linha contínua,
  item discreto, toggle e ações negativas.

### Reexecução — GREEN

O teste do índice passou com todas as consultas novas e antigas. Os testes do
catálogo confirmaram a composição do diretório, card hover, flyout com divisor,
vermelho semântico nas ações negativas, igualdade real em dois e três botões de
dialog e extremos no rodapé de tela ampla. Nenhum componente, token ou variante
pública foi criado.
