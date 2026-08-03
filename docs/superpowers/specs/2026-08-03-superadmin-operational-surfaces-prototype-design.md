---
source: "AGENTS.md; docs/product/prd-superadmin.md; docs/data/data-model.md; docs/design/design-system.md; specs/003-superadmin-core.md; decisions approved by the Owner Coelo on 2026-08-03"
status: "approved-design"
generated_at: "2026-08-03"
---

# Superadmin · Planos, Importações, Convites, Avisos e Auditoria

## Objetivo

Projetar cinco experiências locais navegáveis no Superadmin para orientar uma
implementação Flutter posterior. O Superadmin é a primeira referência visual,
mas este recorte não autoriza copiar domínio administrativo para Admin,
Principal ou site.

As cinco experiências usam dados fictícios em memória, reiniciados ao recarregar
o app. Nenhuma delas afirma persistência, autorização, envio, arquivo, aceite ou
auditoria produtivos.

## Escopo compartilhado

- Rotas de preview em `/dev`.
- Features locais `plans`, `imports`, `invites`, `notices` e `audit`.
- Estado fake de sessão compartilhado no nível do router.
- Ações das quatro features mutáveis alimentam o sininho e a Auditoria fake.
- Shell, tokens e componentes administrativos existentes são reutilizados.
- Cards/tabela seguem Instituições; não há botão de criação no cabeçalho.
- Em cards, criar é o primeiro card tracejado. Em tabela, criar é uma faixa
  separada antes da tabela.
- Auditoria é somente leitura e não possui ação de criação.

## Fora de escopo

- Supabase, migrations, RLS, RPCs, Edge Functions ou backend.
- Upload, download, envio, aceite ou notificação reais.
- Cobrança, assinatura automática ou bloqueio automático por plano.
- Exportação de auditoria.
- Componentes públicos, tokens ou variantes novos sem aprovação separada.
- Persistência dos fixtures depois de atualizar a página.

## Direção visual aprovada

A composição é híbrida e enxuta. Shell, toolbar, busca, filtros, toggle,
cards/tabela, paginação e estados são compartilhados. Cada módulo adiciona
somente a superfície necessária à sua tarefa, como wizard de importação, prévia
de popup ou detalhe de auditoria.

Popup, flyout e dialog usam `colorScheme.surface`, tint transparente, borda e
tokens aprovados. A ação principal é a única ação laranja preenchida. Ações
negativas preservam `error`/`errorContainer`. Formulários reutilizam os campos e
seleções administrativos existentes.

## Responsividade

Decisões de composição usam `LayoutBuilder` e a largura concedida pelo pai, não
tipo de dispositivo ou orientação. A matriz obrigatória é 375, 768, 1024 e
1440 px.

- Compacto: uma coluna, cards em vez de tabela quando necessário e ações
  alcançáveis sem cobrir o conteúdo.
- Médio: conteúdo reorganizado pela largura disponível, sem scroll horizontal
  global.
- Amplo: cards/tabela, formulários limitados em largura e stepper lateral nos
  fluxos longos.
- Listas potencialmente grandes usam construção lazy.
- Mouse, teclado, trackpad e toque oferecem as mesmas ações.

## Planos

### Responsabilidade

Gerenciar o catálogo exclusivo do Superadmin, seus recursos e limites. A tela
não atribui planos a instituições neste recorte.

### Fixtures iniciais

1. `Coelo Essencial`: comunicação, agenda e convites; limites menores.
2. `Coelo Conecta`: acrescenta chat e avisos segmentados.
3. `Coelo Cuidado`: acrescenta Rotina, Flow e Now; limites ampliados.
4. `Coelo Integral`: todos os módulos, incluindo Moments; maiores limites.

### Experiência

- Busca e filtros por status e recursos.
- Cards/tabela com nome, recursos, limites, status e uso fictício.
- Criar e editar em página responsiva.
- Identidade: nome, código, descrição e status.
- Recursos independentes, incluindo Flow, Now, Moments, Chat, Agenda e Rotina.
- Limites para instituições/unidades, usuários, responsáveis por criança,
  armazenamento e mídia.
- Operação manual e observações internas.
- Plano utilizado pode ser arquivado, nunca excluído definitivamente.
- Exclusão definitiva aparece somente para plano nunca utilizado e exige
  confirmação.

## Importações

### Responsabilidade

Centralizar histórico e iniciar importações demonstrativas de Instituições,
Unidades, Grupos, Pessoas e Usuários internos.

### Experiência

- Busca e filtros por entidade, status, instituição, ator e período.
- Cards/tabela mostram arquivo, entidade, destino, progresso, resultado e data.
- Wizard de página: entidade/contexto; CSV/XLSX fictício; mapeamento; estratégia;
  prévia e conflitos; confirmação e acompanhamento.
- Estratégias: criar apenas ou criar e atualizar existentes.
- Revisão exibe a chave fictícia de correspondência e conflitos por linha.
- Resultado separa criados, atualizados, ignorados e rejeitados.
- O arquivo e o modelo para download são apenas simulações.
- Desktop usa stepper lateral; compacto usa indicador superior e uma coluna.

