---
title: "Pendências Coelo — Flutter por tela e ação"
source: "AGENTS.md; .agents/skills/coelo-flutter-review/SKILL.md; .agents/skills/coelo-ui/SKILL.md; .agents/skills/coelo-ui/references/approved-superadmin-visual-baselines.md; .agents/skills/coelo-ui/references/interactive-state-evidence-matrix.md; .agents/skills/coelo-ui/references/rejected-visual-patterns-inbox.md; docs/design/design-system.md; specs/013-ui-packages-componentization.md; decisions/0022-superadmin-activities-and-identity-storage.md; docs/open-questions.md; docs/reviews/2026-08-25-coelo-ui-code-review-pendencias.md; docs/reviews/coelo-flutter-integrado-supabase-pendencias.md; apps/superadmin/lib/app/router/superadmin_routes.dart; Git HEAD 6dedcb79c02fd997eae0f0c5727bf63acb51be3d"
status: "open"
generated_at: "2026-08-26"
updated_at: "2026-08-27"
action_count: 207
family_count: 37
---

# Pendências Coelo — Flutter por tela e ação

## 1. Finalidade e leitura obrigatória

Este é o rastreador vivo das pendências de **Flutter e Dart** do Coelo. Ele deve
ser lido integralmente quando o pedido envolver revisão profunda, auditoria,
correção, componentização, responsividade, acessibilidade, Design System,
navegação, estados de tela ou confirmação de que uma tela Flutter está pronta.

Ele não comprova Supabase nem conclusão ponta a ponta. Para isso, ler também:

- `docs/reviews/coelo-supabase-pendencias.md` para banco, Auth, RLS, RPCs, Edge,
  Storage, migrations e segurança;
- `docs/reviews/coelo-flutter-integrado-supabase-pendencias.md` para o fluxo real
  entre cliente e backend.

### Contrato de abertura da atividade

Antes de corrigir, listar as pendências conhecidas e registrar o recorte:

| Campo | Preenchimento obrigatório |
|---|---|
| Modalidade | Todas as pendências; todas as telas; macrotema; macrotema + telas; telas específicas; ou ações específicas. |
| Objetivo | Resultado concreto esperado nesta atividade. |
| Incluído | Telas, subtelas, `screen_id`, `action_id` e macrotemas trabalhados. |
| Fora de escopo | Pendências conhecidas que não serão tratadas agora. |
| Ordem | Sequência de execução e dependências. |
| Critério de parada | Condição verificável para encerrar ou pausar o recorte. |
| Evidências | Análises, testes, interações, tamanhos, escalas e comparações esperadas. |
| Estimativa | Tempo por fatia e total, com premissas e bloqueios. |

Se o pedido já informar o recorte, confirmá-lo e prosseguir. Se não informar,
fazer somente a inspeção necessária, apresentar as pendências e pedir a escolha
antes de modificar código. Concluir o recorte não significa que as demais
pendências, telas ou ações foram concluídas.

## 2. O que significa “Flutter 100%”

Uma **ação**, não apenas a rota, só recebe `verified` quando todos os itens
aplicáveis abaixo têm evidência atual:

1. A rota produtiva abre pelo menu, link direto, voltar/avançar e recarregamento.
2. Carregamento, vazio, sem resultado, sucesso, erro, nova tentativa, sem
   permissão e indisponível estão tratados sem dados falsos.
3. Lista, Cards, tabela, filtros, flyout, diálogos, calendário, wizard e
   formulários usam os componentes e tokens canônicos da skill `coelo-ui`.
4. A página usa o contêiner macro do shell e mantém hierarquia, espaçamento,
   tipografia, foco, hover e ações iguais às baselines aprovadas.
5. Componentes repetidos foram extraídos; widgets gigantes, regras de negócio
   no `build` e duplicação relevante têm pendência explícita ou foram corrigidos.
6. A experiência funciona em larguras representativas de celular, tablet e web,
   com texto em 100%, 150% e 200%, sem corte, sobreposição ou perda de ação.
7. Teclado, foco, Escape, semântica, contraste e alvos de toque foram verificados.
8. Criar, editar, publicar, arquivar, excluir, enviar, importar ou qualquer outra
   ação aplicável possui feedback, prevenção de duplo envio e tratamento de erro.
9. `dart analyze`, testes unitários, de widget, de navegação e regressões visuais
   aplicáveis passam no estado atual, sem apenas atualizar uma imagem de referência.
10. A evidência contém arquivo/rota, comando, resultado e data. “Abriu aqui” não
    é evidência suficiente.

Uma tela com apenas mock, fixture, repository fake, rota `/dev`, estado
`fail-closed`, teste isolado ou aparência correta continua aberta.

## 3. Estados permitidos

| Estado | Significado simples |
|---|---|
| `not-reviewed` | Ainda não houve verificação atual. |
| `audited` | Foi inspecionada; ainda existem pendências ou falta prova. |
| `in-progress` | Há correção Flutter em andamento. |
| `local-green` | Testes locais passaram, mas faltam gates ou revisão final. |
| `blocked-decision` | Uma decisão de produto, jurídica ou arquitetural impede avanço seguro. |
| `verified` | Todos os itens aplicáveis de “Flutter 100%” foram comprovados. |
| `regressed` | Já esteve verde, mas uma mudança posterior quebrou a evidência. |

Somente `verified` fecha o lado Flutter. O estado geral integrado continua no
rastreador ponta a ponta.

### Glossário em linguagem simples

| Termo | O que significa aqui |
|---|---|
| `screen_id` | Nome curto e estável de uma família de telas. |
| `action_id` | Nome curto de uma ação específica, como criar ou editar. |
| baseline | Referência aprovada usada para comparar o que está sendo revisado. |
| golden | Imagem aprovada que um teste compara com a tela atual. |
| smoke test | Verificação rápida de que a tela abre e o essencial responde. |
| `54/54` | Foram executados 54 testes e todos os 54 passaram; não significa que todos os testes possíveis existem. |
| texto 200% | Simulação da fonte com o dobro do tamanho normal para verificar acessibilidade. |
| `verified` | O lado Flutter dessa ação cumpriu todos os critérios aplicáveis e possui evidência atual. |

## 4. Orçamento e níveis de correção

Se o tempo total ainda não foi informado, perguntar primeiro: **“Quanto tempo
total você quer investir nesta atividade?”**. Depois da resposta, reler as
pendências, recalcular as estimativas e recomendar um pacote. Nenhuma correção
começa antes da confirmação do usuário.

| Nível | O que inclui | O que não promete | Evidência esperada | ETA inicial |
|---|---|---|---|---:|
| Básica | Ajuste pequeno, local e de baixo risco. | Não fecha arquitetura, regressão nem tela. | Teste focado e diff revisado. | 30–90 min por ação simples |
| Intermediária | Básica + problemas principais, contratos Coelo e testes proporcionais. | Pode deixar ações e estados secundários abertos. | Testes da ação, analyzer proporcional e inspeção do fluxo. | 2–6 h por ação ou tela simples |
| Avançada | Anteriores + ações aplicáveis, arquitetura, estados, acessibilidade, responsividade e regressões. | Não conclui se restar qualquer pendência aplicável. | Matriz funcional, visual e técnica atual. | 1–2 dias por tela |
| Completa | Todas as pendências aplicáveis do recorte e evidências finais. | Não certifica Supabase; isso pertence ao rastreador integrado. | Todos os critérios de “Flutter 100%” verdes. | 2–5 dias por tela |

**Intermediária é o MÍNIMO RECOMENDADO.** Risco pode elevar o mínimo. Auth,
permissões, segurança e dados sensíveis não recebem recomendação Básica.
Somente Completa pode sustentar que uma tela Flutter foi integralmente concluída.
Executar Básica, Intermediária ou Avançada não muda automaticamente o estado
para “verified”.

### Tabela geral obrigatória

Os níveis são cumulativos: Intermediária inclui Básica; Avançada inclui
Intermediária; Completa inclui Avançada. As faixas são referências iniciais por
ação ou tela simples e devem ser recalculadas pelo número de ações, dependências,
complexidade, decisões, riscos e regressões do recorte.

| Nível | O que corrige | O que pode continuar pendente | Estimativa inicial | Quando aconselhar |
| --- | --- | --- | ---: | --- |
| Básica | Falha pequena, reprodução e teste focado. | Demais ações, arquitetura, acessibilidade, responsividade e regressão. | 30–90 min | Somente item pequeno e de baixo risco. |
| Intermediária | Básica + problemas principais, componentes canônicos e testes proporcionais. | Ações secundárias, estados amplos e regressão completa. | 2–6 h | Mínimo aconselhado para correção relevante. |
| Avançada | Intermediária + ações relacionadas, arquitetura, estados, acessibilidade e responsividade. | Pendências finais ou itens fora do recorte. | 1–2 dias | Telas complexas e problemas compartilhados. |
| Completa | Avançada + todas as pendências aplicáveis e evidências finais. | Apenas bloqueios externos e Supabase. | 2–5 dias | Obrigatória para declarar a tela Flutter concluída. |

### Aplicação dos quatro níveis a cada ação

Na matriz por ação, as colunas usam os códigos abaixo. O código sempre se aplica
à pendência concreta daquela linha; não é uma autorização genérica para alterar
outras ações da mesma tela.

| Código | Entrega aplicada à ação | O que continua aberto |
|---|---|---|
| `B` | Reproduzir; corrigir uma falha pequena e de baixo risco; executar o menor teste local que falharia sem a correção. | A própria ação não fica `verified`; permanecem contratos amplos, estados, acessibilidade, responsividade e regressão. |
| `I` | `B` + corrigir os problemas principais; aplicar componentes/contratos Coelo UI existentes; testar sucesso e falha proporcionais. | Podem restar ações relacionadas, estados secundários, matriz visual completa e regressão global. |
| `A` | `I` + fechar estados alcançáveis e arquitetura da ação; validar 375/768/1024/1440, texto 100%/150%/200%, light/dark, teclado, foco, `Esc`, semântica e regressões relevantes. | Podem restar pendências finais da tela, goldens específicos ou decisões externas. |
| `C` | `A` + resolver todas as pendências Flutter aplicáveis da ação e reunir evidência final atual. | Somente bloqueio externo/Supabase; a tela só pode ser concluída se todas as suas ações aplicáveis também estiverem em `C` e `verified`. |

**Regra de decisão:** a célula `B`, `I`, `A` ou `C` não afirma que o trabalho foi
executado; descreve o pacote que seria contratado. A coluna “Nível aconselhado”
é a recomendação mínima para atacar a causa com segurança. Básica nunca conclui
uma ação ou tela. Completa pode concluir uma ação Flutter; só conclui a tela
quando todas as linhas aplicáveis da tela cumprirem a definição de `verified`.

### Temas gerais e nível mínimo aconselhado

| ID | Tema | Mínimo | ETA inicial | Motivo |
|---|---|---|---:|---|
| FLU-GEN-001 | Rotas, menus e links diretos | Intermediária | 8 h | Abrange navegação compartilhada e regressão. |
| FLU-GEN-002 | Fakes, fixtures e composição produtiva | Avançada | 12 h | Pode mascarar ausência de implementação real. |
| FLU-GEN-003 | Shell, componentes e padrões Coelo UI | Avançada | 24 h | Afeta todas as famílias e a baseline Instituição. |
| FLU-GEN-004 | Hover, tokens, tipografia e superfícies | Intermediária | 16 h | Exige correção visual sistemática, não pontual. |
| FLU-GEN-005 | Widgets grandes, estado e arquitetura | Avançada | 24 h | Envolve causa raiz e concorrência. |
| FLU-GEN-006 | Responsividade e escala de texto | Avançada | 48 h | Precisa provar larguras e texto até 200%. |
| FLU-GEN-007 | Teclado, foco e acessibilidade | Avançada | 36 h | Falhas podem impedir uso da aplicação. |
| FLU-GEN-008 | Imagens de referência visual | Avançada | 40 h | Cada divergência precisa de decisão consciente. |
| FLU-GEN-009 | Erros, nova tentativa e duplo envio | Avançada | 32 h | Pode gerar comandos repetidos ou feedback falso. |
| FLU-GEN-010 | Analyzer e regressão global | Intermediária | 8 h | É o gate técnico mínimo do recorte. |
| FLU-GEN-011 | Catálogo e fingerprints | Intermediária | 6 h | Há regressão conhecida e decisão pendente. |
| FLU-GEN-012 | Contratos ainda não decididos | Avançada após decisão | Externo | Não se deve inventar comportamento de produto. |

### Nível mínimo por família e ações

O mínimo abaixo serve para atacar o risco principal. Se o objetivo declarado for
“concluir a tela”, o pacote exigido é **Completa**, mesmo quando a coluna diga
Intermediária ou Avançada.

| screen_id | Ações abrangidas | Mínimo aconselhado | ETA inicial atual | Motivo principal |
|---|---|---|---:|---|
| auth | login, recuperar, redefinir, sair, MFA | Avançada | 6 h | Sessão, segurança, teclado e erros. |
| shell | carregar, navegar, trocar contexto, negar, recarregar | Avançada | 6 h | Estrutura compartilhada por todas as telas. |
| institutions | listar, filtrar, detalhe, criar, editar, status, arquivos, importar, exportar, erro/retry, acesso negado e recarregar | Avançada | 16 h | Baseline visual e funcional administrativa; doze ações independentes. |
| units | listar, filtrar, criar, editar, status, importar, exportar, erro, acesso negado e recarregar | Avançada | 13 h | Diretório local está verde; commands, arquivos produtivos e regressão visual continuam abertos. |
| groups | listar, criar, editar, membros, importar, exportar | Avançada | 8 h | CRUD, membros e arquivos precisam regressão. |
| people | listar, criar, editar, vínculos, recarregar | Avançada | 12 h | Identidade produtiva e oito imagens abertas. |
| access_profiles | listar, criar, detalhe, editar, atribuir, excluir | Avançada após decisão | 16 h | Permissões e contrato estendido. |
| access_models | listar, filtrar, criar, detalhe, editar, duplicar | Avançada após decisão | 11 h | Capabilities, filtros e CRUD estão bloqueados; excluir existe apenas no contrato futuro. |
| invites | listar, criar, detalhe, reenviar, revogar | Intermediária | 8 h | UI existe; faltam estados e confirmações. |
| activities | listar, wizard, detalhe, editar, publicar, avaliar | Avançada | 12 h | Wizard, calendário e commands reais. |
| assessments | lançar, diário, fechar, reabrir, detalhe | Avançada | 10 h | Contrato existe; páginas e regressões faltam. |
| students | listar, vincular, transferir, editar, revogar | Avançada após decisão | 8 h | Produção ainda é somente leitura. |
| attendance | painel, criar, marcar, corrigir, concluir, exportar | Avançada | 12 h | Commands, relógio, erros e exportação. |
| daily_routine | listar, criar, editar, aplicar, publicar | Avançada | 8 h | Produção indisponível e regressão visual. |
| agenda | calendário, criar, detalhe, editar, solicitar, permissões | Avançada após decisão | 16 h | Spec e permissões ainda não fechadas. |
| chat | conversas, abrir, enviar, editar, anexar, recibos, revogar | Avançada | 16 h | Mídia, foco, erros e ciclo completo. |
| notices | listar, criar, editar, agendar, publicar, arquivar | Avançada | 10 h | Só a composição de rota foi conhecida. |
| forms_authoring | listar, criar, overview, editar, publicar, testar | Completa | 16 h | Editor, publicação e catálogo bloqueados. |
| forms_responses | monitorar, responder, listar, detalhe, exportar | Completa | 12 h | Fluxo real e autorização ainda faltam. |
| forms_files | upload, resolver, baixar, expirar, excluir | Completa | 12 h | Ciclo protegido de arquivo é indivisível. |
| acontece | feed, criar, publicar, remover | Avançada após decisão | 10 h | Preview não prova publicação e mídia reais. |
| agora | visualizar, criar, publicar, expirar | Avançada após decisão | 8 h | Entrada e ciclo real permanecem abertos. |
| momentos | visualizar, criar, publicar, remover | Avançada após decisão | 8 h | Origem, mídia e publicação reais faltam. |
| principal_profile | Para Você, perfil, editar | Avançada após decisão | 8 h | Preview estático não conclui edição real. |
| child_safety | listar, criança, criar, editar, suspender | Completa | 10 h | Dados de criança e lifecycle sensível. |
| health_care | listar, criar, detalhe, editar | Completa | 12 h | Dados sensíveis e contrato de detalhe. |
| medication | listar, criar, detalhe, editar, evidência | Completa após decisão | 12 h | Segurança e decisão jurídica/produto. |
| imports | hub, criar, upload, preview, confirmar, status, baixar | Avançada | 16 h | Proveniência, arquivos e backend amplo. |
| profile_files | importar, preview, confirmar, status, exportar, baixar | Completa | 12 h | Arquivos privados e lifecycle completo. |
| audit | listar, filtrar, detalhe, exportar | Avançada | 8 h | Dados sanitizados e exportação. |
| support | criar, tabela, kanban, detalhe, responder, encerrar | Avançada | 8 h | Ações negativas e detalhe permanecem. |
| account | perfil, configurações, tema, MFA, sessões, sair | Avançada | 8 h | Sessões, MFA e segurança da conta. |
| catalog | listar, validar, sincronizar, publicar | Intermediária | 6 h | Regressão técnica conhecida. |
| plans | listar, criar, editar, ativar, atribuir | Avançada após decisão | 10 h | Ativação e atribuição não foram definidas. |
| meal_plans | listar, criar, editar, modelos, publicar | Avançada após decisão | 12 h | Lifecycle e publicação estão abertos. |
| internal_users | listar, criar, editar, suspender, MFA | Completa | 10 h | Usuários privilegiados, suspensão e MFA. |
| error_pages | 403, 404, 409, 500, 503, tentar novamente | Intermediária | 6 h | Fluxos transversais e recuperação. |

## 5. Matriz decisória por tela, subtela e ação

Cada linha é uma ação independente. `B`, `I`, `A` e `C` têm o significado
definido na seção anterior. A estimativa é a parcela incremental da família no
nível aconselhado e inclui os testes proporcionais; itens que compartilham
setup, componente ou regressão devem ser contratados em pacote para evitar soma
duplicada. A soma preliminar por família continua na tabela anterior.

### 5.1 Identidade, shell e cadastros estruturais

