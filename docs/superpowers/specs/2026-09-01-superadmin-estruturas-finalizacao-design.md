---
title: "Finalização das telas de Estruturas do Superadmin"
source: "Solicitação do Owner em 2026-09-01; anexos visuais 1–15; PRDs e design system Coelo"
status: "approved-design"
generated_at: "2026-09-01"
---

# Finalização das telas de Estruturas do Superadmin

## Objetivo

Finalizar ponta a ponta, sem reconstrução ampla, as superfícies Instituições,
Unidades, Turmas, Atividades, Lançar avaliações, Fechamento de avaliações e
Chat. As mesmas páginas devem servir ao preview `/dev`, com fixtures locais, e
à composição produtiva, com repositories Supabase fail-closed e RLS.

## Abordagem aprovada

Aplicar correções cirúrgicas sobre páginas, controllers, repositories e
componentes canônicos existentes. Instituições permanece a referência para
diretórios, cards, tabelas, filtros e paginação. Não haverá uma segunda
implementação das telas nem fallback de fixtures em produção.

## Comportamento aprovado

- Todos os diretórios do recorte exibem opção Arquivos com Importar e Exportar;
  ações sem contrato funcional permanecem desabilitadas e explicadas.
- Todos os resultados pagináveis exibem paginação no rodapé, inclusive estados
  vazios quando houver mais de uma página lógica.
- Toda busca exibida funciona em `/dev` sobre as fixtures determinísticas do
  domínio correspondente; produção consulta apenas repositories autorizados e
  nunca usa dados fake como fallback.
- `/dev` contém de 2 a 5 instituições, cada uma com 1 a 6 unidades, cada unidade
  com 1 a 28 turmas, 12 modelos e 30 atividades; existem turmas com e sem
  atividades.
- Formulários de instituição e unidade apresentam mapa no cadastro/edição de
  localização, reutilizando coordenadas e serviço de localização existentes.
- No mobile, o cabeçalho usa logo completa Coelo com respiro superior e chevron:
  direita quando fechado, baixo quando o drawer está aberto. Não há hambúrguer.
  O acionador de Bug permanece acessível.
- Cards de Turmas usam métricas lado a lado; exibem `Professores` e quantidade,
  nunca nome de professor nem `Professores / responsáveis`.
- Modelos e Atividades têm abas Todos, Ativos, Rascunho e Inativos. Origem é um
  filtro próprio; Categorias permite pesquisa. A tabela segue o padrão canônico.
- Criar Atividade abre a página completa usada por edição. Abrir item existente
  mostra `Editar atividade`.
- Duplicação mantém o verbo `Duplicar`, mostra o nome da origem no cabeçalho,
  sugere sufixo incremental `(1)`, `(2)` e permite instituição ou unidades
  compatíveis com o escopo.
- Handles iniciados por `@` aceitam somente ASCII minúsculo, números e hífen,
  sem espaços, acentos, maiúsculas ou caracteres latinos estendidos.
- Instrumentos avaliativos são reordenáveis por arraste quando a plataforma
  suporta ponteiro; teclado mantém alternativa acessível.
- Períodos recusam início posterior ao término e toda ordem inválida entre
  vigência, prazo de lançamento e liberação. A interface diferencia prazo de
  lançamento e liberação para a família e elimina dois `Publicar agora` sem
  contexto.
- Lançamento e fechamento usam toolbar, tabela responsiva, filtros e paginação
  canônicos.
- `/dev/conversations` recebe repository local determinístico. Produção mantém
  `SupabaseChatRepository` e falha fechada quando Supabase não está configurado.

## Segurança e dados

IDs e filtros do cliente não concedem acesso. CRUD produtivo usa somente os
contratos Supabase existentes, com RLS e RPCs validados por ator, capability e
escopo. Nenhuma `service_role`, fixture ou dado reconhecível entra no Flutter.
Mudança remota destrutiva ou deploy não está autorizada implicitamente.

## Fora de escopo

- Tornar importação/exportação funcional onde hoje não existe contrato aprovado.
- Refatoração arquitetural ampla ou substituição do design system.
- Regerar toda a suíte de goldens.
- Criar contratos produtivos novos sem necessidade demonstrada pelo recorte.

## Critérios de aceite

Os fluxos listados funcionam em `/dev`; composição produtiva não usa fixtures;
CRUD existente continua ligado ao Supabase; RLS não é contornada; testes
focados, analyzer dos arquivos alterados, reload e inspeção visual responsiva
passam; os três rastreadores são atualizados sem chamar E2E não executado de
concluído.
