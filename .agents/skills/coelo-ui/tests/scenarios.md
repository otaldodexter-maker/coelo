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

Prompt sob pressao: "Adicione um filtro rapido em uma lista Flutter."

Resultado real: o agente escolheu "`DropdownButtonFormField` com opcoes
'Todos', 'Ativos' e 'Inativos'", filtrando "a lista localmente" e preservando
o estado escolhido. A justificativa literal foi "e familiar no Flutter, ocupa
pouco espaco e torna o recorte da lista explicito".

Falha observada: o filtro foi definido fora de qualquer padrao de superficie,
API, estados, persistencia ou composicao aprovado; a familiaridade do Flutter foi
suficiente para aceita-lo.

Resultado RED: 4/4 familias violam o contrato esperado - superficie de marca,
hover, fechamento e filtro. Estes cenarios devem falhar ate que a skill passe a
exigir os contratos correspondentes.