| Ordem | Tela/subtela | Ação | Pendência Flutter | Estado atual | Básica | Intermediária | Avançada | Completa | Nível aconselhado | Estimativa | Evidência para conclusão |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | --- |
| 1.1 | Auth / Login | `auth.login` | Fluxo local, erros e matriz responsiva revalidados; integração Auth remota e rota global continuam fora da prova. | `local-green` | B | I | A | C | Avançada | 1 h | Login válido/inválido, 375/768/1024/1440, 200%, foco e erro; E2E remoto separado. |
| 1.2 | Auth / Recuperar senha | `auth.recover` | Envio, erro, reenvio, anúncio e matriz responsiva passaram localmente; entrega remota do link não foi certificada. | `local-green` | B | I | A | C | Avançada | 1 h | Envio/erro/reenvio, teclado, foco, responsividade e anúncio; link remoto separado. |
| 1.3 | Auth / Redefinir senha | `auth.reset` | Validação, loading, erro, sucesso e texto a 200% passaram localmente; token real e sessão remota continuam abertos. | `local-green` | B | I | A | C | Avançada | 1 h | Token válido/inválido real, campos, erro, sucesso e 200%; integração remota separada. |
| 1.4 | Auth / Sair | `auth.logout` | Provar sessão revogada e navegação segura. | `local-green` | B | I | A | C | Avançada | 1 h | Logout, voltar/link direto sem dado anterior e foco correto. |
| 1.5 | Auth / MFA | `auth.mfa` | Fluxo sensível e recuperação não têm prova atual. | `audited` | B | I | A | C | Avançada | 2 h | Desafio, erro, cancelamento, sessão revogada e acessibilidade. |
| 2.1 | Shell / Carregamento | `shell.load` | Revalidar sessão, loading e ausência de dado pré-auth. | `local-green` | B | I | A | C | Avançada | 1 h | Loading/sucesso/erro sem vazamento, 375–1440 e 200%. |
| 2.2 | Shell / Navegação | `shell.navigate` | Reconciliar menu, deep link, voltar e foco. | `local-green` | B | I | A | C | Avançada | 1 h | Menu/link direto/voltar/avançar/teclado com rota correta. |
| 2.3 | Shell / Troca de contexto | `shell.switch-context` | Limpeza de estado/cache e foco não comprovados. | `audited` | B | I | A | C | Avançada | 2 h | Contextos A/B, loading novo, sem dado residual e anúncio. |
| 2.4 | Shell / Acesso negado | `shell.unauthorized` | Revalidar rota direta e retorno seguro. | `local-green` | B | I | A | C | Avançada | 1 h | 403 sem conteúdo prévio, teclado e navegação de saída. |
| 2.5 | Shell / Recarregar | `shell.reload` | Retry/reload idempotente e sessão revogada abertos. | `audited` | B | I | A | C | Avançada | 1 h | Reload de sucesso/erro/revogação sem duplicar comandos. |
| 3.1 | Instituições / Diretório | `institutions.list` | Revalidar Cards/tabela, estados e baselines alteradas. | `local-green` | B | I | A | C | Avançada | 2 h | Loading/empty/error/unauthorized, Cards/tabela e goldens exatos. |
| 3.2 | Instituições / Filtros | `institutions.filter` | Revalidar busca, tabs, filtros e sem resultados. | `local-green` | B | I | A | C | Avançada | 1 h | Busca/filtros/tabs, rascunho, limpar/aplicar, teclado e 200%. |
| 3.3 | Instituições / Detalhe | `institutions.detail` | Link direto, not-found e conteúdo autorizado não têm prova Flutter própria. | `audited` | B | I | A | C | Avançada | 1 h | Abrir por Card/tabela/link, not-found, acesso negado, 375–1440 e 200%. |
| 3.4 | Criar Instituição | `institutions.create` | Revalidar wizard, campos, mídia, erros e rodapé. | `local-green` | B | I | A | C | Avançada | 1,5 h | Fluxo completo, validação, duplo envio, 375 light e 1440 dark. |
| 3.5 | Editar Instituição | `institutions.edit` | Revalidar carga, dirty state, mídia e salvamento. | `local-green` | B | I | A | C | Avançada | 1,5 h | Carga/edição/erro/abandono, 375–1440, 200% e golden exato. |
| 3.6 | Instituições / Ativar-desativar | `institutions.status` | Confirmação, ação negativa e feedback precisam rerun. | `local-green` | B | I | A | C | Avançada | 1 h | Ativar/desativar, cancelar, erro, foco devolvido e estado atualizado. |
| 3.7 | Instituições / Arquivos | `institutions.files` | Abertura, foco, autorização e ciclo dos arquivos não têm prova Flutter isolada. | `audited` | B | I | A | C | Avançada | 1,5 h | Flyout canônico, estados, teclado, `Esc`, erro e ausência de path interno. |
| 3.8 | Instituições / Importar | `institutions.import` | Upload, preview, confirmação, falha e retry continuam abertos. | `audited` | B | I | A | C | Avançada | 2 h | Selecionar, validar, prever, confirmar/cancelar, falhar e recarregar. |
| 3.9 | Instituições / Exportar | `institutions.export` | Progresso, falha e download protegido não têm prova Flutter própria. | `audited` | B | I | A | C | Avançada | 1,5 h | Solicitar, aguardar, falhar/repetir e baixar sem expor localização interna. |
| 3.10 | Instituições / Erro e retry | `institutions.error` | Estado de erro existe no conjunto da lista, mas não foi fechado como ação. | `audited` | B | I | A | C | Avançada | 1 h | Erro real, mensagem segura, retry idempotente, foco e ação Criar preservada quando autorizada. |
| 3.11 | Instituições / Acesso negado | `institutions.access-denied` | A negação precisa de prova por rota direta e sem conteúdo anterior. | `audited` | B | I | A | C | Avançada | 1 h | 403, deep link, zero dado residual, teclado/foco e ausência de criação. |
| 3.12 | Instituições / Recarregar | `institutions.reload` | Erro/retry e preservação de filtros não comprovados. | `audited` | B | I | A | C | Avançada | 1 h | Falha, retry, filtros/página preservados e sem duplicação. |
| 4.1 | Unidades / Diretório | `units.list` | Caller recompila com o contrato de estados e 16 testes non-golden passaram; produção, 17+ PNGs e E2E continuam abertos. | `local-green` | B | I | A | C | Avançada | 2 h | Diretório canônico, Cards/tabela, 375–1440, 200%, teclado e visual aprovado. |
| 4.2 | Unidades / Filtrar | `units.filter` | Busca, status e estado sem resultados foram cobertos localmente; persistência de consulta e backend real continuam abertos. | `local-green` | B | I | A | C | Avançada | 1 h | Buscar/limpar/status/sem resultados/reload, foco, 375–1440 e 200%. |
| 4.3 | Criar Unidade | `units.create` | Ação aparece nos estados recuperáveis, mas formulário produtivo e baseline continuam sem fechamento. | `local-green` | B | I | A | C | Avançada | 2 h | Wizard, herança, validação, erro, duplo envio e goldens. |
| 4.4 | Editar Unidade | `units.edit` | Herança/override, dirty state e erro precisam prova. | `local-green` | B | I | A | C | Avançada | 2 h | Herdar/personalizar, salvar/falhar/abandonar e 200%. |
| 4.5 | Unidades / Status | `units.status` | Confirmação e estados após mudança não têm prova final. | `local-green` | B | I | A | C | Avançada | 1 h | Ativar/desativar, confirmação negativa, erro e reload. |
| 4.6 | Unidades / Importar | `units.import` | Adapter cobre template, upload/preview, confirmação e retry, mas produção injeta `UnavailableUnitDirectoryRepository` e `UnavailableUnitBackendCommandsGateway`; composição aguarda handoff Supabase. | `blocked-supabase` | B | I | A | C | Avançada após handoff | 1.5 h + decisão | Composição produtiva aprovada; seleção/validação/preview/confirmar/retry/erro/cancelamento acessíveis. |
| 4.7 | Unidades / Exportar | `units.export` | Flutter em `audited/local-hardening`: gateway exige hub trifásico `request_export` → `status` → `download`, correlaciona o job em cada resposta, valida DTO/colunas/estado/URL HTTPS/TTL e a UI impede duplo clique, preserva idempotência controlada, revalida expiração, injeta opener e apresenta busy/erros acessíveis. A UI também revalida o snapshot após o `await` e não abre artefato produzido para filtros/view antigos. Produção continua com gateway `Unavailable`; escopo autoritativo, remoto, cleanup/cache, remint e E2E seguem bloqueados. O worker local reutiliza replay `SUCESSO`, preserva o artefato pós-conclusão, reautoriza antes da URL e exige delegação interna do hub. | `blocked-supabase` | B | I | A | C | Avançada após decisão e handoff | pacote principal local executado; 5–9 h Flutter/composição residual + decisão/backend/remoto | Flutter 45/45; analyzer focado sem issues. Supabase unit-export 41/47, com 6 REDs explícitos. Ainda exige configuração coordenada do segredo, composição aprovada, tenant A/B, grants legados, retenção/remint, cleanup/purge, remoto e E2E sem expor caminho. |
| 4.8 | Unidades / Erro | `units.error` | Estado de falha e ação criar foram cobertos localmente; erros reais de gateway e telemetria continuam fora. | `local-green` | B | I | A | C | Avançada | 0.5 h | Falhar sem sucesso falso, mensagem clara, criar quando permitido e retry acessível. |
| 4.9 | Unidades / Acesso negado | `units.access-denied` | UI local esconde toolbar, busca, filtros, tabs, alternância Cards/Tabela, arquivos, criar, Cards/tabela e paginação depois que o diretório entra em `unauthorized`; autorização pré-resposta, cache anterior, sessão/vínculo revogado, tenant A/B, deep link e backend real não foram certificados. | `local-green` | B | I | A | C | Avançada | 0.5 h executada; 2–4 h residuais + integração | Estado final negado em 375 px/200% sem dados ou ações, mensagem semântica e bounds válidos; ainda exigir pré-resposta, success→revogação, foco/teclado, 768–1440, tenant A/B, link direto e E2E. |
| 4.10 | Unidades / Recarregar | `units.reload` | Retry local alterna falha e acesso negado, mas preservação completa de filtros/paginação e rede real seguem abertas. | `local-green` | B | I | A | C | Avançada | 1 h | Repetir carga sem duplicar, preservar consulta/página e tratar nova falha. |
| 4.11 | Unidade / Pessoas / Exportar | `units.people-export` | O botão produtivo e o SnackBar de sucesso falso foram removidos: não existe job, arquivo, URL, capability nem contrato de colunas/escopo. A ação permanece ausente até decisão e backend próprios; não confundir com `units.export` nem `people.export`. | `blocked-decision` | B | I | A | C | Completa após decisão | 0,5 h fail-closed executada; 18–32 h para funcional real | RED encontrou o botão; após 10 deleções no widget e 1 expectativa negativa, o teste focado passou e `unit_form_page_test.dart` passou 24/24. Analyzer 0 erros/0 warnings/45 infos; visual e catálogo verdes. Para concluir: capability `people.export` com `unit_id` server-side, AAL2, minimização, tenant A/B, revogação, job/Storage privado, auditoria, cleanup, remoto e E2E. |
| 5.1 | Turmas / Diretório | `groups.list` | Revalidar diretório produtivo, estados e goldens. | `local-green` | B | I | A | C | Avançada | 1.5 h | Cards/tabela, estados, filtros, 375–1440 e 200%. |
| 5.2 | Criar Turma | `groups.create` | CRUD produtivo e regressão do formulário permanecem. | `local-green` | B | I | A | C | Avançada | 1.5 h | Criar, validar, erro, duplo envio e baseline de formulário. |
| 5.3 | Turmas / Detalhe-editar | `groups.edit` | Detalhe/edição e estados de erro não têm prova final. | `local-green` | B | I | A | C | Avançada | 1.5 h | Abrir, editar, cancelar, salvar/falhar e link direto. |
| 5.4 | Turmas / Membros | `groups.members` | Inclusão/remoção, foco e conflitos continuam abertos. | `local-green` | B | I | A | C | Avançada | 1.5 h | Buscar, incluir/remover, negar, conflito, teclado e reload. |
| 5.5 | Turmas / Importar | `groups.import` | Botão e SnackBar de sucesso falso foram removidos do formulário; a ação real de arquivo continua ausente, sem picker, gateway, job, upload ou preview. | `audited` / `fail-closed` | B | I | A | C | Avançada | 0,5 h fail-closed executada; 6–12 h + remoto/E2E | RED→GREEN focado 1/1 e suíte do formulário 8/8 em 375 px/200%; analyzer 0 erros/0 warnings. Para concluir: seleção, preview, validação, confirmação, retry/reload, autorização, tenant A/B, remoto e E2E. |
| 5.6 | Turmas / Exportar | `groups.export` | Botão e SnackBar de sucesso falso foram removidos do formulário; a ação real continua ausente, sem gateway, job, arquivo, status, URL ou download. | `audited` / `fail-closed` | B | I | A | C | Avançada | 0,5 h fail-closed executada; 6–12 h + remoto/E2E | RED→GREEN focado 1/1 e suíte do formulário 8/8 em 375 px/200%; analyzer 0 erros/0 warnings. Para concluir: request/status/download, URL expirada, retry/reload, autorização, tenant A/B, remoto e E2E. |
| 6.1 | Pessoas / Diretório | `people.list` | Identidade produtiva fail-closed; oito goldens abertos. | `audited` | B | I | A | C | Avançada | 3 h | Cards/tabela/tabs/filtros/estados, 375–1440 e goldens. |
| 6.2 | Criar Pessoa | `people.create` | Revalidar formulário e resultado sem fingir persistência. | `local-green` | B | I | A | C | Avançada | 2.5 h | Criar/validar/falhar, 200%, teclado e baseline administrativa. |
| 6.3 | Editar Pessoa | `people.edit` | Carga, vínculos, erro e dirty state ainda abertos. | `local-green` | B | I | A | C | Avançada | 2.5 h | Abrir/editar/salvar/falhar/abandonar, 375–1440. |
| 6.4 | Pessoas / Vínculos | `people.links` | Atividade e vínculos dependem de contrato; estados parciais. | `audited` | B | I | A | C | Avançada após decisão | 2 h + decisão | Fluxos permitidos/indisponíveis claros, foco, erro e reload. |
| 6.5 | Pessoas / Recarregar | `people.reload` | Retry, paginação e filtros não têm prova atual. | `audited` | B | I | A | C | Avançada | 2 h | Erro/retry preservando consulta, página e sem duplicação. |
| 7.1 | Perfis de acesso / Lista | `access-profiles.list` | Diretório e capability precisam revalidação. | `audited` | B | I | A | C | Avançada | 2 h | Lista/estados/filtros/negação e 200%. |
| 7.2 | Criar perfil de acesso | `access-profiles.create` | Access Extended e Imports bloqueiam contrato. | `blocked-decision` | B | I | A | C | Avançada após decisão | 3 h + decisão | Fluxo aprovado, validação, erro, capacidade e regressão visual. |
| 7.3 | Perfil de acesso / Detalhe | `access-profiles.detail` | Detalhe e acesso direto ainda parciais. | `audited` | B | I | A | C | Avançada | 2 h | Abrir/link direto/not-found/unauthorized e 200%. |
| 7.4 | Editar perfil de acesso | `access-profiles.edit` | Contrato estendido e permissões bloqueados. | `blocked-decision` | B | I | A | C | Avançada após decisão | 3 h + decisão | Carga/edição/conflito/erro sem ampliar permissão pela UI. |
| 7.5 | Perfis de acesso / Atribuir | `access-profiles.assign` | Autoridade e efeitos da atribuição não decididos. | `blocked-decision` | B | I | A | C | Avançada após decisão | 3 h + decisão | Atribuir/negar/revogar/reload com capability explícita. |
| 7.6 | Perfis de acesso / Excluir | `access-profiles.delete` | Regra destrutiva e dependências não decididas. | `blocked-decision` | B | I | A | C | Avançada após decisão | 3 h + decisão | Confirmação, bloqueios, erro, foco e ausência após reload. |
| 8.1 | Modelos de acesso / Lista | `access-models.list` | Capability, composição produtiva e estados precisam revisão; rota canônica está fail-closed. | `audited` | B | I | A | C | Avançada após decisão | 2 h + decisão | Diretório/loading/empty/error/negação, Cards/tabela, 375–1440 e 200%. |
| 8.2 | Modelos de acesso / Filtrar | `access-models.filter` | Busca, domínio, status e preservação da consulta não têm prova isolada. | `audited` | B | I | A | C | Avançada após decisão | 1 h + decisão | Buscar/limpar/sem resultados/reload, teclado, foco e 200%. |
| 8.3 | Criar modelo de acesso | `access-models.create` | CRUD bloqueado por decisão de capabilities. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Criar/validar/falhar e autorização explícita. |
| 8.4 | Modelo de acesso / Detalhe | `access-models.detail` | Composition root permanece 503; teste concorrente incompatível foi preservado fora da árvore. Teste router canônico está bloqueado pelo erro externo de Unidades. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Abrir/not-found/unauthorized, teclado, responsividade e 503 enquanto bloqueado. |
| 8.5 | Editar modelo de acesso | `access-models.edit` | CRUD e impacto nas atribuições não decididos. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Editar/conflito/erro/reload sem permissão inferida. |
| 8.6 | Duplicar modelo de acesso | `access-models.duplicate` | Composition root permanece 503; teste concorrente incompatível foi preservado fora da árvore e a capability real segue bloqueada. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Duplicar/cancelar/falhar ou provar 503, conforme decisão de capability/backend. |
| 9.1 | Convites / Lista | `invites.list` | Produção unavailable; estados e goldens abertos. | `local-green` | B | I | A | C | Intermediária | 2 h | Loading/empty/error, filtros, 375–1440 e 200%. |
| 9.2 | Criar Convite | `invites.create` | Email/backend ausente; UI não pode fingir envio. | `local-green` | B | I | A | C | Intermediária | 2 h | Formulário, validação, indisponível/erro e sem sucesso falso. |
| 9.3 | Convite / Detalhe | `invites.detail` | Link direto, expirado e erro precisam prova. | `local-green` | B | I | A | C | Intermediária | 1 h | Abrir/not-found/expirado/unauthorized e responsividade. |
| 9.4 | Convite / Reenviar | `invites.resend` | Feedback, duplo envio e erro não comprovados. | `local-green` | B | I | A | C | Intermediária | 1.5 h | Reenviar/progresso/erro/bloqueio e foco. |
| 9.5 | Convite / Revogar | `invites.revoke` | Confirmação negativa e estados finais abertos. | `local-green` | B | I | A | C | Intermediária | 1.5 h | Confirmar/cancelar/falhar, `Esc`, foco e item revogado. |
| 10.1 | Atividades / Diretório | `activities.list` | Produção fail-closed; matriz visual precisa rerun. | `local-green` | B | I | A | C | Avançada | 2 h | Diretório/estados/filtros, 375–1440, 200% e visual. |
| 10.2 | Criar Atividade / Wizard | `activities.create` | Calendário, About e command exigem revalidação. | `local-green` | B | I | A | C | Avançada | 2 h | Seis etapas, data canônica, erro antes do command e goldens. |
| 10.3 | Atividade / Detalhe | `activities.detail` | Link direto, estados e conteúdo não revalidados. | `local-green` | B | I | A | C | Avançada | 2 h | Abrir/not-found/unauthorized, teclado e 200%. |
| 10.4 | Editar Atividade | `activities.edit` | Carga, dirty state e falha parcial continuam abertos. | `local-green` | B | I | A | C | Avançada | 2 h | Editar/salvar/falhar/abandonar sem sucesso parcial. |
| 10.5 | Atividade / Publicar | `activities.publish` | Confirmação, duplo envio e erro precisam prova. | `local-green` | B | I | A | C | Avançada | 2 h | Publicar/cancelar/falhar/repetir e estado após reload. |
| 10.6 | Atividade / Avaliar | `activities.assessment` | Fluxo e navegação com Avaliações ainda parciais. | `local-green` | B | I | A | C | Avançada | 2 h | Abrir/lançar/erro/retornar, foco e responsividade. |

### 5.2 Operação, agenda, comunicação e formulários

