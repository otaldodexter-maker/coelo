---
source: "docs/superpowers/specs/2026-08-03-superadmin-operational-surfaces-prototype-design.md"
status: "ready-for-execution"
generated_at: "2026-08-03"
---

# Superadmin Operational Surfaces Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar experiências locais navegáveis de Planos, Importações,
Convites, Avisos e Auditoria no preview Flutter do Superadmin.

**Architecture:** Um store fake no escopo do router mantém atividades e eventos
minimizados durante a sessão. Cada feature conserva modelos, estado e UI locais,
reutilizando o shell e os componentes administrativos aprovados. As tarefas são
sequenciais: a fundação vem primeiro; Auditoria vem por último para consultar os
eventos produzidos pelas demais features.

**Tech Stack:** Flutter, Dart, `go_router`, `ChangeNotifier`, componentes
`coelo_ui_admin`, tokens Coelo e testes Flutter existentes.

## Global Constraints

- Trabalhar somente no Superadmin e somente em rotas `/dev`.
- Usar dados fictícios em memória, restaurados ao recarregar o app.
- Não adicionar Supabase, migration, RLS, RPC, Edge Function ou dependência.
- Não implementar upload, download, envio, aceite ou notificação externos.
- Não criar botão primário no cabeçalho dos diretórios.
- Cards usam o primeiro card tracejado para criar; tabela usa uma faixa de
  criação separada antes da tabela; Auditoria não cria registros.
- Reutilizar `CoeloAdminListingToolbar`, `CoeloAdminResizableTable`,
  `CoeloAdminPagination`, `CoeloAdminDialogShell`, filtros, campos e tokens já
  aprovados. Não criar alternativa local quando o componente existente atende.
- Decidir composição por `LayoutBuilder` e largura disponível; validar 375, 768,
  1024 e 1440 px.
- Preservar light/dark, texto a 200%, teclado, foco, semântica e reduced motion.
- Nunca usar arquivos em `failures/` como referência visual.
- Antes de editar, ler `AGENTS.md`, `RTK.md`, a spec fonte, a skill `coelo-ui` e
  os contratos indicados por ela.
- Usar `rtk` nos comandos de terminal e `apply_patch` nas edições.
- Preservar todas as alterações preexistentes do worktree; não limpar, reverter
  ou incluir arquivos alheios em commits.
- Aplicar TDD: teste falhando, implementação mínima, teste passando.
- Ao terminar cada tarefa, executar testes focados, `dart format` e
  `dart analyze`; não atualizar goldens para esconder regressões.

---

### Task 1: Fundação fake compartilhada

**Files:**
- Create: `apps/superadmin/lib/app/prototype/superadmin_prototype_store.dart`
- Test: `apps/superadmin/test/app/prototype/superadmin_prototype_store_test.dart`
- Modify only if needed: `apps/superadmin/lib/app/router/superadmin_router.dart`

**Interfaces:**
- Produces: `SuperadminPrototypeStore`, `PrototypeAuditEvent`,
  `recordActivity(...)`, `recordAuditEvent(...)` and read-only `auditEvents`.
- Consumes: existing `SuperadminActivityController` and `SuperadminActivity`.

- [ ] **Prompt 1 — execute exactly this scope**

