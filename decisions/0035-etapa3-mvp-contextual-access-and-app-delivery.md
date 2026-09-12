---
title: "Etapa 3 do MVP: acesso contextual de funcionários e entrega dos apps"
source: "orientação explícita do Owner em 2026-09-12; decisions/0033-contextual-people-roles-and-family-contexts.md; decisions/0034-mvp-remote-application-and-acceptance-bar.md"
status: "approved-for-planning-not-implementation"
generated_at: "2026-09-12"
---

# ADR 0035 — Escopo reservado para a Etapa 3 do MVP

## Decisão e limite de execução

A Etapa 3 ainda faz parte da entrega do MVP. O Owner determinou registrar os
requisitos abaixo agora, sem iniciar código, SQL, telas, deploy ou migração de
superfícies dessa etapa. A Etapa 2 e suas rodadas continuam com seu recorte.
R09 é uma rodada da Etapa 2, não a Etapa 3.

Quando o Owner abrir explicitamente a Etapa 3, o coordenador deve revisar tudo
o que já está previsto para entregar o app: visão/PRDs, ADRs, specs, inventário,
rastreadores, implementações, provas e pendências remanescentes. Deve apresentar
uma proposta consolidada de escopo, ordem, dependências, aceites e estimativa
inspecionada antes de iniciar a implementação. Esta lista é entrada obrigatória
da proposta, não substitui a revisão do restante do MVP nem aprova uma spec técnica.

## Acesso contextual de funcionários

Prever uma nova tela, possivelmente em Acessos e Pessoas, que liste funcionários
cadastrados por instituição ou unidade. Para cada vínculo de funcionário, permitir:

- liberar ou restringir uso na web, tablet, mobile e aplicativo instalado no celular;
- definir dias da semana e intervalos de horário em que o uso é permitido;
- definir opcionalmente uma vigência de acesso, de uma data até outra, aplicável
  às superfícies indicadas, inclusive ao aplicativo instalado;
- configurar se aparece um popup informando o horário permitido e, opcionalmente,
  as datas da vigência. A exibição do aviso é uma opção administrativa.

Prever outra tela de afastamentos. O período registrado impede o acesso no
vínculo profissional afetado; o administrador pode habilitar um popup informando
que o funcionário está afastado do app entre as datas definidas.

O bloqueio pertence ao contexto de funcionário da instituição/unidade que o
configurou. A identidade global da pessoa, seu @ e sua sessão não são bloqueados
globalmente. A pessoa pode continuar como responsável ou como funcionário em
outros contextos autorizados, inclusive quando também tem vínculo de responsável
na instituição do vínculo profissional restringido. A troca para um contexto
permitido permanece disponível, sem expor dados do contexto bloqueado.

Horário, vigência e afastamento devem governar a autorização no servidor para
aquele vínculo, junto a RLS, capacidades, tenant e hierarquia. O popup é apenas
informativo: desabilitá-lo não desabilita a restrição. Navegação, filtros ou
identificação de dispositivo pelo cliente não constituem controle suficiente.
Preservar trilha de auditoria das alterações administrativas e validação do
escopo de quem configura a regra; detalhes serão definidos na spec futura.

## Tour e home com IA

- Fazer o recurso **Fazer tour** funcionar sobre os fluxos reais do app.
- Fazer a **home com IA para dúvidas sobre o app** funcionar de verdade,
  usando conhecimento aprovado e compatível com o que está implementado.

A proposta futura define audiências, permissões, integração, aceites e eventual
custo de provedor. Não simular resposta de IA como serviço funcional nem publicar
documentação de recurso planejado como funcionalidade disponível.

## Admin e Principal

Na Etapa 3, levar as páginas e fluxos aplicáveis para **admin.coelo.me** e
**app.coelo.me**, correspondentes a `apps/admin` e `apps/principal`, com adaptação
ao papel/contexto, composição e autorização de cada app. Não copiar indiscriminadamente
telas ou privilégios de Superadmin nem importar suas telas entre apps.

O objetivo inclui disponibilizar essas superfícies web; **publicação na Play Store
e Apple App Store fica fora desse momento**. A exigência de acesso controlado no
app instalado continua no desenho; forma de distribuição e validação antes das
lojas deverá ser proposta. Este registro não autoriza deploy agora.

## Pontos a propor quando a etapa abrir

Sem interromper a Etapa 2 para perguntar ou decidir agora:

- localização e composição das duas telas, permissões para administrar as regras;
- fuso horário, virada de dia, horários que cruzam meia-noite, múltiplas janelas,
  limites inclusivos das datas e comportamento sem configuração;
- alcance e precedência das regras de instituição/unidade sobre vínculos
  profissionais e conflitos entre horário, vigência e afastamento;
- distinção verificável entre web/mobile/tablet/app instalado, limitações de
  identificação e comportamento de sessão ativa, cache e acesso offline;
- frequência/conteúdo dos popups, retorno ao contexto permitido e privacidade;
- roteiro do tour, fonte/limites/avaliação das respostas da IA, páginas a levar
  a cada app, distribuição fora das lojas e plano de publicação autorizado.

Aceites devem incluir funcionário restringido no contexto A que segue usando
seu contexto familiar e seu vínculo profissional B; tentativas de acesso a A
continuam negadas pelo backend. Registrar provas de limites temporais e
hierarquia conforme a spec, sem converter essa lista em tarefa da Etapa 2.