| Ordem | Tela/subtela | Ação | Pendência Flutter | Estado atual | Básica | Intermediária | Avançada | Completa | Nível aconselhado | Estimativa | Evidência para conclusão |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | --- |
| 11.1 | Avaliações / Lançamento | `assessments.entry` | Página, estados e comparadores precisam rerun. | `audited` | B | I | A | C | Avançada | 2 h | Lançar/validar/falhar, timezone e 375–1440. |
| 11.2 | Avaliações / Diário | `assessments.gradebook` | Gradebook e navegação não têm prova atual. | `audited` | B | I | A | C | Avançada | 2 h | Lista/edição/empty/error, teclado, 200% e reload. |
| 11.3 | Avaliações / Fechar | `assessments.close` | Confirmação, conflito e feedback abertos. | `audited` | B | I | A | C | Avançada | 2 h | Fechar/cancelar/conflito/erro e estado após reload. |
| 11.4 | Avaliações / Reabrir | `assessments.reopen` | Regra, motivo e conflito não comprovados na UI. | `audited` | B | I | A | C | Avançada | 2 h | Reabrir/cancelar/falhar, motivo, foco e reload. |
| 11.5 | Avaliação / Detalhe | `assessments.detail` | Link direto e estados não revalidados. | `audited` | B | I | A | C | Avançada | 2 h | Abrir/not-found/unauthorized e responsividade. |
| 12.1 | Alunos / Acompanhamento | `students.list` | Versão read-only canônica está verde; 24 legados de gerenciamento foram preservados externamente e retirados do analyzer sem alterar o contrato produtivo. | `local-green` | B | I | A | C | Avançada | 2 h | 22 testes passam em 375–1440, 200%, teclado, offline/unavailable e sem ação falsa; gerenciamento e E2E continuam separados. |
| 12.2 | Alunos / Vincular | `students.link` | Contrato produtivo não aprovado. | `blocked-decision` | B | I | A | C | Avançada após decisão | 1.5 h + decisão | Vínculo permitido/negado/erro e reload conforme contrato. |
| 12.3 | Alunos / Transferir | `students.transfer` | Escopo, confirmação e autoridade não decididos. | `blocked-decision` | B | I | A | C | Avançada após decisão | 1.5 h + decisão | Transferir/cancelar/negar/falhar sem perda de contexto. |
| 12.4 | Alunos / Editar | `students.edit` | Campos e autoridade ainda não aprovados. | `blocked-decision` | B | I | A | C | Avançada após decisão | 1.5 h + decisão | Editar/validar/falhar e retorno ao detalhe. |
| 12.5 | Alunos / Revogar | `students.revoke` | Ação sensível e efeitos não decididos. | `blocked-decision` | B | I | A | C | Avançada após decisão | 1.5 h + decisão | Confirmar/cancelar/negar/falhar, foco e reload. |
| 13.1 | Assiduidade / Dashboard | `attendance.dashboard` | Clock, erros, reload e dois goldens abertos. | `local-green` | B | I | A | C | Avançada | 2 h | Estados, clock determinístico, 375–1440, 200% e goldens. |
| 13.2 | Assiduidade / Nova chamada | `attendance.create` | Contexto, duplo envio e erros precisam prova. | `local-green` | B | I | A | C | Avançada | 2 h | Criar/cancelar/falhar, contexto correto e foco. |
| 13.3 | Assiduidade / Marcar | `attendance.mark` | Interações e concorrência ainda parciais. | `local-green` | B | I | A | C | Avançada | 2 h | Marcar/desmarcar, teclado/toque, erro e snapshot preservado. |
| 13.4 | Assiduidade / Corrigir | `attendance.correct` | Motivo, conflito e erro precisam evidência. | `local-green` | B | I | A | C | Avançada | 2 h | Corrigir/validar/conflito/falhar e reload. |
| 13.5 | Assiduidade / Concluir | `attendance.finish` | Confirmação e command guard não têm fechamento final. | `local-green` | B | I | A | C | Avançada | 2 h | Concluir/cancelar/duplo envio/erro e estado final. |
| 13.6 | Assiduidade / Exportar | `attendance.export` | Worker/download continuam separados. | `audited` | B | I | A | C | Avançada | 2 h | Solicitar/progresso/falha/retry/download acessível. |
| 14.1 | Rotina diária / Diretório | `daily-routine.list` | Produção unavailable; smoke visual ausente. | `local-green` | B | I | A | C | Avançada | 1.5 h | Diretório/estados/filtros, 375–1440 e 200%. |
| 14.2 | Criar Rotina | `daily-routine.create` | Command, erros e visual precisam rerun. | `local-green` | B | I | A | C | Avançada | 1.5 h | Criar/validar/falhar, teclado e baseline de formulário. |
| 14.3 | Editar Rotina | `daily-routine.edit` | Dirty state, seções e erro abertos. | `local-green` | B | I | A | C | Avançada | 1.5 h | Editar/salvar/falhar/abandonar e 200%. |
| 14.4 | Rotina / Aplicar | `daily-routine.apply` | Escopo, confirmação e feedback precisam prova. | `local-green` | B | I | A | C | Avançada | 1.5 h | Aplicar/cancelar/falhar e resultado após reload. |
| 14.5 | Rotina / Publicar | `daily-routine.publish` | Duplo envio, erro e estado final não comprovados. | `local-green` | B | I | A | C | Avançada | 2 h | Publicar/cancelar/falhar/repetir e reload. |
| 15.1 | Agenda / Calendário | `agenda.view` | Spec/draft e comportamento ainda não fechados. | `blocked-decision` | B | I | A | C | Avançada após decisão | 3 h + decisão | Calendário canônico, teclado, 375–1440, 200% e estados. |
| 15.2 | Agenda / Criar evento | `agenda.create` | Campos, audiência e permissões não aprovados. | `blocked-decision` | B | I | A | C | Avançada após decisão | 3 h + decisão | Criar/validar/falhar com date picker canônico. |
| 15.3 | Agenda / Detalhe | `agenda.detail` | Conteúdo e acesso direto não decididos. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Abrir/not-found/unauthorized e responsividade. |
| 15.4 | Agenda / Editar | `agenda.edit` | Autoridade, recorrência e conflitos não definidos. | `blocked-decision` | B | I | A | C | Avançada após decisão | 3 h + decisão | Editar/conflito/erro/reload conforme contrato. |
| 15.5 | Agenda / Solicitar | `agenda.request` | Fluxo de solicitação não aprovado. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Solicitar/cancelar/falhar e feedback acessível. |
| 15.6 | Agenda / Permissões | `agenda.permissions` | Modelo de capacidade permanece aberto. | `blocked-decision` | B | I | A | C | Avançada após decisão | 3 h + decisão | Permitido/negado, sem esconder dado após autorização tardia. |
| 16.1 | Chat / Conversas | `chat.list` | Wiring, paginação, erros e PNGs precisam revisão. | `audited` | B | I | A | C | Avançada | 2 h | Loading/empty/error, paginação, 375–1440 e 200%. |
| 16.2 | Chat / Abrir conversa | `chat.open` | Membership revogada e acesso direto não comprovados. | `audited` | B | I | A | C | Avançada | 2 h | Abrir/link direto/not-found/revogada e foco. |
| 16.3 | Chat / Enviar mensagem | `chat.send` | Duplo envio, erro e recuperação abertos. | `audited` | B | I | A | C | Avançada | 2.5 h | Enviar/falhar/retry, teclado, 200% e sem duplicação. |
| 16.4 | Chat / Editar mensagem | `chat.edit` | Janela, confirmação e erro não comprovados. | `audited` | B | I | A | C | Avançada | 2 h | Editar/cancelar/falhar e estado atualizado. |
| 16.5 | Chat / Anexar arquivo | `chat.attach` | Mídia, upload e falha parcial continuam abertos. | `audited` | B | I | A | C | Avançada | 3 h | Escolher/validar/enviar/cancelar/falhar e foco. |
| 16.6 | Chat / Recibos | `chat.receipts` | Leitura/entrega e semântica não revalidadas. | `audited` | B | I | A | C | Avançada | 2 h | Estados textualizados, teclado e sem depender só de cor. |
| 16.7 | Chat / Revogar-remover | `chat.revoke` | Ação negativa, membership e reload abertos. | `audited` | B | I | A | C | Avançada | 2.5 h | Confirmar/cancelar/negar/falhar, foco e desaparecimento correto. |
| 17.1 | Avisos / Diretório | `notices.list` | Revisão funcional/visual atual inexistente. | `audited` | B | I | A | C | Avançada | 2 h | Lista/estados/filtros, 375–1440, 200% e reload. |
| 17.2 | Criar Aviso | `notices.create` | Formulário e command não revalidados. | `audited` | B | I | A | C | Avançada | 2 h | Criar/validar/falhar e baseline administrativa. |
| 17.3 | Editar Aviso | `notices.edit` | Carga, dirty state e erro abertos. | `audited` | B | I | A | C | Avançada | 1.5 h | Editar/salvar/falhar/abandonar e 200%. |
| 17.4 | Avisos / Agendar | `notices.schedule` | Calendário, timezone e erro precisam prova. | `audited` | B | I | A | C | Avançada | 1.5 h | Agendar/alterar/cancelar/falhar com picker canônico. |
| 17.5 | Avisos / Publicar | `notices.publish` | Confirmação e duplo envio não comprovados. | `audited` | B | I | A | C | Avançada | 1.5 h | Publicar/cancelar/falhar e estado após reload. |
| 17.6 | Avisos / Arquivar | `notices.archive` | Ação negativa e recuperação não comprovadas. | `audited` | B | I | A | C | Avançada | 1.5 h | Arquivar/cancelar/falhar, foco e filtros atualizados. |
| 18.1 | Formulários / Diretório | `forms.list` | Fail-closed; estados e regressão precisam rerun. | `local-green` | B | I | A | C | Completa | 2 h | Diretório/estados/filtros, 375–1440 e 200%. |
| 18.2 | Criar Formulário | `forms.create` | Fluxo real e arquivos ainda parciais. | `audited` | B | I | A | C | Completa | 3 h | Criar/validar/falhar e navegação segura ao editor. |
| 18.3 | Formulário / Visão geral | `forms.overview` | Visão local não prova ações reais. | `local-green` | B | I | A | C | Completa | 2 h | Abrir/estados/ações indisponíveis claras e 200%. |
| 18.4 | Formulário / Editar | `forms.edit` | Componente local/catalogado recompila e tem testes de autosave, erro, 375 px e teclado; rota produtiva, autorização real, 150%/200% e E2E continuam bloqueados. | `local-green` | B | I | A | C | Completa após decisão integrada | 3–4 h + decisão | Componente local já provado; ainda exigir rota/capability aprovadas, sanitização, escalas 150%/200%, regressão visual e E2E. |
| 18.5 | Formulário / Publicar | `forms.publish` | Contrato/capability não fechados. | `blocked-decision` | B | I | A | C | Completa após decisão | 3 h + decisão | Publicar/cancelar/negar/falhar e reload. |
| 18.6 | Formulário / Testar | `forms.test` | Preview/teste e isolamento não aprovados. | `blocked-decision` | B | I | A | C | Completa após decisão | 2 h + decisão | Testar sem persistir, erros, teclado e responsividade. |
| 19.1 | Respostas / Monitor | `forms.monitor` | Estados e atualização não revalidados. | `audited` | B | I | A | C | Completa | 2 h | Loading/empty/error/reload, 375–1440 e 200%. |
| 19.2 | Responder Formulário | `forms.respond` | Contrato canônico fail-closed voltou a compilar e o teste local passou; resposta real, autosave, retomada, mídia e autorização continuam bloqueados por decisão integrada. | `local-green` | B | I | A | C | Completa após decisão integrada | 3 h + decisão | Fail-closed local já provado; ainda exigir contrato aprovado e preencher/validar/autosalvar/falhar/retomar, acessibilidade e E2E. |
| 19.3 | Respostas / Lista | `forms.responses` | Autorização e estados ainda parciais. | `audited` | B | I | A | C | Completa | 2 h | Lista/filtros/empty/error/unauthorized e reload. |
| 19.4 | Resposta / Detalhe | `forms.response-detail` | Correlação, acesso e mídia não comprovados. | `audited` | B | I | A | C | Completa | 3 h | Abrir/not-found/unauthorized, mídia protegida e 200%. |
| 19.5 | Respostas / Exportar | `forms.export` | Export protegido e erro continuam abertos. | `audited` | B | I | A | C | Completa | 2 h | Solicitar/progresso/falhar/retry/download sem correlação indevida. |
| 20.1 | Arquivos de Formulários / Upload | `forms.upload` | Lifecycle protegido e erro parcial abertos. | `audited` | B | I | A | C | Completa | 3 h | Escolher/validar/enviar/cancelar/falhar e reload. |
| 20.2 | Arquivos de Formulários / Resolver | `forms.resolve-file` | Closure F6 e rotas precisam rerun. | `local-green` | B | I | A | C | Completa | 2 h | Resolver permitido/negado/expirado sem expor caminho. |
| 20.3 | Arquivos de Formulários / Baixar | `forms.download` | Download protegido não tem prova integrada atual. | `local-green` | B | I | A | C | Completa | 2 h | Baixar permitido/negado/expirado e erro acessível. |
| 20.4 | Arquivos de Formulários / Expirar | `forms.expire-file` | Ação e atualização visual não comprovadas. | `audited` | B | I | A | C | Completa | 2.5 h | Expirar/cancelar/falhar, foco e reload. |
| 20.5 | Arquivos de Formulários / Excluir | `forms.delete-file` | Confirmação negativa e falha parcial abertas. | `audited` | B | I | A | C | Completa | 2.5 h | Excluir/cancelar/negar/falhar e ausência após reload. |

### 5.3 Principal, cuidado e operações de plataforma

| Ordem | Tela/subtela | Ação | Pendência Flutter | Estado atual | Básica | Intermediária | Avançada | Completa | Nível aconselhado | Estimativa | Evidência para conclusão |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | --- |
| 21.1 | Acontece / Feed | `acontece.feed` | Preview local; origem real e goldens abertos. | `local-green` | B | I | A | C | Avançada | 2 h | Feed/empty/error/reload, 375–1440 e 200%. |
| 21.2 | Acontece / Criar | `acontece.create` | Audiência, mídia e contrato produtivo não aprovados. | `blocked-decision` | B | I | A | C | Avançada após decisão | 3 h + decisão | Criar/validar/falhar, audiência clara e mídia protegida. |
| 21.3 | Acontece / Publicar | `acontece.publish` | Publicação/R2 e confirmação não fechadas. | `blocked-decision` | B | I | A | C | Avançada após decisão | 3 h + decisão | Publicar/cancelar/negar/falhar e resultado após reload. |
| 21.4 | Acontece / Remover | `acontece.remove` | Regra negativa e retenção não decididas. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Remover/cancelar/negar/falhar, foco e feed atualizado. |
| 22.1 | Agora / Visualizar | `agora.view` | Entrada real, origem e goldens precisam rerun. | `local-green` | B | I | A | C | Avançada | 2 h | Card/deep link, fechar/voltar, foco, 375–1440 e 200%. |
| 22.2 | Agora / Criar | `agora.create` | Lifecycle e mídia não aprovados. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Criar/validar/falhar e mídia protegida. |
| 22.3 | Agora / Publicar | `agora.publish` | Publicação real e audiência permanecem abertas. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Publicar/cancelar/negar/falhar e reload. |
| 22.4 | Agora / Expirar | `agora.expire` | Regra de expiração e feedback não decididos. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Expirar/cancelar/falhar e ausência após reload. |
| 23.1 | Momentos / Visualizar | `momentos.view` | Origem/tab real e goldens precisam rerun. | `local-green` | B | I | A | C | Avançada | 2 h | Abrir/fechar/deep link, foco, 375–1440 e 200%. |
| 23.2 | Momentos / Criar | `momentos.create` | Lifecycle/mídia não aprovados. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Criar/validar/falhar com mídia protegida. |
| 23.3 | Momentos / Publicar | `momentos.publish` | Publicação e audiência não fechadas. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Publicar/cancelar/negar/falhar e reload. |
| 23.4 | Momentos / Remover | `momentos.remove` | Regra negativa e retenção não decididas. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Remover/cancelar/falhar, foco e retorno correto. |
| 24.1 | Principal / Para Você | `principal.for-you` | Preview estático; responsive/goldens precisam revisão. | `local-green` | B | I | A | C | Avançada | 2 h | Conteúdo/empty/error, 375–1440, 200% e pacote Principal. |
| 24.2 | Principal / Perfil-circulares | `principal.profile-view` | Hospedagem e separação de pacote estão abertas. | `local-green` | B | I | A | C | Avançada | 3 h | Tabs/conteúdo/erro, sem `coelo_ui_admin`, teclado e visual. |
| 24.3 | Principal / Editar perfil | `principal.profile-edit` | Campos, ownership e superfície final não decididos. | `blocked-decision` | B | I | A | C | Avançada após decisão | 3 h + decisão | Editar/validar/falhar e persistir no pacote correto. |
| 25.1 | Segurança infantil / Lista | `child-safety.list` | Lifecycle e autorização ainda sem prova atual. | `local-green` | B | I | A | C | Completa | 2 h | Lista/empty/error/unauthorized, 375–1440 e 200%. |
| 25.2 | Segurança infantil / Criança | `child-safety.child` | Detalhe, acesso direto e estados abertos. | `local-green` | B | I | A | C | Completa | 2 h | Abrir/not-found/unauthorized e sem dado de outra criança. |
| 25.3 | Segurança infantil / Criar autorização | `child-safety.create` | Validação, erro e fluxo sensível precisam rerun. | `local-green` | B | I | A | C | Completa | 2 h | Criar/validar/negar/falhar e baseline de formulário. |
| 25.4 | Segurança infantil / Editar autorização | `child-safety.edit` | Carga, dirty state e erro ainda parciais. | `local-green` | B | I | A | C | Completa | 2 h | Editar/salvar/negar/falhar/abandonar e 200%. |
| 25.5 | Segurança infantil / Suspender | `child-safety.suspend` | Suspensão/revogação e ação negativa não comprovadas. | `audited` | B | I | A | C | Completa | 2 h | Confirmar/cancelar/negar/falhar, foco e reload. |
| 26.1 | Perfis de cuidado / Lista | `health-care.list` | Produção fail-closed; 12 PNGs e visual abertos. | `local-green` | B | I | A | C | Completa | 3 h | Diretório/estados/tabs, 375–1440, 200% e goldens. |
| 26.2 | Criar perfil de cuidado | `health-care.create` | Fluxo sensível e arquivos precisam fechamento. | `local-green` | B | I | A | C | Completa | 3 h | Criar/validar/negar/falhar e mídia privada. |
| 26.3 | Perfil de cuidado / Detalhe | `health-care.detail` | Detail foi removido; decisão de produto bloqueia. | `blocked-decision` | B | I | A | C | Completa após decisão | 3 h + decisão | Superfície aprovada ou ausência explícita, acesso e estados. |
| 26.4 | Editar perfil de cuidado | `health-care.edit` | Carga, arquivos, dirty state e erro abertos. | `local-green` | B | I | A | C | Completa | 3 h | Editar/salvar/negar/falhar/abandonar e goldens. |
| 27.1 | Medicação / Lista | `medication.list` | OQ-003/OQ-040 bloqueiam produção. | `blocked-decision` | B | I | A | C | Completa após decisão | 2 h + decisão | Lista/estados/negação somente após base legal aprovada. |
| 27.2 | Medicação / Criar | `medication.create` | Dados sensíveis, retenção e mídia não decididos. | `blocked-decision` | B | I | A | C | Completa após decisão | 3 h + decisão | Criar/validar/negar/falhar com proteção e consentimento. |
| 27.3 | Medicação / Detalhe | `medication.detail` | Superfície e acesso permanecem bloqueados. | `blocked-decision` | B | I | A | C | Completa após decisão | 2 h + decisão | Abrir/not-found/unauthorized sem vazamento sensível. |
| 27.4 | Medicação / Editar | `medication.edit` | Correção, retenção e autoridade não aprovadas. | `blocked-decision` | B | I | A | C | Completa após decisão | 2 h + decisão | Editar/validar/negar/falhar e trilha clara. |
| 27.5 | Medicação / Evidência | `medication.evidence` | Upload/download/expiração jurídicos não aprovados. | `blocked-decision` | B | I | A | C | Completa após decisão | 3 h + decisão | Enviar/ver/baixar/negar/expirar sem expor caminho. |
| 28.1 | Importações / Hub | `imports.list` | Estados, provenance e regressão precisam revisão. | `audited` | B | I | A | C | Avançada | 2 h | Lista/empty/error/filtros, 375–1440 e 200%. |
| 28.2 | Importações / Nova | `imports.create` | Dialog verde não fecha fluxo amplo nem golden. | `local-green` | B | I | A | C | Avançada | 2 h | Abrir/fechar/Cancelar/`Esc`/foco e golden aprovado. |
| 28.3 | Importações / Upload | `imports.upload` | Arquivo, validação e falha parcial abertos. | `audited` | B | I | A | C | Avançada | 2.5 h | Escolher/validar/enviar/cancelar/falhar. |
| 28.4 | Importações / Preview | `imports.preview` | Proveniência, erros de linha e 200% não comprovados. | `audited` | B | I | A | C | Avançada | 2 h | Preview/erros/sem resultados, teclado e responsividade. |
| 28.5 | Importações / Confirmar | `imports.confirm` | Duplo envio, confirmação e erro abertos. | `audited` | B | I | A | C | Avançada | 2.5 h | Confirmar/cancelar/falhar/repetir sem duplicação. |
| 28.6 | Importações / Status | `imports.status` | Progresso, falha/retry e reload não comprovados. | `audited` | B | I | A | C | Avançada | 2.5 h | Pending/running/success/failure/retry e reload. |
| 28.7 | Importações / Baixar | `imports.download` | Resultado protegido e expirado não comprovados. | `audited` | B | I | A | C | Avançada | 2.5 h | Baixar permitido/negado/expirado e erro acessível. |
| 29.1 | Arquivos de perfil / Importar | `profile-files.import` | Callback/repository e lifecycle não mapeados. | `audited` | B | I | A | C | Completa | 2 h | Escolher/validar/enviar/falhar sem expor caminho. |
| 29.2 | Arquivos de perfil / Preview | `profile-files.preview` | Conteúdo, erro e privacidade não comprovados. | `audited` | B | I | A | C | Completa | 2 h | Preview permitido/negado/inválido, 200% e teclado. |
| 29.3 | Arquivos de perfil / Confirmar | `profile-files.confirm` | Confirmação, duplo envio e falha parcial abertos. | `audited` | B | I | A | C | Completa | 2 h | Confirmar/cancelar/falhar e reload sem duplicação. |
| 29.4 | Arquivos de perfil / Status | `profile-files.status` | Progresso e recuperação não comprovados. | `audited` | B | I | A | C | Completa | 2 h | Pending/running/success/failure/retry acessíveis. |
| 29.5 | Arquivos de perfil / Exportar | `profile-files.export` | Geração protegida e erro abertos. | `audited` | B | I | A | C | Completa | 2 h | Solicitar/progresso/falhar/retry sem dado sensível na UI. |
| 29.6 | Arquivos de perfil / Baixar | `profile-files.download` | Download/expiração/negação não comprovados. | `audited` | B | I | A | C | Completa | 2 h | Baixar permitido/negado/expirado e foco correto. |
| 30.1 | Auditoria / Lista | `audit.list` | Paginação, sanitização e estados não revisados. | `audited` | B | I | A | C | Avançada | 2 h | Lista/empty/error/paginação, 375–1440 e 200%. |
| 30.2 | Auditoria / Filtrar | `audit.filter` | Filtros, datas e sem resultados precisam prova. | `audited` | B | I | A | C | Avançada | 2 h | Busca/filtros/picker canônico/limpar/sem resultados. |
| 30.3 | Auditoria / Detalhe | `audit.detail` | Dados sanitizados e acesso direto não comprovados. | `audited` | B | I | A | C | Avançada | 2 h | Abrir/not-found/unauthorized sem dados brutos sensíveis. |
| 30.4 | Auditoria / Exportar | `audit.export` | Export protegido, erro e retenção abertos. | `audited` | B | I | A | C | Avançada | 2 h | Solicitar/falhar/retry/baixar sem expor informação proibida. |

### 5.4 Suporte, conta, governança e fechamento

