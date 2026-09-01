---
source: "docs/product/prd-superadmin.md; specs/010-superadmin-completo-v1-technical-spec.md; specs/012-superadmin-mvp.md; docs/design/design-system.md; aprovações do Owner Coelo em 2026-08-05 e 2026-08-11"
status: "approved-design"
generated_at: "2026-08-11"
updated_at: "2026-08-31"
---

# Comunicações do app no Superadmin

## Objetivo e problema

Evoluir Avisos para a experiência administrativa `Comunicações do app`, capaz
de criar, revisar, agendar e acompanhar Avisos, Conteúdos, Destaques e itens
Para você. Aviso preserva exclusivamente a semântica de popup e interrupção;
os demais tipos não podem adquirir comportamento de popup.

O MVP passa a incluir um construtor controlado. Ele não se torna uma plataforma
genérica de campanhas nem um editor livre de layouts.

## Escopo aprovado

- Diretório exclusivo, sem formulário aberto junto à listagem, com categorias
  `Todos`, `Avisos`, `Conteúdos`, `Destaques` e `Para você`.
- O diretório não oferece alternância Cards/Tabela. Tablet e desktop usam a
  tabela canônica de Instituições; mobile adapta os mesmos registros para uma
  lista compacta vertical, sem expor outro modo de visualização.
- Enum fechado de tipo: `Aviso`, `Conteúdo`, `Destaque` e `Para você`.
- Prioridade, público, vigência e recorrência são comuns aos quatro tipos.
- Comportamento de aceite, tamanho, inset e aparência de popup pertencem
  somente a `Aviso`.
- Criar/Editar em rota própria com cinco etapas: Identidade; Conteúdo e
  aparência; Público e dispositivos; Exibição e recorrência; Revisão e
  publicação.
- Dois formatos mutuamente exclusivos: texto sobre fundo; ou uma única imagem
  horizontal/vertical. Pixels, proporção, limite e processamento pertencem à
  futura spec de mídia/R2.
- Cores de fundo e texto pelo seletor avançado Coelo, com contraste validado.
- Audiência controlada: cada aviso escolhe uma variação allowlisted — `Todos`,
  instituição, unidade, turma ou pessoa — e aceita vários recursos explícitos
  ou todos os resultados de um filtro autorizado. Papel é filtro opcional;
  `Todos` é exclusivo e não há construtor booleano livre no cliente.
- Exatamente um destino: web, mobile, tablet ou todos.
- Início/fim e recorrência fechada: única, diária, semanal, mensal por dia do
  mês ou por intervalo inteiro de dias.
- Comportamento dispensável, confirmação obrigatória ou checkbox de ciência.
- Aviso obrigatório reaparece até o aceite e pode bloquear a navegação, mas
  nunca impede a saída do app. Conteúdo crítico obrigatório permanece separado
  de conteúdo opcional silenciável.
- Estados rascunho, agendado, ativo, pausado, expirado e inativo.
- Prévia responsiva fiel ao popup entregue para `Aviso`, inclusive CTA, cor do
  botão, tamanhos e espaçamento externo. Os demais tipos usam card
  administrativo neutro e tipado, sem antecipar a UI futura do Principal.
- Dados, alcance, entrega, visualização e aceite vêm do backend; produção não
  usa fixtures, métricas inventadas nem sucesso local.

## Fora de escopo

- Drag-and-drop, HTML, blocos livres, carrossel ou múltiplas telas.
- Jornadas, gatilhos comportamentais e regras AND/OR arbitrárias.
- A/B testing, personalização, localização e analytics avançado.
- Upload de imagem enquanto a decisão Supabase Storage versus Cloudflare R2
  permanecer aberta. Publicação de imagem falha fechada e não exibe placeholder.

## Superfícies e direção visual

- `apps/superadmin`: diretório, criação/edição e prévia de Comunicações do app.
- Instituições é a baseline do diretório: toolbar, busca, filtros,
  `CoeloAdminCreateAction`, `CoeloAdminResizableTable`, status tabular,
  `CoeloAdminFlyout` e paginação. O toggle Cards/Tabela não se aplica a este
  diretório.
- A referência visual enviada pelo Owner em 2026-08-28 para Comunicações define
  a anatomia informacional e responsiva desejada — categorias, filtros
  aplicados, densidade da tabela e preview lateral no desktop — sempre
  traduzida para componentes, tokens, tipografia e interação do Coelo. Ela não
  autoriza tabela local, aproximação visual nem identidade paralela.
- A lista compacta mobile e a tabela reutilizam literalmente as anatomias
  correspondentes de Instituições, incluindo alinhamento horizontal e vertical,
  baseline tipográfica, alturas, paddings, gaps, estados, largura natural,
  scrollbar e paginação. Não existe seletor de modo.
