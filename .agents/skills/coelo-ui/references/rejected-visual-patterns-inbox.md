---
source: "Rejeição visual explícita do Owner Coelo em 2026-08-03; 14 anexos rejeitados; 32 baselines aprovadas do Superadmin; docs/design/design-system.md"
status: "active"
generated_at: "2026-08-04"
---

# Padrões visuais rejeitados

Este arquivo preserva exemplos que o Owner Coelo classificou explicitamente
como padrões que **nunca devem existir** no Coelo UI. Eles são evidência de
regressão e não podem ser usados como baseline, inspiração, golden aprovado ou
justificativa para ampliar uma allowlist.

Toda criação ou alteração visual do Superadmin precisa consultar este contrato
e as [baselines aprovadas](approved-superadmin-visual-baselines.md). A decisão
começa pelo mapeamento à família aprovada mais próxima; default Material não é
uma família visual Coelo.

## Matriz obrigatória de referência

| Superfície criada ou alterada | Baseline principal |
| --- | --- |
| Autenticação, campo, senha, checkbox ou aviso | Login, anexos aprovados 1–7 |
| Diretório, card, tabela, filtro, busca, arquivos ou paginação | Instituições, anexos 8–18 |
| Ajuda, conversa, sugestão ou compositor | Home, anexo 19 |
| Navegação, sidebar, rail, submenu ou flyout | Menu e flyouts, anexos 20–26 |
| Conta, dados pessoais, segurança, tema ou acessibilidade | Perfil e Configurações, anexos 27–29 |
| Popup, dialog, dismiss ou anexo | Popup de Bug e Ajustar foto, anexos 28 e 30 |
| Qualquer cadastro, edição, wizard, upload, seleção ou rodapé de tela | Criar/Editar instituição, anexos 31–32; a baseline é automática para qualquer entidade |

Se nenhuma família for aplicável, parar e registrar uma proposta visual para
aprovação. Não preencher a lacuna com um widget Material cru.

## Lote rejeitado: estados cinza e controles Material crus

1. Menu/dropdown quadrado com opção inteira em cinza, sombra pesada e nenhuma
   anatomia do flyout Coelo.
2. Linha de pessoa preenchida por faixa cinza de ponta a ponta, com checkbox
   isolado no extremo oposto.
3. Controle/checkbox envolvido por círculo ou faixa cinza sem função semântica.
4. Rodapé com três botões agrupados arbitrariamente; disabled como bloco cinza
   e hierarquia incompatível com Criar/Editar instituição.
5. Selects expostos como texto sublinhado, com seleção cinza e aparência de
   widget Material cru.
6. Editor de rotina usando dropdown cru, estados cinza, composição sem
   hierarquia e controles que não conversam com o restante da tela.
7. Checkbox de login envolvido por faixa cinza em hover/foco.
8. Checkbox selecionado de login dentro de uma barra cinza inteira.
9. Opção de radio em convite destacada por retângulo cinza de ponta a ponta.
10. Wizard de convite com conteúdo perdido em uma área vazia e rodapé sem a
    composição aprovada de extremos de Criar/Editar instituição.
11. Campo de texto alto e deformado, com ícone/conteúdo desalinhado e cursor
    visualmente fora da composição do controle.

## Lote rejeitado: seletor de intervalo de datas

12. Date range picker Material em tela cheia no desktop: calendário minúsculo
    perdido em uma superfície enorme, excesso de vazio, hierarquia fraca,
    fechamento `X` neutro em vez de negativo e ação `Salvar` sem presença de
    ação principal Coelo.
13. Versão comprimida do seletor: título truncado, datas apertadas, composição
    desequilibrada e ações textuais `Cancelar`/`OK` sem a hierarquia, linguagem
    e proporção dos dialogs Coelo.

O seletor de datas futuro deve ser responsivo e baseado nos contratos Coelo de
overlay, formulário e ações. Enquanto não houver componente compartilhado
aprovado, uso direto de `showDateRangePicker` em feature nova é bloqueado e
exige proposta de componente.

## Lote rejeitado: ausência de espaçamento

14. Cards de pessoas encostados verticalmente, com bordas compartilhando a
    mesma linha visual, sem gap entre superfícies e sem respiro antes da seção
    seguinte. A faixa cinza interna também fica colada ao conteúdo e reforça a
    aparência de tabela improvisada.

Superfícies irmãs precisam de separação tokenizada. Cards independentes não
podem parecer uma única massa contínua; conteúdo interno, grupo de chips e
transição para a próxima seção devem preservar a hierarquia espacial aprovada.

## Substituições obrigatórias

| Nunca criar na feature | Usar ou consultar |
| --- | --- |
| `DropdownButton` ou `DropdownButtonFormField` | `CoeloAdminSingleSelectField` ou proposta especializada |
| `PopupMenuButton`, `MenuAnchor` ou menu local | `CoeloAdminFlyout` |
| `RadioListTile` ou `CheckboxListTile` cru | controle compartilhado/composto conforme `pattern.selection-controls` |
| `showDateRangePicker` direto | proposta de seletor responsivo Coelo antes da implementação |
| `Card` + `InkWell` clicável | `CoeloAdminInteractiveCard` |
| fundo cinza local em hover/seleção | estado semântico de `pattern.interaction-states` |
| rodapé inventado | `pattern.form-controls` e baseline Criar/Editar instituição |
| cards sem gap | `CoeloSpacing` da baseline principal |

## Proibições ativas

- fundo ou faixa cinza genérica para hover, foco, seleção ou checkbox;
- dropdown, date picker, radio e checkbox Material crus em telas Coelo;
- rodapé de formulário que ignora a baseline Criar/Editar instituição;
- identidade visual própria de criação/edição implementada antes de proposta e
  aprovação explícita do Owner;
- dialogs com ações desproporcionais, truncadas ou linguagem `OK` genérica;
- controles desalinhados ou deformados para preencher espaço;
- cards, campos ou seções sem gaps e paddings tokenizados;
- tratar estes anexos como referência aprovada.

## Red flags: parar antes de implementar

- “É só um protótipo; o default Material serve.”
- “Depois ajustamos o hover cinza.”
- “É funcional, então não precisa consultar Instituições.”
- “O rodapé cabe; não importa a hierarquia.”
- “Não existe componente, então vou usar `showDateRangePicker` direto.”
- “Zero gap deixa mais compacto.”
- “Vou adicionar à allowlist para o gate passar.”

Qualquer uma dessas frases indica ausência de mapeamento à baseline. Pare,
consulte `pattern.approved-superadmin-surfaces` e escolha o contrato canônico;
se ele não existir, proponha e aguarde aprovação.