| Ordem | Tela/subtela | Ação | Pendência Flutter | Estado atual | Básica | Intermediária | Avançada | Completa | Nível aconselhado | Estimativa | Evidência para conclusão |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | --- |
| 31.1 | Suporte / Criar | `support.create` | UI verde; persistência real e goldens abertos. | `local-green` | B | I | A | C | Avançada | 1 h | Criar/validar/falhar sem sucesso falso, 375–1440. |
| 31.2 | Suporte / Tabela | `support.table` | Backend/goldens e estados finais permanecem. | `local-green` | B | I | A | C | Avançada | 1 h | Lista/empty/error/paginação, 100–200% e visual. |
| 31.3 | Suporte / Kanban | `support.kanban` | Status canônico e goldens precisam fechamento. | `local-green` | B | I | A | C | Avançada | 1.5 h | Colunas/scroll/teclado/estados, 375–1440 e visual. |
| 31.4 | Suporte / Detalhe | `support.detail` | Detalhe e link direto não revalidados. | `audited` | B | I | A | C | Avançada | 1.5 h | Abrir/not-found/unauthorized, 200% e foco. |
| 31.5 | Suporte / Responder | `support.reply` | Envio, duplo envio e erro não comprovados. | `audited` | B | I | A | C | Avançada | 1.5 h | Responder/falhar/retry, teclado e sem duplicação. |
| 31.6 | Suporte / Encerrar | `support.close` | Mapeamento de status e ação negativa abertos. | `audited` | B | I | A | C | Avançada após decisão | 1.5 h + decisão | Confirmar/cancelar/falhar, foco e status após reload. |
| 32.1 | Conta / Perfil | `account.profile` | Oito PNGs e fluxo de perfil precisam rerun. | `audited` | B | I | A | C | Avançada | 1.5 h | Carregar/editar/erro, 375–1440, 200% e goldens. |
| 32.2 | Conta / Configurações | `account.settings` | Estados e visual não revalidados no worktree atual. | `audited` | B | I | A | C | Avançada | 1.5 h | Configurar/salvar/falhar, teclado, 200% e goldens. |
| 32.3 | Conta / Tema | `account.theme` | Duração normativa e regressão ainda abertas. | `local-green` | B | I | A | C | Avançada | 1 h | Light/dark/sistema, reduced motion e persistência local. |
| 32.4 | Conta / MFA | `account.mfa` | Fluxo sensível sem prova atual. | `audited` | B | I | A | C | Avançada | 1.5 h | Habilitar/desabilitar/negar/falhar e sessão revogada. |
| 32.5 | Conta / Sessões | `account.sessions` | Listar/revogar e estado atual não comprovados. | `audited` | B | I | A | C | Avançada | 1.5 h | Lista/empty/error/revogar/reload sem perder sessão errada. |
| 32.6 | Conta / Sair | `account.logout` | Voltar/deep link após revogação precisa rerun. | `local-green` | B | I | A | C | Avançada | 1 h | Logout, voltar/link direto, sem dado anterior e foco. |
| 33.1 | Catálogo / Lista | `catalog.list` | HEAD e fontes preparadas divergem. | `local-green` | B | I | A | C | Intermediária | 1 h | Host/estado/fallback e relatório correspondente ao snapshot. |
| 33.2 | Catálogo / Validar | `catalog.validate` | Validação fresca explica o único diagnóstico restante: `superadmin.forms-response`, bloqueado por contrato funcional. | `local-green` | B | I | A | C | Intermediária | 2 h | 23 testes do sincronizador, índice e fronteiras verdes; diagnóstico restante identificado sem ser ocultado. |
| 33.3 | Catálogo / Sincronizar | `catalog.sync` | Sincronização mecânica concluída; o relatório permanece `catalogStale` somente por `superadmin.forms-response`. | `blocked-decision` | B | I | A | C | Intermediária após decisão | 2 h + decisão | Advanced Color Picker sincronizado; Forms preservado como bloqueio funcional e diff revisado. |
| 33.4 | Catálogo / Publicar | `catalog.publish` | Contrato produtivo de publicação não aprovado. | `blocked-decision` | B | I | A | C | Intermediária após decisão | 1 h + decisão | Acesso/fallback/CSP aprovados; sem deploy implícito. |
| 34.1 | Planos / Diretório | `plans.list` | Fake/protótipo e estados precisam revisão. | `audited` | B | I | A | C | Avançada | 2 h | Lista/empty/error/filtros, 375–1440 e 200%. |
| 34.2 | Criar Plano | `plans.create` | Fluxo local não prova contrato comercial. | `local-green` | B | I | A | C | Avançada após decisão | 2 h + decisão | Criar/validar/falhar sem fingir ativação. |
| 34.3 | Editar Plano | `plans.edit` | Campos, dirty state e erro precisam rerun. | `local-green` | B | I | A | C | Avançada após decisão | 2 h + decisão | Editar/salvar/falhar/abandonar e 200%. |
| 34.4 | Planos / Ativar | `plans.activate` | Autoridade e efeitos comerciais não decididos. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Ativar/cancelar/negar/falhar e reload. |
| 34.5 | Planos / Atribuir | `plans.assign` | Regras de cobrança/contexto não aprovadas. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Atribuir/negar/conflito/falhar e contexto correto. |
| 35.1 | Cardápios / Diretório | `meal-plans.list` | Lifecycle e estados não revalidados. | `audited` | B | I | A | C | Avançada | 2 h | Lista/empty/error/filtros, 375–1440 e 200%. |
| 35.2 | Criar Cardápio | `meal-plans.create` | Wizard, mídia e erro precisam fechamento. | `local-green` | B | I | A | C | Avançada | 2 h | Criar/validar/falhar, mídia e baseline de formulário. |
| 35.3 | Editar Cardápio | `meal-plans.edit` | Carga, dirty state e mídia ainda parciais. | `local-green` | B | I | A | C | Avançada | 2 h | Editar/salvar/falhar/abandonar e goldens. |
| 35.4 | Cardápios / Criar modelo | `meal-plans.model-create` | Modelo e validação não têm prova final. | `local-green` | B | I | A | C | Avançada | 2 h | Criar modelo/validar/falhar e 200%. |
| 35.5 | Cardápios / Editar modelo | `meal-plans.model-edit` | Edição/conflito e regressão permanecem. | `local-green` | B | I | A | C | Avançada | 2 h | Editar/salvar/conflito/falhar e reload. |
| 35.6 | Cardápios / Publicar | `meal-plans.publish` | Contrato de publicação/mídia não aprovado. | `blocked-decision` | B | I | A | C | Avançada após decisão | 2 h + decisão | Publicar/cancelar/negar/falhar e estado final. |
| 36.1 | Usuários internos / Lista | `internal-users.list` | Domínio/realm e produção não decididos. | `blocked-decision` | B | I | A | C | Completa após decisão | 2 h + decisão | Lista/empty/error/negação somente no realm aprovado. |
| 36.2 | Criar usuário interno | `internal-users.create` | Formulário local não prova Auth privilegiado. | `local-green` | B | I | A | C | Completa após decisão | 2 h + decisão | Criar/convidar/negar/falhar com MFA/capability. |
| 36.3 | Editar usuário interno | `internal-users.edit` | Identidade, papel e erro não fechados. | `local-green` | B | I | A | C | Completa após decisão | 2 h + decisão | Editar/validar/negar/conflito/falhar. |
| 36.4 | Usuários internos / Suspender | `internal-users.suspend` | Revogação de sessão e autoridade não aprovadas. | `blocked-decision` | B | I | A | C | Completa após decisão | 2 h + decisão | Suspender/cancelar/negar/falhar e sessões revogadas. |
| 36.5 | Usuários internos / MFA | `internal-users.mfa` | Política/realm e recuperação não decididos. | `blocked-decision` | B | I | A | C | Completa após decisão | 2 h + decisão | Exigir/recuperar/negar/falhar no realm correto. |
| 37.1 | Erros / 403 | `errors.403` | Baseline e navegação de saída precisam rerun. | `audited` | B | I | A | C | Intermediária | 1 h | Rota direta, sem dado prévio, teclado e visual aprovado. |
| 37.2 | Erros / 404 | `errors.404` | Link direto e retorno não revalidados. | `audited` | B | I | A | C | Intermediária | 1 h | Rota inexistente, voltar/início, foco e 200%. |
| 37.3 | Erros / 409 | `errors.409` | Conflito e recuperação precisam prova. | `audited` | B | I | A | C | Intermediária | 1 h | Conflito sanitizado, ação segura e sem retry indevido. |
| 37.4 | Erros / 500 | `errors.500` | Sanitização e fallback não revalidados. | `audited` | B | I | A | C | Intermediária | 1 h | Erro genérico sem detalhe técnico, navegação e foco. |
| 37.5 | Erros / 503 | `errors.503` | Indisponível e ação alternativa precisam rerun. | `audited` | B | I | A | C | Intermediária | 1 h | Indisponível, retry quando seguro, 375–1440 e 200%. |
| 37.6 | Erros / Tentar novamente | `errors.retry` | Idempotência e retorno de foco não comprovados. | `audited` | B | I | A | C | Intermediária | 1 h | Retry permitido/bloqueado, foco e uma única repetição. |

### 5.5 Totais, pacotes e leitura das estimativas

| Unidade de planejamento | Estimativa preliminar | Observação |
|---|---:|---|
| Temas gerais compartilhados | 290 h brutas | Não somar integralmente às famílias: shell, UI, responsividade, acessibilidade e regressão são absorvidos por vários pacotes de tela. |
| 37 famílias / 207 ações Flutter | aproximadamente 388 h sequenciais | Soma operacional atual por família, sem espera externa; inclui a decomposição explícita das 12 ações de Instituições e exige reestimativa após rerun do snapshot. |
| Pacote Intermediário sugerido para decisão | 2–6 h | Uma ou poucas ações relacionadas de baixo/médio risco; nunca conclui a tela. |
| Pacote Avançado de uma família complexa | 1–2 dias | Inclui ações relacionadas, arquitetura, estados, acessibilidade, responsividade e regressões. |
| Pacote Completo de uma tela | 2–5 dias | Só pode fechar a tela Flutter se todas as ações aplicáveis e evidências estiverem completas. |

As estimativas por linha representam trabalho incremental dentro do pacote da
família. Somá-las entre famílias é válido como ordem de grandeza; somá-las aos
temas gerais duplicaria trabalho compartilhado. Espera por decisão, backend,
ambiente remoto, aprovação visual e inspeção humana de PNGs não está incluída.

## 6. Ordem obrigatória

1. **Fase 0 — inventário:** Git, apps, rotas produtivas e `/dev`, menus, flags,
   repositories fake, testes e imagens de referência alteradas.
2. **Fase 1 — fundação Flutter:** shell, tema, tokens, componentes canônicos,
   router, tratamento de erros e estados compartilhados.
3. **Fase 2 — identidade:** login, sessão, MFA, troca de contexto, perfil e acesso.
4. **Fase 3 — cadastros estruturais:** Instituições primeiro; depois Unidades,
   Grupos, Pessoas, Perfis de Acesso, Modelos e Convites.
5. **Fase 4 — operação:** Atividades, Avaliações, Alunos, Assiduidade, Rotina e Agenda.
6. **Fase 5 — comunicação:** Chat, Avisos, Formulários, Acontece, Agora e Momentos.
7. **Fase 6 — cuidado:** Segurança infantil, Saúde e Medicação.
8. **Fase 7 — plataforma:** Importações, arquivos, Auditoria, Suporte, Catálogo,
   Planos, Cardápios, Usuários internos e páginas de erro.
9. **Fase 8 — fechamento:** regressão global, acessibilidade, responsividade,
   relatório e atualização dos três rastreadores.

Em revisão exclusivamente visual/Flutter, a ordem aprovada de liberação é:
Instituições; Unidades; Turmas; Atividades; Pessoas; Perfis e Permissões;
Usuários internos; Assiduidade; Rotina diária; Segurança da criança; Perfis de
cuidado; Planos de medicação; Planos; Importações; Conversas; Convites;
Auditoria; Catálogo; e, por fim, verificação rápida das demais superfícies.
Auth e shell continuam gates anteriores a essa sequência. A coluna `Ordem` da
matriz abaixo serve para inventário compartilhado entre os três rastreadores,
não substitui esta sequência de liberação Flutter.

Dentro de cada família, seguir: **listar/visualizar → criar → detalhe → editar →
publicar/ativar → arquivar/excluir/revogar → arquivos → erros/permissão → reload**.

### Conselho operacional atual e próximo passo seguro

A prioridade extrema não é tentar “fechar telas” em massa no worktree atual. O
primeiro pacote deve restabelecer uma base de evidência confiável, porque router,
Auth, componentes, catálogo, testes e goldens têm mudanças concorrentes.

| Prioridade | Recorte aconselhado | Nível | Estimativa | Resultado esperado | O que continua pendente |
|---:|---|---|---:|---|---|
| P0 | Fase 0 + `catalog.validate` + `catalog.sync` + gates Flutter/UI do snapshot | Intermediária | 4–6 h | Reproduzir o estado atual, classificar os fingerprints, validar composição prod/DEV e corrigir apenas regressões mecânicas comprovadas do catálogo/gates, com testes. | `superadmin.forms-response` depende de decisão funcional; nenhuma tela concluída; Auth, shell, Instituições, responsividade global, goldens e backend continuam abertos. |
| P0.5 | Recuperação de compilação do snapshot: Forms, Acompanhamento, testes de acesso e fronteira com Unidades | Intermediária de integração | 2–4 h de reconciliação; correções funcionais são reestimadas depois | Localizar os lotes/commits correspondentes, recompor versões coerentes e rerodar analyzer sem criar shims ou esconder fail-closed. | Forms integrado, Acompanhamento, Unidades e backend continuam separados até contratos e ownership próprios. |
| P1 | Auth + shell (`auth.*`, `shell.*`) | Avançada | 1–2 dias | Corrigir navegação/sessão/erros compartilhados com matriz responsiva, teclado, foco e regressão. | Supabase/Auth remoto e demais telas continuam abertos. |
| P2 | Instituições: listar, filtrar, status, erro e reload | Avançada | 1 dia | Revalidar a baseline de diretórios, Cards/tabela, filtros, estados e evidências exatas. | Criar/Editar Instituição e backend continuam abertos. |
| P3 | Criar/Editar Instituição | Avançada | 1 dia | Revalidar a baseline administrativa de wizard/formulários, mídia, rodapé e estados. | Só Completa pode encerrar a tela; integração Supabase continua separada. |

**Conselho final atual:** começar por **P0 Intermediária, com teto de 6 horas**.
É o menor pacote que reduz incerteza sem omitir testes, acessibilidade,
responsividade ou evidência. Se P0 revelar regressão estrutural em Auth/shell,
parar no checkpoint e reestimar P1; se os gates ficarem confiáveis, seguir para
Instituições em pacote Avançado. Não aconselhar uma Básica neste snapshot.

**Critério de parada de P0:** inventário do snapshot reproduzível; fingerprints
classificados; primeira falha real corrigida somente se mecânica e dentro do
recorte; análise/testes/validadores proporcionais executados; rastreador
atualizado; nenhum golden promovido automaticamente; nenhum Supabase alterado.

**Checkpoint de P0:** registrar tempo gasto/restante, comando e resultado em
linguagem comum, arquivos tocados, regressões encontradas, ações corrigidas,
ações ainda abertas, dependências integradas, bloqueio e próxima ação segura.

## 7. Snapshot retomável em 2026-08-26

- Base observada: `447ac02c6c75617a8233f141dd0b2c8dc6c228d1`.
- Este arquivo está não rastreado (`??`) no worktree; preservar até integração
  documental deliberada.
- A revisão desta atualização foi exclusivamente documental. Nenhum analyzer,
  teste Flutter, golden, PNG, E2E, banco ou Supabase foi executado agora.
- A última cadeia registrada chegou a analyzer global sem erros/avisos/infos e
  validadores visuais sem diagnóstico antes dos commits finais. Isso não
  substitui uma execução fresca no worktree integrado atual.
- Há 19 commits integrados entre `9e3c9622` e o HEAD atual.
- O relatório **do HEAD** está `catalogStale` com 8 fingerprints:
  `superadmin.avatar-crop-dialog`, `superadmin.advanced-color-picker`,
  `superadmin.cover-crop-dialog`, `admin.dialog-shell`,
  `admin.interactive-card`, `admin.kanban-board`, `superadmin.forms-editor` e
  `superadmin.forms-response`. O worktree contém fontes/relatório preparados que
  reduziriam a contagem a 2, mas eles não estão commitados e não substituem o
  estado de HEAD. Os 2 restantes desse preparo são Advanced Color Picker e as
  duas superfícies Forms cuja decisão funcional continua aberta.
- Resíduo visual atual: 199 PNGs rastreados alterados fora de `failures/`
  (173 `M`, 26 `D`), 72 PNGs rastreados alterados dentro de `failures/`, 93 PNGs
  não rastreados e 1.564 arquivos existentes sob diretórios `failures/`.
  Nenhum deles foi aprovado, restaurado, apagado ou promovido nesta atualização.

### Inventário documental desta atividade

- Orçamento indicado pelo usuário: preferência teórica por **Intermediária**;
  duração total ainda aberta e dependente do inventário.
- HEAD continua em `447ac02c6c75617a8233f141dd0b2c8dc6c228d1`, mas o worktree possui
  centenas de mudanças concorrentes em código, testes, goldens, fontes, specs e
  decisões. Os dois rastreadores consultados continuam não rastreados (`??`).
- Existem alterações atuais em Auth, shell/router, Instituições, Unidades,
  Atividades, Agenda, Chat, Formulários, Saúde, Pessoas, Suporte, pacotes UI,
  testes e goldens. Elas foram somente inventariadas; esta atividade não assume
  autoria, não restaura, não apaga e não certifica nenhuma delas.
- A busca leve de componentes crus encontrou ocorrências em Login,
  Instituições e Suporte. Elas são **candidatas a auditoria**, não defeitos
  declarados: é obrigatório conferir implementação, componente canônico,
  allowlist e evidência antes de corrigir.
- Nenhum analyzer, teste Flutter, golden, validador de catálogo, execução visual
  ou backend foi executado nesta organização documental. Evidências históricas
  foram preservadas, mas precisam ser reexecutadas no snapshot que vier a ser
  contratado.

### Checkpoint operacional P0 — retomada segura

- Pacote e nível: **P0 Intermediária concluída no recorte contratado**, teto de
  6 horas; aproximadamente 1 h 20 min consumidos e cerca de 4 h 40 min ainda
  disponíveis para diagnóstico e contratação do próximo pacote.
- Posição exata: gates e validação estrutural concluídos; iniciar triagem
  somente leitura dos 100 erros globais para definir o próximo pacote por
  tela/ação, sem misturar correções externas ao catálogo.
- Correção desta atividade: o `example` do seletor avançado de cores foi
  alinhado ao uso já existente de `CoeloAdminDialogShell`, fechamento acessível,
  ações Cancelar/Usar cor e controle por teclado. Nenhum comportamento de tela
  foi alterado por esta atividade.
- Evidências frescas: índice válido com zero diagnóstico; fronteiras válidas
  com zero diagnóstico; contrato visual válido com zero diagnóstico; 23 testes
  do sincronizador executados e aprovados; 6 testes do contrato visual
  executados e aprovados; 2 testes do seletor executados e aprovados; análise
  estática dos arquivos do seletor e Forms sem problemas.
- Resultado do sync: caiu de 2 para 1 diagnóstico. O único restante é
  `superadmin.forms-response`, preservado como `blocked-decision`; não alterar o
  exemplo ou relatório apenas para obter estado verde.
- Gate global inicial: o analyzer completo do Superadmin encontrou 174
  diagnósticos — 100 erros, 29 avisos e 45 infos. Após reconciliar
  Acompanhamento, o gate caiu para 91 diagnósticos — 38 erros, 8 avisos e 45
  infos. Os 38 erros restantes são Forms (34), Perfis de acesso (3) e Unidades
  (1); o app ainda não pode ser declarado verde.
- Causa raiz dos 100 erros: 62 pertencem a Acompanhamento, cujas camadas
  data/tela/testes não rastreadas usam contrato diferente do domínio rastreado;
  34 pertencem a Forms, cujas rotas/camadas não rastreadas e teste rastreado
  esperam a API integrada enquanto a página rastreada permanece fail-closed; 3
  pertencem a testes de Perfis de acesso não rastreados com shims reprovados; 1
  pertence a Unidades e está sob alinhamento com a revisão integrada.
- Contratos incompatíveis mapeados: Forms espera `api`, `occurrenceId`, storage
  do segredo anônimo e request ID; Acompanhamento espera cinco drafts, cinco
  comandos de escrita, `canManage`, definições de instrumento/competência/
  desenvolvimento e storage de arquivos que não pertencem ao domínio atual;
  testes de acesso pedem `accessProfileExtendedRepository`/`contextCount`,
  explicitamente reprovados pelo gate fail-closed canônico.
- Dependência de Unidades: o adapter
  `supabase_unit_backend_commands_gateway.dart` já cobre import/export, porém o
  production auth scope injeta explicitamente gateways indisponíveis. Não
  inventar API nem editar a composição até o handoff Supabase.
- Evidência final do P0: 137 testes do Catálogo, 107 testes de
  `coelo_ui_admin` e 8 testes focados do Superadmin foram executados; todos os
  252 passaram. Essas contagens incluem os testes já executados isoladamente e
  não devem ser somadas novamente. Analyzers de Catálogo, `coelo_ui_admin` e
  arquivos focados do Superadmin passaram. O analyzer global não passou pelos
  174 diagnósticos acima.
- Arquivos alterados por esta atividade até aqui:
  `apps/catalog/assets/coelo-ui.index.jsonl`,
  `apps/catalog/assets/catalog-sync-report.json` e este rastreador. Os dois
  assets já continham mudanças concorrentes; preservar o diff completo e não
  assumir autoria externa.
- Integridade do rastreador: 201 ações, 201 `action_id` únicos, zero duplicação
  e zero linha malformada na tabela por tela/ação. `git diff --check` passou.
- Próximo passo seguro: P0.5, localizar a origem dos lotes incompletos e
  reconciliar versões coerentes antes de alterar superfícies. Não criar shims
  `accessProfileExtendedRepository`, `contextCount` ou equivalentes; não tocar
  Unidades antes do alinhamento integrado; não executar goldens com
  `--update-goldens`.
- Supabase, banco, remoto, stage, commit e deploy: não executados e fora do
  recorte.

### Checkpoint P1 — Auth e shell isolados

- Ações revalidadas: `auth.login`, `auth.recover`, `auth.reset`, `auth.logout`,
  `shell.load`, `shell.navigate` e `shell.unauthorized`.
- Auth: 99 testes de domínio, view models, widgets, telas e matriz responsiva
  foram executados e todos passaram; analyzer da feature e testes sem problema.
- Shell visual: 87 testes foram executados e todos passaram; analyzer de
  `lib/app/shell` e `test/app/shell` sem problema. Há cobertura de item
  selecionado, hierarquia, flyout, hover, claro/escuro, larguras responsivas,
  texto ampliado, teclado, reduced motion, logout e feedback de falha.
- Limite da evidência: router/deep links globais não foram promovidos porque o
  snapshot ainda possui 38 erros externos; `shell.switch-context`,
  `shell.reload` e `auth.mfa` continuam abertos. Nenhuma tela foi declarada
  concluída e nenhuma integração Auth/Supabase foi certificada.
- Próximo passo seguro: recuperar um snapshot coerente no P0.5, rerodar o
  analyzer global e só então executar router/deep links de Auth/shell. Se a
  origem não estiver disponível, preservar este checkpoint sem criar shims.

### Checkpoint P0.5 — grupo Acompanhamento

- Origem canônica: `f525a7f4` (`fix(student-tracking): keep production
  read-only`) é ancestral do HEAD; a árvore rastreada atual da família é
  idêntica a esse commit.
- Origens de gerenciamento `69eb6526`/`1e7a5168`, baselines
  `da2e1538`/`f9399723` e branch `codex/student-tracking-readonly` não são
  ancestrais do HEAD. Não restaurar drafts/comandos de escrita no domínio.
- Resíduo recuperado: 24 arquivos, 451.151 bytes, manifesto determinístico
  SHA-256 `5417fc9b1ce2d84f5f182ade9c4f3a16d640a83e19399558b68bb79ecbd8cd3a`.
  Eles incluem adapter Supabase, página de gerenciamento, testes e goldens;
  foram movidos individualmente para
  `C:\Users\adrie\Documents\Coelo-recovery-20260825-final\student-tracking-legacy-20260826-flutter-recovery`
  sem perda ou alteração de manifesto.