```text
Você está no monorepo Coelo. Implemente apenas a fundação fake compartilhada
para os futuros previews operacionais do Superadmin.

Leia integralmente AGENTS.md, RTK.md,
docs/superpowers/specs/2026-08-03-superadmin-operational-surfaces-prototype-design.md,
.agents/skills/coelo-ui/SKILL.md e os contratos apontados pela skill. Use também
ponytail full, flutter-build-responsive-layout, test-driven-development e
verification-before-completion. Consulte o índice Coelo UI antes de decidir.

Contexto atual:
- apps/superadmin/lib/app/activity/superadmin_activity.dart já contém
  SuperadminActivity e SuperadminActivityController;
- apps/superadmin/lib/app/router/superadmin_router.dart já cria controllers de
  preview e deve ser o dono do estado de sessão;
- o worktree está sujo: preserve tudo que não pertence a esta tarefa.

Faça TDD e crie o menor store em memória que sustente os próximos prompts:
- SuperadminPrototypeStore recebe/reutiliza SuperadminActivityController;
- mantém uma lista imutável para consumidores de PrototypeAuditEvent;
- recordActivity(...) encaminha a atividade ao controller existente;
- recordAuditEvent(...) registra somente ID, instante, ator fake, módulo, ação,
  tipo/ID do objeto, contexto opcional, risco, motivo opcional, MFA simulado,
  before/after minimizado e referência relacionada opcional;
- o relógio deve ser injetável para testes determinísticos;
- o store vive no escopo do router de preview e reinicia ao recarregar;
- não crie interface, service locator, package, persistência ou abstração para
  um segundo backend inexistente.

Teste no mínimo: ordem mais recente primeiro, lista externa imutável, encaminhar
atividade uma única vez e registrar before/after sem mapas mutáveis vazando.
Não crie rotas nem telas nesta tarefa.

Rode:
rtk flutter test test/app/prototype/superadmin_prototype_store_test.dart
rtk dart format lib/app/prototype test/app/prototype
rtk dart analyze

Trabalhe em apps/superadmin. Ao final, relate arquivos, testes e qualquer risco;
não faça commit de mudanças alheias.
```

---

### Task 2: Planos

**Files:**
- Create: `apps/superadmin/lib/features/plans/domain/plan_catalog.dart`
- Create: `apps/superadmin/lib/features/plans/data/fake_plan_catalog_repository.dart`
- Create: `apps/superadmin/lib/features/plans/presentation/plan_directory_view_model.dart`
- Create: `apps/superadmin/lib/features/plans/presentation/plan_directory_page.dart`
- Create: `apps/superadmin/lib/features/plans/presentation/plan_form_page.dart`
- Test: matching files under `apps/superadmin/test/features/plans/`
- Modify: `apps/superadmin/lib/app/router/superadmin_routes.dart`
- Modify: `apps/superadmin/lib/app/router/superadmin_router.dart`
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`

**Interfaces:**
- Consumes: `SuperadminPrototypeStore` from Task 1.
- Produces: dev-only plan routes and local audit/activity events.

- [ ] **Prompt 2 — execute after Prompt 1**

```text
Implemente a experiência local navegável de Planos no preview do Superadmin.
Leia AGENTS.md, RTK.md, a spec aprovada em
docs/superpowers/specs/2026-08-03-superadmin-operational-surfaces-prototype-design.md,
o Prompt 1 já implementado, a skill coelo-ui e seus contratos de diretórios,
formulários, superfícies e interação. Use ponytail full,
flutter-build-responsive-layout, TDD e verification-before-completion.

Antes de editar, compare com Instituições:
- apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart
- apps/superadmin/lib/features/institutions/presentation/screens/institution_form_page.dart
- apps/superadmin/test/features/institutions/presentation/screens/

Crie uma feature local plans com repository fake compartilhado durante a sessão,
view model, diretório e formulário de página. Adicione somente rotas /dev/plans,
/dev/plans/new e /dev/plans/:planId/edit. Ative o destino Planos somente no
preview; rotas produtivas continuam inexistentes.

O diretório deve ter busca, filtros por status/recursos, toggle cards/tabela,
paginação e estados loading/content/empty/no-results/error/unauthorized.
Não coloque botão de criar no cabeçalho. Cards usam primeiro card tracejado
“Novo plano”; tabela usa faixa separada “Criar novo plano” antes da tabela.

Fixtures obrigatórios:
- Coelo Essencial (coelo-essential): Comunicação, Agenda e Convites; 2 unidades,
  500 usuários, 2 responsáveis por criança, 25 GB de armazenamento e 5 GB de mídia.
- Coelo Conecta (coelo-connect): anterior + Chat e Avisos; 5 unidades, 1.500
  usuários, 3 responsáveis, 100 GB e 20 GB de mídia.
- Coelo Cuidado (coelo-care): anterior + Rotina, Flow e Now; 15 unidades, 5.000
  usuários, 4 responsáveis, 500 GB e 100 GB de mídia.
- Coelo Integral (coelo-integral): todos + Moments; 50 unidades, 20.000 usuários,
  6 responsáveis, 2 TB e 500 GB de mídia.

