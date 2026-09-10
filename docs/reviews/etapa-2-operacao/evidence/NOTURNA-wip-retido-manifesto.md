---
fonte: rodada noturna 09→10/09/2026, coordenação e integração
status: registro de preservação
data: 2026-09-10
---

# WIP retido na máquina no fechamento

Registro do que existia fora da base entregue no corte das 05:00, preservado antes
de qualquer higiene e **sem nenhuma remoção**. Nenhum `reset`, nenhum `clean`,
nenhum descarte.

## 1. Alteração de código não commitada — a única da máquina

- **Worktree:** `C:/Users/adrie/Documents/Coelo.worktrees/e2-noturna-estrutura`
- **Branch:** `work/etapa2-noturna-estrutura`, cabeça `6709f1473`
- **Caminho:**
  `apps/superadmin/test/features/institutions/presentation/screens/institution_form_save_lifecycle_test.dart`
- **Hash do conteúdo atual:** `1db1d68d8663a85e74f0b90b21e872020f9f9e77`
- **Hash da versão versionada:** `180e8ef0c`
- **Preservação:** o objeto foi escrito no banco de objetos do repositório e a
  diferença completa está publicada ao lado, em
  `NOTURNA-wip-retido-estrutura.patch` — 59 linhas.

Acrescenta três casos de confirmação de saída de formulário de instituição
(`cancel-changed`, `destination-changed`, `same-context`). **Não foi integrado nem
executado sobre a base entregue.** Pertence a uma frente que encerrou às 22:35, e
integrar trabalho de frente encerrada sem decisão não é atribuição da coordenação.

## 2. Commit publicado e não mesclado, por decisão

- `80f160599` — `fix(principal): stop production screens from calling themselves a
  preview`, em `work/etapa2-noturna-copia-previa`, publicado, sem divergência.
- Patch preparado, **não mesclado e não testado sobre a base atual**, aguardando
  decisão do Owner. Worktree em `%TEMP%/coelo-copia-previa`; o conteúdo está no
  remoto, não apenas no disco temporário.

## 3. Commit vazio

- `8d06b8a91` — zero arquivos alterados, em
  `work/etapa2-noturna-chat-comunicacoes-router-dedupe`.
- **A branch foi mantida.** Apagar não traz benefício e a decisão não é da
  coordenação. Fica declarada em vez de silenciosamente removida.

## 4. Recursos declarados e não fechados

- `C:/cdchk` — 12 KB de árvore vazia com um diretório travado por processo; o
  registro de worktree já foi removido do Git. Sai sozinho quando os processos
  morrerem, ou precisa de remoção manual.
- Etiquetas locais `audit-frozen-0200` (`0d847eb7a`) e `audit-frozen-0350`
  (`e864a254f`) — **não publicadas**; somem se o repositório local for limpo.
- Arquivos `packages/coelo_api/pubspec.lock` e `packages/coelo_domain/pubspec.lock`
  aparecem não rastreados em três worktrees. São resíduo de `flutter pub get`, com
  conteúdo idêntico ao já rastreado em `9a896b993`. Não commitados, não apagados.
- 28 processos `dart`/`flutter_tester` vivos no corte, sem dono conhecido: nenhuma
  frente registrou identificador de processo por corrida. Trajetória medida: 32 às
  04:09, 30 às 04:14, 28 às 04:40 e às 04:54.