- GREEN canônico: 22 testes rastreados foram executados e todos passaram; a
  análise dos seis arquivos rastreados não encontrou problemas. Há cobertura
  375/768/1024/1440, texto a 200%, teclado, reduced motion, acesso negado,
  offline, unavailable, retry e ausência de ações de gerenciamento.
- Validação posterior: origem com zero arquivo legado, destino com 24 arquivos,
  451.151 bytes e mesmo manifesto; analyzer global caiu de 100 para 38 erros,
  com zero erro de Acompanhamento; 22 testes canônicos passaram novamente.
- Próximo passo seguro: grupo Forms, somente inventário/recuperação de origem
  dos 34 erros antes de alterar código.

### Checkpoint P0.5 — Forms, subgrupo `forms.respond`

- Posição atual: primeiro subgrupo de Forms encerrado; `forms.edit` é o próximo
  grupo permitido. Não avançar para outras ações de Forms antes de novo
  inventário/contrato nominal.
- Causa reproduzida: um lote concorrente substituía o teste fail-closed por um
  contrato integrado ainda não adotado e adicionava uma rota incompatível. Isso
  produzia 32 dos 34 erros de Forms no analyzer global.
- Preservação: os sete arquivos do delta (1 tracked copiado e 6 untracked
  movidos individualmente) estão em
  `C:\Users\adrie\Documents\Coelo-recovery-20260825-final\forms-response-delta-20260826-flutter-recovery`.
  O destino contém 7 arquivos, 40.944 bytes e manifesto determinístico SHA-256
  `bc578089790f4867ce83b3a26e2da05a57c451d6341cdc1eac6ff87ac227af66`.
- Correção executada: somente
  `test/features/forms/presentation/response/form_response_page_test.dart` foi
  restaurado ao blob canônico do HEAD
  `7006d84b0313cd53609edbbdbc8bc8667da92415`; os seis untracked preservados não
  permanecem na árvore ativa. Nenhum outro path de Forms foi alterado.
- GREEN local: 1 teste canônico fail-closed foi executado e passou. O analyzer
  global caiu de 38 para 6 erros e de 34 para 2 erros em Forms; há zero erro em
  `forms.respond`. Os 6 erros restantes são 2 de `forms.edit`, 3 de Perfis de
  acesso e 1 de Unidades. O analyzer global ainda não está verde: reportou 54
  issues ao incluir warnings e infos.
- Catálogo: validação feita com relatório temporário externo retornou exatamente
  1 diagnóstico, `superadmin.forms-response`. O índice e o report rastreados não
  foram atualizados; nenhum golden foi executado ou regenerado.
- Estado correto: `forms.respond` é `local-green` apenas para o fail-closed. A
  ação e a tela não estão concluídas; resposta real e integração Flutter–Supabase
  continuam pendentes.
- Próximo passo seguro: inventariar separadamente os 2 erros de `forms.edit`,
  identificar a origem do editor concorrente e apresentar contrato/ETA antes de
  preservar ou restaurar qualquer arquivo. ETA inicial do subgrupo: 45–75 min.

### Checkpoint P0.5 — Forms, subgrupo `forms.edit`

- Posição atual: erros de compilação de Forms encerrados. O próximo grupo global
  é Perfis de acesso (3 erros); Unidades permanece congelada por dependência
  integrada e não deve ser composta nesta etapa.
- Causa reproduzida: o Editor integrado já estava coerente com o catálogo, mas o
  teste agregado de superfícies dormant ainda o instanciava pelo construtor
  fail-closed antigo. Os 2 erros restantes de Forms vinham exclusivamente dessa
  referência obsoleta.
- Correção mínima: removidos apenas o import do Editor e a entrada `editor` do
  loop fail-closed em
  `test/features/forms/presentation/forms_dormant_surfaces_test.dart`. As
  superfícies `response` e `test` continuam fail-closed. Página, rota, API,
  catálogo, report e goldens não foram alterados neste subgrupo.
- GREEN local: 24 testes non-golden foram executados e todos os 24 passaram: 2
  de autosave/retry, 17 do componente Editor, 1 arquivo de rota e 4 cenários
  dormant. A matriz inclui 375 px e comandos acessíveis; não houve prova nova de
  texto a 150%/200% nem inspeção visual de golden.
- Analyzer global: caiu de 6 para 4 erros e de 2 para zero erro em Forms. Restam
  3 erros de Perfis de acesso e 1 de Unidades. O resultado global ainda não é
  verde: são 52 issues ao contar warnings e infos.
- Catálogo: sync com report temporário externo retornou exatamente 1 diagnóstico,
  `superadmin.forms-response`. Nenhum índice/report do repositório ou golden foi
  atualizado.
- Limite: `forms.edit` é `local-green` somente como componente local/catalogado.
  `forms.create` e `forms.publish` não foram promovidos; rota produtiva,
  capability, persistência/autorizações reais e integração Flutter–Supabase
  continuam bloqueadas. Nenhuma tela foi declarada concluída.
- Manifesto preventivo não movido: 26 arquivos do lote integrado foram
  inventariados (331.564 bytes, SHA-256
  `bd1995b27ce7051020531c793a49c3d23a160522229fa53ad35f979e5d8155ae`),
  mas permaneceram no workspace por decisão nominal de adoção local.
- Próximo passo seguro: inventariar os 3 erros de Perfis de acesso, separar
  testes/wiring do contrato de repository e apresentar causa/ETA antes de
  corrigir. ETA inicial: 45–75 min.

### Checkpoint P0.5 — inventário Perfis/Modelos de acesso

- Posição atual: opção A fail-closed executada após o checkpoint backend; Access
  tem zero erro no analyzer. Unidades é o único erro global restante e continua
  congelada até sinal integrado.
- Erros mapeados: dois testes router untracked tentam injetar
  `accessProfileExtendedRepository` em uma composition root que deliberadamente
  não aceita esse parâmetro e serve 503 nas rotas de modelos. O terceiro erro
  vem do fake untracked que ainda fornece `PrincipalCapability.contextCount`,
  removido do domínio atual; `isDemo` obsoleto também gera warnings em fakes.
- Mapa de ações: wiring de lista → `access-models.list`; deep links →
  `access-models.detail` e `access-models.duplicate`; fake compartilhado →
  `access-profiles.list`, `access-profiles.detail`, `access-profiles.create` e
  `access-profiles.edit`.
- Lacuna corrigida no rastreador: `access-models.filter` foi adicionada como
  ação independente porque a página possui busca, troca de domínio, estado sem
  resultados e reload. `deleteModel` aparece somente no contrato de repository,
  sem ação de UI comprovada; por isso não virou `action_id` de tela e permanece
  apenas como dependência futura bloqueada.
- Preservação executada: os três arquivos foram copiados para
  `C:\Users\adrie\Documents\Coelo-recovery-20260825-final\access-profiles-delta-20260826-flutter-recovery`
  e validados antes de mover somente os dois testes router incompatíveis. O fake
  compartilhado permaneceu ativo. O destino contém 3 arquivos, 12.539 bytes,
  SHA-256 `fe61476c955fe7701abbb9f3583cea1eb8b1c6c7512d56eda5825410e84a95ae`.
- Correção mínima no fake untracked: removidos somente `isDemo` e
  `PrincipalCapability.contextCount`, ambos ausentes do contrato atual. O fake
  tracked com warning não foi alterado por falta de grant nominal.
- Evidência: 9 testes Access independentes passaram, incluindo UI a 200% e
  768 px. Dois arquivos de teste router não chegaram a executar porque a
  composição global ainda falha no erro de Unidades; isso não é falha de
  comportamento Access. O analyzer caiu de 4 para 1 erro e reportou zero erro
  Access, mas 48 issues totais e um warning Access ainda permanecem.
- Catálogo: sync temporário externo retornou somente
  `superadmin.forms-response`; índice, report e goldens não foram atualizados.
- Limite: nenhum `access-profiles.*` ou `access-models.*` foi declarado integrado
  ou concluído. Create/edit/assign/delete/model CRUD permanecem bloqueados;
  composition root segue 503.
- Próximo passo seguro: aguardar o sinal do integrador para Unidades. Depois de
  remover o erro externo, rerodar os dois testes router fail-closed e o analyzer
  global antes de qualquer nova promoção Access.

### Checkpoint P0.5 — `units.list` e estados do diretório

- Posição atual: o último erro de compilação global foi removido com um patch de
  uma linha no caller de `UnitDirectoryStates`. Nenhuma composição import/export
  está autorizada; pausar aqui antes de qualquer fatia vertical integrada.
- Causa/patch: o delta vivo de `unit_directory_states.dart` tornou
  `createAction` obrigatório para failure/empty/noResults, mas o caller canônico
  não o fornecia. Foi adicionado somente
  `createAction: UnitCreateBanner(onPressed: onCreate),` em
  `unit_directory_page.dart`; nenhum outro hunk de código Units mudou.
- Evidência Units: 16 testes non-golden foram executados e todos passaram. Eles
  cobrem states, Cards/tabela, status, 375/768/1024/1440, texto a 200%, toque e
  estados recuperáveis/unauthorized. O teste existente de diálogo import também
  passou incidentalmente, mas isso não certifica import/export ou backend.
- Evidência Access desbloqueada: os 2 arquivos router antes bloqueados por Units
  executaram 5 testes e todos passaram, confirmando 503 fail-closed em
  375/1440 e texto a 200%.
- Analyzer global: zero erros; ainda existem 47 issues (2 warnings e 45 infos),
  portanto o analyzer não é integralmente verde. Catálogo externo manteve
  exatamente `superadmin.forms-response`; nenhum report/índice/golden mudou.
- Ações separadas: `units.filter`, `units.error`, `units.reload` e
  `units.access-denied` foram adicionadas à matriz com estado máximo
  `local-green`, limitado à UI local. `units.create` não foi promovido.
- Dependência integrada: backend local Units reportado 180/180 verde, mas
  produção continua injetando gateways `Unavailable`; `units.import` e
  `units.export` permanecem `blocked-supabase`.
- Próximo passo seguro: enviar checkpoint ao integrador e aguardar contrato
  nominal antes de qualquer composição import/export. Fora desse handoff, o
  próximo pacote Flutter seguro é reduzir warnings/infos por grupo, sem misturar
  backend; ETA inicial 1–2 h para um grupo pequeno.

### Checkpoint seguro — `units.access-denied`

- Posição atual: o pacote independente corrigiu apenas a composição final de
  acesso negado em `unit_directory_page.dart` e adicionou
  `unit_directory_access_denied_test.dart`. O hunk anterior
  `createAction: UnitCreateBanner(onPressed: onCreate),` foi preservado.
- Correção comprovada: quando o ViewModel termina em `unauthorized`, a árvore
  mantém o painel canônico de negação e omite toolbar, busca/filtros, tabs,
  alternância de visualização, `UnitFileActions`, import/export, criar,
  Cards/tabela e paginação. O source atual **não** oculta esses controles em
  `initial/loading`; não registrar essa proteção como executada.
- Evidência TDD: o RED causal encontrou `UnitDirectoryToolbar` no estado final
  negado. Após o patch, o handoff final registrou 23 testes non-golden e todos
  os 23 passaram; uma suíte ampliada desta frente executou 25 testes e todos os
  25 passaram. Isso inclui acesso negado, states, página e rotas prod/DEV
  fail-closed, mas não constitui E2E.
- Evidência de qualidade: analyzer focado dos dois paths sem issues; analyzer
  global com 0 erros, 0 warnings e 45 infos preexistentes; format 2/2 sem
  mudança e diff-check verde. Validador visual admin terminou com exit 0. O
  catálogo em report externo ficou `synchronized` com zero diagnóstico no
  snapshot corrente; essa mudança concorrente não é atribuída ao patch de
  Unidades. Nenhum golden foi executado ou atualizado.
- Manifesto final: `unit_directory_page.dart`, 16.120 bytes, SHA-256
  `8d51cdda14835d4b0eff14f739470e139ffc85af89a83e0ad54913b28777294e`,
  OID `c5cc5a2e1a14fceccd890498d9108adb925995fd`;
  `unit_directory_access_denied_test.dart`, 4.276 bytes, SHA-256
  `02863c77062affbe2bb43bc1301c2a2d6e3507f74353da307cdb59f43a9f1210`,
  OID `19a0d37f85129ecff5dac813f2ab3d372c6bfec0`.
- Estado correto: atividade corretiva local concluída; ação Flutter permanece
  somente `local-green`; tela de Unidades não concluída; Supabase continua
  `audited/fail-closed`; integração permanece `blocked-supabase`; zero E2E.
- Pendências e bloqueios: o ViewModel ainda conserva página/filtros anteriores
  em memória após a negação, embora a UI final não os renderize. Ausência de
  controles antes da primeira resposta, success→revogação, sessão/vínculo
  revogado, tenant A/B, link direto para criar/editar, foco/teclado e prova
  backend/RLS exigem pacote e contrato próprios. Não inferir capacidade pelo
  estado de loading nem ocultar toolbar durante refresh autorizado, pois isso
  faria busca/filtros perderem geometria e foco.
- Dependência integrada adicional: o handoff remoto informou RED 42702/42703 em
  `institutions.import`/`institutions.export`. Este rastreador mantém essas ações
  somente `audited`, sem `local-green` ou E2E; a falha remota não foi revisada ou
  certificada nesta atividade Flutter.
- Próximo passo seguro: congelar os dois paths e este checkpoint para a
  consolidação documental. Um futuro pacote Avançado de 2–4 h deve começar por
  contrato explícito de capability/revogação e testes delayed-load,
  success→revogação, cache/foco e deep link; backend/tenant/E2E permanecem
  separados.

### Checkpoint seguro — `units.export` HARDEN-EXPORT A+B

- Posição atual: o pacote Flutter local de hardening A+B foi executado somente
  em `unit_backend_commands.dart`,
  `supabase_unit_backend_commands_gateway.dart`, `unit_file_actions.dart` e nos
  testes diretos do gateway/widget. A produção continua injetando
  `UnavailableUnitBackendCommandsGateway`; nenhum auth scope, composition root,
  backend, migration, Edge Function, remoto ou golden foi alterado.
- Contrato A: `request_export` envia o snapshot canônico e recebe apenas o job;
  somente um job `SUCESSO` permite chamar `download` com o mesmo `job_id`. O
  parser rejeita DTO privado/malformado, divergência de job/domínio/direção/
  formato, colunas fora da allowlist, URL precoce, TTL inválido e URL que não
  seja HTTPS da origem/porta Supabase e do path privado canônico. Importação usa
  parser separado e permaneceu funcionalmente intacta.
- Contrato B: a ação é single-flight; retry incerto preserva a mesma chave de
  idempotência e o mesmo snapshot, enquanto mudança de payload ou falha não
  repetível inicia nova tentativa. O opener é injetável e chamado no máximo uma
  vez por execução; popup bloqueado reaproveita o artefato validado sem gerar
  outro export. `expiresAt` é revalidado antes da abertura. Busy usa semântica
  live/disabled, bloqueio de foco, teclado e ponteiro, com guarda interna como
  autoridade. O texto não promete revogação física imediata da URL/cache.
- Evidência: os dois arquivos diretos de gateway e widget executaram 41 testes e
  todos os 41 passaram, incluindo regressões de importação, duas chamadas
  ordenadas, correlação do job, URL/TTL, duplo clique, retry/idempotência,
  opener bloqueado, erros tipados, descarte após `dispose` e 375 px com texto a
  200%. O analyzer global encontrou 0 erros, 0 warnings e 45 infos preexistentes;
  portanto não é integralmente verde. Cinco arquivos estavam formatados e o
  diff-check passou. O catálogo foi validado em report externo e manteve somente
  `superadmin.forms-response`; índice/report rastreados não mudaram. Nenhum
  golden foi executado ou atualizado.
- Estado correto: `units.export` está no máximo `audited/local-hardening` no
  Flutter e continua `blocked-supabase`/`blocked-decision`, com zero prova E2E.
  A atividade contratada A+B pode fechar sem declarar a ação ou a tela
  concluída. Signed URL expirada localmente significa apenas “não abrir este
  link”; não comprova indisponibilidade física imediata no CDN.
- Decisões/dependências: OQ-032 e OQ-034 permanecem abertas. A implementação
  atual exige vínculo platform/global para pedir export, mas materializa por
  `units.read` institucional; não promover Operations. Até decisão canônica,
  Owner global + AAL2 é apenas baseline transitório conservador. Filtros do
  cliente nunca definem alcance; um fluxo futuro precisa persistir escopo
  autoritativo derivado do vínculo e reautorizar `units.export` em request,
  materialize, complete, sign e remint. TTL/cache-control/cleanup por objeto são
  responsabilidades backend/remoto fora deste recorte.
- Lacuna separada registrada como `units.people-export`: o botão e o SnackBar
  de falso sucesso foram removidos. A ação produtiva permanece ausente e
  `blocked-decision`, sem confundir com `units.export` nem `people.export`.
  Implementação funcional exige pacote próprio Completa, 18–32 h, começando
  por decisão de capability/AAL2/escopo unitário/colunas minimizadas.
- Próximo passo seguro: preservar estes cinco paths e o rastreador até o handoff
  nominal; não compor produção. Depois, decidir OQ-032/OQ-034 e alinhar o backend
  remoto antes de qualquer fatia de composição/E2E. Se o trabalho continuar só
  no Flutter, executar um pacote separado para as lacunas não bloqueantes de
  teste (sucesso seguido de nova chave e rebuild alterando filtros/view), ETA
  1–2 h, sem tocar em `units.people-export`.

### Checkpoint seguro — `units.export` snapshot após rebuild

- **Action_id:** somente `units.export`; nenhuma migration, Edge Function,
  configuração, dado ou recurso remoto foi alterado.
- **RED reproduzido:** durante `generateExport`, um rebuild com nova
  `UnitDirectoryQuery` fazia a UI abrir a signed URL do snapshot anterior.
- **Causa raiz:** a assinatura era capturada antes do `await`, mas não era
  revalidada antes de abrir o artefato.
- **Correção mínima:** após a resposta, a UI recompõe a assinatura; em caso de
  divergência limpa o download pendente, não abre URL e informa que filtros ou
  visão mudaram, exigindo nova geração.
- **GREEN focado:** `unit_file_actions_test.dart` passou 21/21, incluindo 375 px
  com texto a 200%; o conjunto gateway + widget passa agora 42 testes diretos.
- **Estado:** a correção Flutter desta unidade está `local-green`, mas a ação
  integrada continua `blocked-supabase`, com produção `Unavailable` e zero E2E.
- **Próximo gate:** revisar o request/status/download do gateway sem compor
  produção; preservar os 11 REDs Supabase já catalogados.

### Checkpoint seguro — `units.export` request/status/download

- **Action_id:** somente `units.export`; nenhuma alteração Supabase ou remota.
- **RED reproduzido:** o teste do contrato canônico exigiu três chamadas e
  recebeu somente duas; o gateway pulava `status` e ia de `request_export`
  diretamente para `download`.
- **Causa raiz:** `generateExport` não consumia a ação `status` já prevista e
  testada pelo hub local.
- **Correção mínima:** `status` é chamado com o `job_id` retornado, sua resposta
  não pode conter artefato, precisa manter ID/domínio/direção/formato e chegar a
  `SUCESSO`; somente então o mesmo ID segue para `download`.
- **Provas:** gateway 24/24, incluindo job divergente, artefato prematuro e
  estado não pronto; widget 21/21; analyzer focado em quatro arquivos sem
  issues. Total direto do recorte Flutter: 45/45.
- **Estado:** gate Flutter `local-green`; `units.export` integrado continua
  `blocked-supabase`, produção `Unavailable`, sem remoto mutável e sem E2E.
- **Próximo gate:** provar replay após sucesso sem rematerialização no backend
  local, mantendo a composição produtiva fechada.

### Checkpoint seguro — `units.export` fronteira pós-conclusão

- **Action_id:** somente `units.export`; nenhuma alteração Flutter adicional,
  migration, deploy ou mutação remota.
- **RED:** resposta de conclusão perdida e falha de signed URL provocavam
  deleção do artefato possivelmente canônico e tentativa de marcar erro.
- **Correção:** o worker registra a fronteira antes de chamar a conclusão; após
  esse ponto, falhas retornam de modo seguro sem cleanup otimista nem demotion.
- **Provas:** os dois cenários passaram; arquivo pós-sucesso ficou 3/4, matriz
  Deno 36/44 e regressão Flutter 45/45.
- **Estado:** dois gates locais GREEN; ação Flutter permanece `local-green`,
  integrada `blocked-supabase`, produção `Unavailable`, zero E2E.
- **Próximo gate:** reautorização depois da conclusão e antes da assinatura.

### Checkpoint seguro — `units.export` reautorização pós-conclusão

- **Action_id:** somente `units.export`; nenhuma alteração Flutter, migration,
  deploy ou mutação remota.
- **RED:** ator revogado depois do commit ainda alcançava a mintagem da URL.
- **Correção:** `reauthorizeExportJob` é executada novamente depois da resposta
  de conclusão e imediatamente antes de `createSignedUrl`.
- **Provas:** pós-sucesso 4/4, matriz Deno 37/44, `deno check` GREEN e Flutter
  45/45 preservado.
- **Estado:** gate local GREEN; ação Supabase `audited`, integrada
  `blocked-supabase`, produção `Unavailable`, zero remoto/E2E.
- **Próximo gate:** impedir chamada direta do worker com JWT do navegador.

### Checkpoint seguro — `units.export` delegação exclusiva ao worker

- **Action_id:** somente `units.export`; Flutter não foi recomposto em produção.
- **RED:** JWT do navegador chamava `unit-export` diretamente, alcançava RPC e
  podia receber campos privados fora do sanitizador do hub.