O formulário separa Identidade, Recursos, Limites e Operação, reutiliza campos e
single-select aprovados e adapta duas colunas para uma por LayoutBuilder. Criar
e editar atualizam a lista local e geram atividade + auditoria fake. Plano com
usedByInstitutionCount > 0 só pode ser arquivado; plano nunca usado pode ser
excluído após confirmação negativa. Não implemente cobrança ou atribuição por
instituição.

Teste os fixtures, busca/filtros, criação dentro do conteúdo, validação, edição,
arquivamento, exclusão permitida/bloqueada, rotas somente /dev, emissão única de
atividade/auditoria e layout em 375/768/1024/1440. Adicione goldens mínimos
mobile light e desktop dark sem tocar failures.

Rode testes focados, rtk dart format nos arquivos tocados e rtk dart analyze.
Relate a verificação e preserve mudanças alheias.
```

---

### Task 3: Importações

**Files:**
- Create: `apps/superadmin/lib/features/imports/domain/import_job.dart`
- Create: `apps/superadmin/lib/features/imports/data/fake_import_repository.dart`
- Create: `apps/superadmin/lib/features/imports/presentation/import_directory_page.dart`
- Create: `apps/superadmin/lib/features/imports/presentation/import_wizard_page.dart`
- Create: `apps/superadmin/lib/features/imports/presentation/import_wizard_controller.dart`
- Test: matching files under `apps/superadmin/test/features/imports/`
- Modify: router, routes and shell files listed in Task 2.

**Interfaces:**
- Consumes: `SuperadminPrototypeStore` and existing activity center.
- Produces: dev-only import routes, local jobs and audit/activity events.

- [ ] **Prompt 3 — execute after Prompt 2**

```text
Implemente a central local navegável de Importações do Superadmin, sem I/O real.
Leia AGENTS.md, RTK.md, a spec aprovada, a fundação já implementada e coelo-ui
com contratos de diretórios, formulários e dialogs. Use ponytail full,
flutter-build-responsive-layout, TDD e verification-before-completion.

Crie a feature imports com repository fake de sessão, diretório e wizard de
página. Adicione somente /dev/imports e /dev/imports/new; ative Importações
somente no preview.

O diretório segue Instituições: busca, filtros por entidade/status/instituição/
ator/período, cards/tabela, paginação e estados completos. Sem ação no cabeçalho:
use card “Nova importação” ou faixa “Iniciar nova importação”. Cada job mostra
arquivo, entidade, destino, progresso, ator, data e resultado.

O wizard tem seis etapas: entidade/contexto; arquivo; mapeamento; estratégia;
prévia/conflitos; confirmação/acompanhamento. Entidades: Instituições, Unidades,
Grupos, Pessoas e Usuários internos. “Selecionar arquivo” escolhe fixtures CSV ou
XLSX conhecidos; “Baixar modelo” apenas gera uma atividade informativa. Não use
file picker, parser ou filesystem.

Permita “Criar apenas” e “Criar e atualizar”. Mostre chave de correspondência,
mapeamento origem→destino, 8 linhas de prévia e conflitos determinísticos por
campo/linha. O resultado separa criados, atualizados, ignorados e rejeitados.
Confirmar fecha o wizard para a central e progride 0/25/55/80/100 por timers
curtos cancelados no dispose. Progresso aparece no sininho; conclusão gera um
evento minimizado de auditoria. Reduced motion afeta transições visuais, não o
estado do job.

No amplo, stepper lateral; no compacto, indicador superior e uma coluna. O
rodapé preserva rascunho ao voltar e segue a hierarquia aprovada.