- A criação usa `CoeloAdminCreateAction.tile` no mobile e a faixa de criação
  canônica acima da tabela nas larguras maiores; não há botão laranja isolado
  no topo. Antes da tabela existe o mesmo respiro tokenizado de Instituições.
- Na coluna Tipo, cada tipo usa badge uniforme, com caixa, padding, largura útil
  e alinhamento consistentes. Status permanece em chip tabular canônico.
- No desktop, o preview lateral pertence a um contêiner auxiliar único, com
  cabeçalho, simulação e resumo organizados por paddings, raios e gaps
  tokenizados, sem competir com a tabela.
- Criar/Editar Instituição e Unidade são a baseline do fluxo:
  `SuperadminFormStepNavigation`, campos Coelo e
  `SuperadminFormActionFooter`.
- Popup de Bug/Ajustar foto define a shell da prévia: `surface`, tint
  transparente, barreira contrastante, fechamento negativo e ações iguais.
- Admin e Principal não são alterados por esta entrega.

## Responsividade e acessibilidade

Decisões usam `LayoutBuilder` e largura disponível. Validar 375, 768, 1024 e
1440 px. Compacto usa uma coluna e resumo da etapa; medium/wide preservam
navegação lateral e conteúdo limitado em largura. Texto a 200% não esconde
etapa, erro ou ação. Foco visível, teclado, toque, alvos de 48 px, contraste
4.5:1 e reduced motion são obrigatórios.

## Entidades, permissões e tenant

`PlatformNotice` e `NoticeDraft` preservam os contratos existentes e passam a
representar também o tipo da comunicação, conteúdo, prioridade, estado,
vigência, audiência, comportamento, destinos, recorrência, orientação, tons e
aparência tipada. A produção usa contrato assíncrono e adapter Supabase; fake
fica restrito a testes isolados.

Produção exige perfil interno autorizado, audiência resolvida server-side e
congelada ao publicar, isolamento entre tenants e auditoria minimizada. O
cliente não amplia audiência nem usa metadados mutáveis como autorização.
Salvar e publicar são comandos idempotentes, versionados e transacionais.
A publicação congela a audiência e cria um job. Um cron versionado aciona uma
Edge Function autenticada por segredo, que materializa a audiência em páginas
limitadas e só então ativa a comunicação. Jobs obsoletos, pausados ou com lease
expirada falham fechados ou voltam para retry; itens cuja vigência terminou
falham antes da materialização. O Flutter nunca executa o worker.

Cada geração de audiência pertence ao `publication_job_id` e à versão congelada
da comunicação. A comunicação aponta para sua publicação corrente; diretório,
detalhe e métricas agregam somente os recibos dessa geração. Republicar preserva
o histórico anterior para auditoria, sem misturar destinatários ou métricas com
a nova publicação.

## Matriz de aplicabilidade aprovada em 2026-08-11

| Tema | Decisão para Avisos |
| --- | --- |
| Aparência | Aplica: fundo, texto, CTA, tamanho, tela cheia, inset e preview real. |
| Herança | Não aplica. |
| Localização/contato | Não aplica. |
| Representantes, admins e profissionais | Aplica somente como vínculos/papéis de audiência. |
| Pessoas/perfis | Aplica: pessoa global e vínculo contextual pesquisado no servidor. |
| Tipos/subtipos | Enum fechado `Aviso`, `Conteúdo`, `Destaque` e `Para você`; sem subtipo livre ou `Outros`. |
| Status | Aplica como `Status do aviso`: rascunho, agendado, ativo, pausado, expirado e inativo. |
| Hierarquia | Aplica: instituição → unidade → turma, validada no servidor. |
| Plano | Não aplica como edição; eventual filtro é somente regra server-side autorizada. |
| Import/export | Não aplica ao construtor; não haverá ação de arquivo demonstrativa. |
| Mídia | Bloqueada até decisão Storage × R2; texto continua disponível. |
| Perfil público/descoberta | Não aplica. |

Avatar, capa, bio, `@`, destaques, entitlement de fotos e descoberta pública
não pertencem ao domínio de Avisos.

## Estados de UX

- Diretório: loading, conteúdo, vazio, sem resultados, erro e sem permissão.
- Formulário: inicial, alterado, erro por etapa, salvando, rascunho salvo,
  agendado/publicado e falha sem perder dados.
- Controles: default, hover, foco, pressed, selected, open e disabled.
- Prévia: popup para Aviso; card administrativo para os demais tipos. Apenas
  Aviso oferece os três comportamentos de aceite.

## Ciclo de vida

