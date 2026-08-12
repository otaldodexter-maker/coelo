---
source: "Solicitações aprovadas em 2026-07-29 e 2026-08-05; docs/product/prd-superadmin.md; specs/014-atividade-contextual.md; decisions/0014-contextual-activities-and-delegated-unit-creation.md"
status: "approved"
generated_at: "2026-08-05"
updated_at: "2026-08-11"
---

# Diretório e visualização de Atividades do Superadmin

## Aditivo produtivo aprovado em 2026-08-11

Esta versão consolida o comportamento produtivo aprovado, preservando
integralmente o baseline visual.
O Superadmin pode ler, criar, editar, vincular, importar e exportar Atividades
quando possuir a capability de plataforma específica, sempre revalidada por
RPC/RLS. Owner possui todas; Operations administra taxonomia; outros usuários
internos dependem do perfil de acesso.

Diretório, detalhe e formulário usam apenas relações reais. Alunos e
profissionais podem ser exibidos somente no conjunto hierárquico autorizado.
Importação/exportação usa jobs e arquivos reais; foto de identidade usa
Supabase Storage privado; mídia editorial continua no R2. Nenhuma ação
habilitada pode ser no-op ou anunciar sucesso antes da persistência.

## Objetivo

Permitir que o Superadmin inspecione e administre definições de atividades e
seus vínculos quando possuir a capability de plataforma correspondente. A
superfície replica os padrões visuais aprovados de Instituições, mas usa
somente campos e relações reais de `activity_definitions`.

## Escopo

- Listagem em cards e tabela, com busca, filtros e paginação.
- Visualização da definição, governança, unidades, grupos, profissionais e
  participantes dentro do escopo hierárquico autorizado.
- Criação, edição, vínculo, importação e exportação produtivos por capability.
- Catálogo versionado de categorias, subtipos e modelos de atividades.
- Criação atômica de atividade a partir de modelo e duplicação de modelo para
  o escopo institucional.
- Estados loading, vazio, sem resultados, erro, sem permissão e não encontrado.
- Rotas `/activities`, `/activities/:activityId` e equivalentes de
  desenvolvimento.
- Rotas produtivas `/activities/new`, `/activities/:activityId/edit` e
  equivalentes de desenvolvimento.

## Fora de escopo

- Recorrência, agenda, duração, horário, tipo de atividade, publicação,
  cancelamento ou conclusão.
- Mídia editorial de Now, Happens e Moments, que permanece no R2 e fora deste
  formulário.

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

O CTA `Criar atividade` é persistente nos estados com dados, vazio, sem
resultados e falha recuperável quando o ator possui `activities.create`. Ele
fica ausente no estado sem permissão. Card e linha preservam `Visualizar
atividade`; `Editar` aparece somente com capability e abre o fluxo produtivo.
Loading, vazio, sem resultados, falha, sem permissão e não encontrado nunca
repovoam dados nem anunciam sucesso artificial.

O catálogo versionado inclui 40 modelos iniciais em categorias filtráveis de
esportes, artes, idiomas, ciências exatas e naturais, tecnologia, apoio
pedagógico, bem-estar, sustentabilidade, vida prática e socioemocional. Entre
eles estão Natação, Futebol, Futsal, Matemática e Física. Começar a partir de um modelo é uma
única mutação idempotente e auditada que aplica defaults e overrides e persiste
a origem. Duplicar modelo cria uma cópia institucional, também idempotente e
auditada; não cria uma atividade por engano.

## Visualização

O detalhe usa superfície neutra e hierarquia administrativa aprovada, sem
simular um formulário desabilitado. Ele apresenta:

- identidade, instituição, descrição e status;
- origem, unidade de origem, distribuição e governança;
- datas de criação, atualização e arquivamento;
- unidades vinculadas, status e validade;
- grupos vinculados, unidade, participação e status;
- contagens de profissionais atribuídos e participantes.

Voltar, tentar novamente, editar e demais comandos aparecem conforme capability
e estado real do recurso.

## Autorização e privacidade

O Superadmin usa capabilities server-side `activities.read`,
`activities.create`, `activities.manage`, `activities.link_units`,
`activities.link_groups`, `activities.assign_people`,
`activities.manage_permissions`, `activities.import`, `activities.export`
e `activities.templates.manage`. RPCs e RLS recalculam identidade, capability,
MFA e escopo em cada requisição. Erros explícitos `42501` e `PGRST301`
tornam-se estado sem permissão; resposta autorizada vazia permanece vazio ou
não encontrado. A interface não consulta helpers privados, não usa
`service_role` e não infere autorização de metadata do cliente.

## Critérios de aceite

- A estética de Instituições é preservada em 375, 768, 1024 e 1440 px,
  light/dark e texto a 200%.
- Busca, filtros, cards, tabela e paginação preservam o contrato existente e
  usam somente dados reais.
- Tabela mantém coluna fixa, resize e rolagem horizontal.
- Filtros preservam rascunho, Aplicar, Limpar, Escape e restauração de foco.
- Rodapé e launcher não se sobrepõem.
- Toda ação habilitada persiste ou retorna erro recuperável honesto.
- O CTA de criação permanece em vazio, sem resultados e falha recuperável, mas
  não aparece sem autorização.
- Começar a partir de modelo é atômico; duplicar modelo cria modelo
  institucional e os 21 seeds permanecem versionados.
- O detalhe e o formulário expõem pessoas somente no escopo autorizado.

## Testes exigidos

- Modelos, parsing Supabase, busca, filtros, paginação e estados de erro.
- Rotas normais e de desenvolvimento, inclusive capabilities negativas.
- Widget tests de cards, tabela, filtros, paginação, estados e detalhe.
- Goldens da matriz responsiva, light/dark, hover/foco e texto a 200%.
- Testes de idempotência, modelo-origem, cópia institucional, RLS e auditoria.
- Análise estática, validadores do catálogo e gates de conhecimento.
