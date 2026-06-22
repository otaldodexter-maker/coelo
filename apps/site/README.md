---
source: "AGENTS.md; docs/contexts/site-context.md; decisions/0008-astro-site.md"
status: "planning-context"
generated_at: "2026-06-22"
---

# Site Publico Astro

Superficie publica principal do Coelo em `coelo.me`, orientada a SEO,
marca, narrativa institucional, confianca e conversao. O site fica separado
dos apps Flutter e nao deve depender de logica privada.

## Estrutura planejada

- `src/pages`: rotas publicas do site.
- `src/layouts`: cascas compartilhadas de pagina.
- `src/components`: componentes reutilizaveis de UI.
- `src/sections`: blocos grandes de pagina, como hero e CTA.
- `src/styles`: CSS global, tokens web e variaveis.
- `src/content`: conteudo editorial ou colecoes Astro.
- `src/lib`: helpers de SEO, dados estaticos e utilitarios.
- `src/middleware`: contexto para helpers de middleware; Astro usa
  `src/middleware.ts` quando middleware real for necessario.
- `public`: assets publicos nao processados pelo build.

## Por que assim

Astro cria rotas a partir de `src/pages`, enquanto as demais pastas sao
convencoes para manter conteudo, layout e componentes separados. Isso ajuda
o site a evoluir sem misturar marketing, app privado e regras sensiveis.
