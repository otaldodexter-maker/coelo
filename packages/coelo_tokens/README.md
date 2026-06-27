---
source: "docs/design/design-system.md; decisions/0009-design-system-and-tokens.md"
status: "implemented-package"
generated_at: "2026-06-27"
---

# coelo_tokens

Design tokens compartilhados do Coelo para Flutter: paleta oficial, temas
claro/escuro, tipografia Nunito Sans, espacamentos, radius, elevacao,
breakpoints, tamanhos, movimento e cores semanticas de status.

## Uso

Quando um app Flutter tiver `pubspec.yaml`, adicione:

```yaml
dependencies:
  coelo_tokens:
    path: ../../packages/coelo_tokens
```

Em seguida, use:

```dart
import 'package:coelo_tokens/coelo_tokens.dart';

MaterialApp(
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: ThemeMode.system,
);
```

## Status

Pacote Flutter local implementado. Os apps `admin`, `principal` e
`superadmin` ainda nao possuem `pubspec.yaml`; por isso a dependencia local
deve ser adicionada neles quando os projetos Flutter forem materializados.