- **Correção:** hub e worker compartilham somente em runtime o segredo dedicado
  `COELO_UNIT_EXPORT_WORKER_SECRET`; o worker exige o header interno antes de
  ler a sessão ou chamar RPC. Não foi usado `service_role` como credencial de
  delegação.
- **Provas:** chamada direta 403/zero RPC; hub verifica o header; pós-sucesso
  4/4; suíte unit-export 41/47 e Flutter 45/45.
- **Estado:** sétimo gate local GREEN e pacote principal 7/7; ação continua
  `blocked-supabase`, pois segredo/deploy remoto, grants, retenção, cleanup,
  composição e E2E seguem abertos.
- **Encerramento medido:** recorte 100,00% (7/7), restante 0,00% (0/7);
  backlog integrado 0,00% (0/207), restante 100,00% (207/207). Foram medidos
  28 min entre o marcador retomável 16:44 e 17:12 BRT; o inventário anterior ao
  marcador não é reconstruível com precisão e não foi inventado.

### Dependências integradas identificadas e fora de escopo

A consulta leve ao rastreador Flutter–Supabase registra a estrutura atual de
**202 ações normativas + 5 ações de shell = 207 IDs totais**. No último
checkpoint integrado recebido, 40 estavam `not-reviewed`, 111
`blocked-supabase` e 51 `blocked-decision`; nenhuma estava `verified-e2e`.
Esses números significam que não há ação com prova atual completa do clique no
Flutter até persistência/autorização no backend. Nesta atividade Flutter:

- Auth, MFA, sessão e usuários internos dependem de Auth/capabilities reais;
- criar, editar, publicar, arquivar, revogar e excluir dependem de comandos
  autorizados e não podem ser simulados pela UI;
- arquivos e mídia dependem dos gateways privados e da separação Storage/R2;
- ações com dados infantis, saúde, medicação e auditoria dependem de decisões
  jurídicas, retenção e autorização;
- nenhuma migration, policy, RPC, Edge Function, bucket, deploy ou dado remoto
  será revisado, alterado ou certificado neste recorte Flutter.

### Evidência recente já integrada

As contagens abaixo registram gates executados nas respectivas cessões. Elas não
foram reexecutadas nesta consolidação e não provam ações não cobertas pelo teste.

| Commit | Fechamento Flutter comprovado no lote | Limite ainda aberto |
|---|---|---|
| `447ac02c` | Catálogo Fase 1A integrado; relatório HEAD materializado com 8 fingerprints. | Fontes posteriores preparadas não estão commitadas; Forms editor/response e publicação/API continuam abertas. |
| `bd476af8` | Suporte compacto: 54/54 testes; paginação 15/15; 375/768/1024/1440 e texto 150%/200% no lote. | Detalhe, responder, encerrar e goldens não foram fechados. |
| `c04e49fb` | Assiduidade em 375 px: matriz 9/9, suíte da família 47/47 e DEV 4/4 no handoff; texto 200% coberto no lote. | Dois goldens do dashboard, E2E e exportação permanecem separados. |
| `9119e03b` | Agora/Momentos: rota 6/6 e regressões non-golden 73/73; `Esc` fecha e devolve foco no cenário coberto. | Publicar/remover/expirar reais e E2E continuam abertos. |
| `b2ff69bf` | Central de Ajuda usa flyout canônico; 12/12; viewport, teclado, `Esc` e foco no lote. | Goldens não foram executados. |
| `90982592` | Segurança infantil: correções mecânicas e suíte focada 23/23. | Suspensão/revogação real e matriz visual integral não comprovadas. |
| `ec31171c` | Atividades: 90/90 non-golden; adapters gate-only 21/21; fluxo DEV e fail-closed produtivo. | Produção permanece indisponível e sem E2E. |
| `aa414efa` | Convites: 56/56 non-golden no fechamento consolidado; produção indisponível e DEV isolado. | Email/Supabase, goldens e lifecycle real permanecem abertos. |
| `9e3c9622` | Access Basic estático/fail-closed: 35/35 no runtime e 15/15 no recorte de páginas. | Access Extended, Imports prerequisite, CRUD e goldens continuam bloqueados. |
| `6bdbbdac` | Forms composition fail-closed; rotas indisponíveis sem sucesso aparente. | Editor/respostas reais, arquivos F6 e backend continuam abertos. |
| `672ad118` | Grupos: 30/30 feature, 39/39 feature+roots e 33/33 regressões por fatias; DEV isolado e produção fail-closed. | CRUD produtivo, import/export e goldens continuam abertos. |
| `738ce5a9` | Rotina: 35/35 por fatias, incluindo roots 8/8 e regressões 19/19; DEV isolado e produção fail-closed. | Smoke visual integral, E2E e backend continuam abertos. |
| `e5f0523d`/`258afdb7` | Avaliações: repository 3/3, rotas 4/4, controller 5/5 e timezone server-owned. | Páginas/goldens e fluxo completo não foram revalidados. |
| `440b1ca7`/`e4baa5ff` | Pessoas: identidade fail-closed e fake movido a test-support; gates 18/18 e 45/45 nas cessões. | Oito goldens de diretório, status/card e backend permanecem abertos. |
| `8377197b`/`8e743d2c` | Unidades: closure U0/U1 53/53; produção indisponível e DEV isolado. | Commands reais, import/export, geometria e goldens permanecem abertos. |
| `5a56288e` | Perfil Principal estático: 9/9, 375 e 1440 a 200% no lote non-golden. | É preview estático; edição, backend e goldens ficaram fora. |
| `f525a7f4` | Acompanhamento: 29/29; produção somente leitura; gerenciamento indisponível. | Vincular/transferir/editar/revogar reais continuam bloqueados. |
| `3f4b3bf7` | Saúde B2: 28/28 + 42/42 e rotas 6/6; legado/detail removidos e adapter desconectado. | 12 PNGs Health divergentes e medication plans reais permanecem bloqueados. |
| `31660efe` | Import New Dialog funcional com shell/X/Cancelar no lote source/test. | Proveniência/golden, fluxo de importação e download continuam parciais. |

## 8. Pendências gerais Flutter/Dart

| ID | Estado | Pendência atual | Próxima prova exigida | ETA Flutter |
|---|---|---|---|---:|
| FLU-GEN-001 | `audited` | Reconciliar novamente 79 rotas produtivas, 96 DEV, menus e deep links após os commits finais. | Inventário HEAD + smoke source/runtime sem absorver overlays. | 8 h |
| FLU-GEN-002 | `audited` | Confirmar que fake/fixture/cache DEV não aparece em composição produtiva; várias famílias estão fail-closed. | Source guards e testes de wiring por família. | 12 h |
| FLU-GEN-003 | `audited` | Aplicar e provar shell, diretórios, formulários, flyouts, diálogos, calendário e páginas de erro canônicos. | Checklist `coelo-ui` por família. | 24 h |
| FLU-GEN-004 | `audited` | Revisar componentes Material crus, hover, tokens, tipografia, cores e superfícies. | Validador + inspeção dos estados abertos. | 16 h |
| FLU-GEN-005 | `audited` | Revisar widgets grandes, estado assíncrono, guards de comando, `mounted` e separação UI/estado/dados. | Code review e testes de concorrência/erro. | 24 h |
| FLU-GEN-006 | `regressed` | Não existe prova atual completa de 375/768/1024/1440, light/dark e texto 100%/150%/200% para as 37 famílias. | Matriz responsiva incremental, sem golden update automático. | 48 h |
| FLU-GEN-007 | `audited` | Teclado, foco, `Esc`, semântica, contraste, toque e reduced motion só foram provados em lotes específicos. | Matriz de interação por ação alcançável. | 36 h |
| FLU-GEN-008 | `regressed` | 199 PNGs rastreados fora de `failures/` exigem reconciliação individual; 1.564 artefatos `failures/` não são baseline. | Comparação HEAD/current por família e inspeção consciente. | 40 h |
| FLU-GEN-009 | `audited` | Erros, retry/reload, duplo envio, conflito, confirmação e feedback não estão uniformemente provados. | Testes RED/GREEN por comando e estado. | 32 h |
| FLU-GEN-010 | `audited` | Analyzer global fresco após reconciliar Forms, Access e Units tem zero erros, mas ainda reporta 47 issues (2 warnings e 45 infos). | Tratar warnings/infos por grupo e repetir analyzer, suítes non-golden, validadores e diff-check sem confundir zero erro com gate verde. | 3–6 h |
| FLU-GEN-011 | `regressed` | Catálogo HEAD está `catalogStale` com 8 fingerprints; fontes preparadas e não commitadas reduzem a 2. | Revalidar os 6 mecânicos e decidir Forms editor/response antes de regenerar relatório final. | 6 h |
| FLU-GEN-012 | `blocked-decision` | Tours, Agenda draft, Access Extended, Imports parciais, Medication, Plans e usuários internos ainda dependem de contratos/decisões. | Decisão canônica antes de habilitar UI produtiva. | externo |

## 9. Ledger compacto retomável das 37 famílias e ações

Nenhuma família está Flutter 100%. `local-green` significa apenas que o lote
local executado passou; `fail-closed`, `/dev`, preview ou fixture continuam
abertos. O ETA soma trabalho Flutter sequencial e exclui espera por decisões,
backend, ambiente remoto e inspeção humana de cada PNG.

| # | `screen_id` e telas/subtelas | Estado por `action_id` | Bloqueio, próxima ação exata e ETA da família |
|---:|---|---|---|
| 1 | `auth` — Login, recuperar, redefinir, MFA | `auth.login` `local-green`; `auth.recover` `local-green`; `auth.reset` `local-green`; `auth.logout` `local-green`; `auth.mfa` `audited` | 99 testes locais de Auth passaram com matriz 375–1440 e 200%; ainda provar MFA, rotas globais, token/link/sessão reais e integração remota; 3–6 h. |
| 2 | `shell` — Home, menu, contexto, unauthorized, reload | `shell.load` `local-green`; `shell.navigate` `local-green`; `shell.switch-context` `audited`; `shell.unauthorized` `local-green`; `shell.reload` `audited` | Reconciliar deep links e troca de contexto; smoke dos estados e foco; 6 h. |
| 3 | `institutions` — Lista, filtros, detalhe, criar, editar, status, arquivos, importar/exportar, erro, acesso negado e reload | `institutions.list`/`filter`/`create`/`edit`/`status` `local-green`; `institutions.detail`/`files`/`import`/`export`/`error`/`access-denied`/`reload` `audited` | Revalidar baseline e 7 PNGs alterados, com prova isolada das 12 ações e texto 200%; 16 h. |
| 4 | `units` — Lista, filtros, criar, editar, status, erro, acesso negado, reload e arquivos | `units.list`/`filter`/`create`/`edit`/`status`/`error`/`access-denied`/`reload` `local-green`; `units.import`/`export` `blocked-supabase`; `units.people-export` `blocked-decision` | Diretório recompila e 16 testes passaram; import/export continuam com gateways produtivos indisponíveis; `people-export` não possui capability, job, arquivo ou URL próprios e exige decisão. Revisar 17+ PNGs, E2E e composição somente após handoff; 13 h + decisão. |
| 5 | `groups` — Lista, criar, detalhe/editar, membros, arquivos | `groups.list` `local-green`; `groups.create` `local-green`; `groups.edit` `local-green`; `groups.members` `local-green`; `groups.import`/`groups.export` `audited`/`fail-closed`, com falsos controles removidos | Preservar Profile About canônico; provar CRUD produtivo, membros e fluxos reais de arquivo com gateway/job/Storage, autorização, tenant A/B, remoto/E2E; 8 h + backend. |
| 6 | `people` — Lista, criar, editar, vínculos | `people.list` `audited`; `people.create` `local-green`; `people.edit` `local-green`; `people.links` `audited`; `people.reload` `audited` | Identidade produtiva fail-closed; comparar 8 goldens de diretório e revisar status/card, vínculo e reload; 12 h. |
| 7 | `access_profiles` — Lista, criar, detalhe, editar, atribuir/excluir | `access-profiles.list` `audited`; `access-profiles.create` `blocked-decision`; `access-profiles.detail` `audited`; `access-profiles.edit` `blocked-decision`; `access-profiles.assign` `blocked-decision`; `access-profiles.delete` `blocked-decision` | Access Basic 503 é seguro; Access Extended depende de Imports/backend e 16-path closure; não aceitar shims `isDemo/contextCount`; 16 h após decisão. |
| 8 | `access_models` — Lista, filtros, criar, detalhe, editar, duplicar | `access-models.list`/`filter` `audited`; `access-models.detail`/`duplicate`/`create`/`edit` `blocked-decision` | Manter Basic Access; testes concorrentes foram preservados e composition root segue 503. `deleteModel` não possui superfície UI comprovada. Capability/backend ainda bloqueiam composição; 11 h. |
| 9 | `invites` — Lista, criar, detalhe, reenviar, revogar | `invites.list` `local-green`; `invites.create` `local-green`; `invites.detail` `local-green`; `invites.resend` `local-green`; `invites.revoke` `local-green` | UI/DEV verdes, produção unavailable; provar estados, confirmação negativa, email/backend e goldens; 8 h. |
| 10 | `activities` — Lista, wizard, detalhe, editar, publicar, avaliação | `activities.list` `local-green`; `activities.create` `local-green`; `activities.detail` `local-green`; `activities.edit` `local-green`; `activities.publish` `local-green`; `activities.assessment` `local-green` | Produção fail-closed; revalidar rota agora que calendário existe, matriz visual e falha de About antes de command; 12 h. |
| 11 | `assessments` — Lançamento, diário, fechamento/reabertura, detalhe | `assessments.entry` `audited`; `assessments.gradebook` `audited`; `assessments.close` `audited`; `assessments.reopen` `audited`; `assessments.detail` `audited` | Contratos/controller verdes, páginas e 8 comparadores não revalidados; executar non-golden e inspeção visual separada; 10 h. |
| 12 | `students` — Lista, gerenciar, transferir, editar, revogar | `students.list` `local-green`; `students.link` `blocked-decision`; `students.transfer` `blocked-decision`; `students.edit` `blocked-decision`; `students.revoke` `blocked-decision` | Produção somente leitura e sem Gerenciar/Justificar; provar unavailable/offline a 200% e aguardar contrato de commands; 8 h. |
| 13 | `attendance` — Dashboard, nova chamada, presença, correção, conclusão, export | `attendance.dashboard` `local-green`; `attendance.create` `local-green`; `attendance.mark` `local-green`; `attendance.correct` `local-green`; `attendance.finish` `local-green`; `attendance.export` `audited` | Revalidar relógio determinístico, guards/erros/reload, dois goldens e worker de export separado; 12 h. |
| 14 | `daily_routine` — Lista, criar, editar, aplicar, publicar | `daily-routine.list` `local-green`; `daily-routine.create` `local-green`; `daily-routine.edit` `local-green`; `daily-routine.apply` `local-green`; `daily-routine.publish` `local-green` | Produção unavailable e DEV local; executar smoke visual 375–1440, 200%, comandos/erro/reload; 8 h. |
| 15 | `agenda` — Calendário, criar, detalhe, editar, solicitações/permissões | `agenda.view` `blocked-decision`; `agenda.create` `blocked-decision`; `agenda.detail` `blocked-decision`; `agenda.edit` `blocked-decision`; `agenda.request` `blocked-decision`; `agenda.permissions` `blocked-decision` | Spec/draft e permissões não permitem inferir comportamento; decidir contrato canônico e então revisar calendário; 16 h após decisão. |
| 16 | `chat` — Conversas, conversa, mensagens, edição, anexos, recibos/revogação | `chat.list` `audited`; `chat.open` `audited`; `chat.send` `audited`; `chat.edit` `audited`; `chat.attach` `audited`; `chat.receipts` `audited`; `chat.revoke` `audited` | Revisar grupos/mídia, shell/chat PNGs, erros, foco, semântica e lifecycle; 16 h. |
| 17 | `notices` — Lista, criar, editar, agendar, publicar, arquivar | `notices.list` `audited`; `notices.create` `audited`; `notices.edit` `audited`; `notices.schedule` `audited`; `notices.publish` `audited`; `notices.archive` `audited` | Somente composição de rota conhecida; executar revisão funcional/visual completa e erros/reload; 10 h. |
| 18 | `forms_authoring` — Lista, criar, overview, editar, publicar, testar | `forms.list` `local-green`; `forms.create` `audited`; `forms.overview` `local-green`; `forms.edit` `local-green`; `forms.publish` `blocked-decision`; `forms.test` `blocked-decision` | Editor está verde apenas como componente catalogado; composição produtiva segue fail-closed. Resolver rota/capability, escalas e E2E antes de habilitar; 16 h. |
| 19 | `forms_responses` — Monitor, responder, respostas, detalhe, exportar | `forms.monitor` `audited`; `forms.respond` `local-green`; `forms.responses` `audited`; `forms.response-detail` `audited`; `forms.export` `audited` | Fail-closed recompilado e testado; `superadmin.forms-response` permanece diagnóstico deliberado. Resposta real, autorização e export continuam abertos; 12 h + decisão. |
| 20 | `forms_files` — Upload, resolver, baixar, expirar, excluir | `forms.upload` `audited`; `forms.resolve-file` `local-green`; `forms.download` `local-green`; `forms.expire-file` `audited`; `forms.delete-file` `audited` | Resolver F6 transitive closure, sem `storage_path` direto, rotas prod/DEV e lifecycle protegido; 12 h. |
| 21 | `acontece` — Feed, criar/publicar, remover | `acontece.feed` `local-green`; `acontece.create` `blocked-decision`; `acontece.publish` `blocked-decision`; `acontece.remove` `blocked-decision` | Preview enquadrado está verde; produção, mídia R2, publicação/remover e goldens exigem contrato/E2E; 10 h. |
| 22 | `agora` — Viewer, criar/publicar, expirar | `agora.view` `local-green`; `agora.create` `blocked-decision`; `agora.publish` `blocked-decision`; `agora.expire` `blocked-decision` | Viewer/foco coberto no lote; provar entrada por card/deep link e lifecycle real sem alterar baseline; 8 h. |
| 23 | `momentos` — Viewer, criar/publicar, remover | `momentos.view` `local-green`; `momentos.create` `blocked-decision`; `momentos.publish` `blocked-decision`; `momentos.remove` `blocked-decision` | `Esc`/foco cobertos; publicação/remover, origem real, R2 e goldens continuam abertos; 8 h. |
| 24 | `principal_profile` — Para Você, perfil/circulares, editar | `principal.for-you` `local-green`; `principal.profile-view` `local-green`; `principal.profile-edit` `blocked-decision` | Preview é estático sem PII/backend; revisar separação de account, responsive/goldens e decidir edição real; 8 h. |
| 25 | `child_safety` — Lista, criança, criar/editar autorização, suspender | `child-safety.list` `local-green`; `child-safety.child` `local-green`; `child-safety.create` `local-green`; `child-safety.edit` `local-green`; `child-safety.suspend` `audited` | Correção mecânica não prova lifecycle; executar suspensão/revogação, erro/permissão, 200% e visual; 10 h. |
| 26 | `health_care` — Perfis, criar, detalhe, editar | `health-care.list` `local-green`; `health-care.create` `local-green`; `health-care.detail` `blocked-decision`; `health-care.edit` `local-green` | Detail legado foi removido conforme spec; 12 PNGs M estão bloqueados e produção está fail-closed; 12 h. |
| 27 | `medication` — Lista, criar, detalhe, editar, evidência | `medication.list` `blocked-decision`; `medication.create` `blocked-decision`; `medication.detail` `blocked-decision`; `medication.edit` `blocked-decision`; `medication.evidence` `blocked-decision` | OQ-003/OQ-040 mantêm planos indisponíveis, zero wiring Supabase; decidir contrato antes da UI; 12 h após decisão. |
| 28 | `imports` — Hub, criar, upload, preview, confirmar, status, download | `imports.list` `audited`; `imports.create` `local-green`; `imports.upload` `audited`; `imports.preview` `audited`; `imports.confirm` `audited`; `imports.status` `audited`; `imports.download` `audited` | Dialog funcional não fecha provenance/golden; Imports A exige backend amplo e pacotes parciais não são equivalentes; 16 h após prerequisite. |
| 29 | `profile_files` — Importar, preview, confirmar, status, exportar/baixar | `profile-files.import` `audited`; `profile-files.preview` `audited`; `profile-files.confirm` `audited`; `profile-files.status` `audited`; `profile-files.export` `audited`; `profile-files.download` `audited` | Mapear callbacks/repositories e provar lifecycle, erros, reload e autorização; 12 h. |
| 30 | `audit` — Lista, filtros, detalhe, exportar | `audit.list` `audited`; `audit.filter` `audited`; `audit.detail` `audited`; `audit.export` `audited` | Apenas rota/inventário; revisar dados sanitizados, filtros, detalhe, export e responsividade; 8 h. |
| 31 | `support` — Criar, tabela, kanban, detalhe, responder, encerrar | `support.create` `local-green`; `support.table` `local-green`; `support.kanban` `local-green`; `support.detail` `audited`; `support.reply` `audited`; `support.close` `audited` | Support7 fechou scroll/paginação/200%; revisar detalhe, reply/close negativo, backend e goldens; 8 h. |
| 32 | `account` — Perfil, configurações, tema, MFA, sessões, logout | `account.profile` `audited`; `account.settings` `audited`; `account.theme` `local-green`; `account.mfa` `audited`; `account.sessions` `audited`; `account.logout` `local-green` | Oito PNGs de conta estavam divergentes; revalidar perfil/sessões/MFA, foco e 200%; 8 h. |
| 33 | `catalog` — Lista, validar, sincronizar, publicar | `catalog.list` `local-green`; `catalog.validate` `local-green`; `catalog.sync` `blocked-decision`; `catalog.publish` `blocked-decision` | Validação fresca deixou apenas `superadmin.forms-response` como fingerprint funcional bloqueado; Advanced Color Picker foi sincronizado. Decidir Forms antes de um report totalmente verde; 4–6 h para o P0, além da decisão. |
| 34 | `plans` — Lista, criar, editar, ativar, atribuir | `plans.list` `audited`; `plans.create` `local-green`; `plans.edit` `local-green`; `plans.activate` `blocked-decision`; `plans.assign` `blocked-decision` | Wizard/goldens históricos não provam ativação/atribuição; decidir contrato e rerodar visual; 10 h. |
| 35 | `meal_plans` — Cardápios, criar/editar, modelos, publicar | `meal-plans.list` `audited`; `meal-plans.create` `local-green`; `meal-plans.edit` `local-green`; `meal-plans.model-create` `local-green`; `meal-plans.model-edit` `local-green`; `meal-plans.publish` `blocked-decision` | Interpolações/identificadores têm characterization test; lifecycle, mídia e publicação não foram fechados; 12 h. |
| 36 | `internal_users` — Lista, criar, editar, suspender, MFA | `internal-users.list` `blocked-decision`; `internal-users.create` `local-green`; `internal-users.edit` `local-green`; `internal-users.suspend` `blocked-decision`; `internal-users.mfa` `blocked-decision` | Formulário verde, mas abrir/desativar foi desabilitado sem contrato; decidir domínio e provar MFA/suspensão; 10 h. |
| 37 | `error_pages` — 403, 404, 409, 500, 503, retry | `errors.403` `audited`; `errors.404` `audited`; `errors.409` `audited`; `errors.500` `audited`; `errors.503` `audited`; `errors.retry` `audited` | Baselines protegidas não foram rerenderizadas integralmente; executar rotas, teclado, reload/retry e matriz visual; 6 h. |

