---
title: "Checkpoint da revisão faseada de UI/UX do Superadmin"
source: "Solicitação aprovada do Owner Coelo em 2026-08-03"
status: "completed"
generated_at: "2026-08-03"
updated_at: "2026-08-03"
---

# Checkpoint da revisão faseada de UI/UX do Superadmin

## Concluído

- Paginação sticky compartilhada sem linha superior, blur de 12 px e superfície
  semântica translúcida; migrações concluídas nas listagens aplicáveis.
- Seletor local Cards/Tabela com visão agrupada padrão e flyout acessível por
  mouse, foco, teclado e toque.
- Footer glass compartilhado, medido e responsivo aplicado aos formulários
  revisados, com conteúdo e launcher afastados das ações.
- Instituições e Unidades preservam a visão agrupada e agora materializam linhas
  detalhadas reais por Unidade, Grupo e Atividade, com ancestrais replicados e
  ordenação Instituição → Unidade → Grupo → Atividade.
- Métricas locais solicitadas adicionadas às tabelas e cards, com fixtures
  determinísticas e sem PII real.
- Atividades usa paginação compartilhada, export preview da visão atual, catálogo
  Supercategoria → Categoria → Nome completo e previews locais de foto, conversa
  e publicação `Atividade X · Grupo Y`.
- Pessoas possui filtros progressivos, métricas contextuais pertinentes, busca
  demonstrativa por identificadores fictícios/mascarados, footer compartilhado e
  export preview da visão atual.
- Grupos, Usuários Internos e Perfis/Permissões tiveram formulários e exports
  alinhados; protótipos efêmeros são identificados e a regra perfil-teto/
  atribuição-contexto está visível.
- `/dev/support` abre localmente sem sessão e `/support` produtivo permanece
  autenticado. O seletor de responsável usa `CoeloAdminDialogShell`.
- Chat preserva o launcher recolhido/arrastável/acessível; clique fora fecha em
  estado neutro, ações discretas usam `primaryContainer/primary`, destrutivas
  usam `errorContainer/error` e o launcher respeita os insets medidos.
- Home, Perfil e Configurações foram preservados, com revisão somente de popups
  e regressões compartilhadas.

## Em andamento

- Nenhum lote funcional em andamento. Código pronto para commit e novo localhost.

## Pendente

- Goldens globais não foram regenerados. Uma execução anterior da suíte global
  deixou feedback em `failures/`; esses artefatos foram preservados e ficaram
  fora do commit conforme proteção explícita do worktree.
- Limpeza desses artefatos exige autorização separada do owner.

## Testes

- `dart analyze` completo do Superadmin: `No issues found`.
- Gate funcional final de 21 arquivos focados: 172/172 GREEN, cobrindo componentes
  compartilhados, rotas, diretórios, formulários, Chat, Suporte e shell persistente.
- Validações adicionais dos lotes: Atividades 11/11; Pessoas 44/44; tabelas de
  Instituições/Unidades 57/57; Grupos/Usuários/Perfis 30/30.
- Teste completo de Suporte: 17/17 GREEN.
- Gates Coelo UI de índice e contratos de superfície: PASS.
- Gates Coelo Knowledge de base, consulta e cenários: PASS (`no-op` nesta auditoria;
  as regras duráveis já estavam nas fontes canônicas atualizadas).
- `git diff --check` será repetido sobre o conjunto staged antes do commit.
- A primeira tentativa do gate final teve 167 testes verdes e encerrou apenas por
  um caminho de teste inexistente; a lista foi corrigida e repetida integralmente.

## Decisões

- Escopo estritamente local; Supabase, migrations, RPCs, policies, RLS e
  autorização produtiva permaneceram intocados.
- Hierarquia canônica: Instituição → Unidade → Grupo (Turma) → Atividade contextual.
- Grupo é a entidade; Turma é termo equivalente de apresentação, nunca entidade-pai.
- Dados novos são fixtures/protótipos fictícios ou mascarados.
- `AGENTS.md`, `skills-lock.json`, `RTK.md`, alterações preexistentes e todo
  diretório `failures/` ficam fora do commit.

## Próximo ponto seguro

- Commitar somente o conjunto intencional revisado, encerrar o processo Flutter
  atual e iniciar um novo web-server local na mesma porta, validando PID, porta e logs.

## Revisão visual adicional dos anexos 1–15

### Concluído

- Restaurado o toggle Cards/Tabela segmentado aprovado, sem texto instrucional visível;
  flyout alinhado ao espaçamento dos menus Tour, Arquivos e Perfil.
- Tabelas detalhadas usam a largura natural das colunas, células alinhadas ao centro
  vertical/esquerda e status semântico consistente.
- Cards de Unidade, Grupo e Atividade foram alinhados à geometria de Instituição;
  ações de criação acompanham a altura do card vizinho.
- Pessoas e Perfis/Permissões usam abas sublinhadas abaixo dos filtros; cards de
  Pessoas exibem apenas relações quantitativas, sem Contato ou Papéis.
- Launcher do Chat não recorta ícone/badge e preserva a posição arrastada entre rotas
  durante a navegação local.
- O shell não aplica fade próprio ao trocar destinos.
- Suporte foi renomeado para `Suporte e implantação`; o detalhe expandido fecha sem
  branco e pode ser movido por arraste ou teclado dentro da viewport/SafeArea.
- Login, recuperação e nova senha não exibem seletor de tema.
- `/dev/catalog` abre preview local sem depender do domínio externo.

### Em andamento

- Nenhum lote desta revisão permanece em andamento.

### Pendente

- A análise global conclui com exit code 0 e oito avisos informativos
  preexistentes/concorrentes em `health_care`, fora deste lote; a análise focada
  dos arquivos desta revisão permanece limpa.

### Testes

- Toggle compartilhado: 5/5 GREEN.
- Tabela redimensionável compartilhada: 16/16 GREEN.
- Launcher de Chat: 11/11 GREEN.
- Unidades, Grupos e Atividades: 29/29 GREEN.
- Pessoas, Perfis/Permissões e shell: 77/77 GREEN.
- Suporte, Auth e Catálogo: 64/64 GREEN nos lotes focados; correções de integração
  de Suporte/Catálogo repetidas com 16/16 GREEN.
- `dart analyze` global: exit code 0, somente oito infos concorrentes de
  `health_care`; análise focada do lote e do pacote de tabela: sem issues.
- Gates Coelo UI de índice e superfícies: PASS; gate de memória Coelo: PASS com
  `no-op`, pois nenhuma nova regra de produto ou permissão foi criada.
- O gate de sincronização do Catálogo atualizou o fingerprint da tabela, mas a
  árvore concorrente ainda exporta `CoeloAdminFlyout` e
  `CoeloAdminInteractiveCard` sem entradas de índice; esses componentes não
  pertencem a este lote e foram preservados sem integração antecipada.

### Decisões

- O ajuste adicional permanece exclusivamente local e visual; nenhum artefato
  Supabase foi consultado ou alterado.
- Artefatos em `failures/` e mudanças concorrentes de Attendance, Daily Routine e
  Health/Safety permanecem preservados e fora do escopo desta revisão.

### Próximo ponto seguro

- Commit `20b90fe` criado somente com o escopo intencional. O localhost anterior
  foi encerrado e a nova instância responde HTTP 200 em
  `http://127.0.0.1:8775` (PID 43092).
