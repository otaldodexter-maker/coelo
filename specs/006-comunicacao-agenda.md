---
title: "Agenda institucional do Superadmin"
source: "decisions/0028-superadmin-agenda-product-surface.md; docs/product/prd-master.md; docs/product/prd-superadmin.md; docs/architecture/domain-map.md; docs/design/design-system.md; docs/design/references/superadmin-agenda-approved-2026-08-31.png; decisões explícitas do Owner em 2026-08-31 e na conversa Codex 01a05d88-3187-79a3-9443-218a0c5cb8ae em 2026-09-01"
status: "approved-for-flutter-ui"
generated_at: "2026-09-01"
---

# Agenda institucional do Superadmin

## Objetivo e autoridade

Este contrato autoriza exclusivamente Flutter/Dart, UI/UX e fixtures
determinísticas de `/dev` para a Agenda institucional produtiva em
`apps/superadmin`. Ele substitui o escopo anterior em `apps/admin` e
`apps/principal` no recorte vigente.

Backend e integração produtiva permanecem fora de escopo. Rotas normais devem
usar a mesma composição visual de `/dev` e permanecer fail-closed quando a ação
depender de persistência ou autorização remota.

## Navegação e composição

- As visões principais são `Calendário` e `Lista`.
- `Criar evento` é subitem de Agenda e não uma ação preenchida no cabeçalho.
- `Solicitações` contém RSVP, ciência e autorização vinculados ao evento.
- `Aprovações` contém pedidos de publicação de eventos.
- No desktop, Lista usa timeline cronológica, data lateral e cards de evento.
- Tablet e mobile usam calendário mensal contínuo.
- Selecionar um dia abre eventos agrupados por horário.
- No mobile, o detalhe diário ocupa a tela; no tablet/web, abre em painel lateral
  expansível.
- Não existe visão Semana nesta entrega.
- Shell, containers, calendário, tokens e componentes canônicos Coelo são
  obrigatórios.
- A anatomia vinculante é
  `docs/design/references/superadmin-agenda-approved-2026-08-31.png`.

## Tipos de evento

O catálogo fechado desta entrega contém:

- evento;
- rotina recorrente;
- aniversário;
- feriado/recesso;
- compromisso;
- prazo;
- alteração operacional;
- reserva;
- outro.

## Campos, contexto e audiência

- São obrigatórios: título, tipo, contexto principal, audiência e início/fim ou
  dia inteiro.
- Cada evento possui exatamente um contexto principal: instituição, unidade,
  turma, atividade ou pessoa.
- A audiência pode ser refinada por perfis e pessoas dentro do contexto
  autorizado.
- Descrição, local e anexo são opcionais.
- IDs, filtros e contexto enviados pelo cliente nunca constituem autorização.

## Lifecycle e ações negativas

- O fluxo é `rascunho → agendado | publicado → cancelado`.
- Um evento cancelado pode ser restaurado, preservando o histórico.
- Apenas rascunhos podem ser excluídos.
- Um evento que já foi publicado nunca é apagado.
- Cancelar, restaurar e excluir exigem confirmação e feedback.
- Falhas preservam o estado e os dados locais.
- Toda transição relevante aparece no histórico visual.

## Recorrência, ocorrência e tempo

- Recorrência diária, semanal ou mensal.
- Término por data ou quantidade.
- Edição de somente esta ocorrência, esta e próximas, ou toda a série.
- O fuso padrão é o IANA da instituição.
- Alterar o fuso é uma decisão explícita e visível.
- Evento de dia inteiro não mostra horário.
- Exceções e alterações preservam vínculo e histórico da série.

## Conflitos

- Conflito comum gera aviso e permite decisão consciente.
- Conflito de reserva bloqueia a conclusão.
- Sobrescrever conflito de reserva exige capability específica, justificativa
  obrigatória e histórico.
- A UI produtiva não simula aceite do backend.

## Respostas do evento

Cada evento escolhe exatamente um modo:

- nenhum;
- RSVP: Sim, Não ou Talvez;
- Ciência;
- Autorização: Autorizo ou Não autorizo.

O criador escolhe entre `um responsável basta` e `todos devem responder`; `um
responsável basta` vem marcado por padrão. Quando um responsável responde, os
demais recebem aviso no sininho e visualizam a resposta registrada.

A Agenda compõe a experiência, mas não transforma autorização simples em
ownership do domínio D14.

## Perguntas do evento

- O criador pode incluir perguntas opcionais junto à descrição do evento.
- O catálogo fechado desta etapa contém resposta curta e Sim ou Não.
- Toda pergunta adicionada exige título não vazio; perguntas vazias devem ser
  preenchidas ou removidas antes de salvar ou publicar.
- Perguntas não devem solicitar dados sensíveis ou conteúdo incompatível com o
  melhor interesse da criança.