Teste todos os tipos de entidade, as duas estratégias, mapeamento, conflito,
cancelamento de timer, resumo, card/faixa de criar, evento local e matriz
375/768/1024/1440. Use relógio/timers controláveis para testes estáveis. Adicione
goldens mínimos e rode testes focados, format e analyze.
```

---

### Task 4: Convites

**Files:**
- Create: `apps/superadmin/lib/features/invites/domain/platform_invite.dart`
- Create: `apps/superadmin/lib/features/invites/data/fake_invite_repository.dart`
- Create: `apps/superadmin/lib/features/invites/presentation/invite_directory_page.dart`
- Create: `apps/superadmin/lib/features/invites/presentation/invite_form_page.dart`
- Create: `apps/superadmin/lib/features/invites/presentation/invite_detail_page.dart`
- Test: matching files under `apps/superadmin/test/features/invites/`
- Modify: router, routes and shell files listed in Task 2.

**Interfaces:**
- Consumes: `SuperadminPrototypeStore`.
- Produces: dev-only invite routes and minimized local events.

- [ ] **Prompt 4 — execute after Prompt 3**

```text
Implemente a experiência local navegável de Convites no preview do Superadmin.
Leia AGENTS.md, RTK.md, a spec aprovada, a fundação implementada e os contratos
coelo-ui aplicáveis. Use ponytail full, responsive layout, TDD e verificação.

Crie a feature invites com repository fake de sessão, diretório, formulário de
página e detalhe. Adicione somente /dev/invites, /dev/invites/new e
/dev/invites/:inviteId. Ative Convites somente em /dev.

Públicos: equipe interna Coelo, owners/administradores, profissionais,
responsáveis e demais pessoas vinculadas. Estados: draft, pending, accepted,
expired, revoked e failed. Canais fictícios: e-mail, celular e link copiável.

O diretório segue o padrão aprovado, sem botão no cabeçalho; use card/faixa de
novo convite. Inclua busca e filtros por público, instituição, unidade, grupo,
papel, canal, status e período. O formulário contextual segue: público;
hierarquia/escopo; papel/finalidade; destinatário; canal; expiração; revisão.
Validade padrão exata: 48 horas a partir do relógio injetado, editável.

O detalhe mostra linha do tempo. Permita copiar link, revogar e reenviar convites
pending ou expired. Reenvio cria uma URL fake nova, marca a anterior inválida e
reinicia a expiração; não gere token seguro nem faça rede. Não permita reenviar
accepted ou revoked. Cada envio, reenvio e revogação registra atividade e evento
minimizado, sem e-mail/celular completos no log.

Teste validade de 48h, alteração manual, filtros, regras de reenvio/revogação,
mascaramento do destinatário, invalidação do link, rotas /dev, eventos únicos e
responsividade. Use relógio fixo. Adicione goldens mínimos e rode testes focados,
format e analyze.
```

---

### Task 5: Avisos

**Files:**
- Create: `apps/superadmin/lib/features/notices/domain/platform_notice.dart`
- Create: `apps/superadmin/lib/features/notices/data/fake_notice_repository.dart`
- Create: `apps/superadmin/lib/features/notices/presentation/notice_directory_page.dart`
- Create: `apps/superadmin/lib/features/notices/presentation/notice_form_page.dart`
- Create: `apps/superadmin/lib/features/notices/presentation/notice_preview_dialog.dart`
- Test: matching files under `apps/superadmin/test/features/notices/`
- Modify: router, routes and shell files listed in Task 2.

**Interfaces:**
- Consumes: `SuperadminPrototypeStore`.
- Produces: dev-only notice routes and local publication/acceptance events.

- [ ] **Prompt 5 — execute after Prompt 4**

```text
Implemente a experiência local navegável de Avisos oficiais no preview do
Superadmin. Não confunda com avisos familiares de presença. Leia AGENTS.md,
RTK.md, a spec aprovada, a fundação e coelo-ui, incluindo contratos de
diretórios, formulários, dialogs, ações e hierarquia negativa. Use ponytail
full, responsive layout, TDD e verificação.

Crie notices com repository fake de sessão, diretório, editor de página e
preview do popup. Adicione somente /dev/notices, /dev/notices/new e
/dev/notices/:noticeId/edit; ative Avisos somente no preview.

O diretório usa cards/tabela, paginação, estados e criação dentro do conteúdo.
Filtros: status, prioridade, obrigatoriedade, vigência e audiência. Estados:
draft, scheduled, active, ended e cancelled. Mostre alcance, entregues,
visualizados e aceites fictícios.

O editor contém título, mensagem, prioridade, início/fim, imagem/anexo fake,
audiência, comportamento, rótulo do botão e link opcional. Audiência trabalha
somente com destinatários identificados: todos, equipe Coelo, instituição,
unidade, grupo, papel ou pessoa. Não importe widgets internos da feature chat;
componha com seleções administrativas existentes e dados fake locais.

