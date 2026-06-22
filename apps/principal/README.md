---
source: "AGENTS.md; docs/contexts/principal-context.md; docs/product/prd-app.md"
status: "planning-context"
generated_at: "2026-06-22"
---

# Principal Flutter

Aplicacao principal do Coelo em `app.coelo.me` e futuro mobile. Atende
responsaveis, familias, alunos/participantes e equipe no uso diario.

O nome oficial e `principal`. Nao usar `family` em novos nomes de app,
pacote, spec ou contexto.

## Estrutura planejada

- `lib/app`: composicao do app, shell mobile-first e rotas.
- `lib/core`: configuracoes, guards e infraestrutura local.
- `lib/features`: modulos de experiencia diaria.

## Contextos iniciais

- `context`: instituicao/papel/crianca ou grupo ativo.
- `flow`: feed privado e comunicados.
- `now`: conteudo temporario de 24 horas.
- `moments`: videos privados de ate 2 minutos.
- `routine`: diario de rotina.
- `chat`: conversas e canais contextuais.
- `agenda`: eventos, ciencia e autorizacoes simples.
- `profile`: perfil, preferencias e portal do responsavel.

## Por que assim

O Principal e mobile-first, privado e orientado ao cuidado diario. A estrutura
por feature evita importar componentes administrativos e ajuda cada fluxo a
respeitar contexto ativo, vinculo familiar e melhor interesse da crianca.
