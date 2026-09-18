---
title: Protótipos de criação e edição de atividades no Superadmin
source: "docs/superpowers/specs/2026-07-29-superadmin-activity-inspection-design.md; specs/014-atividade-contextual.md; docs/superpowers/specs/2026-07-27-superadmin-institution-form-visual-refactor-design.md; decisão explícita do usuário em 2026-07-29"
status: approved
generated_at: 2026-07-29
---

# Protótipos de criação e edição de atividades no Superadmin

## Objetivo

Acrescentar à superfície de Atividades do Superadmin os affordances e
formulários demonstrativos de Criar e Editar, preservando integralmente a
estética e os contratos de interação aprovados de Instituições.

Os formulários são protótipos visuais locais. Eles não gravam no Supabase,
não simulam autorização institucional e não alteram migrations, RLS,
permissões ou contratos públicos.

## Decisão de autorização

O usuário atual possui `platform.read`, que permite consultar instituições,
unidades e atividades. O contrato remoto exige `activities.create` para criar
e `activities.manage` para editar, ambas capacidades institucionais ausentes
no Superadmin atual.

Por decisão explícita, a entrega não amplia autorização. O submit valida os
campos e comunica de forma inequívoca que nenhuma alteração foi persistida.
Nenhum segredo privilegiado, bypass de RLS ou autorização inferida no cliente
será utilizado.

## Referências visuais

As referências canônicas são:

- shell, menu e hierarquia de Instituições;
- tile de criação nos cards de Instituições;
- banner de criação acima da tabela de Instituições;
- Criar instituição em mobile light;
- Editar instituição em desktop dark;
- popup de Bug;
- flyout do perfil;
- flyout do tour;
- contratos públicos de formulário, seleção e diálogo.

O wizard institucional de sete etapas não será copiado. Ele pertence ao
domínio de Instituições. Atividade utiliza página única porque o contrato
mínimo confirmado possui poucos campos.

## Listagem e detalhe

- Cards exibem um `CoeloAdminCreateAction` na variante `tile`, com o mesmo
  espaçamento e estados de Instituições.
- Tabela exibe o banner de criação aprovado acima da tabela.
- Ambos navegam para `/activities/new`.
- O detalhe exibe a ação Editar e navega para
  `/activities/:activityId/edit`.
- As ações são identificadas como protótipos visuais em seus tooltips,
  semântica contextual ou feedback de submit; não sugerem persistência real.

## Criar atividade

O formulário usa o shell, a superfície neutra, a largura útil, os gaps, o grid
responsivo e o rodapé de Instituições.

Campos confirmados:

- nome obrigatório;
- descrição opcional;
- instituição obrigatória;
- unidade inicial ativa e pertencente à instituição selecionada.

Instituições e unidades são carregadas somente em leitura. Trocar a
instituição limpa uma unidade incompatível. A unidade nunca é inferida ou
mantida entre tenants.

O submit:

1. valida os quatro campos;
2. impede duplo acionamento durante o feedback;
3. exibe `Protótipo visual — nenhuma alteração foi salva.`;
4. retorna à listagem sem inserir registro.

## Editar atividade

O formulário carrega o detalhe existente e mantém editáveis somente:

- nome;
- descrição.

Instituição, origem e unidade de origem aparecem como contexto somente leitura.
Status, distribuição, governança, vínculos, participantes e profissionais não
são editados por esse protótipo.

O submit valida, exibe o mesmo aviso demonstrativo, redefine o baseline de
alterações pendentes e permanece na página. Registro ausente, falha e sem
permissão reutilizam os estados já aprovados do detalhe.

## Interações

- `CoeloFormTextField` atende nome e descrição.
- `CoeloAdminSingleSelectField` atende instituição e unidade.
- O rodapé usa superfície neutra e ação primária dominante.
- Cancelar, back do sistema e troca de destino passam por confirmação quando
  houver alterações.
- A confirmação reutiliza `CoeloAdminDialogShell`, com duas ações 50/50,
  `Escape`, close acessível e retorno ao fluxo sem descarte involuntário.
- A ordem de foco segue a ordem visual; labels persistentes, erros associados
  e alvos mínimos são obrigatórios.
- Reduced motion remove transições não essenciais.

## Responsividade

- A página decide composição pelas constraints disponíveis.
- Em 375 px, campos e ações ficam em uma coluna e a ação primária ocupa a
  largura útil.
- Em 768, 1024 e 1440 px, o conteúdo permanece centralizado e limitado, com
  até duas colunas e gaps `12/16/20` derivados dos tokens aprovados.
- O rodapé e o conteúdo rolável não podem se sobrepor, inclusive com texto a
  200%.

## Estados

Criar cobre loading das opções, erro, sem permissão e estado pronto.
Editar cobre loading, not-found, erro, sem permissão e estado pronto.
Ambos cobrem validação, dirty, confirmação de saída e feedback demonstrativo
de submit.

## Fora de escopo

- persistência local ou remota;
- alteração da listagem após submit;
- status e arquivamento;
- grupos, profissionais, participantes ou políticas;
- agenda, recorrência, duração, anexos e arquivos;
- importar ou exportar;
- migration, RLS, grants, RPC ou nova permissão;
- componente, token ou API pública nova.

## Testes e evidências

- RED antes de implementar botões, rotas e formulários;
- controller: defaults, hidratação, validação, dirty e reset de baseline;
- widgets: criação, edição, seleções dependentes, confirmação de saída,
  ausência de persistência e estados;
- rotas normais e `/dev`;
- cards e tabela com ações de criação;
- detalhe com Editar;
- 375, 768, 1024 e 1440 px, light/dark, texto a 200%, teclado, foco,
  semântica e reduced motion;
- goldens mínimos `activity_form_create_light_375.png` e
  `activity_form_edit_dark_1440.png`, comparados visualmente com Instituições
  antes da atualização intencional;
- análise estática, testes focados, validadores de índice/catálogo, gates de
  conhecimento e `git diff --check`.
