---
source: "docs/design/design-system.md; decisions/0009-design-system-and-tokens.md"
status: "implemented-package"
generated_at: "2026-07-24"
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

Pacote Flutter local implementado e consumido pelo Superadmin, pelo catalogo e
pelos pacotes de UI materializados. Admin e Principal devem reutilizar esta
mesma fonte Flutter quando suas superficies forem implementadas.

A futura implementacao Astro nao importara Dart ou widgets Flutter. Ela devera
derivar tokens CSS da mesma fonte neutra futura, preservando os papeis
semanticos registrados no indice como `astro-planned`.