**ETA Flutter sequencial das 37 famílias:** aproximadamente 388 h de execução,
mais espera por decisões, ownership, backend/E2E e inspeção humana de imagens.
Famílias independentes podem reduzir tempo de calendário, nunca a quantidade de
prova necessária.

## 10. Resíduos e bloqueios que não podem ser esquecidos

| Resíduo | Estado | Próxima ação segura |
|---|---|---|
| Catálogo D | `regressed` | HEAD contém 8 fingerprints. Preservar o preparo não commitado que chega a 2, revalidar os 6 mecânicos e não promover exports/API para silenciar o gate. |
| Forms | `blocked-decision` | `superadmin.forms-editor` e `superadmin.forms-response` são as duas dívidas funcionais do catálogo; manter authoring/response fail-closed e fechar decisão do editor e F6 files/media. |
| Access Extended | `blocked-decision` | Não integrar helper/shims; retomar Access16 somente após prerequisite Imports canônico. |
| Imports parciais | `audited` | Preservar dialog source/test; provenance/golden e backend A continuam separados. |
| PNG/goldens | `regressed` | Reconciliar 199 rastreados fora de `failures/` individualmente; não atualizar em massa. |
| `failures/` | `audited` | 1.564 arquivos são feedback transitório; nunca baseline, staging ou aprovação. |
| Rotas `/dev` | `local-green` | Manter repositories/cache Development locais e provar tripwire zero em produção. |
| Fail-closed produtivo | `local-green` | É fechamento de segurança, não conclusão da tela; habilitar somente com contrato real. |
| Agenda/Tours | `blocked-decision` | Não inventar conteúdo, permissões ou ações; exigir fonte aprovada. |
| Saúde/Medicação | `blocked-decision` | Health detail removido; medication plans continuam 503/Unavailable e adapter desconectado. |
| Assiduidade | `local-green` | Tratar clock/goldens/export separadamente; preservar U1 e guards de comando. |
| Pessoas | `audited` | Oito goldens de diretório e status/card continuam fora do closure de identidade/rewire. |

## 11. Handoff para o rastreador integrado

O próximo editor de
`docs/reviews/coelo-flutter-integrado-supabase-pendencias.md` deve copiar os
estados abaixo sem convertê-los em `verified-e2e`. Cada grupo contém os
`action_id` oficiais; o lado integrado deve permanecer aberto enquanto backend,
RLS/Edge/Storage, ambiente remoto, cenários negativos e reload não estiverem
comprovados.

Esta organização Flutter passou de 195 para **201 ações** ao separar em
Instituições `detail`, `files`, `import`, `export`, `error` e `access-denied`,
que antes estavam escondidas em linhas agregadas. O controlador integrado
consultado continua com 190 operações normativas. Uma atividade integrada
futura deve mapear essas seis ações às operações existentes ou aprovar o
crosswalk; esta atividade não inventa RPC, tabela, policy ou operação backend.

| `screen_id` | Estado Flutter a alimentar por `action_id` | Estado integrado máximo permitido agora |
|---|---|---|
| `auth` | login/recover/reset/mfa `audited`; logout `local-green` | `blocked-supabase` |
| `shell` | load/navigate/unauthorized `local-green`; switch-context/reload `audited` | `not-reviewed` |
| `institutions` | list/filter/create/edit/status `local-green`; detail/files/import/export/error/access-denied/reload `audited` | `ready-for-e2e` apenas após normalizar o crosswalk e rerun Flutter |
| `units` | list/filter/create/edit/status/error/access-denied/reload `local-green`; import/export `blocked-supabase` | `blocked-supabase` |
| `groups` | list/create/edit/members `local-green`; import/export `audited` | `blocked-supabase` |
| `people` | create/edit `local-green`; list/links/reload `audited` | `blocked-supabase` |
| `access_profiles` | list/detail `audited`; create/edit/assign/delete `blocked-decision` | `blocked-flutter` |
| `access_models` | list/filter `audited`; create/detail/edit/duplicate `blocked-decision`; delete sem superfície UI | `blocked-flutter` |
| `invites` | todos os 5 action_ids `local-green` fail-closed | `blocked-supabase` |
| `activities` | todos os 6 action_ids `local-green` fail-closed | `blocked-supabase` |
| `assessments` | todos os 5 action_ids `audited` | `not-reviewed` |
| `students` | list `local-green`; link/transfer/edit/revoke `blocked-decision` | `blocked-supabase` |
| `attendance` | dashboard/create/mark/correct/finish `local-green`; export `audited` | `ready-for-e2e` somente para ações com backend cedido |
| `daily_routine` | todos os 5 action_ids `local-green` fail-closed | `blocked-supabase` |
| `agenda` | todos os 6 action_ids `blocked-decision` | `blocked-decision` |
| `chat` | todos os 7 action_ids `audited` | `not-reviewed` |
| `notices` | todos os 6 action_ids `audited` | `not-reviewed` |
| `forms_authoring` | list/overview/edit `local-green`; create `audited`; publish/test `blocked-decision` | `blocked-supabase` |
| `forms_responses` | respond `local-green`; monitor/responses/detail/export `audited` | `blocked-supabase` |
| `forms_files` | resolve/download `local-green`; upload/expire/delete `audited` | `blocked-supabase` |
| `acontece` | feed `local-green`; create/publish/remove `blocked-decision` | `blocked-decision` |
| `agora` | view `local-green`; create/publish/expire `blocked-decision` | `blocked-decision` |
| `momentos` | view `local-green`; create/publish/remove `blocked-decision` | `blocked-decision` |
| `principal_profile` | for-you/profile-view `local-green`; profile-edit `blocked-decision` | `blocked-decision` |
| `child_safety` | list/child/create/edit `local-green`; suspend `audited` | `not-reviewed` |
| `health_care` | list/create/edit `local-green`; detail `blocked-decision` | `blocked-supabase` |
| `medication` | todos os 5 action_ids `blocked-decision` | `blocked-decision` |
| `imports` | create `local-green`; demais 6 action_ids `audited` | `blocked-supabase` |
| `profile_files` | todos os 6 action_ids `audited` | `blocked-supabase` |
| `audit` | todos os 4 action_ids `audited` | `not-reviewed` |
| `support` | create/table/kanban `local-green`; detail/reply/close `audited` | `blocked-supabase` |
| `account` | theme/logout `local-green`; profile/settings/mfa/sessions `audited` | `blocked-supabase` |
| `catalog` | list `local-green`; validate/sync `regressed` com 8 fingerprints em HEAD; publish `blocked-decision` | `blocked-flutter` |
| `plans` | create/edit `local-green`; list `audited`; activate/assign `blocked-decision` | `blocked-decision` |
| `meal_plans` | create/edit/model-create/model-edit `local-green`; list `audited`; publish `blocked-decision` | `blocked-decision` |
| `internal_users` | create/edit `local-green`; list/suspend/mfa `blocked-decision` | `blocked-decision` |
| `error_pages` | todos os 6 action_ids `audited` | `not-reviewed` |

## 12. Protocolo de pausa e retomada

Antes de pausar, registrar posição atual, último teste confiável, arquivos
alterados, pendências, bloqueio, próxima ação executável e tempo restante. Ao
retomar, não confiar cegamente no estado registrado: conferir Git, rotas e testes
afetados e iniciar pela primeira ação não `verified` da ordem obrigatória.

O relatório ao usuário deve dizer, sem siglas desnecessárias: **onde estamos,
o que foi concluído, o que foi comprovado, o que falta, qual é o bloqueio, qual
é a próxima ação e quanto tempo efetivo ainda é estimado**.
Na primeira vez que um termo técnico aparecer, escrever também seu significado
cotidiano. Contagens e percentuais devem ser explicados, nunca apresentados
isoladamente.

## 13. Prompt mestre — revisão e correção Flutter

```text
Use obrigatoriamente coelo-flutter-review. Ela deve chamar coelo-ui, rtk,
ponytail, flutter-dart-code-review e flutter-build-responsive-layout, além de
consultar brevemente coelo-flutter-supabase-review para registrar dependências
integradas fora deste recorte Flutter.

Se eu ainda não tiver informado um orçamento, pergunte somente: “Quanto tempo
total você quer investir nesta atividade?”. Aguarde e não corrija nada. Se o
tempo já estiver na minha mensagem, não pergunte novamente.

Depois de saber o orçamento, leia AGENTS.md e
docs/reviews/coelo-flutter-pendencias.md integralmente. Inventarie novamente as
pendências gerais, telas, subtelas e ações.

Antes de alterar código, apresente uma tabela com pendência, nível mínimo
aconselhado, motivo/risco, tempo recalculado, o que cabe no orçamento e o que
continuará pendente. Apresente também objetivo, incluído, fora de escopo, ordem,
critério de parada e evidências. O recorte pode ser todas as pendências, todas as
telas, macrotema, macrotema + X telas, X telas na ordem ou X ações específicas.

Recomende pelo menos Intermediária; eleve para Avançada ou Completa quando o
risco exigir. Básica nunca conclui tela. Somente Completa pode sustentar
conclusão integral do Flutter. Recomende o pacote, peça minha confirmação, pare
e aguarde. Só depois execute as correções autorizadas.

Use Criar/Editar Instituição como baseline administrativa e aplique o Design
System Coelo: shell e contêiner macro, flyout, filtros, Cards/tabelas, diálogos,
wizard, calendário, espaçamento, hover, foco e responsividade. Componentize
quando houver repetição ou responsabilidade separável. Não preserve componente
Material cru ou padrão divergente apenas porque compila.

Corrija o que estiver autorizado, crie ou ajuste testes e atualize o rastreador
após cada ação. Uma rota aberta, um teste isolado, uma imagem golden atualizada,
um mock ou analyzer verde não tornam a tela concluída. Só use `verified` quando
todos os critérios de “Flutter 100%” tiverem evidência atual.

Informe sempre: posição atual, correções feitas, evidências em linguagem simples,
pendências, bloqueios, próxima ação e tempo estimado restante. Antes de pausar,
deixe o Markdown pronto para retomada sem depender da memória da conversa.
```

## 14. Execução Flutter/UI das 17 telas — 2026-08-27

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações).

**Progresso do recorte — Concluído:** 0,00% (0/89 `action_id` verificados).

**Progresso do recorte — Restante:** 100,00% (89/89 `action_id`).

O trabalho abaixo é evidência `local-green`, regressão ou fail-closed. Não
promove nenhuma ação a `verified`/E2E. O tempo wall-clock confiável deste
checkpoint foi medido de 15:53 a 16:15 (22 min); o trecho paralelo anterior da
mesma execução não tem marco inicial confiável e permanece **não calculável**.
Os oito lotes seguros e seus handoffs foram fechados; a estimativa restante
para verificar os 89 `action_id` permanece não calculável sem decisões de
produto, backend, ambiente integrado e inspeção visual humana pendentes.

| Lote | Telas alteradas ou regredidas | Arquivos modificados | Correções realizadas | Estado atual | Bloqueios e pendências restantes |
|---:|---|---|---|---|---|
| 1–4 | Rotina diária; Segurança da criança; Perfis de cuidado; Planos de medicação; Cardápio/Modelo; Formulários; Conversas; Comunicação | `daily_routine_pages.dart`; `safety_pages.dart`; `health_care_directory_page.dart`; `health_care_file_actions.dart`; `health_care_form_pages.dart`; `health_medication_plan_directory_page.dart`; `meal_plan_directory_page.dart`; `meal_plan_wizard_page.dart`; `forms_directory_page.dart`; `forms_overview_page.dart`; `superadmin_chat_page.dart`; `notice_directory_page.dart`; `notice_popup_preview.dart`; testes focados correspondentes; `superadmin_router.dart`; `health_care_routes_test.dart` | Insets `space4/space6/space10`; ordem toolbar/tabs/conteúdo; cards `space6`; paginação sticky; frames canônicos; datas Coelo; status progressivo; unauthorized sem conteúdo anterior; callbacks ausentes desabilitados; demo de arquivos removida; fixtures de cuidado injetadas somente em `/dev`. | `local-green`/fail-closed; nenhum golden ou backend alterado. | Validação visual global ainda bloqueada por `CheckboxListTile` em Instituições e `InkWell` em Pessoas, fora do recorte. Nomenclatura Avisos/Comunicação depende de produto. |
| 5 | Assiduidade; Rotina diária; Acompanhamento; Agenda | `daily_routine_pages.dart`; `daily_routine_production_page_test.dart`; `agenda_module_shell.dart`; `agenda_calendar_page.dart`; `agenda_calendar_page_test.dart` | Rotina alinhada e fail-closed; Agenda `/dev` sem overflow a 200% e com insets locais. Assiduidade e Acompanhamento passaram regressão sem alteração. | Rotina `local-green`; Agenda continua `/dev`; Assiduidade/Acompanhamento sem desvio estrutural reproduzido. | Agenda, permissões e navegação continuam `blocked-decision`; E2E e goldens permanecem abertos. |
| 6 | Segurança; Perfis de cuidado; Medicação; Cardápio; Modelo de cardápio | `safety_pages.dart`; `safety_pages_test.dart`; quatro libs de `health_care/presentation`; seis testes de `health_care/presentation`; dois arquivos de router/teste; três arquivos de Cardápios e dois testes | Validade aberta preservada; criação exige capability; produção de cuidado indisponível sem contrato; Medicação produtiva 503; wizard Cardápios em `SuperadminFormFrame`; callbacks no-op removidos. | `local-green`, `/dev` ou fail-closed conforme a rota. | Detalhe de Perfis, Medicação OQ-003/OQ-040, publicação/mídia e duas asserções antigas de teste de Medicação permanecem abertas. |
| 7 | Formulários; Conversas; Convites; Comunicação | quatro arquivos de Formulários e testes; `superadmin_chat_page.dart` e teste; `notice_directory_page.dart`, `notice_popup_preview.dart` e dois testes | Diretório/overview de Formulários alinhados; busca Chat canônica com debounce e proteção contra resposta stale; Avisos sem header duplicado, CTA vazio ou vazamento em forbidden. Convites passou regressão sem alteração. | Formulários e UI de Comunicação `local-green`; Convites produtivo continua unavailable. | Editor/respostas/arquivos de Formulários e repository produtivo de Convites permanecem fail-closed; contratos de membership/mídia não mudaram. |
| 8 | Acontece; Para Você; Momentos; Agora | Nenhum arquivo modificado. | 64 testes non-golden passaram; rotas e fixtures confirmadas somente em `/dev`; nenhuma dependência `coelo_ui_admin` foi adicionada ao Principal. | Regressão local verde, sem desvio estrutural reproduzido. | Produção, publicação, lifecycle e mídia dependem de produto/backend; dark específico de algumas superfícies permanece coberto somente por goldens não executados. |

## 15. Consolidação Flutter/UI complementar — 2026-08-27

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações).

**Progresso do recorte — Concluído:** 0,00% (0/89 `action_id` verificados).

**Progresso do recorte — Restante:** 100,00% (89/89 `action_id`).

Este checkpoint integrou somente evidência local: wizards canônicos de Publicar
Acontece/Momentos/Agora; um único shell para prévias/Perfil e wiring de Conteúdo
somente em `/dev`; Conteúdo demonstrativo com preview responsivo; launcher de
Chat arrastável e fail-safe; tabela canônica de permissões da Agenda; campos de
Medicação legíveis a 200%; e serialização de salvar/publicar no Acontece. Rotas
produtivas, repositories reais, backend, migrations, mídia remota e goldens não
foram habilitados nem executados.

Os gates finais executaram 58 testes não-golden e todos passaram; o analyzer
completo terminou sem issues em 70,6 s. Os handoffs específicos somaram ainda
testes focados previamente aceitos de Momentos, Agora, Conteúdo e Chat. Nenhuma
ação foi promovida a `verified` ou E2E. O tempo total confiável desta rodada não
é calculável porque implementação, revisão paralela e consolidação vieram de
frentes com marcos distintos; a ETA das 89 ações permanece não calculável sem
decisões, backend, ambiente integrado e inspeção visual humana.

Pendências explícitas preservadas: dashboard de Assiduidade; Perfil detalhado;
Lançar atividade; Cardápio/Modelo; Criar Formulário; Perfil de cuidado; e
validação transversal de tabelas/cards, flyouts e shell nas demais telas. O
validador visual continua RED somente nos dois desvios preexistentes fora do
recorte (`CheckboxListTile` em Instituições e `InkWell` em Pessoas).

## 16. Fechamento seguro da worktree Flutter/UI — 2026-08-27

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

**Progresso do recorte — Concluído:** 0,00% (0/89 `action_id` verificados E2E).

**Progresso do recorte — Restante:** 100,00% (89/89 `action_id` E2E).

| Campo | Registro factual |
|---|---|
| Telas alteradas | Shell/navegação; Acontece; Para Você; Momentos; Agora; Perfil; Publicar Acontece/Momentos/Agora; Assiduidade; Atividades; Formulários; Cardápios/Modelos; Perfis de cuidado; Pessoas; Instituições; Unidades; Turmas; Rotina diária; Segurança; Convites; Avisos; Imports; Configurações; Suporte. |
| Arquivos modificados | Manifesto Git da worktree: 97 arquivos rastreados mais 7 arquivos novos de repositories/testes de desenvolvimento; concentrados em `apps/superadmin/lib/app/{navigation,router,shell}`, `apps/superadmin/lib/features/{activities,attendance,forms,groups,health_care,imports,institutions,invites,meal_plans,notices,people,platform_users,principal_*,units}` e testes focados correspondentes. O rastreador é o único arquivo documental deste fechamento. |
| Correções realizadas | Shell único e contêiner direito responsivo nos previews Principal; wizards canônicos; proteção contra respostas A→B obsoletas; retry de cuidado; isolamento `/dev` de Imports, Forms, Agora, Support e Settings; idempotência local de Cardápios alinhada ao receipt produtivo; callbacks vazios removidos; rotas produtivas mutantes sem capability autoritativa redirecionadas antes do builder para 503 fullscreen; comandos embutidos de diretórios ficam ocultos/desabilitados em produção e ativos somente no `/dev` local. |
| Estado atual | `local-green`, `/dev` isolado ou fail-closed conforme a superfície. Analyzer completo: sem issues. `git diff --check`: verde. Suítes focadas de races/wizards/diretórios/rotas passaram nos casos alterados. Nenhum backend, migration, RLS, Auth, Storage remoto ou golden foi alterado. |
| Bloqueios | Capability autoritativa server-side ainda não existe; produção permanece 503 para mutações sem prova. Detalhe de Perfis, Medicação, Agenda, publicação/mídia Principal e partes de Forms dependem de produto/backend. O validador visual ainda aponta o `CheckboxListTile` cru preexistente em `institution_form_sections.dart:471`. Um teste preexistente de semântica de status de Unidades continua RED (`Status: Rascunho` não encontrado). Uma execução acidental do golden de Segurança divergiu 9,97%; imagem não foi atualizada nem ocultada. |
| Pendências restantes | Contrato server-side de capabilities; integrações backend/E2E; decisões de produto listadas; inspeção visual humana final; corrigir o controle cru de Instituições e a semântica do status de Unidades em lote próprio. Access Profiles mantém noop interno apenas em composição produtiva já unavailable; Platform Users é somente `/dev`. |
| Tempo usado | Não calculável com precisão: implementação e revisões ocorreram em frentes paralelas e atravessaram retomadas sem um único marco confiável. |
| Estimativa restante | Não calculável até existirem decisões de produto, contratos backend/capabilities, ambiente integrado e inspeção visual humana. |

## 16.1. Correções visuais focadas — 2026-08-27, lote 10 h

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

Este lote corrige divergências locais reproduzidas sem promover rota `/dev`,
teste de widget ou inspeção de código a evidência ponta a ponta. O recorte
estrito abaixo ficou `local-green` após revisão independente; backend, Auth,
RLS, migrations, mídia remota e goldens permaneceram intocados.

