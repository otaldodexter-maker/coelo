---
source: "Coelo UI/UX implementation handoff"
status: "completed"
generated_at: "2026-08-05"
---

# Handoff - Correcoes UI/UX da tela Avisos (Superadmin)

## Encerramento seguro
- data-hora: 2026-08-05
- objetivo original: corrigir e ajustar a UI/UX da tela Avisos no Superadmin, mantendo o Design System Coelo.
- escopo efetivamente trabalhado: listagem de avisos, editor contextual, preview do popup e responsividade da propria tela; sem mudanca de regra de negocio.

## Decisoes de produto e UI/UX preservadas
- Fluxo unico de listagem + editor contextual.
- Cards no desktop, densidade adaptativa no tablet e lista compacta no mobile.
- Desktop com editor lateral; mobile/tablet com superficie clara e fundo branco no tema claro, inspirado conceitualmente em Instagram/Airbnb.
- Marca laranja #D63C00, grafite #3F4549, Nunito Sans e tokens semanticos Coelo.
- Reuso de componentes Coelo para toolbar, cards, chips, campos, toggles e dialogos.
- Conteudo do aviso, visual, alcance, agendamento, recorrencia, comportamento, status e preview permanecem no mesmo fluxo.

## Referencias consultadas
- `.agents/skills/coelo-ui/SKILL.md`
- `.agents/skills/ponytail/SKILL.md`
- `.agents/skills/flutter-build-responsive-layout/SKILL.md`
- `.agents/skills/rtk/SKILL.md`
- `apps/superadmin/lib/features/notices/presentation/notice_directory_page.dart`
- `apps/superadmin/lib/features/notices/presentation/notice_form_page.dart`
- `apps/superadmin/lib/features/notices/presentation/notice_preview_dialog.dart`

## Arquivos criados
- Nenhum arquivo de codigo novo.

## Arquivos alterados e commit
- `apps/superadmin/lib/features/notices/presentation/notice_directory_page.dart`
- `apps/superadmin/lib/features/notices/presentation/notice_form_page.dart`
- `apps/superadmin/lib/features/notices/presentation/notice_preview_dialog.dart`
- Este handoff.
- Commit: `84f22c5 feat(superadmin): finalize notices uiux screen`

## Componentes, rotas e superficies afetadas
- Tela de diretorio de Avisos do Superadmin.
- Formulario de criacao/edicao de Avisos.
- Dialogo de preview do popup.

## Concluido
- Layout de listagem com cards e editor contextual.
- Preview visual do popup e configuracoes de conteudo/imagem/cores.
- Estados, alcance, agendamento e recorrencia apresentados no formulario.
- Fundo claro mobile/tablet ajustado para `Colors.white`, preservando superficie semantica no dark theme.
- Correcoes de compatibilidade de callbacks e campos Flutter.
- Formatacao aplicada nos tres arquivos de tela.

## Parcialmente concluido
- Recorrencia e agendamento permanecem como composicao de UI; regras de dominio/backend nao foram alteradas.

## Nao iniciado
- Validacao visual pixel-perfect em localhost, explicitamente fora desta etapa.

## Verificacoes executadas
- `dart format` nos tres arquivos: concluido.
- `dart analyze` nos tres arquivos: `No issues found`.
- Busca RTK por widgets Material proibidos nos arquivos de Avisos: nenhum encontrado.
- Busca RTK por recursos responsivos: `LayoutBuilder`, `MediaQuery` e `Expanded` presentes; `Flexible` nao necessario.
- `rtk --version`: executado nesta validacao.
- `rtk git status --short`, `rtk git show --stat --oneline HEAD` e `rtk git show --name-only --format='' 84f22c5`: executados nesta validacao.

## Erros, avisos e bloqueios
- Nenhum erro de analise conhecido no escopo.
- Nao foi aberto localhost conforme solicitado.
- O repositorio possui outras mudancas preexistentes fora do escopo; nao foram alteradas.

## Estado atual
- Tela Avisos funcional e validada estaticamente no escopo de UI/UX.
- Commit criado; nao houve push, merge ou alteracao de branch.

## Proximo passo exato
- Nenhum passo obrigatorio para esta entrega. Qualquer nova alteracao deve ser uma tarefa separada e restrita a Avisos.

## Primeiro arquivo para abrir na retomada
- `apps/superadmin/lib/features/notices/presentation/notice_directory_page.dart`

## Criterio de conclusao
- A tela Avisos permanece alinhada ao Design System Coelo, responsiva nos breakpoints previstos, sem widgets Material proibidos e com o fluxo listagem + editor entregue no commit indicado.
