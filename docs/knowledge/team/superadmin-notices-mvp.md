---
title: Avisos do Superadmin MVP
knowledge_id: superadmin-notices-mvp
source: docs/superpowers/specs/2026-08-05-superadmin-notices-mvp-design.md
status: validated
generated_at: 2026-08-05
audience: team
surfaces: [superadmin, notices]
visibility: internal
review_owner: Coelo Product
---

# Avisos do Superadmin MVP

Avisos oficiais da plataforma são diferentes dos avisos familiares de
assiduidade. O módulo permite que equipe Coelo autorizada crie popups globais
com um alvo global, instituição, unidade ou turma e papel opcional.
Audiência e autorização produtivas são sempre resolvidas server-side.

O MVP usa um construtor controlado em cinco etapas: identidade; conteúdo e
aparência; público e dispositivos; exibição e recorrência; revisão e
publicação. A composição aceita texto sobre fundo ou uma única imagem
horizontal/vertical, com cores Coelo e contraste validado.

O destino é uma escolha única entre web, mobile, tablet ou todos. A vigência
pode ter início e fim, com recorrência única, diária, semanal, mensal por dia do
mês ou por intervalo inteiro de dias. Os estados são
rascunho, agendado, ativo, pausado, expirado e inativo.

O aviso pode ser dispensável, exigir confirmação ou exigir checkbox de ciência
seguido de confirmação. Aviso obrigatório reaparece até o aceite e pode
bloquear a navegação, mas nunca impede a saída do app. Conteúdo crítico é
separado de conteúdo opcional silenciável.

Métricas básicas agregam alcance, entrega, visualização e aceite. Auditoria
registra apenas resumos minimizados das mutações, sem PII, destinatários, mídia
ou mensagem integral.

O protótipo local não representa envio, upload/R2, recibos, autorização ou
auditoria produtivos. Também não autoriza editor livre, HTML, carrossel,
jornadas, gatilhos comportamentais, regras AND/OR arbitrárias, A/B testing,
personalização, localização ou analytics avançado.
