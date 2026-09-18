---
title: "Checkpoint da correcao UI/UX de Instituicoes, foto e Bio"
source: "Solicitacoes do Owner Coelo e implementacao revisada em 2026-08-04"
status: "implementation-checkpoint"
generated_at: "2026-08-04"
updated_at: "2026-08-04"
---

# Checkpoint da correcao UI/UX de Instituicoes, foto e Bio

## Encerramento

- Data e hora: 2026-08-04 21:03 (America/Sao_Paulo).
- Implementacao funcional no commit `2db640d`
  (`fix(superadmin): corrigir flyout foto e bio`).
- Branch permaneceu `dev`; nao houve push, merge ou troca de branch.
- Supabase, banco, migrations, RPCs e integracoes externas nao foram tocados.

## Objetivo e escopo efetivo

Revisar Instituicoes, Criar e Editar; garantir flyout amplo com separacao entre
hovers; fazer Escolher/Trocar foto abrir o ajuste circular do Perfil; manter a
Bio contida; preservar o commit e abrir outro localhost sem encerrar existentes.

Foram conferidos commit, contratos, indice, memoria e testes de
`CoeloAdminFlyout`, `CoeloFormTextField`, picker institucional,
`AvatarCropDialog` e toggle Cards/Tabela. Foi criado o worktree isolado
`.worktrees/institutions-ui-review-localhost` em `2db640d`. Nenhuma nova
funcionalidade, refatoracao ou integracao foi iniciada.

## Decisoes a preservar

- `CoeloAdminFlyout`: superficie neutra, largura util de 220 px e
  `CoeloSpacing.spaceHalf` entre itens. Hover, foco e selecao arredondados nao
  ficam colados. `startsGroup` usa somente o divisor.
- Instituicoes mantem o flyout amplo; nao usar `MenuAnchor` local.
- Foto institucional usa o mesmo `FilePicker` do Perfil, com bytes e
  PNG/JPG/JPEG/WebP, antes de `AvatarCropDialog`. Nao usar picker `dart:html`.
- Bio usa `CoeloFormTextField`; icone, texto e cursor permanecem contidos a
  200%. Nao criar workaround local.
- Baseline principal: Criar/Editar instituicao. Instituicoes e Menu/Flyouts sao
  complementares; Design System Coelo prevalece sobre Material.

## Referencias preservadas

- `.agents/skills/coelo-ui/SKILL.md`
- contratos de superficie, diretorios/flyouts, formularios e matriz de estados;
- baselines aprovadas, padroes rejeitados e verificacao Coelo UI;
- `.agents/skills/coelo-knowledge/SKILL.md`;
- `docs/design/design-system.md`;
- indice: `admin.flyout`, `core.form-text-field`,
  `superadmin.avatar-crop-dialog`, `pattern.admin-directory` e
  `pattern.media-adjustment`.

## Arquivos e superficies

O commit `2db640d` consolidou 18 arquivos: skill/contratos/indice,
`institution_logo_picker.dart`, `coelo_admin_flyout.dart`,
`coelo_form_text_field.dart`, testes, goldens do flyout e Bio, Design System
e memorias de diretorio/formulario de Instituicoes.

Arquivo criado neste encerramento:
`docs/superpowers/checkpoints/2026-08-04-institutions-ui-followup-handoff.md`.

Superficies afetadas: flyout administrativo, campo multilinha, picker/crop de
foto e diretorio/formulario Criar/Editar Instituicao.

## Concluido

- Flyout amplo de 220 px e gap tokenizado entre destaques.
- Picker institucional convergido para o fluxo real do Perfil antes do crop.
- Bio multilinha contida horizontal e verticalmente a 200%.
- Padroes forcados na skill, contratos, Design System, indice e memoria.
- Revisao confirmou que nao e necessario novo ajuste Coelo UI.
- Feedback transitorio de golden foi limpo somente do worktree isolado, que
  voltou a `git status` limpo.

## Parcial e nao iniciado

- Worktree do novo localhost criado e validado.
- Localhost novo nao iniciado porque o encerramento seguro chegou antes.
- Suite geral de goldens teve pequenas diferencas uniformes; nenhuma baseline
  foi atualizada.

## Verificacoes executadas

- Campo compartilhado: 3/3 passaram.
- Flyout compartilhado: 3/3 passaram.
- Picker + formulario + toggle: 43/43 passaram.
- Golden especifico da Bio: passou.
- `institution_directory_page_golden_test.dart`: falhou em seis grupos com
  diferencas uniformes de 283 px (0,02%-0,03%); flyout de navegacao colapsada
  passou. Feedback foi limpo sem atualizar goldens.
- `git diff --check 2db640d^ 2db640d`: passou.
- Worktree isolado apos limpeza: limpo.

## Erros, bloqueios e debitos

- RTK bloqueia ate em `rtk --version`; usado fallback Flutter/Dart direto sem
  reconfigurar instalacao.
- Diagnosticar separadamente o delta uniforme de 283 px; nao regenerar goldens
  por conveniencia.
- Diretorio principal tinha 402 entradas concorrentes antes deste checkpoint;
  foram preservadas integralmente.
- Opcional futuro: teste geometrico de gap em `startsGroup`. Nao pertence a
  retomada imediata.

## Estado do Git e resumo do diff

- Principal: branch `dev`, `HEAD 2db640d`, arvore muito suja por trabalhos
  paralelos; nenhuma entrada concorrente foi staged ou alterada nesta revisao.
- Isolado: `.worktrees/institutions-ui-review-localhost`, detached em
  `2db640d`, limpo.
- Commit: 18 arquivos, 229 insercoes e 25 remocoes.
- Diff concorrente em skill/Design System/indice: 7 arquivos, 75 insercoes e
  19 remocoes; nao integrar nem sobrescrever automaticamente.

## Proximo passo exato

Ler este checkpoint, conferir `git status` e `git diff`, reabrir
`.agents/skills/coelo-ui/SKILL.md` e confirmar o worktree limpo. Sem modificar
codigo, verificar que 8778 esta livre e iniciar o Superadmin pelo worktree
isolado, sem encerrar outras portas. Validar listener, HTTP 200 e logs.

## Comandos de retomada

```powershell
git status --short
git diff --stat
git -C .worktrees/institutions-ui-review-localhost status --short
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue
```

Depois iniciar Flutter web-server em 8778 com
`--dart-define=COELO_DEV_MFA=true` e logs separados em `.codex/`.

## Criterios de conclusao da proxima etapa

- worktree isolado continua limpo em `2db640d`;
- nenhum servidor existente foi encerrado;
- nova URL responde HTTP 200 e nao ha erro fatal de compilacao;
- URL e PID sao informados ao Owner;
- nenhuma alteracao de Supabase, branch, merge ou push ocorre.