## Convites

### Responsabilidade

Emitir e acompanhar convites fictícios para equipe Coelo, owners e
administradores institucionais, profissionais, responsáveis e demais pessoas
vinculadas.

### Experiência

- Filtros por público, hierarquia, papel, canal, status e período.
- Estados: rascunho, pendente, aceito, expirado, revogado e falha simulada.
- Fluxo: público; hierarquia/escopo; papel/finalidade; destinatário; canal;
  expiração; revisão.
- Validade padrão de dois dias, editável antes do envio.
- Destino por e-mail ou celular e link copiável, todos fictícios.
- Ações: visualizar, copiar link, reenviar pendente/expirado e revogar.
- Reenvio gera um link fake novo e invalida o anterior.
- Detalhe apresenta a linha do tempo completa do convite.

## Avisos

### Responsabilidade

Criar popups oficiais para destinatários identificados. A audiência pode ser
global ou segmentada por instituição, unidade, grupo, papel ou pessoa. Avisos
familiares de presença pertencem a outro domínio.

### Experiência

- Filtros por status, prioridade, obrigatoriedade, vigência e audiência.
- Estados: rascunho, agendado, ativo, encerrado e cancelado.
- Editor de página com título, mensagem, prioridade, vigência, mídia/anexo fake,
  audiência, comportamento, rótulo de ação e link opcional.
- Comportamentos limitados a: apenas fechar; confirmação obrigatória; checkbox
  de aceite mais confirmação.
- Prévia do popup em larguras diferentes.
- Aviso opcional pode ser dispensado e não reaparece ao destinatário fake.
- Aviso obrigatório bloqueia a navegação até a decisão, permite sair do app e
  reaparece no próximo acesso enquanto não for aceito.
- Resultados mostram alcance, entrega, visualização e aceite fictícios.
- Ações: editar rascunho/agendado, duplicar, publicar, cancelar e consultar
  resultados.
- Não existem visitantes anônimos no público deste fluxo.

## Auditoria

### Responsabilidade

Consultar evidências fictícias e minimizadas das ações sensíveis realizadas na
sessão. A tela não cria, altera, exclui ou exporta eventos.

### Experiência

- Tabela no desktop e cards compactos em larguras menores.
- Busca por identificador, ator, ação ou objeto.
- Filtros por período, módulo, ação, ator, instituição/contexto e risco.
- Resumo mostra data/hora, ator, módulo, ação, objeto, contexto e risco.
- Detalhe mostra ID, instante, ator fake, escopo, motivo, origem, MFA simulado,
  before/after minimizado e vínculo com o objeto relacionado.
- Eventos de Planos, Importações, Convites e Avisos surgem imediatamente.
- Logs nunca incluem PII, mensagem integral, token ou conteúdo de arquivo.

## Estado e fluxo de dados

O router de preview mantém um único store fake de sessão. Cada feature possui
seu repository/controller local e envia somente um resumo minimizado ao store
de atividade. O store publica a entrada ao sininho e à consulta de Auditoria.
Não se cria uma abstração genérica além do necessário para esse fluxo comum.

As mutações são síncronas ou usam pequenos atrasos determinísticos para
demonstrar progresso. Atualizar o navegador recria fixtures e relógios fixos,
mantendo testes estáveis.

## Estados e falhas

Cada diretório demonstra carregamento, conteúdo, vazio, sem resultados, erro e
sem permissão. Formulários demonstram validação, envio em andamento, sucesso e
falha fake. A ação falha sem perder o rascunho. Confirmações sensíveis deixam
claro que o efeito é apenas local.

## Acessibilidade

- Alvos mínimos, foco visível, tooltips e semântica conforme Design System.
- Labels persistentes e erros associados aos campos.
- Texto a 200% sem truncar ações essenciais.
- Ordenação de foco preservada nos wizards e dialogs.
- Reduced motion elimina animações não essenciais.
- Cor nunca é o único indicador de status, seleção, risco ou erro.

## Verificação esperada

- Testes de widget para cada diretório, criação/edição e ação sensível.
- Teste integrado local comprovando ação → sininho → Auditoria.
- Testes de arquivamento/exclusão de plano, mapeamento e conflitos de importação,
  reenvio de convite e bloqueio de aviso obrigatório.
- Matriz 375/768/1024/1440, light/dark, teclado, texto a 200% e reduced motion.
- Goldens mínimos em mobile light e desktop dark por composição nova.
- `dart format` e `dart analyze` sem novos problemas.

## Forma de entrega dos prompts

1. Prompt de fundação compartilhada.
2. Prompt de Planos.
3. Prompt de Importações.
4. Prompt de Convites.
5. Prompt de Avisos.
6. Prompt de Auditoria.

Cada prompt deve poder ser executado por um agente Flutter após o anterior,
declarar o escopo fake e impedir expansão silenciosa para backend.
