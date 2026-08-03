---
title: "Sentimentos opcionais na Rotina diária do Superadmin"
source: "decisão aprovada pelo usuário em 2026-08-03; docs/product/prd-master.md; specs/021-superadmin-daily-routine-prototype.md"
status: "approved-design"
generated_at: "2026-08-03"
---

# Sentimentos opcionais na Rotina diária do Superadmin

## Objetivo e problema

Permitir que a equipe registre, de forma rápida e acolhedora, como cada
participante chegou, sem transformar uma percepção subjetiva em dado
obrigatório ou em parte da chamada oficial.

O protótipo local já possui o campo textual `Como chegou?`, mas ele nasce
obrigatório, recebe `Tranquilo` como valor inicial e não oferece seleção visual.
Esta mudança substitui esse comportamento por um catálogo curto de sentimentos
com emoji e rótulo acessível.

## Escopo

- Tornar `Como chegou?` opcional e sem valor inicial.
- Exibir cinco sentimentos principais diretamente no fluxo operacional.
- Disponibilizar quatro sentimentos adicionais por `Ver mais`.
- Permitir selecionar, trocar ou limpar o sentimento de cada participante.
- Permitir escolher um sentimento antes da aplicação em lote.
- Preservar valores individuais no lote, salvo confirmação explícita para
  sobrescrever.
- Permitir o envio local de uma sugestão para ampliar o catálogo.
- Registrar sugestões somente em memória durante o protótipo.

## Fora de escopo

- Alterar Assiduidade ou Chamada.
- Implementar backend, persistência após recarga, moderação ou aprovação de
  sugestões.
- Disponibilizar sentimentos personalizados imediatamente no registro.
- Alterar `apps/admin` ou `apps/principal`.
- Inferir sentimento automaticamente ou usar IA para classificar participantes.

## Superfícies afetadas

A mudança fica limitada ao protótipo de Rotina diária em
`apps/superadmin`, especialmente à prévia operacional do editor. O catálogo de
sentimentos é domínio local da feature e não cria componente público novo.

## Catálogo aprovado

Os cinco sentimentos principais são:

| Identificador | Emoji | Rótulo |
| --- | --- | --- |
| `animated` | 😊 | Animado |
| `calm` | 😌 | Calmo |
| `sensitive` | 🥺 | Sensível |
| `irritated` | 😠 | Irritado |
| `sleepy` | 😴 | Sonolento |

Os quatro sentimentos adicionais são:

| Identificador | Emoji | Rótulo |
| --- | --- | --- |
| `sad` | 😢 | Triste |
| `discouraged` | 😔 | Desanimado |
| `distracted` | 🤔 | Distraído |
| `agitated` | 😣 | Agitado |

`Não informado` representa ausência de registro. Não é um sentimento e não é
persistido como valor.

## Linguagem e proteção infantil

Emoji nunca aparece sem rótulo textual. Os termos descrevem um estado percebido
naquele momento e não diagnóstico, traço permanente ou avaliação da criança.
`Distraído` substitui `Desatento` para reduzir linguagem julgadora. Sugestões
livres não podem ser aplicadas a participantes antes de uma futura revisão do
catálogo.

## Modelo e fluxo de dados

Um tipo de domínio local representa cada sentimento com identificador estável,
emoji, rótulo e posição no catálogo. Valores de participantes armazenam o
identificador estável, não o emoji nem o texto de apresentação.

O campo `Como chegou?` continua sendo uma escolha única, passa a
`required: false` e não possui `initialValue`. Limpar a seleção remove o valor do
campo em vez de gravar uma string vazia ou `Não informado`.

A sugestão contém identificador local, texto normalizado, estado `pending` e
data local de criação. Ela permanece separada dos valores de participantes e do
catálogo aprovado. Como o protótipo não possui backend, recarregar a aplicação
descarta sugestões.

## Composição e interação

### Seleção individual

Cada participante mostra as cinco opções principais com emoji e texto. Somente
uma pode estar selecionada. A ação `Ver mais` abre uma superfície administrativa
neutra com as quatro opções adicionais e a ação `Sugerir sentimento`.

Escolher uma opção adicional fecha a superfície, atualiza o participante e
devolve o foco ao gatilho. Se o valor atual estiver entre as opções adicionais,
o resumo continua exibindo emoji e rótulo. A ação `Limpar sentimento` remove o
valor atual e volta a exibir `Não informado`.

### Aplicação em lote