- Persistência, respostas, retenção e autorização dessas perguntas dependem do
  contrato backend futuro e permanecem fora deste recorte local de UI.

## Publicação e aprovação

- Quem possui capability de publicar pode publicar ou agendar.
- Sem essa capability, a pessoa salva o rascunho e solicita publicação.
- Aprovar ou recusar exige estado visível, justificativa e histórico.
- `Solicitações` e `Aprovações` são superfícies distintas.

## Lembretes e notificações

- Opções: na publicação, 24 horas antes, 1 hora antes e horário customizado.
- Nesta etapa, o criador define somente quando lembrar. A seleção de canais não
  aparece no formulário; a estratégia de entrega permanece responsabilidade da
  plataforma até contrato posterior aprovado.
- Mudança relevante, cancelamento e restauração notificam automaticamente.
- O autor pode acrescentar mensagem opcional.
- Fixtures de `/dev` não representam entrega remota real.

## Capacidades

A fonte das capacidades é Perfis e Permissões:

- criar;
- editar próprios;
- editar todos;
- publicar;
- cancelar/restaurar;
- gerenciar respostas/autorizações;
- sobrescrever conflito de reserva.

Não existe uma tela autônoma de Permissões dentro da Agenda. O submenu Agenda
contém Criar evento, Solicitações e Aprovações; links legados de permissões
redirecionam para Perfis e Permissões, onde a regra é administrada.

A Agenda somente apresenta a capability efetiva. Ocultar ou desabilitar um
controle não constitui autorização; o backend futuro deverá revalidar ator,
tenant, contexto e recurso.

## Acesso direto

- Usar 404 quando a existência do recurso não puder ser revelada.
- Usar 403 quando o recurso for legitimamente conhecido, mas o acesso ou a ação
  não forem permitidos.
- `/dev` cobre conteúdo, loading, vazio, sem resultados, erro/retry,
  unauthorized, not-found e unavailable.
- Produção usa a mesma hierarquia visual e permanece fail-closed.

## Relação com Formulários

- Formulários não aparecem como eventos e não são editados na Agenda.
- Pendências de Formulários permanecem no sininho.
- Um evento pode conter link ou CTA para um Formulário.
- O CTA abre o fluxo próprio de Formulários.
- Recorrência, ocorrência e lembrete de Forms não são entidades de Agenda.

## Aniversários

- São gerados automaticamente a partir do cadastro e dos vínculos/hierarquia.
- A visibilidade respeita instituição, unidade, turma, atividade e vínculos que
  façam sentido para o contexto.
- Para crianças, exibir somente primeiro nome, contexto e foto autorizada.
- Nunca exibir idade nem ano de nascimento.
- Sem foto autorizada, usar fallback canônico sem inferir permissão.

## Paridade `/dev` e produção

- Mesmos widgets, composição, rotas e estados.
- `/dev` usa fixtures determinísticas e mutações locais para exercitar estados.
- Produção não apresenta sucesso falso; callbacks ausentes ou integrações não
  aprovadas resultam em fail-closed explícito.
- Esta entrega não introduz Supabase nem contratos backend.

## Action IDs

- `agenda.view`: calendário, lista, detalhe diário e acesso direto.
- `agenda.create`: criação.
- `agenda.detail`: detalhe, respostas e histórico.
- `agenda.edit`: edição, ocorrência/série, cancelar/restaurar e excluir rascunho.
- `agenda.request`: Solicitações e Aprovações.
- `agenda.permissions`: visualização das capacidades efetivas.

O estado máximo desta entrega é `local-green` visual/Flutter.

## Critérios de aceite e testes

- Validar 375, 768, 1024 e 1440 px.
- Validar light/dark e texto em 100%, 150% e 200%.
- Validar reduced motion, teclado, mouse, toque, foco, hover, seleção, menu aberto
  e retorno de foco.
- Cobrir loading, conteúdo, vazio, sem resultados, erro/retry, unauthorized,
  not-found e unavailable.
- Não admitir overflow.
- Cobrir rotas diretas, back/forward e reload.
- Confirmações negativas e falhas preservam dados locais.
- Gerar e inspecionar goldens Flutter reais antes de aceitar a baseline.
- Produção não usa fixtures nem comunica persistência ou autorização inexistente.

## Fora de escopo

- Supabase, Postgres, Auth, RLS, RPCs e migrations.
- Edge Functions, Storage, deploy e projeto remoto.
- `packages/coelo_database` e contratos backend novos.
- Entrega real de notificações.
- Persistência e autorização remotas.

## Perguntas abertas

Não há decisão de UI/UX pendente para o recorte aprovado em 2026-08-31.
Lacunas backend continuam fora de escopo e não impedem `local-green` Flutter.
