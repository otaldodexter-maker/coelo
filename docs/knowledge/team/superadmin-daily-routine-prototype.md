---
title: Rotina diária no Superadmin
knowledge_id: superadmin-daily-routine-prototype
source: specs/021-superadmin-daily-routine-prototype.md
status: validated
generated_at: 2026-08-06
audience: team
surfaces: [superadmin, daily-routine]
visibility: internal
review_owner: Coelo Product
---

# Rotina diária no Superadmin

`Modelo` é uma base reutilizável; `Rotina` é o objeto efetivamente utilizado. O mesmo diretório usa tabs lineares `Modelos` e `Rotinas`, com `Criar modelo` e `Nova rotina` contextualizados. Uma rotina pode nascer preenchida a partir de modelo, e a duplicação preserva o tipo e usa sufixo incremental normalizado.

Modelo Berçário, Modelo Fundamental, Modelo Médio, Modelo Pré e Modelo Maternal são fornecidos pelo Coelo: podem ser visualizados e duplicados, mas não editados nem excluídos. A cópia é editável.

Modelos têm origem institucional ou de unidade. Atividade é somente alcance contextual dentro dos grupos selecionados, nunca uma origem independente. Unidades podem manter a base, criar versão própria e acrescentar campos. Atualização opcional não sobrescreve a unidade. Mudança obrigatória preserva adicionais compatíveis, arquiva conflitos e gera notificação no sino compartilhado. Snapshots históricos continuam vinculados à versão efetivamente usada.

O cadastro possui identidade, alcance, seções e campos, e revisão/ativação; Participantes e Prévia não pertencem a esse fluxo. Campos de escolha aceitam valor inicial somente entre as opções cadastradas. Se uma opção inicial for removida, o salvamento exige nova escolha válida.

O suporte canônico de `Como chegou?` continua uma oportunidade para a aplicação cotidiana, fora do cadastro, sem schema ou comportamento novo nesta decisão.