O fluxo de lote exige escolher um dos nove sentimentos antes de habilitar
`Aplicar em lote`. Se algum participante selecionado já possuir valor, o diálogo
existente pergunta se deve preservar ou sobrescrever. Preservar mantém as
exceções; sobrescrever aplica o sentimento escolhido a todos os selecionados.

Nenhum sentimento é aplicado automaticamente ao selecionar participantes,
abrir a tela ou acionar valores iniciais.

### Sugestão de sentimento

`Sugerir sentimento` abre `CoeloAdminDialogShell` com superfície
`colorScheme.surface`, sem tint, um campo `CoeloFormTextField` rotulado
`Sentimento sugerido` e as ações `Cancelar` e `Enviar sugestão` em larguras
iguais. O envio permanece desabilitado enquanto o texto normalizado estiver
vazio.

Ao enviar, o protótipo armazena a sugestão em memória, fecha o diálogo, devolve
o foco à origem e apresenta confirmação breve. A sugestão não é incluída no
catálogo, não altera modelos e não pode ser aplicada a participantes.

## Estados de UX

- Sem valor: `Não informado` e nenhuma opção selecionada.
- Selecionado: emoji e rótulo com estado visual e semântico de escolha única.
- Opções adicionais abertas: superfície neutra, foco contido e fechamento por
  `Esc` quando permitido.
- Sugestão vazia: ação primária desabilitada.
- Sugestão enviada: confirmação breve e catálogo inalterado.
- Somente leitura: valores são visíveis; seleção, limpeza, lote e sugestão ficam
  indisponíveis.
- Lote com conflitos: confirmação explícita para preservar ou sobrescrever.

## Permissões e contexto

Somente `DailyRoutinePermissions.owner` pode selecionar, limpar, aplicar em lote
ou sugerir sentimentos. Atores somente leitura podem consultar valores já
registrados. As regras existentes de instituição, unidade, grupo e atividade
permanecem inalteradas.

## Acessibilidade e responsividade

- Emoji sempre acompanha texto e não é o único portador de significado.
- Cada opção expõe rótulo, estado selecionado e disponibilidade para tecnologia
  assistiva.
- Teclado, foco visível, toque e mouse oferecem as mesmas ações.
- Alvos interativos respeitam o mínimo do Design System.
- A seleção deve refluir sem overflow em 375, 768, 1024 e 1440 px e permanecer
  utilizável com texto a 200%.
- `Ver mais` e o diálogo usam os contratos aprovados de superfície, hierarquia
  de ações e retorno de foco.
- Light e dark usam apenas tokens semânticos, sem cores locais.

## Eventos, feedback e falhas

O protótipo não envia eventos remotos. O repositório local mantém a lista de
sugestões pendentes para testes determinísticos. Envio vazio é bloqueado antes
de chegar ao repositório. Falhas de backend ficam fora de escopo; uma futura
integração deverá definir retry, deduplicação, moderação, auditoria e proteção
contra abuso antes de persistir sugestões.

## Critérios de aceite

- `Como chegou?` é opcional e não recebe valor inicial.
- Cinco opções principais aparecem diretamente e quatro ficam em `Ver mais`.
- As nove opções usam exatamente os identificadores, emojis e rótulos aprovados.
- Seleção individual pode ser alterada ou limpa.
- `Não informado` nunca é persistido como sentimento.
- O lote usa a opção escolhida e preserva exceções por padrão.
- Sugestão válida fica pendente em memória, mas não entra no catálogo nem em
  qualquer registro de participante.
- Atores somente leitura não conseguem alterar ou sugerir.
- A composição passa por testes de widget, domínio, responsividade,
  acessibilidade, análise estática e validador visual administrativo.

## Estratégia de testes

- Testes de domínio para catálogo, identificadores, opcionalidade, limpeza,
  aplicação em lote e separação das sugestões.
- Testes de widget para cinco opções principais, `Ver mais`, escolha adicional,
  seleção individual, limpeza e estados somente leitura.
- Testes do diálogo para validação vazia, envio, confirmação e catálogo
  inalterado.
- Verificação responsiva em 375, 768, 1024 e 1440 px, light/dark, texto a 200%,
  teclado, foco e semântica.
- Execução do validador bloqueante de contratos visuais administrativos.

## Riscos e decisões futuras

- O catálogo fixo pode precisar variar por segmento ou faixa etária. Isso exige
  spec própria para configuração, herança e versionamento.
- Sugestões livres precisarão de moderação e prevenção de abuso antes do
  backend produtivo.
- A exibição futura no Admin e no Principal precisa preservar finalidade,
  contexto, retenção e melhor interesse da criança.

Nenhuma dessas decisões futuras bloqueia o protótipo local aprovado.
