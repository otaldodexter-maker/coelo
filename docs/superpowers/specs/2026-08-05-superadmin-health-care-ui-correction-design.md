---
title: "Correção de UI de Saúde e Cuidado no Superadmin"
source: "aprovação do Owner Coelo em 2026-08-05; specs/020-superadmin-health-care.md; docs/design/design-system.md; .agents/skills/coelo-ui/references/admin-directory-flyout-contracts.md; .agents/skills/coelo-ui/references/form-layout-contracts.md"
status: "approved"
generated_at: "2026-08-05"
---

# Correção de UI de Saúde e Cuidado no Superadmin

## Objetivo

Refazer a experiência visual de `Saúde e Cuidado` no Superadmin sem alterar
regras de negócio, arquitetura, persistência ou permissões. O módulo mantém
duas áreas irmãs e distintas: `Perfis de cuidado`, para informações permanentes
da criança, e `Planos de medicação`, para vigência, horários, responsáveis e
registros periódicos de doses.

## Baselines aprovadas

- Diretórios, cards, tabela, filtros, arquivos e paginação: Instituições.
- Segmentação linear de status: Pessoas e Instituições.
- Criar e editar: Criar/Editar Instituição e Criar/Editar Unidade.
- Flyouts: Fazer tour, Arquivos e conta.
- Campos: autenticação e componentes compartilhados Coelo.

Não usar as páginas atuais de detalhe de Perfil de cuidado ou Plano de
medicação como referência. Ambas constam como padrões rejeitados.

## Escopo

- os diretórios de Perfis de cuidado e Planos de medicação;
- as páginas de criar e editar das duas entidades;
- as páginas de visualização/detalhe das duas entidades;
- os componentes compartilhados já responsáveis por toggle, flyout, tabela e
  scrollbar, somente quando a correção pertencer ao padrão transversal;
- testes funcionais e goldens proporcionais aos estados alterados;
- nomenclatura visível `Saúde e Cuidado` em todo o módulo.

Ficam fora do escopo migrations, Supabase remoto, RLS, novas permissões,
integração produtiva de arquivos e alterações na regra de medicação.

## Diretórios

Os dois diretórios reutilizam `CoeloAdminListingToolbar`, busca, filtros,
`SuperadminDirectoryViewToggle`, `CoeloAdminFileActions`,
`CoeloAdminCreateAction`, `CoeloAdminInteractiveCard`,
`CoeloAdminResizableTable` e `CoeloAdminPagination`.

O toggle Cards/Tabela preserva segmentos de 64 × 48 px. Tabela seleciona
diretamente `Agrupado` quando for a única visão. Havendo variações, o flyout
usa `CoeloAdminFlyout`, painel de 236 px, item útil de 220 px e `space1` entre
itens.

As tabelas nascem centralizadas quando a largura natural é menor que a área
disponível. Scrollbar e track horizontais ficam visíveis sobre a coluna fixa,
desde a primeira coluna. O botão de criar preserva as medidas atuais: tile na
primeira célula dos cards e banner acima da tabela, separado por `space4`.

Arquivos oferece `Importar`, `Exportar CSV` e `Exportar XLSX` nas duas áreas.
Nesta UI demonstrativa, as ações seguem o fluxo local existente e não criam
integração produtiva.

### Perfis de cuidado

- título: `Perfis de cuidado`;
- descrição centrada em alergias, restrições e orientações permanentes;
- tabs exclusivas: `Todos`, `Ativos`, `Em Implantação` e `Inativos`;
- filtros contextuais reaproveitados de Pessoas para criança, instituição,
  unidade e turma/atividade;
- remover o banner demonstrativo que compete com a toolbar;
- cards resumem criança, alertas ativos, orientações e pendências sem excesso
  de chips ou contornos.

### Planos de medicação

- título: `Planos de medicação`;
- cards e tabela priorizam criança, medicamento, vigência, horários, contexto
  responsável e status;
- filtros operacionais continuam distintos da segmentação de Perfis de
  cuidado;
- situações de dose não são convertidas silenciosamente em status cadastral.

## Criar e editar

Os formulários deixam de ser uma coluna longa. Em medium e wide, reutilizam
`SuperadminFormStepNavigation`; no compacto, preservam um resumo acessível da
mesma hierarquia. Campos usam os componentes Coelo e o rodapé reutiliza
`SuperadminFormActionFooter`.

Etapas do Perfil de cuidado:

1. Criança.
2. Alergias e restrições.
3. Orientações de cuidado.
4. Revisão.

Etapas do Plano de medicação:

1. Criança e medicamento.
2. Vigência.
3. Horários e responsáveis.
4. Documento.
5. Revisão.

No desktop, `Cancelar` permanece no extremo esquerdo; `Anterior`, `Continuar`
e a única ação preenchida ficam à direita. No compacto, a ação primária ocupa
a largura útil e aparece primeiro. Nenhum campo, select, botão ou card usa
hover cinza ou overlay Material adicional.

## Visualização e detalhe

As páginas de detalhe deixam de usar coluna central longa, cards empilhados,
chips como estrutura e ações espalhadas. Cada detalhe reutiliza a hierarquia
de formulário aprovada em modo somente leitura, com navegação lateral por
seções, uma área de resumo prioritária e ações no rodapé.

O Perfil de cuidado destaca primeiro riscos e orientações permanentes; o Plano
de medicação destaca próximo horário, vigência, responsáveis e registros de
dose. Os dois preservam linguagem de apoio, sem semáforo clínico e sem depender
somente de cor.

## Responsividade e acessibilidade

- `LayoutBuilder` decide a composição pela largura realmente disponível;
- 375 px usa uma coluna, toolbar refluída e resumo compacto de etapas;
- 768 e 1024 px preservam navegação lateral quando couber sem comprimir campos;
- 1440 px limita a largura legível e centraliza conteúdo natural;
- alvos mínimos de 48 px, foco visível, teclado, toque e semântica;
- texto a 200%, light/dark e reduced motion;
- status sempre combina texto com cor e, quando aplicável, ícone.

## Estados e evidências

Cobrir default, hover, foco, cards/tabela, flyout aberto, Arquivos aberto,
filtro selecionado, loading, vazio, sem resultado, erro, não autorizado,
paginação, criar compacto light, editar desktop dark e detalhes responsivos.
Goldens de `failures/` não são referência.

## Critérios de aceite

- o módulo é nomeado `Saúde e Cuidado` em todas as superfícies visíveis;
- Perfis de cuidado e Planos de medicação continuam irmãos e separados;
- ambos oferecem Arquivos com importar e exportar;
- toggle, flyout, tabela, scrollbar, centralização e criação seguem os
  componentes compartilhados;
- criar, editar e detalhe seguem a família Instituição + Unidade;
- não há hover cinza, widget Material cru novo ou overflow nos quatro
  breakpoints;
- nenhuma regra de domínio, persistência ou autorização é alterada.

