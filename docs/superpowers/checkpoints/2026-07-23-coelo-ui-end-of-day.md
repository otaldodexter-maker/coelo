---
title: "Encerramento seguro da fundacao Coelo UI em 2026-07-23"
source: "docs/superpowers/plans/2026-07-22-coelo-ui-foundation-componentization-catalog.md; estado local verificado em 2026-07-23"
status: "paused-safe"
generated_at: "2026-07-23"
---

# Encerramento seguro da fundacao Coelo UI

## Ponto exato

A fundacao esta pausada em ponto verde parcial da Task 7 de 16. As Tasks 1 a 6
estao concluidas. Na Task 7, busca, status, toolbar responsiva, paginacao e
mecanica da tabela foram migrados. A composicao de dominio da tabela foi
separada em `institution_directory_table.dart`.

A ultima verificacao verde registrada antes deste encerramento foi:

- `coelo_ui_admin`: 8 testes focados da tabela e 27 testes do pacote;
- pagina de instituicoes: 29 testes passaram e 2 gaps conhecidos foram
  ignorados;
- suite de instituicoes: 64 testes passaram e 2 gaps conhecidos foram
  ignorados;
- goldens: 5 casos e 26 imagens sem atualizacao ou diferenca;
- analise de `coelo_ui_admin` e `apps/superadmin`: limpa;
- revisao independente da tabela: zero achado critical, important ou minor.

Nenhum teste foi reexecutado depois deste registro porque o encerramento de hoje
alterou somente documentacao. Nao houve commit, push, deploy ou dependencia
externa.

## Pendencias confirmadas

1. O submenu da navegacao recolhida possui uma correcao candidata no codigo
   (hover/focus/pressed laranja, padding entre itens, elevacao e deslocamento
   vertical), mas nao sera chamado de entregue antes de nova demonstracao
   visual.
2. O botao circular de recolher/abrir deve permanecer parcialmente dentro e
   parcialmente fora da lateral. O codigo da correcao candidata do submenu nao
   altera sua geometria; a posicao ainda sera conferida visualmente.
3. O filtro geografico ainda usa as opcoes anteriores. A entrega aprovada deve
   derivar UFs dos registros acessiveis, depois municipios das UFs selecionadas
   e bairros do recorte anterior. A regra fica em repository/view model e tera
   testes antes da implementacao.
4. A marca deve ser restaurada e padronizada no menu, login, esqueci minha senha
   e redefinicao de senha:
   - light: circulo laranja com `logo Coelo branco.svg`;
   - dark: circulo branco com `logo Coelo Laranja.svg`.
   Os SVGs canonicos ficam em `assets/brand/logos/svg/`. Antes de trocar os
   assets usados pelo app, conferir se as copias em `apps/superadmin/assets/brand/`
   sao fieis aos canonicos. Esta rodada antecipa somente a correcao visual da
   marca; a componentizacao completa dos formularios de auth permanece na
   Task 13.
5. Na Task 7, states e multiselects continuam locais por incompatibilidades de
   contrato aprovadas. Toolbar, states e cards ainda precisam da divisao local
   segura; a reducao de rebuilds sera avaliada depois.

## Primeira sequencia da proxima sessao

1. Conferir `git status` e este checkpoint, sem descartar mudancas existentes.
2. Subir uma build atual em uma porta diferente de `8080`.
3. Demonstrar no localhost novo o submenu recolhido e o botao circular.
4. Registrar o baseline das logos no shell e nas telas de login, esqueci minha
   senha e redefinicao; restaurar a combinacao light/dark aprovada com testes e
   goldens antes/depois.
5. Se houver diferenca, escrever primeiro o teste de caracterizacao que falha,
   aplicar a menor correcao e repetir shell, goldens e validacao visual.
6. Implementar em TDD a cascata geografica derivada dos dados acessiveis.
7. Terminar as pendencias estruturais da Task 7 e repetir analise, testes,
   goldens, scans de estilos/fronteiras e revisao do diff.

## Servidor local

O processo Python que servia `127.0.0.1:8080` foi encerrado e a porta foi
confirmada sem listener. Na proxima sessao sera usada outra porta.

## Protecoes

- Nao atualizar goldens para esconder diferenca.
- Nao alterar visualmente instituicoes sem proposta e aprovacao.
- Nao promover state, multiselect ou card com API especulativa.
- Nao misturar componentes administrativos com Principal.
- Preservar todas as mudancas preexistentes do worktree.