- Novo aviso nasce em rascunho.
- Publicar move o rascunho para agendado e enfileira a materialização.
- Ao alcançar o início, o worker cria os recibos de audiência e só ativa a
  comunicação após concluir todo o job.
- Ativo pode ser pausado; somente pausado pode ser reativado.
- Ativo ou agendado expira automaticamente ao alcançar o término.
- Rascunho, agendado, ativo ou pausado pode ser inativado manualmente.
- Expirado e inativo são terminais no MVP; duplicar cria novo rascunho.

### Decisão de cutover interno — 2026-09-01

O vocabulário canônico e exclusivo para novas escritas é `draft`, `scheduled`,
`active`, `paused`, `expired` e `inactive`. O cutover forward-only converte
linhas legadas `published` para `active` e `archived` para `inactive`; esses
dois labels legados podem permanecer fisicamente no enum PostgreSQL, mas não
podem ser gravados nem devolvidos pelas RPCs v2. `expired` e `inactive` são
terminais.

No localhost produtivo do Superadmin, Avisos usa exclusivamente a identidade
interna da ADR 0019/spec 039 e wrappers RPC v2 com envelope estável. Leitura é
permitida a Owner, Conteúdo e Operações com vínculo global; criação, edição,
publicação e transições são exclusivas de Owner e exigem AAL2. Vínculos com
escopo institucional, identidades exclusivas de Admin/Principal e acesso direto
às tabelas falham fechados. O texto persiste e publica normalmente; mídia
continua bloqueada até existir um gateway Cloudflare R2 aprovado.

## Eventos, logs e notificações

Produção registra no backend resumos minimizados para salvar, publicar, pausar,
reativar e inativar. Logs não incluem mensagem integral, mídia, PII ou
destinatários. Entrega, leitura e aceite ficam em recibos/eventos operacionais
protegidos, separados da trilha administrativa append-only.
Criar um receipt materializa o destinatário, mas não preenche `delivered_at`;
esse timestamp pertence ao runtime que realmente entregar ou exibir o item.
O receipt nasce `pending`, registra separadamente `materialized_at`, job e
versão, e só avança para entregue, visualizado ou aceito por evento real do
runtime consumidor.

## Critérios de aceite

1. Diretório e editor nunca aparecem na mesma composição.
2. As cinco etapas preservam o rascunho ao avançar e voltar.
3. Texto sobre fundo ou uma imagem horizontal/vertical e cores têm prévia
   legível.
4. Audiência, destinos, vigência, recorrência e comportamento são revisados
   antes de publicar.
5. As transições locais cobrem rascunho, agendamento/publicação, pausa,
   reativação, expiração e inativação.
6. A matriz responsiva, light/dark, teclado, toque e texto a 200% passa.
7. Cor não é o único indicador e nenhum widget Material cru proibido entra.
8. Valores legados `popup`, `notice` e `critical_notice` são lidos como Aviso;
   `content_card` é lido como Conteúdo, sem migração destrutiva.
9. O tipo pode mudar em rascunho, agendado ou pausado, com revalidação e
   remoção das configurações exclusivas de popup quando deixar de ser Aviso.
10. O diretório não expõe toggle Cards/Tabela: mobile usa lista compacta
    automática e tablet/desktop usam tabela, preservando filtros, categoria,
    ordenação e paginação.
11. A tabela de Comunicações é uma composição literal da tabela de
    Instituições, sem substituto local ou aproximação de alinhamento,
    tipografia, densidade e estados.
12. Criação, coluna Tipo, filtros, respiro anterior à tabela e contêiner do
    preview obedecem ao contrato visual aprovado em 2026-08-31.

## Testes exigidos

- Widget tests do diretório, filtros, paginação, tabela, lista compacta, status
  tabular e flyout.
- Widget tests do wizard, validação, preservação e rodapé.
- Prévia para três destinos, duas orientações e três comportamentos.
- Transições do repositório fake.
- Audiência hierárquica com papel opcional, isolamento cross-tenant, escolha
  única de destino e cada variante da recorrência fechada.
- Métricas restritas a alcance, entrega, visualização e aceite.
- Republicação cria uma geração independente de receipts; métricas da
  publicação corrente não reutilizam entregas de versões anteriores.
- Vigência encerrada falha fechada antes de criar novos receipts ou ativar o
  item.
- Goldens mobile light e desktop dark, mais estados interativos dedicados.
- Validador visual administrativo, analyzer focado e suíte da feature.

## Riscos e perguntas abertas

- Pixels, proporção, tamanho máximo, crop, compressão e persistência dependem do
  spike/spec de Cloudflare R2.
- Prioridade entre múltiplos avisos e frequência por destinatário dependem da
  futura spec de execução server-side.
