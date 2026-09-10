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

## 5. Worktrees de pé no fechamento, e a distância de cada uma

Nenhuma worktree foi removida por mim. Quem abrir qualquer uma delas amanhã vai
encontrar um checkout **válido e desatualizado**, e nada na worktree grita isso.
A tabela existe para que a distância seja vista antes de alguém trabalhar em cima.

**Base entregue: `cb7ffe077`.**

| Worktree | Cabeça | Commits atrás da base |
| --- | --- | --- |
| `coelo-base-check` | `d784462c1` | 877 |
| `coelo-copia-previa` | `80f160599` | 317 |
| `e2-noturna-acessos-pessoas` | `992f3530d` | 548 |
| `e2-noturna-alunos-rotina` | `c73f7b526` | 399 |
| `e2-noturna-chat-comunicacoes` | `8a09d66ac` | 41 |
| `e2-noturna-estrutura` | `6709f1473` | 826 |
| `e2-noturna-formularios-cuidado` | `55f4b5910` | 815 |
| `e2-noturna-operacoes-sistema` | `dd1a95bcd` | 351 |
| `e2-noturna-perfil-para-voce` | `1d46746ff` | 214 |
| `e2-noturna-publicacoes-midia` | `69e377f3e` | 511 |
| `e2-noturna-verificacao` | `d784462c1` | 877 |
| `e2-r02-d01-autenticacao` | `dc44df9e1` | 998 |
| `e2-r02-d02-estrutura` | `40ec50d72` | 998 |
| `e2-r02-d03-acompanhamento` | `0a2ecb34e` | 998 |
| `e2-r02-d04-acessos` | `375e0a62a` | 998 |
| `e2-r02-l00-coordenacao-claude` | `bdef0f559` | 998 |
| `e2-r02-l01-publicacoes` | `3697dd49e` | 998 |
| `e2-r02-l02-chat-comunicacoes` | `45d92b9c1` | 998 |
| `e2-r02-l03-perfil-para-voce` | `b209b4e0f` | 950 |

Um número alto aqui não é problema: significa apenas que a frente parou antes das
últimas integrações. **É problema quando alguém retoma sem olhar.**
