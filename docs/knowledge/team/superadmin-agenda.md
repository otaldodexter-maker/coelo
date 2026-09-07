---
title: Agenda institucional do Superadmin
knowledge_id: superadmin-agenda
source: specs/050-superadmin-agenda-backend.md
status: validated
generated_at: 2026-09-01
updated_at: 2026-09-07
audience: team
surfaces: [superadmin, agenda, events, permissions, notifications]
visibility: internal
review_owner: Coelo Product
---

# Agenda institucional do Superadmin

Fontes complementares: `specs/006-comunicacao-agenda.md` e
`decisions/0029-superadmin-agenda-backend-authorization.md`.

A Agenda institucional produtiva do recorte vigente existe exclusivamente no
Superadmin. Admin e Principal não recebem telas ou rotas de Agenda nesta versão.
A ADR 0029 supera a limitação anterior a Flutter/Dart, UI/UX e fixtures de
`/dev`: o recorte aprovado inclui backend produtivo e integração no Superadmin,
conforme a spec 050. Essa autorização não comprova implantação nem conclusão
E2E. Rotas produtivas só deixam de ser fail-closed mediante evidência remota de
autorização, isolamento e persistência. Entrega real por canal de notificação
continua fora do contrato.

A navegação oferece Calendário e Lista. Criar evento é subitem de Agenda, não
ação preenchida no cabeçalho. A Lista web usa timeline com data lateral e cards;
tablet e mobile usam calendário mensal contínuo. Selecionar um dia abre detalhe
cronológico em tela inteira no mobile e painel lateral expansível no tablet/web.
Não há visão Semana nesta entrega.

Os tipos são evento, rotina recorrente, aniversário, feriado/recesso,
compromisso, prazo, alteração operacional, reserva e outro. Cada evento possui
um contexto principal e audiência refinada por perfis ou pessoas. O lifecycle é
rascunho, agendado/publicado e cancelado; cancelados podem ser restaurados,
somente rascunhos podem ser excluídos e o histórico é preservado.

A recorrência pode ser diária, semanal ou mensal, com término por data ou
quantidade e edição por ocorrência, ocorrências futuras ou série. O fuso padrão
é o IANA da instituição. Conflitos comuns geram aviso; reservas conflitantes são
bloqueadas e só podem ser sobrescritas por capability específica, justificativa
e histórico.

Cada evento escolhe nenhum retorno, RSVP, ciência ou autorização. O criador
define se uma resposta por criança basta — opção padrão — ou se todos os
responsáveis devem responder. Solicitações reúne esses retornos; Aprovações
reúne pedidos de publicação de quem pode criar, mas não publicar.

O evento pode incluir perguntas opcionais de resposta curta ou Sim/Não junto à
descrição. Toda pergunta adicionada exige título e não deve solicitar dados
sensíveis. A spec 050 inclui persistência, respostas e autorização server-side;
a retenção jurídica detalhada das respostas permanece pendente de contrato
próprio.

Na criação, o autor escolhe quando lembrar (publicação, 24 horas antes, 1 hora
antes ou horário personalizado). A seleção de canais não integra o formulário
nesta etapa; a estratégia de entrega fica sob responsabilidade da plataforma
até contrato posterior aprovado.

Perfis e Permissões é a fonte das capacidades de criar, editar próprios, editar
todos, publicar, cancelar/restaurar, gerenciar respostas e sobrescrever conflito
de reserva. A Agenda apenas apresenta o acesso efetivo; o backend deve revalidar
ator, tenant, contexto e recurso em cada leitura e escrita.

Por isso, a Agenda não possui uma tela própria de permissões. Seu submenu termina
em Aprovações e URLs antigas de permissões levam a Perfis e Permissões.

Formulários não aparecem nem são editados na Agenda. Um evento pode conter CTA
para abrir um Formulário no fluxo próprio, e pendências de Forms permanecem no
sininho. Autorizações formais continuam owned pelo domínio D14.

Aniversários são derivados dos cadastros e respeitam hierarquia e vínculos. Para
crianças, a Agenda mostra somente primeiro nome, contexto e foto autorizada,
nunca idade ou ano de nascimento.

`/dev` e produção compartilham widgets, composição, rotas e estados. `/dev` usa
fixtures locais; produção permanece explicitamente fail-closed onde faltar
integração e nunca apresenta sucesso remoto falso.