Comportamentos permitidos: apenas fechar; confirmação obrigatória; checkbox de
aceite + confirmar. Imagem/anexo usa fixture e prévia, sem picker ou arquivo.
O preview usa CoeloAdminDialogShell, surface/tint aprovados, barreira preta,
ações irmãs iguais e X vermelho apenas quando dispensável.

Aviso opcional dispensado não reaparece para o destinatário fake. Aviso
obrigatório impede continuar a navegação no modo de simulação, permite sair do
app e reaparece no próximo acesso simulado enquanto não aceito. Não bloqueie o
shell real fora do preview do aviso. Permita editar rascunho/agendado, duplicar,
publicar, cancelar e consultar resultados. Publicação, cancelamento e aceite
geram eventos locais minimizados.

Teste audiência hierárquica, vigência, três comportamentos, preview, bloqueio,
saída permitida, aceite, duplicação, criação dentro do conteúdo, eventos e
375/768/1024/1440. Adicione goldens mobile light/desktop dark e rode testes,
format e analyze.
```

---

### Task 6: Auditoria e integração final

**Files:**
- Create: `apps/superadmin/lib/features/audit/presentation/audit_directory_page.dart`
- Create: `apps/superadmin/lib/features/audit/presentation/audit_detail_panel.dart`
- Test: matching files under `apps/superadmin/test/features/audit/`
- Test: `apps/superadmin/test/features/operational_prototype_integration_test.dart`
- Modify: router, routes and shell files listed in Task 2.

**Interfaces:**
- Consumes: `SuperadminPrototypeStore.auditEvents`.
- Produces: dev-only read-only Audit route and final integration coverage.

- [ ] **Prompt 6 — execute after Prompt 5**

```text
Implemente Auditoria somente leitura e feche a integração local das cinco
features. Leia AGENTS.md, RTK.md, a spec aprovada, o store e as quatro features
já implementadas. Leia coelo-ui e os contratos de diretório, tabela, filtros,
painéis e ações. Use ponytail full, responsive layout, TDD e verificação.

Crie a tela /dev/audit e ative Auditoria somente em preview. Não crie rota de
novo/editar, card de criação, faixa de criação, botão de mutação ou exportação.

No amplo, use CoeloAdminResizableTable; no compacto, cards. Busca por ID, ator,
ação ou objeto. Filtros por período, módulo, ação, ator, instituição/contexto e
risco. Colunas: data/hora, ator, módulo, ação, objeto, contexto e risco. Use
paginação aprovada e estados loading/content/empty/no-results/error/unauthorized.

O detalhe responsivo exibe ID, instante, ator fake, escopo, motivo, origem, MFA
simulado, before/after minimizado e referência ao plano, importação, convite ou
aviso. Não exiba PII, destinatário completo, mensagem integral, token, link ou
conteúdo de arquivo. Risco e status nunca dependem apenas de cor.

Inclua 8 fixtures iniciais cobrindo os quatro módulos e riscos baixo/médio/alto,
e una-os aos
eventos gerados na sessão, mais recentes primeiro. Não permita alterar ou
remover eventos.

Escreva um teste integrado local que faça uma mutação válida em cada feature e
comprove uma atividade no sininho e exatamente um evento correspondente na
Auditoria. Teste filtros, detalhe minimizado, somente leitura, ausência de
conteúdo sensível, teclado e matriz responsiva. Adicione goldens mínimos.

Rode todos os testes focados das cinco features e app/prototype, depois:
rtk dart format lib test
rtk dart analyze

Faça o gate coelo-knowledge: atualize primeiro fonte canônica se uma decisão
durável nova foi necessária; caso contrário valide e relate no-op. Não altere
goldens em failures e não inclua mudanças preexistentes em commits.
```

## Execution Order

1. Prompt 1 — fundação fake compartilhada.
2. Prompt 2 — Planos.
3. Prompt 3 — Importações.
4. Prompt 4 — Convites.
5. Prompt 5 — Avisos.
6. Prompt 6 — Auditoria e integração final.

Cada prompt termina com software navegável e testes focados. Não executar os
prompts em paralelo porque router, shell e store são arquivos compartilhados.
