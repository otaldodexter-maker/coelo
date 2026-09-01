---
source: ".superpowers/sdd/task-4-brief.md"
status: "flutter-local-complete"
generated_at: "2026-09-01"
---

# Task 4 — Card Publicar agora e polimento focal

## Resultado

O card “Publicar agora” de Acontece usa contorno tracejado 4/4 e resolve os
estados hover, foco e pressionado pelo `CoeloPrincipalActionCard`. A abstração
especializada preserva semântica e teclado, incorpora `selected` aos estados
expostos e evita o `InkWell` cru proibido pelo gate administrativo. O painter
desenha o traço insetado por metade da espessura, sem recorte externo.

O Perfil não apresenta mais Seguidores, Seguindo ou Acompanhar. As métricas
locais são Publicações, Momentos e Circulares, sem contrato remoto inventado.

## TDD e revisão

- RED: keys/estado tracejado ausentes; “Seguidores” ainda presente; builders de
  estado do componente inexistentes; `selected` não chegava aos builders.
- GREEN: 132 testes das seis páginas focais passaram.
- Analyzer dos sete arquivos Dart afetados: `No issues found!`.
- `validate_admin_visual_contracts`: exit 0, sem allowlist nova.
- `git diff --check`: limpo antes do commit.
- Review inicial pediu correções de `selected`, inset do painter, cobertura de
  semântica/foco/pressed e este relatório; todas foram tratadas.

## Telas verificadas por testes

- Acontece: card, hover, foco, pressed, semântica, callback e responsividade.
- Para Você: regressão focal e componente interativo compartilhado.
- Perfil: remoção de follow público, conteúdo/abas e responsividade.
- Publicar no Acontece, Publicar Agora e Publicar em Momentos: suíte focal de
  regressão e layout.

## Referências preservadas

- `docs/reviews/evidence/etapa-2/coelo-principal-superadmin/create-institution-default.png`
- `docs/reviews/evidence/etapa-2/coelo-principal-superadmin/create-institution-hover.png`
- `docs/reviews/evidence/etapa-2/coelo-principal-superadmin/acontece-current-desktop-double-chrome.png`
- `docs/reviews/evidence/etapa-2/coelo-principal-superadmin/acontece-current-mobile-double-chrome.png`
- `docs/reviews/evidence/etapa-2/coelo-principal-superadmin/para-voce-responsive-reference.png`
- `docs/reviews/evidence/etapa-2/coelo-principal-superadmin/perfil-institucional-responsive-reference.png`
- publicadores inventariados no manifesto da mesma pasta.

## Commits

- `b9c75c7e fix(principal): polish publish card and profile`
- correções do review e este relatório: commit imediatamente posterior, a ser
  registrado no fechamento documental.

## Limite de evidência

Esta tarefa comprova apenas Flutter local nas rotas `/dev`. Não comprova rota
real, Supabase local/remoto, RLS, CRUD remoto ou E2E e não deve ser declarada
ponta a ponta. A implantação sem `/dev` é um gate separado aberto pelo usuário.