| Campo | Registro factual |
|---|---|
| Telas alteradas | Conversas; Unidades; Criar/Editar Instituição; Agenda > Permissões. |
| Arquivos modificados | `superadmin_chat_launcher.dart`; `chat_routes_test.dart`; `superadmin_chat_launcher_test.dart`; `unit_directory_cards.dart`; `unit_directory_page_test.dart`; `institution_form_sections.dart`; `institution_form_page_test.dart`; `agenda_permissions_page.dart`; `agenda_management_test.dart`. |
| Correções realizadas | Launcher circular apenas no compacto e cápsula `Mens.` em `medium+`, com drag/teclado preservados e navegação shell→Conversas provada; card informativo de Unidade preserva um único anúncio de status sem botão ou ação falsa; representantes sugeridos usam `CoeloAdminMultiSelectField<String>` com nome e e-mail, `Esc`, retorno de foco e `Aplicar`; tabela de Permissões usa linha de 88 px, célula compacta, reflow para cards com texto ampliado e uma única autoridade semântica por toggle. |
| Estado atual | `local-green`. Chat 74/74; Unidades 16/16; Agenda 6/6; Instituições 2/2 focados; analyzer dos 9 paths e validador visual verdes; `git diff --check` verde; revisão independente sem P0/P1. |
| Bloqueios | A suíte completa de Instituições mantém um RED preexistente no teste do seletor avançado de cor (`Dialog` versus cast para `AlertDialog`), fora deste delta. Duas expectativas do `persistent_shell_routes_test.dart` permanecem incompatíveis com o redirecionamento produtivo fail-closed; 62 casos da regressão ampliada passaram e 2 ficaram RED sem tocar router/shell. O contrato documental do launcher diverge entre arraste persistido e launcher fixo; o arraste existente foi preservado conforme pedido explícito do usuário. |
| Pendências restantes | Prova integrada/E2E das 207 ações; inspeção visual humana; decisões e contratos de produto/backend já listados; ampliar a matriz route-level do shell/Principal sem alterar produção salvo RED reproduzido. |
| Tempo usado | 28 min de wall-clock confiável, medidos de 21:12 a 21:40; inventário paralelo anterior sem marco único não foi somado. |
| Estimativa restante | O pacote de 9 paths não possui P0/P1 conhecido após review. O recorte maior continua não calculável até decisões de produto, contratos backend/capabilities, ambiente integrado e inspeção visual humana. |

## 16.2. Matriz shell/Principal e wizard — 2026-08-27

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Telas alteradas ou regredidas | Acontece; Para Você; Momentos; Agora; Perfil; Publicar Acontece/Momentos/Agora; Criar/Editar Instituição. |
| Arquivos modificados | `principal_for_you_preview_page.dart`; `persistent_shell_routes_test.dart`; `principal_happens_preview_route_test.dart`; `principal_for_you_preview_route_test.dart`; `principal_now_preview_route_test.dart`; `principal_profile_preview_route_test.dart`; `principal_moments_publication_route_test.dart`; `institution_form_page_test.dart`. |
| Correções realizadas | Matriz route-level prova oito rotas dentro de um único shell persistente e do contêiner direito em 375/768/1024/1440 e texto 100%/200%; Para Você ganhou `Flexible` no título editorial após overflow real de 30 px em 768/200%; Publicar Momentos passou a comprovar `SuperadminFormFrame`, navegação de etapas e footer canônicos; o teste do seletor de cor foi alinhado ao `Dialog` do `CoeloAdminDialogShell` e o fluxo de convite ficou determinístico sem alterar produção. |
| Estado atual | `local-green`. Matriz do shell 1/1; cinco arquivos de rotas Principal 19/19; suíte completa Criar/Editar Instituição 46/46; analyzer dos 8 paths e `git diff --check` verdes. Nenhum golden, router, backend ou fixture produtiva foi alterado. |
| Bloqueios | O arquivo amplo `persistent_shell_routes_test.dart` conserva dois REDs preexistentes fora deste delta, ligados a expectativas anteriores ao fail-closed produtivo; o novo teste foi executado isoladamente e ficou verde. Publicação, mídia e rotas produtivas Principal continuam bloqueadas pelas decisões/contratos já registrados. |
| Pendências restantes | Inspeção visual humana final; integração/E2E; decisões de produto/backend. Não há outro overflow conhecido nas oito rotas cobertas pela matriz atual. |
| Tempo usado | 17 min de wall-clock confiável neste lote, medidos de 21:40 a 21:57. |
| Estimativa restante | Nenhuma correção adicional é conhecida neste recorte de shell/Principal após os gates; o total de 207 ações E2E permanece não calculável pelos bloqueios externos já descritos. |

## 16.3. Rotas reais de wizards e fechamento dos REDs do shell — 2026-08-27

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Telas alteradas ou regredidas | Shell persistente; Criar Cardápio; Criar Modelo de cardápio; Criar Formulário; Criar Perfil de cuidado; Criar Plano de medicação. |
| Arquivos modificados | `superadmin_router.dart`; `dev_medication_plan_repository.dart`; `dev_medication_plan_health_care_repository.dart`; `health_medication_plan_form_page.dart`; `persistent_shell_routes_test.dart`; `meal_plan_development_routes_test.dart`; `forms_fail_closed_routes_test.dart`; `health_care_routes_test.dart`; `dev_medication_plan_repository_test.dart`; `dev_medication_plan_health_care_repository_test.dart`; `medication_plan_ui_contract_test.dart`. |
| Correções realizadas | As expectativas antigas do shell e de Cuidado foram alinhadas ao redirecionamento produtivo fail-closed. O detalhe produtivo legado de Perfil agora redireciona diretamente ao 503, antes de montar o formulário. As cinco rotas reais `/dev` comprovam um único shell, wizard dentro do contêiner de conteúdo, `SuperadminFormFrame`, navegação de etapas e footer canônicos em 375/768/1024/1440 com texto a 200%. Cardápio/Modelo comprovam repository local e mídia indisponível; Forms e Cuidado comprovam zero chamada aos adapters produtivos. Medicação usa uma única fonte local no create, diretório, detalhe e edição: salva, reaparece na lista, hidrata o mesmo item e atualiza sua versão. O wizard bloqueia dados obrigatórios e vigência invertida, preserva draft/erro/retry sem falso sucesso, mantém o `requestId` em retry idêntico e cria nova intenção somente após edição real; navegar entre etapas não cria revisão de auditoria falsa. Em resposta ambígua, reconcilia primeiro o receipt da intenção original, recupera `planId/version` e aplica a edição sobre o mesmo item, sem duplicar. O repository `/dev` aplica replay global e CAS síncrono; updates concorrentes produzem um sucesso e um conflito. O adapter preserva o contexto institucional (`atHome=false`) e nunca apresenta falsamente “Casa”. Inputs e selects permanecem dentro do viewport após scroll. |
| Estado atual | `local-green`. Gate conjunto fresco: 49/49; analyzer dos onze arquivos sem issues; formatter aplicado; `git diff --check` verde. Revisão independente final: GREEN, nenhum P0/P1 no delta. Nenhum backend, repository produtivo, fixture produtiva ou golden foi alterado. |
| Bloqueios | As rotas produtivas mutantes continuam 503 sem capability autoritativa; isso é comportamento fail-closed, não conclusão funcional. Persistência real, mídia, decisões de produto e E2E permanecem fora deste pacote. |
| Pendências restantes | Inspeção visual humana; contratos backend/capabilities e verificação E2E das 207 ações. |
| Tempo usado | Cerca de 1 h 30 min de wall-clock desde 21:57; o encerramento exato não foi recuperado pelo shell. Inclui três ciclos de review independente e correção dos P1 encontrados. |
| Estimativa restante | Nenhum desvio estrutural adicional é conhecido nas cinco rotas cobertas; o total E2E continua não calculável pelos bloqueios externos já registrados. |

## 16.4. Assiduidade Dashboard e contraprova de Principal — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Telas alteradas ou regredidas | Dashboard de Assiduidade; contraprova sem alteração de Acontece, Para Você, Momentos, Agora, Perfil e três publicações. |
| Arquivos modificados | `superadmin_router.dart`; `attendance_dashboard_controller.dart`; `attendance_dashboard_page.dart`; `attendance_routes_test.dart`; `attendance_dashboard_controller_test.dart`; `attendance_pages_test.dart`. |
| Correções realizadas | Produção deixa de exibir botão, coluna ou cabeçalho de abrir chamada quando a rota mutante está indisponível; `/dev` preserva a ação e a navegação local. Reloads fora de ordem validam a geração antes de alterar access/query. Trocar repository/contexto dispõe o controller anterior, cancela seu debounce, limpa a busca e carrega somente o contexto novo; resposta tardia de A não aparece em B. |
| Estado atual | `local-green`. REDs reproduzidos; regressão conjunta fresca 44/44; analyzer dos seis arquivos sem issues; formatter e `git diff --check` verdes. Duas revisões independentes finais: GREEN, P0=0/P1=0. Principal passou contraprova non-golden separada de 62/62, confirmando shell único, `embedded` e wizard canônico; nenhum arquivo Principal mudou. |
| Bloqueios | Abrir/criar chamada em produção permanece 503 sem capability autoritativa. Backend, autorização integrada, dois goldens do dashboard e E2E continuam fora do pacote. |
| Pendências restantes | Clock do dashboard ainda não é injetável; banner de refresh-error não possui matriz própria 375/1440 a 200%; inspeção visual humana e contratos integrados permanecem necessários. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu inventário paralelo, três REDs, duas rodadas de review e gates focados. |
| Estimativa restante | O próximo lote seguro é Rotina diária ou Comunicação/Avisos para fechar troca de repository/contexto; a ETA E2E continua não calculável sem backend e decisões de capability. |

## 16.5. Rotina diária — troca segura de contexto — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Tela alterada ou regredida | Diretório de Rotina diária. |
| Arquivos modificados | `daily_routine_pages.dart`; `daily_routine_production_page_test.dart`. |
| Correções realizadas | Ao receber outra instância de repository/contexto, a página remove o listener e descarta o controller anterior, limpa busca e permissão de gestão, restaura o tipo inicial e carrega um controller novo. O descarte invalida a carga anterior; uma resposta tardia do tenant A não pode notificar nem repovoar a superfície do tenant B. Estado `unauthorized` do novo contexto retorna antes de toolbar, tabs, criação e conteúdo anterior. |
| Estado atual | `local-green`. RED reproduzido antes da correção; regressão não-golden fresca 37/37; analyzer dos dois arquivos sem issues; formatter aplicado; `git diff --check` verde. Duas revisões independentes finais: GREEN, P0=0/P1=0. Nenhum backend, adapter produtivo ou golden foi alterado. |
| Bloqueios | Persistência real, autorização integrada, cross-tenant remoto, inspeção visual humana e E2E permanecem fora deste pacote. |
| Pendências restantes | Contraprova futura pode cobrir troca para tenant B autorizado preservando uma preferência de layout explícita; isso não altera a correção de privacidade já exercitada. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu RED, correção, 37 testes e duas revisões independentes. |
| Estimativa restante | O próximo lote seguro é Comunicação/Avisos, com foco em troca de repository/ID e comandos assíncronos; a ETA E2E continua dependente dos bloqueios externos registrados. |

## 16.6. Comunicação/Avisos — isolamento do diretório — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Tela alterada ou regredida | Diretório de Comunicação/Avisos; composição produtiva e `/dev` da rota. |
| Arquivos modificados | `notice_directory_page.dart`; `notice_directory_page_test.dart`; `notice_logout_wiring_test.dart`. |
| Correções realizadas | Troca de repository/tenant invalida loads e comandos anteriores, cancela debounce, limpa busca, filtros, cursores, preview, ledger e busy antes de carregar B. Resposta ou comando atrasado de A não mostra feedback, não recarrega nem altera B. Preview e diálogo de inativação pertencentes à página são removidos no swap/dispose; o fechamento termina antes do descarte de controllers. Request IDs são estáveis apenas para intenção idêntica e mudam quando ação, versão ou motivo normalizado mudam. Criar comunicação é omitido sem callback real: produção não promete uma rota 503, enquanto `/dev` preserva a ação local. |
| Estado atual | `local-green`. REDs reproduzidos antes das correções; regressão não-golden fresca 75/75; analyzer dos três arquivos sem issues; formatter aplicado; validador visual canônico e `git diff --check` verdes. Duas revisões independentes finais: GREEN, P0=0/P1=0. Nenhum backend, adapter produtivo ou golden foi alterado. |
| Bloqueios | Capabilities produtivas de criação/lifecycle continuam indisponíveis e fail-closed; backend, autorização integrada, mídia e E2E permanecem fora deste pacote. |
| Pendências restantes | Formulário de Avisos ainda requer sublote próprio para estado de load sem footer mutante, retry transitório e reconciliação de resposta ambígua antes de edição subsequente. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu cinco REDs, correções incrementais, suíte 75/75 e duas rodadas de review. |
| Estimativa restante | Próximo sublote seguro: formulário de Avisos; a ETA E2E permanece dependente dos contratos externos registrados. |

## 16.7. Comunicação/Avisos — estados de load do formulário — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Tela alterada ou regredida | Criar/Editar Comunicação/Aviso. |
| Arquivos modificados | `notice_form_controller.dart`; `notice_form_page.dart`; `notice_form_page_test.dart`. |
| Correções realizadas | Loading e falha de carregamento retornam uma superfície de estado antes de montar `SuperadminFormFrame`, navegação de etapas ou footer mutante. Edição com falha transitória oferece retry generation-safe no mesmo local; 403 e not-found continuam sem retry e sem affordance de salvar/publicar. Sucesso reidrata o wizard canônico. |
| Estado atual | `local-green`. Regressão focada fresca 25/25; analyzer dos três arquivos sem issues; formatter, validador visual canônico e `git diff --check` verdes. Duas revisões independentes finais: GREEN, P0=0/P1=0 no delta. Nenhum backend, adapter produtivo ou golden foi alterado. |
| Bloqueios | Criação/edição produtiva continua 503 sem capability autoritativa; persistência real, autorização integrada, mídia e E2E permanecem fora deste pacote. |
| Pendências restantes | Reconciliação de save ambíguo após edição permanece P1 separado e não foi promovida por este GREEN. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu testes de retry/403, regressão focada e duas revisões independentes. |
| Estimativa restante | Próximo sublote seguro: receipt/idempotência do save de Avisos; ETA E2E depende dos contratos externos registrados. |

## 16.8. Comunicação/Avisos — receipts ambíguos do formulário — 2026-08-28

**Progresso geral conhecido — Concluído:** 0,00% (0/207 ações E2E).

**Progresso geral conhecido — Restante:** 100,00% (207/207 ações E2E).

| Campo | Registro factual |
|---|---|
| Tela alterada ou regredida | Criar/Editar Comunicação/Aviso; comandos Salvar rascunho e Publicar. |
| Arquivos modificados | `notice_form_controller.dart`; `notice_form_controller_test.dart`. |
| Correções realizadas | Save ambíguo preserva request ID e payload exatos, reconcilia o receipt persistido e atualiza o mesmo aviso com nova intenção quando o draft mudou. Publicação ambígua preserva uma intenção tipada através de edições, replaya primeiro o comando original, valida ID/versão/status e só então salva/publica a edição sobre a versão reconciliada. Edição durante qualquer replay invalida o follow-up automático. Receipts impossíveis falham fechado; falhas determinísticas descartam a intenção e falhas transitórias a preservam. |
| Estado atual | `local-green`. Regressão focada fresca 16/16 e suíte não-golden de Avisos 79/79; analyzer dos dois arquivos sem issues; formatter, `git diff --check` e secret scan verdes. Duas revisões independentes finais: GREEN, P0=0/P1=0. Nenhum backend, adapter produtivo ou golden foi alterado. |
| Bloqueios | Criação/edição/publicação produtiva continua condicionada à capability autoritativa e aos contratos backend/RLS. Este pacote prova somente comportamento Flutter local e fail-closed; não constitui E2E. |
| Pendências restantes | Persistência produtiva, autorização integrada, mídia, resposta remota perdida real e validação cross-tenant continuam nos rastreadores backend/integrado. |
| Tempo usado | Não calculável com precisão pelo shell; incluiu REDs de save/publish ambíguos, gates não-golden e duas rodadas de revisão independente. |
| Estimativa restante | Próximo lote Flutter deve ser independente deste formulário; ETA E2E continua dependente dos contratos externos registrados. |

## 17. Histórico

| Data | Mudança |
|---|---|
| 2026-08-26 | `groups.import`/`groups.export`: removidos do formulário os dois botões e SnackBars que simulavam sucesso sem arquivo, gateway ou job. RED→GREEN focado 1/1 e suíte `group_form_page_test.dart` 8/8; analyzer focado e global sem erros/warnings. Estado máximo `audited`/fail-closed; fluxos reais de import/export, autorização, Storage, remoto e E2E continuam pendentes. |
| 2026-08-26 | `units.people-export`: removido o botão produtivo que apenas mostrava SnackBar sem gerar job, arquivo ou URL. RED focado reproduziu a ação falsa; GREEN focado 1/1 e suíte `unit_form_page_test.dart` 24/24. Estado máximo fail-closed/`blocked-decision`; funcional real exige capability e snapshot próprios de Pessoas escopados à unidade, backend/Storage, tenant A/B, revogação, cleanup, remoto e E2E. |
| 2026-08-26 | `units.access-denied`: pacote Flutter local omitiu toolbar/filtros/tabs/arquivos/criar/conteúdo/paginação no estado final `unauthorized`, preservando o `createAction` anterior. Handoff registrou 23 testes finais aprovados e esta frente executou uma suíte ampliada de 25 testes, todos aprovados; analyzer ficou em 0 erros/0 warnings/45 infos. Estado máximo `local-green`; pré-resposta, cache/revogação, tenant A/B, deep link, backend/RLS e E2E permanecem abertos. |
| 2026-08-26 | `units.export` HARDEN-EXPORT A+B: gateway Flutter passou a exigir `request_export` → `download` com job correlacionado, DTO/colunas/URL/TTL estritos; UI ganhou single-flight, idempotência controlada, opener injetável, expiração e busy acessível. Os dois arquivos diretos executaram 41 testes e todos passaram; analyzer ficou em 0 erros/0 warnings/45 infos e Catálogo externo manteve somente `superadmin.forms-response`. Estado máximo `audited/local-hardening`; produção `Unavailable`, decisões OQ-032/OQ-034, backend/remoto/E2E e `units.people-export` separado permanecem abertos. |
| 2026-08-26 | P0.5 Units `units.list`: patch de 1 linha forneceu `createAction`; 16 testes Units e 5 router Access passaram; analyzer chegou a zero erros/47 issues; quatro ações de estado adicionadas, totalizando 206 IDs; import/export/backend/goldens permaneceram intocados. |
| 2026-08-26 | P0.5 Access opção A: 3 arquivos preservados externamente com 12.539 bytes/manifesto idêntico; 2 testes router incompatíveis removidos da árvore; fake alinhado sem `isDemo/contextCount`; 9 testes passaram; Access 3→0 erros e global 4→1, bloqueado por Units; 2 router tests não compilaram por esse erro externo. |
| 2026-08-26 | P0.5 Access inventário: 3 erros ligados a testes untracked incompatíveis com composition root 503 e fake com `contextCount`; manifesto de 3 arquivos registrado sem mutação; `access-models.filter` adicionado por possuir UI real, enquanto delete permanece só como contrato futuro; correção aguarda checkpoint backend. |
| 2026-08-26 | P0.5 Forms `forms.edit`: teste dormant reconciliado com o componente catalogado por patch de 2 linhas; 24 testes non-golden passaram; erros globais 6→4 e Forms 2→0; catálogo manteve somente `superadmin.forms-response`; rota produtiva/create/publish/backend/goldens não promovidos. |
| 2026-08-26 | P0.5 Forms `forms.respond`: delta concorrente de 7 arquivos preservado externamente com 40.944 bytes e manifesto idêntico; teste canônico restaurado ao HEAD; 1 teste passou; erros globais 38→6 e Forms 34→2; catálogo manteve exatamente `superadmin.forms-response`; nenhum golden/backend/stage/commit. |
| 2026-08-26 | P0.5 Acompanhamento concluído: 24 legados preservados externamente com manifesto idêntico; erros globais 100→38 e Student Tracking 62→0; 22 testes canônicos passaram. |
| 2026-08-26 | P0.5 Acompanhamento: `f525a7f4` confirmado como contrato read-only canônico; 24 legados não rastreados manifestados; 22 testes canônicos e analyzer focado verdes; preservação externa aguarda coordenação. |
| 2026-08-26 | P1 isolado: 99 testes de Auth e 87 testes de shell passaram; analyzers focados verdes. Login/recovery/reset promovidos a `local-green`, sem conclusão de tela ou integração remota. |
| 2026-08-26 | Contratos parciais de Forms/Acompanhamento/Acesso mapeados; `units.import` e `units.export` marcados `blocked-supabase` porque o adapter existe, mas produção injeta gateways indisponíveis até handoff. |
| 2026-08-26 | Triagem pós-P0 agrupou os 100 erros em 62 de Acompanhamento, 34 de Forms, 3 de testes de acesso e 1 de Unidades; P0.5 de recuperação do snapshot registrado como próximo pacote seguro. |
| 2026-08-26 | Primeiro checkpoint de 60 min do P0: gates focados verdes, analyzer global com 174 diagnósticos; `forms.respond`, `students.list` e `units.list` marcados como regressões externas ao catálogo. |
| 2026-08-26 | P0 Intermediária retomada: `catalog.validate` reproduzido, Advanced Color Picker sincronizado após testes e análise, Forms Response preservado como bloqueio funcional e checkpoint seguro registrado. |
| 2026-08-26 | Criação do rastreador Flutter separado do backend e da prova integrada. |
| 2026-08-26 | Consolidação retomável em HEAD `447ac02c`: 37 famílias, estados por ação, commits/gates, resíduos, ETA e handoff integrado. |
| 2026-08-26 | Organização decisória: tabela geral cumulativa, definição B/I/A/C, matriz de 201 ações com nível aconselhado/estimativa/evidência, decomposição explícita das 12 ações de Instituições, dependências integradas fora de escopo e inventário do worktree concorrente; nenhum código ou backend alterado. |
