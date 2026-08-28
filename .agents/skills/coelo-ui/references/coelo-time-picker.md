---
source: "docs/superpowers/specs/2026-08-28-coelo-visual-completion-stage-design.md"
status: "proposed"
generated_at: "2026-08-28"
---

# Proposta — seletor de hora Coelo

Esta referência registra uma proposta, não um padrão aprovado. Nenhum consumidor
deve adotá-la antes da aprovação visual explícita do Owner.

## Problema e consumidores

Cardápio e modelo de cardápio capturam hora por campos textuais locais. Medicação
usa `showTimePicker` Material e `CoeloDateTimeField` contém um diálogo Coelo
privado que não pode ser reutilizado. Os consumidores imediatos propostos são
Cardápio/Modelo, Medicação e o próprio `CoeloDateTimeField`.

## Componentes avaliados

- `CoeloDateTimeField`: possui a anatomia Coelo mais próxima, mas combina data e
  hora e mantém o diálogo de hora privado.
- `CoeloFormTextField`: fornece o campo-base aprovado, mas sozinho não oferece
  confirmação modal, parsing único nem retorno de foco.
- `showTimePicker`: rejeitado por introduzir a identidade e os estados Material
  crus onde o Coelo exige superfície própria.

## Anatomia e composição propostas

`CoeloTimeField` exibe label persistente, ícone de relógio, valor `HH:mm` ou
convite para seleção e chevron. A ativação abre uma superfície `surface`, sem
tint, de até 420 px, com título, fechamento negativo, campo `HH:mm`, erro
associado e ações `Cancelar`/`Aplicar` em 50/50. A implementação extrai a
anatomia privada já usada por `CoeloDateTimeField`; não cria outra identidade.

## Estados e variantes

- campo: vazio, selecionado, hover, foco, disabled e aberto;
- diálogo: inicial, edição, erro, confirmação e cancelamento;
- apenas variante de campo isolado nesta promoção; sem segundos, fuso, intervalo,
  presets ou recorrência especulativos.

## Tokens

Usar somente `color.surface`, `color.onSurface`, `color.outlineVariant`,
`color.primary`, `color.error`, `spacing.3`, `spacing.4`, `radius.md`,
`radius.lg` e `size.touch-min`. Não há lacuna de token.

## Responsividade

Em 375 e 768 px, diálogo e ações respeitam a largura útil e texto a 200% sem
overflow; as ações podem empilhar quando a constraint real exigir. Em 1024 e
1440 px, a superfície permanece limitada a 420 px. Light e dark usam os mesmos
papéis semânticos. Reduced motion não acrescenta animação não essencial.

## Acessibilidade

Campo e fechamento têm alvos mínimos de 48 px. Enter e Espaço abrem o seletor;
Enter confirma entrada válida; Escape cancela; o foco retorna ao campo de
origem. Semântica anuncia label e valor, o erro é associado ao input e o formato
é pt-BR de 24 horas (`HH:mm`).

## Package e API pública mínima

O proprietário proposto é `coelo_ui_core`, pois hora local não depende de
produto, domínio ou administração. API mínima:

```dart
CoeloTimeField({
  required TimeOfDay? value,
  required ValueChanged<TimeOfDay?> onChanged,
  String labelText = 'Horário',
  bool enabled = true,
})

Future<TimeOfDay?> showCoeloTimePicker({
  required BuildContext context,
  required TimeOfDay initialValue,
  String title = 'Defina o horário',
})
```

## Evidência e migração propostas

- testes de widget: mouse, Enter/Espaço, Escape, retorno de foco, valor válido,
  erro, disabled, semântica e texto a 200%;
- goldens dedicados: aberto light/375 e dark/1440, sem atualização automática;
- exemplo executável no catálogo e entrada consultável no índice;
- `CoeloDateTimeField` passa a chamar `showCoeloTimePicker`;
- Cardápio/Modelo posiciona `CoeloTimeField` logo abaixo do nome da refeição e
  mantém detalhes como campo multilinha Coelo;
- Medicação substitui `showTimePicker` pelo mesmo campo, sem mudar domínio nem
  persistência.

## Decisão necessária

O Owner precisa aprovar explicitamente esta extração para `coelo_ui_core`, a API
mínima acima e os dois goldens propostos. Até essa aprovação, o índice permanece
`proposed` e V3.18 fica bloqueado antes do código de produção.
