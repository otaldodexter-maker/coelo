---
source: Owner e seis anexos de Saúde e Cuidado na conversa de 2026-09-13; specs/020-superadmin-health-care.md; specs/049-superadmin-internal-care-profile-crud-v2.md
status: backlog R12; sem implementação
generated_at: 2026-09-13
---

# R12 — Perfis de cuidado e medicação

Quarto bloco de R12-apontamentos-owner.md. Fora da execução R11. Host:
apps/superadmin > Saúde e Cuidado; família administrativa, wizard de Instituições.
Seis anexos vistos na conversa; binários não exportados e dados pessoais não
transcritos. Responsável: C0 R12, após abertura explícita.

| ID / anexos | Tela/subtela e action_ids | Requisito / primeiro gate |
|---|---|---|
| R12-28 / 1 | Perfis de cuidado > Editar > Criança; health-care.edit | Exibir nome real da criança que está sendo editada no campo bloqueado; hoje aparece Perfil de cuidado. Conferir leitura/associação e reload sem permitir troca de criança. |
| R12-29 / 2 | Criar/Editar > Alergias e restrições; health-care.create, health-care.edit, health-care.detail | Criança pode ter vários registros. Ação Adicionar restrição abaixo do formulário e tabela dos itens cadastrados, com criar, consultar, editar e excluir individualmente. Não sobrescrever item anterior ao adicionar. Conferir como diferenciar alergia/restrição e identificar o agente/item, além de tipo/status/episódio. |
| R12-30 / 3 | Criar/Editar > Orientações de cuidado; health-care.create, health-care.edit, health-care.detail | Mesmo conceito: múltiplas orientações, adicionar e tabela com CRUD por item. Manter sinais, adaptações e orientações relacionados ao item correto, sem reduzir a um único bloco sobrescrito. |
| R12-31 / 4–6 | Planos de medicação > Criança/medicamento, Vigência, Horários/responsáveis; medication.create, medication.edit | Padronizar inputs de data/hora, dias da semana, via, dose/unidade e responsável; corrigir rótulos cortados, altura e alinhamento pelos componentes canônicos. Estado Nenhuma opção disponível do responsável exige verificar contrato/lista, não inventar nomes. |
| R12-32 / 4–6 + relato | Medicação > Lista/Detalhe/horários; medication.list, medication.detail, medication.create, medication.edit | Visão deve reunir todos os medicamentos da criança a administrar no período, dentro da instituição/unidade autorizada; não mostrar só o plano isolado. Identificar instituição, unidade, turma e responsáveis que administrarão cada ocorrência/horário. Conferir vínculos reais, vigência e escopo de consulta versus administração. |
| R12-33 / relato | Medicação > contexto responsável e notificações; medication.create, medication.edit, medication.detail (notificações: mapear ação específica) | Instituição/unidade/turma responsáveis devem receber notificação. Definir eventos e destinatários autorizados no servidor por vínculo/capacidade, e registrar entrega/ciência separadas da administração. Não enviar para todos os membros da instituição/turma. |

## Direção aprovada e detalhes a desenhar

O Owner solicita múltiplos registros com CRUD para alergias/restrições e orientações,
nome da criança identificável na edição, inputs padronizados, visão de medicações
por período e contexto, responsáveis de administração e notificações aos contextos
responsáveis. Implementação e modelo técnico ainda precisam ser inspecionados.

A spec 020 já separa perfil permanente de doses periódicas e atribui cada horário
à casa ou instituição. Usar essa base; o pedido explicita unidade/turma e visão
consolidada de vários planos. Não copiar plano integral por tenant para simular
alcance, nem conceder acesso ao histórico privado de outra instituição.

Proposta de apresentação a validar: criança/contexto/período no topo; tabela de
ocorrências com horário, medicamento, dose/unidade, via, unidade/turma responsável,
responsável e situação real. Não combinar doses ou medicamentos distintos; não
inferir prescrição nem ajustar horários/doses clinicamente. Registro/claim de dose
e recibo de ciência continuam distintos; evitar duplicidade ao haver mais de um
profissional/contexto. Mudanças preservam histórico e versão conforme contrato.

Questões de desenho ainda abertas:
- CRUD exclui item ativo da lista, mas precisa respeitar histórico/auditoria;
  definir exclusão lógica/arquivamento conforme contrato sem apagar provas antigas.
- Separar Adicionar item ao rascunho de Salvar alterações persistidas; proposta
  deve tornar isso visível e proteger cancelamento/edição sem perda dos demais itens.
- Definir quais eventos notificam (novo plano, alteração, suspensão e/ou lembrete
  de horário), antecedência/canal e quem responde no contexto. O pedido de receber
  notificação está aprovado; esses detalhes não foram definidos.
- Conferir se turma é obrigatória ou contextual quando administração ocorre pela
  equipe da unidade; não restringir nem ampliar a regra por inferência.
- Conteúdo de notificação deve ser mínimo; detalhe de saúde só após autorização.

## FE / BE / E2E e handoff

FE: requisitos planejados, nada corrigido agora. BE: verificar suporte atual a
coleções, identidade dos itens, persistência, versões, contexto por horário,
responsáveis e eventos. Anexos não confirmam causa backend. E2E: provar múltiplos
itens após salvar/reload, editar/excluir um preservando outros, vários medicamentos
no mesmo período e contextos diferentes, negação de acesso cruzado, destinatários
corretos e ocorrência sem duplicação. Usar exclusivamente massa sintética de QA.

R12-saude-cuidado-delta.json contém deltas propostos, NÃO aplicados: C0 central
rebaseia notas atuais antes de apply-tracker-delta.cjs e incorpora ownerItems no
manifesto. Notificações exigem mapeamento específico antes de contabilização.
Não alterar denominadores/certificações por este registro. Preservar WIP R11;
integração nos três rastreadores permanece pendência do integrador. Sem SQL,
notificação real, build, deploy ou implementação de R12 neste turno.
