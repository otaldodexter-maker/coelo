---
title: "Decisão do Owner de 10/09/2026 — rodapé ancorado e chat fora das telas de edição"
source: "resposta do Owner à página de comparação https://claude.ai/code/artifact/555d48fb-f427-4aa3-9710-71c22ac9acdc"
status: "decidida e em implementação pelo grupo estrutura"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# O que o Owner decidiu

**Rodapé (opção A).** Fixar o rodapé no fim da tela em mobile, para os quatro
formulários. É o que a referência de Turmas e Atividades mostra, e alinha o
mobile com o desktop, que já fixa. O Owner aceitou explicitamente a consequência:
o golden de Instituições em 375 muda junto e precisa ser regravado, apesar de ter
sido aceito como A.

**Chat (regra nova).** O botão de chat não deve aparecer em telas de criar,
editar e publicar, nem no Agora aberto e no Momentos aberto.

Ambas foram gravadas nas skills: o contrato de rodapé e a regra do chat em
`.agents/skills/coelo-ui/references/form-layout-contracts.md`, e a parte de
Agora/Momentos em `.agents/skills/coelo-ui/references/principal-visual-surfaces.md`.

# Duas consequências que atravessam grupos

**1. O rodapé é do frame compartilhado, e ele serve 19 formulários.**
`SuperadminFormFrame` é usado por access_profiles, activities, agenda,
assessments, daily_routine, forms, groups, health_care (dois), imports,
institutions, invites, meal_plans, notices, people, platform_users, safety e
units. Aplicar a decisão no frame — que é o certo, porque o conceito de família
vive uma vez no componente compartilhado — muda o render mobile dos dezenove, não
só dos quatro do recorte de Estrutura.

Os goldens mobile de formulário dos outros grupos vão divergir. Isso não é
regressão: é a decisão do Owner chegando neles. Cada grupo precisa reconhecer a
mudança e regravar os seus, e o coordenador precisa saber disso antes de tratar a
divergência como conflito.

**2. A regra do chat vale além de Estrutura.** Apliquei
`showChatLauncher: false` nos quatro formulários do meu recorte: Instituições,
Unidades, Turmas e Atividades. Continuam faltando, em outros grupos:

- o Agora aberto e o Momentos aberto, do grupo `principal-chat-sistema`;
- os fluxos de publicação;
- estas telas de criar/editar de outros grupos, que montam o `SuperadminShell`
  diretamente e ainda não passam `showChatLauncher: false`:
  `access_profiles/access_profile_form_page.dart`,
  `access_profiles/access_profile_duplicate_page.dart`,
  `daily_routine/daily_routine_form_sections.dart`,
  `health_care/health_care_form_pages.dart`,
  `health_care/health_medication_plan_form_page.dart`,
  `invites/invite_form_page.dart`,
  `people/person_form_page.dart`,
  `platform_users/platform_user_form_page.dart`.

A lista acima cobre quem monta o shell diretamente. Telas que herdam o shell de
um pai, ou que usam só o `SuperadminFormFrame`, precisam de conferência própria
pelo grupo dono — não consigo decidir por elas sem abrir cada composição.

# Correção de rumo neste grupo

Mais cedo nesta rodada eu tinha feito o oposto: corrigi o formulário de
Atividades para **mostrar** o balão de chat, porque a regra transversal CHAT da
lista de decisões dizia que o chat segue a referência guardada em todas as
larguras, e a referência mostra o balão. A decisão do Owner inverte isso para
telas de edição. A palavra dele vence a referência guardada, e a linha do
`onDestinationSelected` que eu havia ajustado continua correta pelo motivo certo
— navegação do menu não deve depender de o chamador ter passado callback — mas
não é mais justificada pelo chat.
