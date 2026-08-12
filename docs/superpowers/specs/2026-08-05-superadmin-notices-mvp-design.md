---
source: "docs/product/prd-superadmin.md; specs/010-superadmin-completo-v1-technical-spec.md; specs/012-superadmin-mvp.md; docs/design/design-system.md; aprovações do Owner Coelo em 2026-08-05 e 2026-08-11"
status: "approved-design"
generated_at: "2026-08-11"
---

# Avisos do Superadmin no MVP

## Objetivo e problema

Refatorar Avisos como experiência administrativa para criar, revisar, agendar
e acompanhar popups oficiais do Coelo. A implementação atual mistura diretório
e formulário, enfraquecendo a hierarquia e a revisão antes da publicação.

O MVP passa a incluir um construtor controlado. Ele não se torna uma plataforma
genérica de campanhas nem um editor livre de layouts.

## Escopo aprovado

- Diretório exclusivo, sem formulário aberto junto à listagem.
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
- Prévia responsiva fiel ao popup entregue, inclusive CTA, cor do botão,
  tamanhos compacto, padrão, expandido e tela cheia e espaçamento externo.
- Dados, alcance, entrega, visualização e aceite vêm do backend; produção não
  usa fixtures, métricas inventadas nem sucesso local.

## Fora de escopo

- Drag-and-drop, HTML, blocos livres, carrossel ou múltiplas telas.
- Jornadas, gatilhos comportamentais e regras AND/OR arbitrárias.
- A/B testing, personalização, localização e analytics avançado.
- Upload de imagem enquanto a decisão Supabase Storage versus Cloudflare R2
  permanecer aberta. Publicação de imagem falha fechada e não exibe placeholder.

## Superfícies e direção visual

- `apps/superadmin`: diretório, criação/edição e prévia de Avisos.
- Instituições é a baseline do diretório: toolbar, busca, filtros,
  `CoeloAdminCreateAction`, `CoeloAdminInteractiveCard`, status expansível,
  `CoeloAdminFlyout` e paginação.
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

`PlatformNotice` e `NoticeDraft` representam conteúdo, prioridade, estado,
vigência, audiência, comportamento, destinos, recorrência, orientação, tons e
aparência tipada. A produção usa contrato assíncrono e adapter Supabase; fake
fica restrito a testes isolados.

Produção exige perfil interno autorizado, audiência resolvida server-side e
congelada ao publicar, isolamento entre tenants e auditoria minimizada. O
cliente não amplia audiência nem usa metadados mutáveis como autorização.
Salvar e publicar são comandos idempotentes, versionados e transacionais.

## Matriz de aplicabilidade aprovada em 2026-08-11

| Tema | Decisão para Avisos |
| --- | --- |
| Aparência | Aplica: fundo, texto, CTA, tamanho, tela cheia, inset e preview real. |
| Herança | Não aplica. |
| Localização/contato | Não aplica. |
| Representantes, admins e profissionais | Aplica somente como vínculos/papéis de audiência. |
| Pessoas/perfis | Aplica: pessoa global e vínculo contextual pesquisado no servidor. |
| Tipos/subtipos | Aplica apenas enum fechado de aviso; sem subtipo livre ou `Outros`. |
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
- Prévia: texto sobre fundo, imagem horizontal, imagem vertical e os três
  comportamentos de aceite.

## Ciclo de vida

- Novo aviso nasce em rascunho.
- Rascunho publicado imediatamente fica ativo; com início futuro, agendado.
- Agendado fica ativo ao alcançar o início.
- Ativo pode ser pausado; somente pausado pode ser reativado.
- Ativo ou agendado expira automaticamente ao alcançar o término.
- Rascunho, agendado, ativo ou pausado pode ser inativado manualmente.
- Expirado e inativo são terminais no MVP; duplicar cria novo rascunho.

## Eventos, logs e notificações

Produção registra no backend resumos minimizados para salvar, publicar, pausar,
reativar e inativar. Logs não incluem mensagem integral, mídia, PII ou
destinatários. Entrega, leitura e aceite ficam em recibos/eventos operacionais
protegidos, separados da trilha administrativa append-only.

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

## Testes exigidos

- Widget tests do diretório, filtros, paginação, cards, status e flyout.
- Widget tests do wizard, validação, preservação e rodapé.
- Prévia para três destinos, duas orientações e três comportamentos.
- Transições do repositório fake.
- Audiência hierárquica com papel opcional, isolamento cross-tenant, escolha
  única de destino e cada variante da recorrência fechada.
- Métricas restritas a alcance, entrega, visualização e aceite.
- Goldens mobile light e desktop dark, mais estados interativos dedicados.
- Validador visual administrativo, analyzer focado e suíte da feature.

## Riscos e perguntas abertas

- Pixels, proporção, tamanho máximo, crop, compressão e persistência dependem do
  spike/spec de Cloudflare R2.
- Prioridade entre múltiplos avisos e frequência por destinatário dependem da
  futura spec de execução server-side.
