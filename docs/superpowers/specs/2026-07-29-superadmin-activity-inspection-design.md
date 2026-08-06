---
source: "Solicitações aprovadas em 2026-07-29 e 2026-08-05; docs/product/prd-superadmin.md; specs/014-atividade-contextual.md; decisions/0014-contextual-activities-and-delegated-unit-creation.md"
status: "approved"
generated_at: "2026-08-05"
updated_at: "2026-08-05"
---

# Diretório e visualização de Atividades do Superadmin

## Objetivo

Permitir que o Superadmin inspecione definições de atividades e seus vínculos
sem assumir a operação cotidiana da instituição. A superfície replica os
padrões visuais aprovados de Instituições, mas usa somente campos e relações
reais de `activity_definitions`.

## Escopo

- Listagem em cards e tabela, com busca, filtros e paginação.
- Visualização somente leitura da definição, governança, unidades e grupos.
- Contagens de profissionais e participantes sem expor seus nomes.
- Estados loading, vazio, sem resultados, erro, sem permissão e não encontrado.
- Rotas `/activities`, `/activities/:activityId` e equivalentes de
  desenvolvimento.
- Rotas locais demonstrativas `/activities/new`,
  `/activities/:activityId/edit` e equivalentes de desenvolvimento, sem
  persistência ou autorização produtiva.

## Fora de escopo

- Persistir, arquivar, promover ou alterar atividades produtivamente no
  Superadmin.
- Importar, exportar, anexar arquivos ou gerir mídia.
- Expor nomes de profissionais, crianças ou participantes.
- Recorrência, agenda, duração, horário, tipo de atividade, publicação,
  cancelamento ou conclusão.
- Alterar migrations, RLS, permissões ou APIs públicas de UI.

## Dados e filtros

A listagem usa nome, descrição, instituição, status, origem, distribuição,
governança e contagens de unidades e grupos. A busca considera nome e
descrição. Os filtros são instituição, status e origem. Status aceitos:
`draft`, `active`, `inactive`, `suspended` e `archived`; origens:
`institution` e `unit`.

Datas `starts_at` e `ends_at` pertencem à validade dos vínculos e não representam
calendário ou recorrência da atividade.

## Composição visual

Instituições é a baseline integral de shell, toolbar, alternância, cards,
tabela, estados e paginação sticky. Cards usam `CoeloAdminInteractiveCard`,
preservam geometria, densidade, hover e foco e exibem status somente pelo
`CoeloAdminExpandableStatusIndicator` compacto; a tabela mantém status em chip.
Status é filtro multi-select real e não usa tabs lineares. A tabela reutiliza
`CoeloAdminResizableTable`; filtros reutilizam `CoeloAdminMultiSelectFilter`;
a paginação reutiliza `CoeloAdminPagination`.

Cards usam 11 itens por página e oferecem `11, 20, 50, 100`; tabela usa 8 e
oferece `8, 20, 50, 100`. O rodapé sticky mede sua altura e desloca o launcher
de mensagens para impedir sobreposição.

O diretório exibe tile e banner de criação demonstrativa e ação local de
edição. Card e linha preservam `Visualizar atividade`; a ação `Editar` abre o
protótipo local sem alegar gravação.

## Visualização

O detalhe usa superfície neutra e hierarquia administrativa aprovada, sem
simular um formulário desabilitado. Ele apresenta:

- identidade, instituição, descrição e status;
- origem, unidade de origem, distribuição e governança;
- datas de criação, atualização e arquivamento;
- unidades vinculadas, status e validade;
- grupos vinculados, unidade, participação e status;
- contagens de profissionais atribuídos e participantes.

Somente voltar, tentar novamente e navegação global permanecem disponíveis.

## Autorização e privacidade

O Superadmin lê pelas policies existentes de `platform.read`. Erros explícitos
`42501` e `PGRST301` tornam-se estado sem permissão; resposta vazia permanece
vazio ou não encontrado. A interface não consulta helpers privados, não usa
`service_role` e não infere autorização de metadata do cliente.

Criar e editar produtivamente continuam no Admin e dependem de memberships e
capacidades institucionais `activities.create` e `activities.manage`. O
protótipo do Superadmin não amplia autorização, não persiste e não consulta
novos dados remotos.

## Critérios de aceite

- A estética de Instituições é preservada em 375, 768, 1024 e 1440 px,
  light/dark e texto a 200%.
- Busca, filtros, cards, tabela e paginação preservam o contrato existente;
  novos detalhes, sugestões e formulários usam fixtures locais explícitas.
- Tabela mantém coluna fixa, resize e rolagem horizontal.
- Filtros preservam rascunho, Aplicar, Limpar, Escape e restauração de foco.
- Rodapé e launcher não se sobrepõem.
- Ações demonstrativas deixam claro que nenhuma alteração será salva.
- O detalhe não expõe nomes de pessoas ou crianças.

## Testes exigidos

- Modelos, parsing Supabase, busca, filtros, paginação e estados de erro.
- Rotas normal e de desenvolvimento.
- Widget tests de cards, tabela, filtros, paginação, estados e detalhe.
- Goldens da matriz responsiva, light/dark, hover/foco e texto a 200%.
- Análise estática, validadores do catálogo e gates de conhecimento.
